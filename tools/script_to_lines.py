"""Turn the spoken script in docs/MATHILDA_STORY.md into assets/audio/voice/lines.json.

The story doc is the script of record. `--check` exits 1 if lines.json differs.
"""

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs/MATHILDA_STORY.md"
OUT = ROOT / "assets/audio/voice/lines.json"
# Section heading -> (group, shape): keyed (id: line), staged (stage: [lines]), flat [lines], single line.
SECTIONS = {
    "Page reactions": ("pages", "keyed"),
    "Deciphered pages": ("deciphered", "keyed"),
    "First visits": ("places", "keyed"),
    "Revisits": ("revisits", "keyed"),
    "Time and the lake": ("moments", "keyed"),
    "Idle thoughts": ("bored", "staged"),
    "Memories": ("memories", "staged"),
    "Calls into the storm": ("calls", "staged"),
    "When she runs out of breath": ("spent", "flat"),
    "The cold": ("cold", "flat"),
    "Falls": ("falls", "flat"),
    "Turning around": ("turned", "single"),
    "The trees answer": ("answers", "keyed"),
    "Rejected readings in the journal": ("misread", "flat"),
    "Over the end card": ("endings", "keyed"),
}
STAGE = {"hope": "hope", "doubt": "doubt", "resolve": "resolve", "after": "after"}
# The lake ending keeps the old key "road", which the voice and its answer use.
ENDING_IDS = {"the lake": "road", "the road": "road", "one set of prints": "prints", "mathilda is gone": "gone"}
# Per-line delivery overrides for the baker; the game ignores them.
OVERRIDES = {
    "Go, then!": {"exaggeration": 0.9},
    # A single word gives Chatterbox too little to hold on to; calmer sampling keeps it a word.
    "Okay.": {"temperature": 0.5, "cfg": 0.6},
}
KEYED = re.compile(r"^- \*\*(.+?):\*\* \[([a-z]+)\] (.+)$")
PLAIN = re.compile(r"^- \[([a-z]+)\] (.+)$")


def parse(text):
    script = text.split("## Spoken script", 1)[1]
    data, group, shape, stage = {}, None, None, None
    for raw in script.splitlines():
        line = raw.strip()
        if line.startswith("### "):
            title = line[4:]
            group, shape = next((v for k, v in SECTIONS.items() if title.startswith(k)), (None, None))
            stage = None
            if group and group not in data:
                data[group] = [] if shape == "flat" else {}
            continue
        if line.startswith("**") and shape == "staged":
            word = line[2:].split("**", 1)[0].split()[0].lower()
            stage = STAGE.get(word)
            if stage:
                data[group].setdefault(stage, [])
            continue
        if not group or not line.startswith("- "):
            continue
        keyed, plain = KEYED.match(line), PLAIN.match(line)
        if shape == "keyed" and keyed:
            key = keyed.group(1)
            key = ENDING_IDS.get(key.lower(), key)
            data[group][key] = entry(keyed.group(3), keyed.group(2))
        elif plain and shape == "staged" and stage:
            data[group][stage].append(entry(plain.group(2), plain.group(1)))
        elif plain and shape == "flat":
            data[group].append(entry(plain.group(2), plain.group(1)))
        elif plain and shape == "single":
            data[group] = entry(plain.group(2), plain.group(1))
    return data


def entry(text, mood):
    item = {"text": text.strip(), "mood": mood}
    item.update(OVERRIDES.get(item["text"], {}))
    return item


def count(data):
    total = 0
    for value in data.values():
        if isinstance(value, list):
            total += len(value)
        elif "text" in value:
            total += 1
        else:
            total += sum(len(v) if isinstance(v, list) else 1 for v in value.values())
    return total


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = parse(DOC.read_text(encoding="utf-8"))
    rendered = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    print(f"{count(data)} lines: " + ", ".join(f"{k} {count({k: v})}" for k, v in data.items()))
    if args.check:
        same = OUT.exists() and json.loads(OUT.read_text(encoding="utf-8")) == data
        print("lines.json matches the script" if same else "lines.json differs from the script")
        sys.exit(0 if same else 1)
    OUT.write_text(rendered, encoding="utf-8")


if __name__ == "__main__":
    main()
