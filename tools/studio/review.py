"""Reviewing new clips: what is new since the last commit, what it replaces,
and accept / reject / re-take. docs/STORY_STUDIO.md, section 5.6.

New means untracked or added under assets/audio/voice (what the next commit
would carry). Accepting only remembers the decision (build/studio/review.json);
rejecting moves the clip and its .import into build/voice/archive/ the way the
bake tools do, so nothing is ever deleted.
"""
import json
import subprocess
import sys
import time
from pathlib import Path

from studio import model

ROOT = model.ROOT
STORE = ROOT / "build/studio/review.json"
REFS = ROOT / "tools/voice/ref"
CB_VENV = ROOT / "build/voice/cb-venv/Scripts/python.exe"


def _git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")


def new_clips():
    out = _git("status", "--porcelain", "--untracked-files=all", "--", "assets/audio/voice").stdout
    found = []
    for row in out.splitlines():
        status, path = row[:2], row[3:].strip().strip('"')
        if path.endswith(".wav") and ("?" in status or "A" in status):
            found.append(path)
    return sorted(found)


def _at_head(path):
    result = _git("show", "HEAD:" + path.relative_to(ROOT).as_posix())
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def _decisions():
    try:
        return json.loads(STORE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _save(decisions):
    STORE.parent.mkdir(parents=True, exist_ok=True)
    STORE.write_text(json.dumps(decisions, indent=1), encoding="utf-8")


def _impression(line):
    folder = REFS if line.speaker == "ophelia" else REFS / "mathilda"
    ref = folder / f"{line.mood}.wav"
    return ref.relative_to(ROOT).as_posix() if ref.exists() else ""


def retake_plan(line):
    """The command that performs this line again, and why there may be none."""
    if line.chapter == "ophelia":
        return [str(CB_VENV), "tools/bake_speech.py", "--only", line.text], ""
    if line.chapter == "doorway":
        return [str(CB_VENV), "tools/bake_meeting.py", "--engine", "chatterbox", "--speaker", line.speaker,
                "--first-seed", str(int(time.time()) % 900 + 4)], ""
    return None, "Kokoro reads a line the same way every time; change its words, mood or voice in the lab instead."


def items():
    lines = model.load()
    by_key = {}
    for line in lines:
        by_key.setdefault(line.clip_key, []).append(line)
    before = {line.uid: line for line in model.load(read=_at_head, locate=False)}
    decided = _decisions()
    result = []
    for path in new_clips():
        key = Path(path).stem
        owners = by_key.get(key, [])
        item = {"path": path, "key": key, "draft": "/draft/" in path, "decision": decided.get(key, {}).get("decision", ""),
                "lines": [{k: getattr(l, k) for k in ("uid", "chapter", "group", "speaker", "mood", "text")} for l in owners],
                "previous": None, "impression": "", "retake": False, "retake_why": ""}
        if owners:
            line = owners[0]
            item["impression"] = _impression(line)
            command, why = retake_plan(line)
            item["retake"] = bool(command) and CB_VENV.exists()
            item["retake_why"] = why or ("" if CB_VENV.exists() else "Re-takes run on the desktop (Chatterbox).")
            old = before.get(line.uid)
            if old and old.clip_key != key:
                folder = model.CHAPTERS[old.chapter]["clips"]
                for candidate in (folder / f"{old.clip_key}.wav", folder / "draft" / f"{old.clip_key}.wav"):
                    if candidate.exists():
                        item["previous"] = {"path": candidate.relative_to(ROOT).as_posix(), "text": old.text, "mood": old.mood}
                        break
                else:
                    item["previous"] = {"path": "", "text": old.text, "mood": old.mood}
        result.append(item)
    return result


def accept(key):
    decided = _decisions()
    decided[key] = {"decision": "accepted", "at": time.time()}
    _save(decided)
    return {"ok": True}


def reject(path):
    target = (ROOT / path).resolve()
    if path not in new_clips() or not target.exists():
        return {"ok": False, "error": "only a new clip (not yet committed) can be rejected here"}
    sys.path.insert(0, str(ROOT / "tools"))
    import bake_speech
    where = bake_speech.archive([target], label="rejected")
    decided = _decisions()
    decided.pop(target.stem, None)
    _save(decided)
    return {"ok": True, "archived_to": where.relative_to(ROOT).as_posix()}
