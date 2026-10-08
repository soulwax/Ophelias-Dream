"""Where every spoken line stands: final, draft or missing, and what is owed to whom.

  python tools/voice_status.py              # summary and the owed list
  python tools/voice_status.py --json       # every line, for tools
  python tools/voice_status.py --owed kokoro  # only one engine's debt

docs/STORY_STUDIO.md, phase 0. Standard library only.
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from studio import model  # noqa: E402


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--owed", help="only lines owed to this engine (kokoro, desktop:chatterbox)")
    args = parser.parse_args()
    lines = model.load()
    if args.json:
        print(json.dumps([line.as_dict() for line in lines], ensure_ascii=False, indent=1))
        return
    print(f"{'chapter':10} {'lines':>5} {'final':>5} {'draft':>5} {'missing':>7}")
    for chapter, row in model.summary(lines).items():
        print(f"{chapter:10} {row['lines']:5} {row['final']:5} {row['draft']:5} {row['missing']:7}")
    for engine, owed in model.owed(lines).items():
        if args.owed and engine != args.owed:
            continue
        print(f"\nowed to {engine}: {len(owed)}")
        for line in owed:
            print(f"  [{line.clip:7}] {line.uid:34} {line.mood:9} {line.text[:70]}")
    stray = model.orphans(lines)
    if stray and not args.owed:
        print(f"\nclips no line plays any more: {len(stray)} (archive candidates)")


if __name__ == "__main__":
    main()
