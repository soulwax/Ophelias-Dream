"""The meeting on the ice (docs/LAKE_MEETING.md, the script of record).

Writes assets/audio/voice/lake/lines.json from the script's lines table, and
bakes Mathilda's lines with her chapter's voice (Kokoro af_bella at 0.94, CPU)
into assets/audio/voice/lake/, named like every clip by the SHA-256 of
"text|mood". Ophelia's lines are left for the Chatterbox bake on the desktop;
until then they show as subtitles.

  python tools/bake_lake.py --check     # lines.json matches the script
  python tools/bake_lake.py --write     # only rewrite lines.json
  build/voice/venv/Scripts/python.exe tools/bake_lake.py   # write and bake
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs/LAKE_MEETING.md"
OUT = ROOT / "assets/audio/voice/lake"
ROW = re.compile(r"^\| ([a-z]\d\d) \| (ophelia|mathilda) \| ([a-z]+) \| (.+) \|$")
# A beat after each line before the next, longer after the heavy ones.
PAUSE = {"breaking": 0.9, "numb": 0.9, "hushed": 0.6}


def parse():
    lines = []
    for raw in DOC.read_text(encoding="utf-8").splitlines():
        match = ROW.match(raw.strip())
        if match:
            ident, speaker, mood, text = match.groups()
            lines.append({"id": ident, "speaker": speaker, "mood": mood, "text": text.strip(),
                          "pause": PAUSE.get(mood, 0.4)})
    return lines


def key(entry):
    return hashlib.sha256((entry["text"] + "|" + entry["mood"]).encode("utf-8")).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    lines = parse()
    target = OUT / "lines.json"
    if args.check:
        same = target.exists() and json.loads(target.read_text(encoding="utf-8")) == lines
        print(f"{len(lines)} lines; " + ("lines.json matches the script" if same else "lines.json differs from the script"))
        sys.exit(0 if same else 1)
    OUT.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(lines, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(lines)} lines")
    if args.write:
        return
    from types import SimpleNamespace
    import soundfile as sf
    import bake_speech
    speak = bake_speech.bake_kokoro(SimpleNamespace(voice="af_bella", speed=0.94))
    for entry in lines:
        if entry["speaker"] != "mathilda":
            continue
        path = OUT / (key(entry) + ".wav")
        if path.exists():
            continue
        print(f"{entry['id']}: {entry['text']}", flush=True)
        samples, rate = speak(entry["text"])
        sf.write(path, samples, rate, subtype="PCM_16")
    print("lake bake complete", flush=True)


if __name__ == "__main__":
    main()
