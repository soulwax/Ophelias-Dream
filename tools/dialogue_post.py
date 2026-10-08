"""Clean, level and time the doorway meeting's clips (docs/MEETING_VOICE.md, stages 6-7).

Clips are baked dry: the game supplies the room. `clean()` gives every take the
same treatment, so both voices sit in one dry room: a shared 70 Hz high-pass,
silence trimmed, 8 ms fades against clicks, the mood's dBFS level from
bake_speech.MOODS, and one matched noise floor.

`python tools/dialogue_post.py` writes assets/audio/voice/meeting/timing.json:
per line the clip in use (final, draft or none), its length, the authored pause
and any authored overlap. Conversation reads it. `--check` fails when it no
longer matches lines.json or the clips on disk.
"""
import argparse
import json
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/voice/meeting"
DRAFT = OUT / "draft"
HIGH_PASS_HZ = 70.0
FADE_S = 0.008
NOISE_FLOOR_DB = -72.0


def clip_name(text, mood):
    import hashlib
    return hashlib.sha256((text + "|" + mood).encode("utf-8")).hexdigest() + ".wav"


def clean(samples, rate, mood):
    """One dry treatment for every take of either speaker."""
    import numpy as np
    import bake_speech
    samples = np.asarray(samples, dtype=np.float32)
    # One-pole high-pass, the same corner for both voices.
    alpha = 1.0 / (1.0 + 2.0 * np.pi * HIGH_PASS_HZ / rate)
    filtered = np.empty_like(samples)
    previous_in = previous_out = 0.0
    for i, value in enumerate(samples):
        previous_out = alpha * (previous_out + value - previous_in)
        previous_in = value
        filtered[i] = previous_out
    samples = bake_speech.trim(filtered, rate)
    fade = min(int(FADE_S * rate), len(samples) // 2)
    if fade > 0:
        ramp = np.linspace(0.0, 1.0, fade, dtype=np.float32)
        samples[:fade] *= ramp
        samples[-fade:] *= ramp[::-1]
    samples = bake_speech.level(samples, rate, bake_speech.MOODS[mood][5])
    rng = np.random.default_rng(1701)
    samples = samples + rng.standard_normal(len(samples)).astype(np.float32) * (10.0 ** (NOISE_FLOOR_DB / 20.0))
    return np.clip(samples, -1.0, 1.0)


def seconds(path):
    with wave.open(str(path), "rb") as clip:
        return clip.getnframes() / float(clip.getframerate())


def timing(lines):
    sheet = []
    for line in lines:
        name = clip_name(line["text"], line["mood"])
        source, length = "none", None
        if (OUT / name).exists():
            source, length = "final", seconds(OUT / name)
        elif (DRAFT / name).exists():
            source, length = "draft", seconds(DRAFT / name)
        sheet.append(dict(id=line["id"], source=source, file=name if source != "none" else None,
                          seconds=round(length, 3) if length is not None else None,
                          pause=line["pause"], overlap=line.get("overlap", 0.0)))
    return sheet


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="Fail if timing.json is stale")
    args = parser.parse_args()
    lines = json.loads((OUT / "lines.json").read_text(encoding="utf-8"))
    sheet = timing(lines)
    target = OUT / "timing.json"
    if args.check:
        if not target.exists() or json.loads(target.read_text(encoding="utf-8")) != sheet:
            sys.exit("meeting/timing.json is stale; run tools/dialogue_post.py")
        print(f"Timing matches lines.json and the clips ({len(sheet)} lines)")
        return
    target.write_text(json.dumps(sheet, indent=2) + "\n", encoding="utf-8")
    counts = {kind: sum(1 for entry in sheet if entry["source"] == kind) for kind in ("final", "draft", "none")}
    print(f"Wrote {target.relative_to(ROOT)}: {counts['final']} final, {counts['draft']} draft, {counts['none']} subtitle only")


if __name__ == "__main__":
    main()
