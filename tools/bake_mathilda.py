"""Perform Mathilda's separate local voice from the authored chapter script."""
import argparse, hashlib, json, re
from pathlib import Path
from types import SimpleNamespace
import bake_speech
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/voice/mathilda"

def parse():
    groups, current = {}, None
    text = (ROOT / "docs/MATHILDA_POV.md").read_text(encoding="utf-8").split("## Spoken script", 1)[1]
    for line in text.splitlines():
        if line.startswith("### "):
            current = line[4:]; groups[current] = []
        keyed = re.match(r"^- \*\*([a-z0-9_]+):\*\* \[([a-z]+)\] (.+)$", line)
        if keyed:
            groups[current].append(dict(id=keyed[1], mood=keyed[2], text=keyed[3]))
            continue
        match = re.match(r"^- \[([a-z]+)\] (.+)$", line)
        if match:
            groups[current].append(dict(mood=match[1], text=match[2]))
    return groups

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--write", action="store_true", help="only rewrite lines.json")
    args = parser.parse_args()
    data = parse()
    target = OUT / "lines.json"
    if args.check:
        assert json.loads(target.read_text(encoding="utf-8")) == data
        print("Mathilda script matches lines.json")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    if args.write:
        print("Mathilda lines.json written")
        return
    import soundfile as sf
    speak = bake_speech.bake_kokoro(SimpleNamespace(voice="af_bella", speed=0.94))
    for group, entries in data.items():
        for entry in entries:
            key = hashlib.sha256((entry["text"]+"|"+entry["mood"]).encode()).hexdigest()
            path = OUT / (key+".wav")
            if path.exists(): continue
            print(group+": "+entry["text"], flush=True)
            samples, rate = speak(entry["text"])
            sf.write(path, samples, rate, subtype="PCM_16")
    print("Mathilda bake complete", flush=True)
if __name__ == "__main__": main()
