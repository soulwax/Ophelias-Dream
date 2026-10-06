"""Perform her lines into clips; no model runs during gameplay.

Her script is docs/MATHILDA_STORY.md (tools/script_to_lines.py writes lines.json).
Each of the 14 moods has an impression: a short reference performance rendered
once with Qwen3-TTS VoiceDesign (`--impressions`, in build/voice/gpu-venv).
Every line is then performed by Chatterbox (build/voice/cb-venv), cloned from
its mood's impression and pushed by that mood's controls. Three takes, Whisper
drops takes with wrong words, the take most like the impression wins.
`build/voice/review.html` lists every clip to listen to. Clips land in
assets/audio/voice/ as sha256("text|mood").wav, and are never deleted: replaced
or scrapped clips move to build/voice/archive/. Setup: docs/VOICE.md.
"""

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/voice"
# Everything a bake depends on is committed under tools/voice/ (Godot ignores it):
# the per-mood references, the raw impression picks, and voice_lock.json.
VOICE = ROOT / "tools/voice"
REF = VOICE / "ref"
LOCK = VOICE / "voice_lock.json"
CANDIDATES = ROOT / "build/voice/candidates"
HF = ROOT / "build/voice/hf"
ARCHIVE = ROOT / "build/voice/archive"
DESIGN_MODEL = "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
IDENTITY = ("A woman around thirty. A low, soft alto with a little breath in it, plain North American accent. "
            "She is cold, tired, and talking quietly to herself in an empty place; never theatrical, never narrating.")
# Mood: direction (impressions), impression text, Chatterbox exaggeration, cfg_weight, temperature, level dBFS.
MOODS = {
    "steady": ("Calm and even, talking herself into calm.", "Okay. The kettle's on, the door's shut, the lantern's lit. Everything is where it should be. I'm fine.", 0.45, 0.50, 0.80, -12.0),
    "warm": ("Tender and fond, almost smiling, a catch at the end.", "You always do this. You show up late with snow in your hair and you think a smile fixes it. ...It does, a bit.", 0.55, 0.45, 0.80, -12.0),
    "hushed": ("Barely above a whisper, close and careful, as if something might hear.", "Shh. Don't move. If we stay very still, maybe it won't hear us breathing.", 0.35, 0.55, 0.70, -18.0),
    "shaken": ("Unsteady, breath short, words coming a little too fast.", "I don't... I don't understand, it was right here, I put it right here, I know I did.", 0.70, 0.40, 0.85, -12.0),
    "breaking": ("On the edge of tears, voice cracking, pauses where it gives out.", "I'm sorry. I'm so sorry. I didn't mean it, I never meant any of it, please come back.", 0.85, 0.35, 0.90, -13.0),
    "resolve": ("Low and determined, jaw set, each word placed.", "No. I'm not stopping. Not now. I'll walk until there's nowhere left to walk.", 0.55, 0.45, 0.75, -12.0),
    "calling": ("Shouting as loud as she can into a strong wind, straining, desperate.", "Can you hear me? Hello? I'm over here! Over here!", 1.00, 0.30, 0.85, -9.0),
    "numb": ("Flat, slow and far away, the feeling gone out of her voice.", "It doesn't hurt any more. That's the strange part. Nothing hurts. It's all very far away.", 0.25, 0.60, 0.60, -15.0),
    "bitter": ("Hurt turned into anger, clipped, a little too loud, then quiet.", "Oh, of course. Of course you did. You always get to leave, and I always get to clean up after.", 0.75, 0.40, 0.85, -11.0),
    "pleading": ("Small and begging, bargaining with something that isn't listening.", "Please. I'll do anything. Just this once. Just let her be all right, and I won't ask for anything else.", 0.70, 0.35, 0.85, -13.0),
    "wry": ("Dark humour under her breath, half a laugh, to keep from crying.", "Well. That went about as well as everything else today. Brilliant. Really.", 0.50, 0.45, 0.85, -13.0),
    "remembering": ("Soft and slow, looking at something far away, a smile that hurts.", "We used to skate on the lake when it froze. She'd hold my hands and go backwards, laughing, the whole way across.", 0.40, 0.50, 0.75, -14.0),
    "panicked": ("Fast and breathless, words tripping over each other.", "No no no, where is it, where did it go, I can't, I can't breathe, where is it...", 0.95, 0.30, 0.95, -11.0),
    "spent": ("Completely out of breath, gasping between the words.", "Wait... wait... I just... I need... one second. Okay. Okay.", 0.80, 0.35, 0.90, -13.0),
}
TAKES = 3
MAX_WER = 0.15


def clip_name(text, mood):
    return hashlib.sha256(f"{text}|{mood}".encode("utf-8")).hexdigest() + ".wav"


def lines(data):
    """Every (category, text, mood, overrides) in lines.json, once each."""
    found = []

    def add(category, item):
        if isinstance(item, str):
            item = {"text": item, "mood": "steady"}
        extra = {k: item[k] for k in ("exaggeration", "cfg", "temperature") if k in item}
        found.append((category, item["text"].strip(), item.get("mood", "steady"), extra))

    for category in ("pages", "deciphered", "places", "revisits", "endings", "answers"):
        for item in data.get(category, {}).values():
            add(category, item)
    for category in ("bored", "memories", "calls"):
        group = data.get(category, {})
        if isinstance(group, list):
            group = {"hope": group}
        for stage in ("hope", "doubt", "resolve", "after"):
            for item in group.get(stage, []):
                add(category, item)
    for category in ("misread", "spent", "cold", "falls"):
        for item in data.get(category, []):
            add(category, item)
    if isinstance(data.get("turned"), dict):
        add("turned", data["turned"])
    seen, unique = set(), []
    for entry in found:
        if (entry[1], entry[2]) not in seen:
            seen.add((entry[1], entry[2]))
            unique.append(entry)
    return unique


ONES = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven",
        "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]


def spelled(number):
    """Whisper writes small numbers as digits; the script spells them."""
    if number < 20:
        return [ONES[number]]
    if number < 100:
        return [TENS[number // 10]] + ([ONES[number % 10]] if number % 10 else [])
    return [str(number)]


def words(text):
    heard = re.findall(r"[a-z0-9']+", text.lower().replace("’", "'"))
    out = []
    for word in heard:
        if word.isdigit():
            out += spelled(int(word))
        # Whisper often uses the more common spelling for the same spoken name.
        else:
            out.append("mathilda" if word == "matilda" else word)
    return out


def wer(reference, heard):
    ref, hyp = words(reference), words(heard)
    row = list(range(len(hyp) + 1))
    for i, r in enumerate(ref, 1):
        prev, row[0] = row[0], i
        for j, h in enumerate(hyp, 1):
            prev, row[j] = row[j], min(row[j] + 1, row[j - 1] + 1, prev + (r != h))
    return row[len(hyp)] / max(len(ref), 1)


def level(samples, rate, target_db):
    import numpy as np
    window = max(1, int(rate * 0.05))
    power = np.convolve(samples.astype(np.float64) ** 2, np.ones(window) / window, mode="valid")
    gain = min(10 ** (target_db / 20) / max(float(np.sqrt(power.max())), 1e-8),
               0.95 / max(float(np.abs(samples).max()), 1e-8))
    return samples * gain


def trim(samples, rate, keep=0.06, floor_db=-45.0):
    import numpy as np
    loud = np.abs(samples) > 10 ** (floor_db / 20) * max(float(np.abs(samples).max()), 1e-8)
    idx = np.flatnonzero(loud)
    if idx.size == 0:
        return samples
    pad = int(rate * keep)
    return samples[max(idx[0] - pad, 0): idx[-1] + pad + 1]


def archive(paths, label=""):
    """Move clips (with their .import files) out of the game, never deleting them."""
    import datetime
    import shutil
    target = ARCHIVE / (datetime.date.today().isoformat() + (f"-{label}" if label else ""))
    target.mkdir(parents=True, exist_ok=True)
    for path in paths:
        for item in (path, path.with_name(path.name + ".import")):
            if item.exists():
                shutil.move(str(item), str(target / item.name))
    return target


def write_page(path, title, groups):
    """A local listening page: groups of (src, label, detail) rows, each with an audio player."""
    import html
    parts = [f"<!doctype html><meta charset=utf-8><title>{title}</title>",
             "<style>body{font:15px system-ui;margin:24px;max-width:980px}h2{margin-top:28px}"
             ".row{display:flex;gap:12px;align-items:center;margin:6px 0}.d{color:#777;font-size:13px}</style>",
             f"<h1>{title}</h1>"]
    for heading, rows in groups:
        parts.append(f"<h2>{html.escape(heading)}</h2>")
        for src, label, detail in rows:
            parts.append(f"<div class=row><audio controls preload=none src='{html.escape(src)}'></audio>"
                         f"<div>{html.escape(label)}<div class=d>{html.escape(detail)}</div></div></div>")
    path.write_text("\n".join(parts), encoding="utf-8")


class Qwen:
    """Qwen3-TTS VoiceDesign, used only to perform the per-mood impressions."""

    def __init__(self):
        import torch
        from qwen_tts import Qwen3TTSModel
        self.torch = torch
        self.design = Qwen3TTSModel.from_pretrained(
            str(HF / "VoiceDesign"), device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")

    def perform(self, mood, count):
        import numpy as np
        direction, text = MOODS[mood][0], MOODS[mood][1]
        self.torch.manual_seed(500)
        wavs, rate = self.design.generate_voice_design(
            text=[text] * count, language="English", instruct=[f"{IDENTITY} {direction}"] * count,
            max_new_tokens=384)
        return [(np.asarray(w, dtype=np.float32).reshape(-1), int(rate)) for w in wavs]


class Chatter:
    """Chatterbox clones each line from its mood's impression, acted by that mood's controls."""

    def __init__(self):
        import torch
        from chatterbox.tts import ChatterboxTTS
        self.torch = torch
        self.model = ChatterboxTTS.from_pretrained(device="cuda")

    def perform(self, text, mood, extra, seed):
        import numpy as np
        _, _, exaggeration, cfg, temperature, _ = MOODS[mood]
        self.torch.manual_seed(seed)
        wav = self.model.generate(
            text, audio_prompt_path=str(REF / f"{mood}.wav"),
            exaggeration=extra.get("exaggeration", exaggeration),
            cfg_weight=extra.get("cfg", cfg), temperature=extra.get("temperature", temperature))
        return wav.squeeze(0).cpu().numpy().astype(np.float32), int(self.model.sr)


class Judge:
    """Whisper for the words, an ECAPA embedding for whether it is her."""

    def __init__(self):
        import torch
        # ctranslate2 finds cuDNN/cuBLAS in torch's own lib folder.
        os.add_dll_directory(str(Path(torch.__file__).parent / "lib"))
        import torchaudio
        from faster_whisper import WhisperModel
        from speechbrain.inference.speaker import EncoderClassifier
        from speechbrain.utils.fetching import LocalStrategy
        self.torch, self.torchaudio = torch, torchaudio
        free, _total = torch.cuda.mem_get_info()
        self.device = "cuda" if free >= 2 * 1024**3 else "cpu"
        print(f"Judging on {self.device} ({free / 1024**3:.1f} GiB GPU free)", flush=True)
        self.asr = WhisperModel(str(HF / "whisper-model"), device=self.device,
                                compute_type="int8_float16" if self.device == "cuda" else "int8")
        self.ecapa = EncoderClassifier.from_hparams(
            source=str(HF / "ecapa-model"), savedir=str(HF / "ecapa"),
            run_opts={"device": self.device}, local_strategy=LocalStrategy.COPY)
        self.anchor = None

    def _16k(self, samples, rate):
        wave = self.torch.from_numpy(samples).float().unsqueeze(0)
        return self.torchaudio.functional.resample(wave, rate, 16000)

    def hear(self, samples, rate):
        wave = self._16k(samples, rate).squeeze(0).numpy()
        segments, _ = self.asr.transcribe(wave, language="en", beam_size=5)
        return " ".join(segment.text.strip() for segment in segments)

    def embed(self, samples, rate):
        with self.torch.no_grad():
            vector = self.ecapa.encode_batch(self._16k(samples, rate).to(self.device)).squeeze()
        return vector / vector.norm()

    def embed_file(self, path):
        import soundfile as sf
        samples, rate = sf.read(path, dtype="float32")
        if samples.ndim > 1:
            samples = samples.mean(axis=1)
        return self.embed(samples, rate)

    def similarity(self, samples, rate):
        return float((self.embed(samples, rate) * self.anchor).sum())


def impressions(args):
    """Render candidate impressions per mood, pick one each, and write impressions.html."""
    import shutil
    import soundfile as sf
    judge, qwen = Judge(), Qwen()
    CANDIDATES.mkdir(parents=True, exist_ok=True)
    moods = args.moods.split(",") if args.moods else list(MOODS)
    if "steady" in moods:
        moods = ["steady"] + [m for m in moods if m != "steady"]
    picks = dict(p.split("=") for p in args.pick or [])
    rows = []
    for mood in moods:
        print(f"[{mood}] {MOODS[mood][1]}", flush=True)
        # Steady is measured against the approved anchor; every other mood against steady.
        judge.anchor = judge.embed_file(REF / ("anchor.wav" if mood == "steady" else "steady.wav"))
        scored = []
        for n, (samples, rate) in enumerate(qwen.perform(mood, args.candidates)):
            samples = trim(samples, rate)
            path = CANDIDATES / f"{mood}_{n}.wav"
            sf.write(path, level(samples, rate, MOODS[mood][5]), rate, subtype="PCM_16")
            heard = judge.hear(samples, rate)
            scored.append(dict(n=n, path=path, wer=wer(MOODS[mood][1], heard),
                               similarity=judge.similarity(samples, rate), heard=heard))
            print(f"    {n}: wer {scored[-1]['wer']:.2f} sim {scored[-1]['similarity']:.2f} | {heard}", flush=True)
        usable = [s for s in scored if s["wer"] <= 0.25] or scored
        chosen = int(picks[mood]) if mood in picks else max(usable, key=lambda s: s["similarity"])["n"]
        shutil.copyfile(CANDIDATES / f"{mood}_{chosen}.wav", REF / f"{mood}.wav")
        (REF / "raw").mkdir(exist_ok=True)
        shutil.copyfile(CANDIDATES / f"{mood}_{chosen}.wav", REF / "raw" / f"{mood}.wav")
        print(f"    picked {chosen}", flush=True)
        rows.append((mood, scored, chosen))
    write_page(ROOT / "build/voice/impressions.html", "Impressions", [
        (mood, [(f"candidates/{s['path'].name}", f"#{s['n']}{' (picked)' if s['n'] == chosen else ''}",
                 f"wer {s['wer']:.2f} · sim {s['similarity']:.2f} · {s['heard']}") for s in scored])
        for mood, scored, chosen in rows])


def unify(args):
    """Give every mood's impression steady's voice, keeping its delivery (Chatterbox VC, cb-venv).

    VoiceDesign renders each mood as a slightly different woman; cloning lines from
    those would carry the drift into the game. The raw picks stay in ref/raw/.
    """
    import shutil
    import soundfile as sf
    from chatterbox.vc import ChatterboxVC
    judge = Judge()
    vc = ChatterboxVC.from_pretrained(device="cuda")
    (REF / "raw").mkdir(exist_ok=True)
    judge.anchor = judge.embed_file(REF / "steady.wav")
    moods = args.moods.split(",") if args.moods else [m for m in MOODS if m != "steady"]
    for mood in moods:
        raw = REF / "raw" / f"{mood}.wav"
        if not raw.exists():
            shutil.copyfile(REF / f"{mood}.wav", raw)
        before = float((judge.embed_file(raw) * judge.anchor).sum())
        wav = vc.generate(str(raw), target_voice_path=str(REF / "steady.wav"))
        samples = wav.squeeze(0).cpu().numpy().astype("float32")
        samples = level(trim(samples, vc.sr), vc.sr, MOODS[mood][5])
        after = judge.similarity(samples, vc.sr)
        heard = judge.hear(samples, vc.sr)
        sf.write(REF / f"{mood}.wav", samples, vc.sr, subtype="PCM_16")
        print(f"[{mood}] sim to steady {before:.2f} -> {after:.2f}, wer {wer(MOODS[mood][1], heard):.2f} | {heard}", flush=True)


def lock(args):
    """Record what produced her voice in tools/voice/voice_lock.json, and freeze this venv's packages."""
    import datetime
    import importlib.metadata as meta
    import subprocess
    venv = Path(sys.executable).parent.parent.name
    frozen = subprocess.run([sys.executable, "-m", "pip", "freeze"], capture_output=True, text=True).stdout
    if not frozen.strip():
        frozen = subprocess.run(["uv", "pip", "freeze", "--python", sys.executable], capture_output=True, text=True).stdout
    (VOICE / f"requirements-{venv}.txt").write_text(frozen, encoding="utf-8")
    data = json.loads(LOCK.read_text(encoding="utf-8")) if LOCK.exists() else {}
    versions = {}
    for package in ("torch", "torchaudio", "chatterbox-tts", "qwen-tts", "faster-whisper", "speechbrain"):
        try:
            versions[package] = meta.version(package)
        except meta.PackageNotFoundError:
            pass
    data.setdefault("environments", {})[venv] = {"python": sys.version.split()[0], "packages": versions,
                                                 "requirements": f"requirements-{venv}.txt"}
    data["models"] = {"impressions": DESIGN_MODEL, "lines": "ResembleAI/chatterbox",
                      "unify": "ResembleAI/chatterbox (ChatterboxVC)",
                      "judge": ["mobiuslabsgmbh/faster-whisper-large-v3-turbo", "speechbrain/spkrec-ecapa-voxceleb"]}
    data["identity"] = IDENTITY
    data["moods"] = {m: {"direction": v[0], "impression": v[1], "exaggeration": v[2], "cfg_weight": v[3],
                         "temperature": v[4], "level_dbfs": v[5]} for m, v in MOODS.items()}
    data["seeds"] = {"impressions": 500, "takes": list(range(1, TAKES + 1))}
    data["max_wer"] = MAX_WER
    if args.picks:
        data["picks"] = dict(p.split("=") for p in args.picks.split(","))
    data["locked"] = datetime.date.today().isoformat()
    LOCK.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Locked {venv} into {LOCK}")


def bake_kokoro(args):
    import numpy as np
    import onnxruntime as ort
    from kokoro_onnx import Kokoro
    models = ROOT / "build/voice/models"
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    session = ort.InferenceSession(str(models / "kokoro-v1.0.int8.onnx"), sess_options=options,
                                   providers=["CPUExecutionProvider"])
    kokoro = Kokoro.from_session(session, str(models / "voices-v1.0.bin"))

    def speak(text):
        samples, rate = kokoro.create(text, voice=args.voice, speed=args.speed, lang="en-us")
        return np.asarray(samples, dtype=np.float32), rate
    return speak


def best_take(chatter, judge, text, mood, extra):
    judge.anchor = judge.embed_file(REF / f"{mood}.wav")
    scored = []
    for seed in range(1, TAKES + 1):
        samples, rate = chatter.perform(text, mood, extra, seed)
        samples = trim(samples, rate)
        heard = judge.hear(samples, rate)
        scored.append(dict(samples=samples, rate=rate, wer=wer(text, heard),
                           similarity=judge.similarity(samples, rate), heard=heard))
        print(f"    take {seed}: wer {scored[-1]['wer']:.2f}  sim {scored[-1]['similarity']:.2f}  | {heard}", flush=True)
    good = [s for s in scored if s["wer"] <= MAX_WER]
    return (max(good, key=lambda s: s["similarity"]) if good else min(scored, key=lambda s: s["wer"])), bool(good)


def write_review(clips):
    order = ["pages", "deciphered", "places", "revisits", "bored", "memories", "calls", "spent", "cold",
             "falls", "turned", "answers", "misread", "endings"]
    groups = []
    for category in order + sorted({c["category"] for c in clips} - set(order)):
        rows = [(f"../../assets/audio/voice/{c['file']}", c["text"],
                 f"[{c['mood']}] wer {c.get('wer') if c.get('wer') is not None else '-'} · "
                 f"sim {round(c['similarity'], 2) if c.get('similarity') is not None else '-'}")
                for c in clips if c["category"] == category]
        if rows:
            groups.append((category, rows))
    write_page(ROOT / "build/voice/review.html", "Her lines", groups)


def self_test():
    assert clip_name("a", "b") == hashlib.sha256(b"a|b").hexdigest() + ".wav"
    assert wer("Mathilda... please.", "Mathilda, please") == 0.0
    assert wer("Mathilda!", "Matilda!") == 0.0
    assert wer("two cups", "two cups here") == 0.5
    assert wer("Nineteen. It's still nineteen.", "19. It's still 19.") == 0.0
    assert wer("The dog stayed eleven years. Thirty years.", "The dog stayed 11 years. 30 years.") == 0.0
    assert wer("I'm not lifting that sheet", "im not lifting the sheet") > 0.0
    data = json.loads((OUT / "lines.json").read_text(encoding="utf-8"))
    every = lines(data)
    assert len(every) == 137, len(every)
    assert all(mood in MOODS for _, _, mood, _ in every), {m for _, _, m, _ in every} - set(MOODS)
    assert len(MOODS) == 14 and all(len(v) == 6 and v[1] for v in MOODS.values())
    assert any(extra.get("exaggeration") == 0.9 for _, text, _, extra in every if text == "Go, then!")
    print("SELF-TEST PASS")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--engine", choices=["chatterbox", "kokoro"], default="chatterbox")
    parser.add_argument("--force", action="store_true", help="Re-perform every line")
    parser.add_argument("--only", help="Re-perform only the line with exactly this text")
    parser.add_argument("--mood", help="Re-perform only the lines in this mood")
    parser.add_argument("--accept-bad", action="store_true", help="Keep the best take even above MAX_WER")
    parser.add_argument("--scrap", action="store_true", help="Archive every clip and start fresh")
    parser.add_argument("--impressions", action="store_true", help="Render per-mood impressions (gpu-venv)")
    parser.add_argument("--lock", action="store_true", help="Record this venv and the voice settings in tools/voice/")
    parser.add_argument("--picks", help="mood=n,... impression picks to record with --lock")
    parser.add_argument("--unify", action="store_true", help="Convert every impression to steady's voice (cb-venv)")
    parser.add_argument("--moods", help="Comma list of moods for --impressions or --unify")
    parser.add_argument("--candidates", type=int, default=4)
    parser.add_argument("--pick", action="append", help="mood=n: keep that impression candidate")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--voice", default="af_sarah", help="kokoro voice")
    parser.add_argument("--speed", type=float, default=0.92, help="kokoro speed")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    manifest_path = OUT / "manifest.json"
    if args.scrap:
        where = archive(sorted(OUT.glob("*.wav")) + [manifest_path], "qwen")
        manifest_path.write_text(json.dumps({"engine": None, "clips": []}, indent=2) + "\n", encoding="utf-8")
        print(f"Archived the old clips to {where}")
        return
    if args.impressions:
        return impressions(args)
    if args.unify:
        return unify(args)
    if args.lock:
        return lock(args)
    import numpy as np
    import soundfile as sf

    todo = lines(json.loads((OUT / "lines.json").read_text(encoding="utf-8")))
    old = {}
    if manifest_path.exists():
        for clip in json.loads(manifest_path.read_text(encoding="utf-8")).get("clips", []):
            old[clip["file"]] = clip
    chatter = judge = kokoro = None
    if args.engine == "chatterbox":
        missing = sorted({mood for _, _, mood, _ in todo if not (REF / f"{mood}.wav").exists()})
        if missing:
            sys.exit(f"No impression for {', '.join(missing)}; run --impressions first.")
        chatter, judge = Chatter(), Judge()
    else:
        kokoro = bake_kokoro(args)

    def save(clips):
        manifest_path.write_text(json.dumps({"engine": args.engine, "clips": clips},
                                            indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    partial = args.only is not None or args.mood is not None
    clips, bad, keep = [], [], set()
    for category, text, mood, extra in todo:
        name = clip_name(text, mood)
        keep.add(name)
        target = OUT / name
        if partial:
            redo = text == args.only or mood == args.mood
        else:
            redo = args.force or not target.exists()
        if not redo:
            if target.exists():
                entry = old.get(name) or dict(text=text, mood=mood, file=name,
                                              seconds=float(sf.info(target).duration), engine="unknown")
                entry["category"] = category
                clips.append(entry)
            continue
        print(f"[{mood}] {text}", flush=True)
        if kokoro:
            samples, rate = kokoro(text)
            result, ok = dict(samples=trim(samples, rate), rate=rate, wer=None, similarity=None), True
        else:
            result, ok = best_take(chatter, judge, text, mood, extra)
        if not ok:
            bad.append(text)
            if not args.accept_bad:
                print("    no take passed; skipped (re-run with --accept-bad to keep the best)", flush=True)
                if target.exists():
                    clips.append(old.get(name) or dict(text=text, mood=mood, category=category, file=name))
                continue
        samples = level(result["samples"], result["rate"], MOODS[mood][5])
        if len(samples) == 0 or not np.isfinite(samples).all():
            raise ValueError(f"Invalid speech for {text!r}")
        if target.exists():
            archive([target], "replaced")
        sf.write(target, samples, result["rate"], subtype="PCM_16")
        clips.append(dict(text=text, mood=mood, category=category, file=name,
                          seconds=len(samples) / result["rate"], wer=result["wer"],
                          similarity=result["similarity"], engine=args.engine,
                          reference=f"{mood}.wav" if chatter else None))
        save(clips)
    if not partial:
        stale = [path for path in OUT.glob("*.wav") if path.name not in keep]
        if stale:
            print(f"Archived {len(stale)} clips no longer in the script to {archive(stale, 'stale')}")
    save(clips)
    write_review(clips)
    print(f"Baked {len(clips)} clips into {OUT}; listen at build/voice/review.html")
    if bad:
        print("No take passed for:\n  " + "\n  ".join(bad))
        if not args.accept_bad:
            sys.exit(1)


if __name__ == "__main__":
    main()
