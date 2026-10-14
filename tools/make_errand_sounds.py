"""Cuts and levels the errand sounds from Kenney's CC0 audio packs.

    python tools/make_errand_sounds.py ["<bank root>"]   # writes assets/audio/errands/

Sources are Kenney's Impact Sounds and RPG Audio (CC0 1.0, kenney.nl), read
from the owner's asset bank with the License.txt beside each pack checked.
Each OGG is decoded to mono 44.1 kHz with ffmpeg, its leading and trailing
silence trimmed (the bell keeps its whole ringing tail), and levelled the way
tools/make_soundscape.py levels one-shots: the RMS of its loudest 50 ms to a
-12 dBFS impact, never peaking over -1 dBFS. How loud each plays in the game
comes from its SPL in scripts/audio/loudness.gd. Credits go into
assets/audio/provenance.json under errands/; a re-run replaces them, never
duplicates them. Needs ffmpeg on PATH.
"""

import json
import math
import subprocess
import sys
import wave
from array import array
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(r"C:\Users\soulwax\OneDrive - Biz\Desktop\Assets")
KENNEY = BANK / "Kenney Game Assets All-in-1 3.7.0/Audio"
AUDIO = ROOT / "assets/audio"
OUT = AUDIO / "errands"
RATE = 44100
IMPACT_DB = -12.0
CEILING = 0.89  # -1 dBFS
GATE_DB = -45.0  # below the loudest sample: counts as silence when trimming
PACKS = {
	"impact": ("Impact Sounds", "https://kenney.nl/assets/impact-sounds"),
	"rpg": ("RPG Audio", "https://kenney.nl/assets/rpg-audio"),
}
# Output stem: pack, source files (one output each, numbered when several).
SOUNDS = {
	"bell": ("impact", ["impactBell_heavy_000.ogg", "impactBell_heavy_001.ogg"]),  # the longest of these is kept
	"wood_drop": ("impact", ["impactWood_heavy_000.ogg", "impactWood_heavy_001.ogg", "impactWood_heavy_002.ogg", "impactWood_medium_000.ogg"]),
	"wood_stack": ("impact", ["impactPlank_medium_000.ogg", "impactPlank_medium_001.ogg", "impactPlank_medium_002.ogg"]),
	"tin": ("impact", ["impactTin_medium_000.ogg", "impactTin_medium_001.ogg", "impactTin_medium_002.ogg"]),
	"cup": ("impact", ["impactGlass_light_000.ogg", "impactGlass_light_001.ogg", "impactGlass_light_002.ogg"]),
	"cupboard_open": ("rpg", ["doorOpen_1.ogg", "doorOpen_2.ogg"]),
	"cupboard_close": ("rpg", ["doorClose_1.ogg", "doorClose_2.ogg", "doorClose_3.ogg"]),
	"latch": ("rpg", ["metalLatch.ogg"]),
	"kettle": ("rpg", ["metalPot1.ogg"]),  # a one-shot clank, not a loop: the pack has no simmer
	"cloth": ("rpg", ["cloth1.ogg", "cloth2.ogg", "cloth3.ogg", "cloth4.ogg"]),
	"snow_dump": ("impact", ["impactSoft_heavy_000.ogg", "impactSoft_heavy_001.ogg", "impactSoft_heavy_002.ogg", "impactSoft_medium_000.ogg"]),
}
SINGLE = {"bell", "latch", "kettle"}
KEEP_TAIL = {"bell"}


def decode(path: Path) -> array:
	run = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"], capture_output=True)
	if run.returncode != 0:
		raise RuntimeError(run.stderr.decode("utf-8", "replace"))
	samples = array("h")
	samples.frombytes(run.stdout)
	return samples


def trim(samples: array, keep_tail: bool) -> tuple:
	peak = max((abs(s) for s in samples), default=0)
	if peak == 0:
		return 0, 0
	gate = peak * 10.0 ** (GATE_DB / 20.0)
	tail_gate = 2 if keep_tail else gate  # the bell rings out to true silence
	start = next(i for i, s in enumerate(samples) if abs(s) >= gate)
	end = len(samples) - next(i for i, s in enumerate(reversed(samples)) if abs(s) >= tail_gate)
	start = max(0, start - int(0.004 * RATE))
	end = min(len(samples), end + int((0.0 if keep_tail else 0.03) * RATE))
	return start, end


def level(samples: list, tail: float) -> list:
	window = int(0.05 * RATE)
	best = 1.0
	for i in range(0, max(1, len(samples) - window), window // 2):
		block = samples[i:i + window]
		best = max(best, math.sqrt(sum(x * x for x in block) / max(1, len(block))))
	gain = 10.0 ** ((IMPACT_DB - 20.0 * math.log10(best / 32768.0)) / 20.0)
	peak = max(abs(s) for s in samples) * gain
	if peak > 32768.0 * CEILING:
		gain *= 32768.0 * CEILING / peak
	out = [s * gain for s in samples]
	fade_in = int(0.003 * RATE)
	fade_out = min(len(out) // 2, int(tail * RATE))
	for k in range(min(fade_in, len(out))):
		out[k] *= k / fade_in
	for k in range(fade_out):
		out[-1 - k] *= math.sin(0.5 * math.pi * k / fade_out)
	return out


def write_wav(path: Path, samples: list) -> None:
	pcm = array("h", (max(-32767, min(32767, int(round(s)))) for s in samples))
	with wave.open(str(path), "wb") as out:
		out.setnchannels(1)
		out.setsampwidth(2)
		out.setframerate(RATE)
		out.writeframes(pcm.tobytes())


def licence_ok(pack: str) -> bool:
	licence = KENNEY / pack / "License.txt"
	if not licence.exists():
		print("missing", licence)
		return False
	text = licence.read_text(encoding="utf-8", errors="replace")
	if "CC0" not in text and "Creative Commons Zero" not in text:
		print("not CC0:", licence)
		return False
	return True


def main() -> int:
	if not KENNEY.exists():
		sys.exit(f"No Kenney audio at {KENNEY}")
	allowed = {key for key, (pack, _) in PACKS.items() if licence_ok(pack)}
	OUT.mkdir(parents=True, exist_ok=True)
	for old in OUT.glob("*.wav"):
		old.unlink()
	record = {}
	for stem, (key, files) in SOUNDS.items():
		if key not in allowed:
			continue
		pack, page = PACKS[key]
		cuts = []
		for name in files:
			src = KENNEY / pack / "Audio" / name
			if not src.exists():
				print("missing", name)
				continue
			samples = decode(src)
			start, end = trim(samples, stem in KEEP_TAIL)
			if end - start < int(0.02 * RATE):
				print("silent", name)
				continue
			cuts.append((name, start, end, list(samples[start:end])))
		if stem in SINGLE and cuts:
			cuts = [max(cuts, key=lambda cut: cut[2] - cut[1])]
		for index, (name, start, end, samples) in enumerate(cuts):
			out_name = f"{stem}.wav" if stem in SINGLE else f"{stem}_{index:02d}.wav"
			write_wav(OUT / out_name, level(samples, 0.004 if stem in KEEP_TAIL else 0.02))
			record[f"errands/{out_name}"] = {
				"source": "kenney",
				"id": f"{pack}/{name}",
				"page": page,
				"title": f"{pack} ({KENNEY.parent.name}): {name}",
				"author": "Kenney (kenney.nl)",
				"license": "CC0 1.0",
				"taken": f"{start / RATE:.3f}-{end / RATE:.3f}s, mono mix",
				"processing": "levelled one-shot" + (", natural tail kept" if stem in KEEP_TAIL else ""),
			}
			print("sound", out_name, "<-", name, f"{(end - start) / RATE:.2f}s")

	provenance_path = AUDIO / "provenance.json"
	manifest = json.loads(provenance_path.read_text(encoding="utf-8"))
	files = {k: v for k, v in manifest["files"].items() if not k.startswith("errands/")}
	files.update(record)
	manifest["files"] = dict(sorted(files.items()))
	provenance_path.write_text(json.dumps(manifest, indent="\t"), encoding="utf-8", newline="\n")
	print(f"{len(record)} errand sounds, provenance in {provenance_path.relative_to(ROOT)}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
