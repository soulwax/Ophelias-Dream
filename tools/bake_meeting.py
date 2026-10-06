"""Write and perform the doorway meeting (docs/MATHILDA_MEETING.md).

`python tools/bake_meeting.py --lines` rewrites assets/audio/voice/meeting/lines.json
from the script; `--check` fails if the two have drifted. A bake performs every
missing clip, named sha256("text|mood").wav like the rest of the voice:

- Mathilda's lines with Kokoro af_bella at 0.94, the voice of her chapter
  (build/voice/venv).
- Ophelia's lines with Chatterbox, cloned from her mood impressions in
  tools/voice/ref/ and judged like bake_speech.py (build/voice/cb-venv, CUDA).
- `--draft` performs Ophelia with Kokoro af_sarah into meeting/draft/ instead,
  for machines without the GPU. The game prefers a final clip over a draft and
  plays the subtitle alone when neither exists.

Existing clips are kept; nothing is deleted.
"""
import argparse
import json
import re
import sys
from pathlib import Path
from types import SimpleNamespace

import bake_speech

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "docs/MATHILDA_MEETING.md"
OUT = ROOT / "assets/audio/voice/meeting"
DRAFT = OUT / "draft"
HEAD = re.compile(r"^### ([a-z0-9]+) \| (ophelia|mathilda) \| ([a-z]+) \| ([0-9.]+)$")


def parse():
    lines, current = [], None
    for raw in SCRIPT.read_text(encoding="utf-8").splitlines():
        match = HEAD.match(raw)
        if match:
            current = dict(id=match[1], speaker=match[2], mood=match[3], text="", reaction="", pause=float(match[4]))
            lines.append(current)
        elif current and raw.startswith("Action / reaction: "):
            current["reaction"] = raw[len("Action / reaction: "):].rstrip(".")
        elif current and raw.startswith("> ") and not current["text"]:
            current["text"] = raw[2:].strip()
        elif raw.startswith("## ") and raw not in ("## Spoken exchange", "## Branches"):
            current = None
    ids = [line["id"] for line in lines]
    assert len(ids) == len(set(ids)), "duplicate line ids"
    for line in lines:
        assert line["text"], f"line {line['id']} has no text"
        assert line["mood"] in bake_speech.MOODS, f"line {line['id']}: unknown mood {line['mood']}"
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="Fail if lines.json differs from the script")
    parser.add_argument("--lines", action="store_true", help="Only rewrite lines.json")
    parser.add_argument("--draft", action="store_true", help="Ophelia with Kokoro into meeting/draft/")
    parser.add_argument("--accept-bad", action="store_true", help="Keep Ophelia's best take even above MAX_WER")
    args = parser.parse_args()
    data = parse()
    target = OUT / "lines.json"
    if args.check:
        if not target.exists() or json.loads(target.read_text(encoding="utf-8")) != data:
            sys.exit("meeting/lines.json has drifted from docs/MATHILDA_MEETING.md; run --lines")
        print(f"Meeting script matches lines.json ({len(data)} lines)")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(data)} lines to {target.relative_to(ROOT)}")
    if args.lines:
        return

    import soundfile as sf
    mathilda = bake_speech.bake_kokoro(SimpleNamespace(voice="af_bella", speed=0.94))
    ophelia_draft = bake_speech.bake_kokoro(SimpleNamespace(voice="af_sarah", speed=0.92)) if args.draft else None
    chatter = judge = None
    bad = []
    for line in data:
        name = bake_speech.clip_name(line["text"], line["mood"])
        if (OUT / name).exists():
            continue
        if line["speaker"] == "mathilda":
            path = OUT / name
            samples, rate = mathilda(line["text"])
            samples = bake_speech.trim(samples, rate)
        elif args.draft:
            path = DRAFT / name
            if path.exists():
                continue
            samples, rate = ophelia_draft(line["text"])
            samples = bake_speech.trim(samples, rate)
        else:
            path = OUT / name
            if chatter is None:
                chatter, judge = bake_speech.Chatter(), bake_speech.Judge()
            result, ok = bake_speech.best_take(chatter, judge, line["text"], line["mood"], {})
            if not ok and not args.accept_bad:
                bad.append(line["text"])
                continue
            samples, rate = result["samples"], result["rate"]
        print(f"{line['id']} {line['speaker']} [{line['mood']}] {line['text']}", flush=True)
        samples = bake_speech.level(samples, rate, bake_speech.MOODS[line["mood"]][5])
        path.parent.mkdir(parents=True, exist_ok=True)
        sf.write(path, samples, rate, subtype="PCM_16")
    print("Meeting bake complete")
    if bad:
        sys.exit("No take passed for:\n  " + "\n  ".join(bad))


if __name__ == "__main__":
    main()
