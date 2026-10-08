"""Story Studio: a local workbench for the script, the voices and the bake.

  python tools/studio/server.py            # then open http://127.0.0.1:4317
  python tools/studio/server.py --port 5000 --no-browser

Standard library only. Listens on 127.0.0.1. Every button runs one of the
commands in ACTIONS (the same commands documented in CLAUDE.md), shown verbatim
with its log. docs/STORY_STUDIO.md has the plan this follows.
"""
import argparse
import hashlib
import json
import mimetypes
import os
import subprocess
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio import model, review, writers  # noqa: E402

ROOT = model.ROOT
STATIC = Path(__file__).resolve().parent / "static"
SCRATCH = ROOT / "build/studio/scratch"
VENV = ROOT / "build/voice/venv/Scripts/python.exe"
CB_VENV = ROOT / "build/voice/cb-venv/Scripts/python.exe"
GODOT = Path(os.environ.get("STUDIO_GODOT", str(Path.home() / "scoop/apps/godot-mono/4.7.2/godot-mono.console.exe")))
AUDIO_ROOTS = [ROOT / "assets/audio/voice", SCRATCH, ROOT / "tools/voice/ref"]


def _python():
    return str(VENV if VENV.exists() else Path(sys.executable))


def _actions():
    py = _python()
    godot = str(GODOT)
    probe = lambda name: [godot, "--headless", "--path", ".", f"tools/{name}_probe.tscn"]  # noqa: E731
    actions = [
        ("validate", "Check every script", "check", [
            [py, "tools/script_to_lines.py", "--check"],
            [py, "tools/bake_mathilda.py", "--check"],
            [py, "tools/bake_lake.py", "--check"],
            [py, "tools/bake_meeting.py", "--check"],
            [py, "tools/dialogue_post.py", "--check"]]),
        ("tables", "Write the line tables from the scripts", "check", [
            [py, "tools/script_to_lines.py"],
            [py, "tools/bake_lake.py", "--write"],
            [py, "tools/bake_meeting.py", "--write"]]),
        ("paths", "Doorway meeting: every path as text", "check", [[py, "tools/bake_meeting.py", "--paths"]]),
        ("bake_mathilda", "Bake Mathilda's chapter (Kokoro)", "bake", [[py, "tools/bake_mathilda.py"]]),
        ("bake_lake", "Bake the lake, Mathilda's side (Kokoro)", "bake", [[py, "tools/bake_lake.py"]]),
        ("meeting_drafts", "Doorway drafts for both (Kokoro)", "bake", [[py, "tools/bake_meeting.py", "--engine", "kokoro"]]),
        ("ophelia_final", "Ophelia's owed lines (Chatterbox, desktop)", "desktop", [[str(CB_VENV), "tools/bake_speech.py"]]),
        ("meeting_final", "Doorway finals (Chatterbox, desktop)", "desktop", [[str(CB_VENV), "tools/bake_meeting.py", "--engine", "chatterbox"]]),
        ("import", "Import new clips into Godot", "game", [[godot, "--headless", "--path", ".", "--import"]]),
        ("probes", "Voice, journal, Mathilda, meeting and passing probes", "game", [
            probe("voice"), probe("journal"), probe("mathilda"), probe("meeting"), probe("encounter")]),
    ]
    result = {}
    for ident, label, kind, commands in actions:
        runnable = all(Path(c[0]).exists() or c[0] == sys.executable for c in commands)
        result[ident] = {"id": ident, "label": label, "kind": kind, "commands": commands, "runnable": runnable}
    return result


class Jobs:
    """One job at a time, in order; the bake tools are not safe to run side by side."""

    def __init__(self):
        self.jobs, self.lock, self.queue = [], threading.Lock(), []
        self.wake = threading.Event()
        threading.Thread(target=self._loop, daemon=True).start()

    def submit(self, action):
        job = {"id": len(self.jobs) + 1, "action": action["id"], "label": action["label"], "state": "queued",
               "commands": [" ".join(c) for c in action["commands"]], "log": [], "code": None,
               "started": None, "ended": None, "_commands": action["commands"]}
        with self.lock:
            self.jobs.append(job)
            self.queue.append(job)
        self.wake.set()
        return job["id"]

    def busy(self):
        with self.lock:
            return any(job["state"] in ("queued", "running") for job in self.jobs)

    def view(self):
        with self.lock:
            return [{k: v if k != "log" else v[-400:] for k, v in job.items() if not k.startswith("_")}
                    for job in reversed(self.jobs[-20:])]

    def _loop(self):
        while True:
            self.wake.wait()
            with self.lock:
                job = self.queue.pop(0) if self.queue else None
                if not self.queue:
                    self.wake.clear()
            if job:
                self._run(job)

    def _run(self, job):
        job["state"], job["started"] = "running", time.time()
        env = dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1")
        env.setdefault("HF_HOME", str(ROOT / "build/voice/hf/cache"))
        code = 0
        for command in job["_commands"]:
            job["log"].append("$ " + " ".join(command))
            try:
                process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                           stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
                for raw in process.stdout:
                    job["log"].append(raw.rstrip())
                code = process.wait()
            except OSError as error:
                job["log"].append(f"could not start: {error}")
                code = -1
            if code != 0:
                break
        job["code"], job["ended"] = code, time.time()
        job["state"] = "done" if code == 0 else "failed"


class Lab:
    """The Kokoro worker, started on first use and kept warm."""

    def __init__(self):
        self.process, self.lock, self.voices = None, threading.Lock(), []

    def _ensure(self):
        if self.process and self.process.poll() is None:
            return
        if not VENV.exists():
            raise RuntimeError("No Kokoro venv at build/voice/venv")
        self.process = subprocess.Popen([str(VENV), str(Path(__file__).with_name("kokoro_worker.py"))],
                                        cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
        ready = json.loads(self.process.stdout.readline() or "{}")
        if not ready.get("ready"):
            raise RuntimeError("Kokoro worker did not start")

    def ask(self, request):
        with self.lock:
            self._ensure()
            self.process.stdin.write(json.dumps(request) + "\n")
            self.process.stdin.flush()
            return json.loads(self.process.stdout.readline() or '{"ok": false, "error": "worker gone"}')

    def render(self, text, voice, speed):
        name = hashlib.sha256(f"{text}|{voice}|{speed:.2f}".encode("utf-8")).hexdigest()[:24] + ".wav"
        out = SCRATCH / name
        if out.exists():
            return {"ok": True, "path": out.relative_to(ROOT).as_posix(), "cached": True}
        answer = self.ask({"text": text, "voice": voice, "speed": speed, "out": str(out)})
        if answer.get("ok"):
            answer["path"] = out.relative_to(ROOT).as_posix()
        return answer

    def list_voices(self):
        if not self.voices:
            self.voices = self.ask({"voices": True}).get("voices", [])
        return self.voices


CHECKS = {
    "ophelia": ["tools/script_to_lines.py", "--check"],
    "mathilda": ["tools/bake_mathilda.py", "--check"],
    "lake": ["tools/bake_lake.py", "--check"],
    "doorway": ["tools/bake_meeting.py", "--check"],
}


def _tool(args):
    result = subprocess.run([_python(), *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", env=dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1"))
    return result.returncode == 0, (result.stdout + result.stderr).strip()


class Editor:
    """Writes one line back into its script, regenerates its table, checks it, and can undo."""

    def __init__(self):
        self.history, self.lock = [], threading.Lock()

    def edit(self, uid, text, mood, dry_run):
        lines = model.load()
        line = next((l for l in lines if l.uid == uid), None)
        if line is None:
            return 404, {"error": "no such line"}
        text, mood = text.strip(), mood.strip()
        if text == line.text and mood == line.mood:
            return 200, {"ok": True, "unchanged": True}
        problem = writers.check(line, text, mood, lines)
        if problem:
            return 400, {"error": problem}
        path = writers.doc_path(line)
        before = writers.read(path)
        try:
            after = writers.rewrite(before, line, text, mood)
        except writers.EditError as error:
            return 409, {"error": str(error)}
        warnings = []
        engine = model.FINAL_ENGINE[(line.chapter, line.speaker)]
        if line.clip != "missing":
            warnings.append(f"Its {line.clip} clip stops playing; the line shows as a subtitle until it is baked again ({engine}).")
        for other in writers.quoted_by(line, lines):
            if other.meta["quote"] not in text:
                warnings.append(f"{other.uid} answers this line by quoting \"{other.meta['quote']}\", which is no longer in it.")
        name = model.CHAPTERS[line.chapter]["doc"]
        result = {"ok": True, "diff": writers.diff(before, after, name), "warnings": warnings}
        if dry_run:
            return 200, result
        if JOBS.busy():
            return 409, {"error": "a job is running; save when it has finished"}
        with self.lock:
            writers.write(path, after)
            self.history.append({"uid": uid, "chapter": line.chapter, "path": str(path), "before": before,
                                 "label": f"{uid}: {line.text[:40]} -> {text[:40]}", "at": time.time()})
            wrote, log = _tool(writers.TABLE_WRITERS[line.chapter])
            checked, check_log = _tool(CHECKS[line.chapter])
        result.update(table_ok=wrote, check_ok=checked, log=f"{log}\n{check_log}".strip())
        return 200, result

    def undo(self):
        with self.lock:
            if not self.history:
                return 400, {"error": "nothing to undo"}
            entry = self.history.pop()
            writers.write(Path(entry["path"]), entry["before"])
            wrote, log = _tool(writers.TABLE_WRITERS[entry["chapter"]])
            checked, check_log = _tool(CHECKS[entry["chapter"]])
        return 200, {"ok": True, "undone": entry["label"], "uid": entry["uid"], "check_ok": checked,
                     "log": f"{log}\n{check_log}".strip()}

    def view(self):
        return [{"label": e["label"], "uid": e["uid"], "at": e["at"]} for e in reversed(self.history)]


# Which bake renders a line on this machine; the tool only performs what is missing.
def bake_for(line):
    if line.chapter == "mathilda":
        return "bake_mathilda", "Kokoro, final for her chapter"
    if line.chapter == "lake" and line.speaker == "mathilda":
        return "bake_lake", "Kokoro, final for her lake lines"
    if line.chapter == "doorway" and line.clip == "missing":
        return "meeting_drafts", "Kokoro draft; the final still waits for the desktop"
    if line.chapter == "doorway":
        return None, "It already has a draft; its final needs Chatterbox on the desktop"
    return None, "Ophelia's voice needs Chatterbox on the desktop"


# Where to drop her so the line can be heard where the game plays it (dev hooks).
ROOM_SPAWNS = {"bedroom": "bedroom", "hall": "living", "living": "living", "backhall": "stair", "stair": "stair",
               "landing": "cellar", "corridor": "cellar", "janitor": "janitor", "morgue": "morgue",
               "snow": "outside", "lights": "lookout", "lookout": "lookout", "lake": "lake"}


def scene_for(line):
    parts = line.uid.split("/")
    if line.chapter == "doorway":
        return {"RUN_MATHILDA": "1", "RUN_MEETING": "open"}, "Mathilda's chapter, at the door with the meeting open"
    if line.chapter == "lake":
        return {"RUN_PLAY": "1", "RUN_SPAWN": "lake"}, "Ophelia at the lake (the meeting needs every page read)"
    if line.chapter == "mathilda":
        if parts[1] == "passing" and parts[2].startswith("w_"):
            return {"RUN_PLAY": "1", "RUN_SPAWN": "outside", "RUN_WANDER": "now"}, "Ophelia outside, Mathilda brought out at once"
        if parts[1] == "passing":
            return {"RUN_MATHILDA": "1", "RUN_WANDER": "now"}, "Mathilda's chapter, Ophelia brought out at once"
        return {"RUN_MATHILDA": "1"}, "Mathilda's chapter at her camp"
    group = parts[1]
    if group == "encounters":
        return {"RUN_PLAY": "1", "RUN_SPAWN": "outside", "RUN_WANDER": "now"}, "Ophelia outside, Mathilda brought out at once"
    if group in ("places", "revisits") and parts[2] in ROOM_SPAWNS:
        return {"RUN_PLAY": "1", "RUN_SPAWN": ROOM_SPAWNS[parts[2]]}, f"Ophelia near the {parts[2]}"
    if group == "chores":
        return {"RUN_PLAY": "1", "RUN_SPAWN": "living"}, "Ophelia in the living room, by the stove and the window"
    return {"RUN_PLAY": "1"}, "Ophelia's afternoon from the start"


def play(line):
    if not GODOT.exists():
        return 409, {"error": f"no Godot at {GODOT} (set STUDIO_GODOT)"}
    extra, where = scene_for(line)
    env = {k: v for k, v in os.environ.items() if not k.startswith("RUN_")}
    env.update(extra)
    windowed = GODOT.with_name(GODOT.name.replace(".console", ""))
    subprocess.Popen([str(windowed if windowed.exists() else GODOT), "--path", str(ROOT)], cwd=ROOT, env=env,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    hooks = " ".join(f"{k}={v}" for k, v in extra.items())
    return 200, {"ok": True, "where": where, "hooks": hooks}


JOBS, LAB, EDITOR = Jobs(), Lab(), Editor()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, status, body, kind="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _file(self, path):
        kind = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        self._send(200, path.read_bytes(), kind)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/":
            return self._file(STATIC / "index.html")
        if url.path.startswith("/static/"):
            target = (STATIC / url.path[len("/static/"):]).resolve()
            if target.parent == STATIC.resolve() and target.exists():
                return self._file(target)
            return self._send(404, {"error": "no such file"})
        if url.path == "/audio":
            relative = parse_qs(url.query).get("path", [""])[0]
            target = (ROOT / relative).resolve()
            allowed = any(target.is_relative_to(base.resolve()) for base in AUDIO_ROOTS)
            if allowed and target.suffix == ".wav" and target.exists():
                return self._file(target)
            return self._send(404, {"error": "no such clip"})
        if url.path == "/api/state":
            lines = model.load()
            return self._send(200, {
                "lines": [line.as_dict() for line in lines],
                "summary": model.summary(lines),
                "orphans": len(model.orphans(lines)),
                "moods": model.MOODS,
                "actions": [{k: v for k, v in a.items() if k != "commands"} | {"commands": [" ".join(c) for c in a["commands"]]}
                            for a in _actions().values()],
            })
        if url.path == "/api/jobs":
            return self._send(200, JOBS.view())
        if url.path == "/api/review":
            return self._send(200, review.items())
        if url.path == "/api/history":
            return self._send(200, EDITOR.view())
        if url.path == "/api/voices":
            try:
                return self._send(200, {"voices": LAB.list_voices()})
            except RuntimeError as error:
                return self._send(503, {"error": str(error)})
        return self._send(404, {"error": "unknown"})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            return self._send(400, {"error": "bad json"})
        url = urlparse(self.path)
        if url.path == "/api/run":
            action = _actions().get(str(body.get("action", "")))
            if not action:
                return self._send(404, {"error": "unknown action"})
            if not action["runnable"]:
                return self._send(409, {"error": "this machine cannot run that (missing venv or Godot)"})
            return self._send(200, {"job": JOBS.submit(action)})
        if url.path == "/api/edit":
            status, answer = EDITOR.edit(str(body.get("uid", "")), str(body.get("text", "")),
                                         str(body.get("mood", "")), bool(body.get("dry_run", True)))
            return self._send(status, answer)
        if url.path in ("/api/bake_line", "/api/play"):
            line = next((l for l in model.load() if l.uid == str(body.get("uid", ""))), None)
            if line is None:
                return self._send(404, {"error": "no such line"})
            if url.path == "/api/play":
                return self._send(*play(line))
            ident, why = bake_for(line)
            if ident is None:
                return self._send(409, {"error": why})
            if line.clip == "final":
                return self._send(409, {"error": "it already has its final clip"})
            actions = _actions()
            action = dict(actions[ident])
            action["label"] = f"Bake {line.uid} ({why})"
            action["commands"] = action["commands"] + actions["import"]["commands"]
            if not all(Path(c[0]).exists() for c in action["commands"]):
                return self._send(409, {"error": "this machine cannot run that (missing venv or Godot)"})
            return self._send(200, {"job": JOBS.submit(action), "why": why})
        if url.path == "/api/review/accept":
            return self._send(200, review.accept(str(body.get("key", ""))))
        if url.path in ("/api/review/reject", "/api/review/retake"):
            if JOBS.busy():
                return self._send(409, {"error": "a job is running; decide when it has finished"})
            path = str(body.get("path", ""))
            line = None
            if url.path == "/api/review/retake":
                line = next((l for l in model.load() if l.clip_key == Path(path).stem), None)
                command, why = review.retake_plan(line) if line else (None, "no line plays this clip")
                if command is None or not Path(command[0]).exists():
                    return self._send(409, {"error": why or "re-takes run on the desktop (Chatterbox)"})
            answer = review.reject(path)
            if not answer.get("ok") or line is None:
                return self._send(200 if answer.get("ok") else 400, answer)
            action = {"id": "retake", "label": f"Re-take {line.uid}",
                      "commands": [command] + _actions()["import"]["commands"]}
            answer["job"] = JOBS.submit(action)
            return self._send(200, answer)
        if url.path == "/api/undo":
            status, answer = EDITOR.undo()
            return self._send(status, answer)
        if url.path == "/api/try":
            text = str(body.get("text", "")).strip()[:600]
            if not text:
                return self._send(400, {"error": "no text"})
            try:
                speed = min(max(float(body.get("speed", 0.94)), 0.5), 1.6)
                return self._send(200, LAB.render(text, str(body.get("voice", "af_bella")), speed))
            except (RuntimeError, ValueError) as error:
                return self._send(503, {"ok": False, "error": str(error)})
        return self._send(404, {"error": "unknown"})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=4317)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    url = f"http://127.0.0.1:{args.port}"
    print(f"Story Studio on {url}", flush=True)
    if not args.no_browser:
        webbrowser.open(url)
    server.serve_forever()


if __name__ == "__main__":
    main()
