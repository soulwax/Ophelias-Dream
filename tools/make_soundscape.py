"""Cuts and levels the CC0 recordings in build/sfx_src/ into the game's sounds.

    python tools/fetch_sounds.py      # once: downloads the sources
    python tools/make_soundscape.py   # writes assets/audio/{steps,weather,nature}/

Every one-shot is levelled to the same impact loudness (the RMS of its loudest
50 ms) and every loop to the same RMS, so how loud a sound plays in the game
comes only from its physical level in scripts/audio/loudness.gd and its
distance from her ears. Loops are made seamless by crossfading their tail
into their head. Writes assets/audio/provenance.json. Needs ffmpeg on PATH.
"""

import json
import math
import pathlib
import subprocess
import sys
import tempfile
import wave
from array import array

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "build" / "sfx_src"
AUDIO = ROOT / "assets" / "audio"
RATE = 48000
SCAN_RATE = 16000
HOP = 0.005
IMPACT_DB = -12.0
BED_DB = -20.0
CEILING = 0.89  # -1 dBFS

# Event cuts: output stem, source, channel, how many, detection settings.
# rise: dB above the noise floor an onset must reach; gap: shortest time
# between two events; length: longest event; span: how far below the
# loudest moment an event may be and still count.
EVENTS = [
	("steps/snow", "snow_bsb_2890", None, 6, dict(rise=10, gap=0.3, length=0.55, span=26, highpass=250)),
	("steps/snow", "snow_bsb_0208", None, 5, dict(rise=10, gap=0.3, length=0.55, span=26, highpass=250)),
	("steps/snow", "snow_bsb_3363", None, 4, dict(rise=10, gap=0.25, length=0.5, span=26, highpass=250)),
	("steps/snow", "snow_fs_613849", None, 4, dict(rise=10, gap=0.3, length=0.6, span=26, highpass=250)),
	("steps/snow", "snow_fs_554726", 0, 5, dict(rise=10, gap=0.3, length=0.6, span=26, highpass=250)),
	("steps/wood", "wood_bsb_0165", None, 4, dict(rise=12, gap=0.3, length=0.45, span=24, highpass=120)),
	("steps/wood", "wood_bsb_0376", None, 6, dict(rise=12, gap=0.3, length=0.45, span=24, highpass=120)),
	("steps/wood", "wood_fs_614291", None, 6, dict(rise=12, gap=0.3, length=0.45, span=24, highpass=120)),
	("steps/wood", "wood_fs_142000", 0, 4, dict(rise=12, gap=0.3, length=0.45, span=24, highpass=120)),
	("steps/stone", "stone_bsb_0606", None, 5, dict(rise=12, gap=0.3, length=0.45, span=24, highpass=150)),
	("steps/stone", "stone_bsb_0514", None, 4, dict(rise=12, gap=0.3, length=0.45, span=24, highpass=150)),
	("steps/stone", "stone_fs_521590", None, 3, dict(rise=12, gap=0.3, length=0.45, span=24, highpass=150)),
	("steps/stone", "stone_fs_677069", None, 5, dict(rise=12, gap=0.3, length=0.45, span=24, highpass=150)),
	("steps/stone", "stone_fs_813622", None, 4, dict(rise=12, gap=0.3, length=0.45, span=24, highpass=150)),
	("steps/creak", "creak_fs_506665", 0, 1, dict(rise=8, gap=0.5, length=1.2, span=30, highpass=80)),
	("steps/creak", "creak_fs_264306", 0, 5, dict(rise=8, gap=0.6, length=1.2, span=24, highpass=80)),
	("steps/creak", "creak_bsb_0518", None, 4, dict(rise=8, gap=0.6, length=1.2, span=24, highpass=80)),
	("steps/grass", "grass_fs_521587", 0, 6, dict(rise=10, gap=0.3, length=0.5, span=26, highpass=150)),
	("steps/grass", "grass_fs_331167", 0, 5, dict(rise=10, gap=0.3, length=0.5, span=26, highpass=150)),
	("steps/grass", "grass_fs_505833", 0, 5, dict(rise=10, gap=0.3, length=0.5, span=26, highpass=150)),
	("steps/grass", "grass_fs_206030", 0, 4, dict(rise=10, gap=0.3, length=0.5, span=26, highpass=150)),
	("steps/grass", "grass_fs_389625", 0, 4, dict(rise=10, gap=0.3, length=0.5, span=26, highpass=150)),
	("nature/flump", "snowfall_fs_116136", 0, 8, dict(rise=10, gap=0.8, length=1.6, span=24, highpass=60)),
	("nature/tree_creak", "treecreak_fs_95264", 0, 5, dict(rise=8, gap=0.8, length=2.5, span=24, highpass=80)),
	("nature/crow", "crow_fs_334231", 0, 6, dict(rise=12, gap=0.3, length=1.4, span=24, highpass=300)),
	("nature/crow", "crow_fs_252685", 0, 3, dict(rise=12, gap=0.3, length=1.4, span=24, highpass=300)),
	("nature/raven", "raven_fs_675958", None, 5, dict(rise=12, gap=0.3, length=1.4, span=24, highpass=250)),
	("nature/raven", "raven_fs_864903", 0, 3, dict(rise=12, gap=0.3, length=1.4, span=24, highpass=250)),
]

# Loops: output, source, channel, start (s), length (s).
BEDS = [
	("weather/storm_0", "storm_fs_35480", 0, 10.0, 110.0),
	("weather/storm_1", "storm_fs_35480", 1, 95.0, 110.0),
	("weather/storm_2", "storm_fs_505999", 0, 20.0, 110.0),
	("weather/storm_3", "storm_fs_505999", 1, 190.0, 110.0),
	("weather/breeze_0", "wind_bsb_0595", None, 2.0, 40.0),
	("weather/breeze_1", "wind_bsb_0595", None, 45.0, 40.0),
	("weather/howl", "howl_fs_256862", 0, 0.5, 22.0),
	("weather/window", "window_fs_69512", 0, 30.0, 90.0),
	("nature/trees_0", "trees_bsb_1051", None, 3.0, 70.0),
	("nature/trees_1", "trees_bsb_1051", None, 78.0, 70.0),
	("nature/trees_2", "treecreak_fs_140047", 0, 40.0, 90.0),
]

# Footsteps heard through the boards from the cellar: wood steps, dulled.
ABOVE = ("steps/above", "steps/wood", 6, "lowpass=f=700,lowpass=f=900,aecho=0.7:0.5:14:0.3")


def sources() -> dict:
	return json.loads((SRC / "sources.json").read_text(encoding="utf-8"))


def ffmpeg(args: list, data: bytes | None = None) -> bytes:
	run = subprocess.run(["ffmpeg", "-v", "error", "-y", *args], input=data, capture_output=True)
	if run.returncode != 0:
		raise RuntimeError(run.stderr.decode("utf-8", "replace"))
	return run.stdout


def decode(path: pathlib.Path, channel, start=None, length=None, rate=RATE, extra="") -> array:
	args = []
	if start is not None:
		args += ["-ss", f"{max(start, 0.0):.4f}"]
	if length is not None:
		args += ["-t", f"{length:.4f}"]
	chain = [f"pan=mono|c0=c{channel}"] if channel is not None else []
	if extra:
		chain.append(extra)
	args += ["-i", str(path)]
	if chain:
		args += ["-af", ",".join(chain)]
	args += ["-ac", "1", "-ar", str(rate), "-f", "s16le", "-"]
	samples = array("h")
	samples.frombytes(ffmpeg(args))
	return samples


def write_wav(path: pathlib.Path, samples) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	pcm = array("h", (max(-32767, min(32767, int(round(s)))) for s in samples))
	with wave.open(str(path), "wb") as out:
		out.setnchannels(1)
		out.setsampwidth(2)
		out.setframerate(RATE)
		out.writeframes(pcm.tobytes())


def envelope(samples, rate) -> list:
	hop = int(rate * HOP)
	out = []
	for i in range(0, len(samples) - hop, hop):
		block = samples[i:i + hop]
		energy = sum(x * x for x in block) / hop
		out.append(10.0 * math.log10(energy + 1e-3) - 90.31)
	return out


def find_events(env, rise, gap, length, span, min_length=0.08, decay=32.0) -> list:
	ranked = sorted(env)
	floor = ranked[len(ranked) // 5]
	threshold = max(floor + rise, ranked[-1] - span)
	attack = int(0.03 / HOP)
	found = []
	i = 0
	last = -1e9
	while i < len(env):
		sharp = env[i] - min(env[max(0, i - attack):i + 1]) >= 6.0
		if env[i] < threshold or not sharp or i * HOP - last < gap:
			i += 1
			continue
		start = max(0, i - 2)
		peak = env[i]
		quiet = 0
		j = i
		limit = min(len(env), i + int(length / HOP))
		# Cut off by the next event: stop short of its attack, not after it.
		chopped = False
		while j < limit:
			peak = max(peak, env[j])
			if (j - i) * HOP >= gap and env[j] >= threshold and env[j] - min(env[max(0, j - attack):j + 1]) >= 6.0:
				chopped = True
				j = max(i + 1, j - attack)
				break
			quiet = quiet + 1 if env[j] < max(floor + 3.0, peak - decay) else 0
			if quiet * HOP >= 0.04:
				break
			j += 1
		if (j - start) * HOP >= min_length:
			found.append((start * HOP, j * HOP, peak, chopped))
		last = i * HOP
		i = max(i + 1, j)
	return found


def rank(found: list) -> list:
	"""Steadiest first: events near the typical level, spread through the take."""
	if not found:
		return []
	peaks = sorted(event[2] for event in found)
	typical = peaks[len(peaks) // 2]
	steady = [event for event in found if abs(event[2] - typical) <= 8.0]
	order = []
	stride = max(1, len(steady) // 12)
	for offset in range(stride):
		order.extend(steady[offset::stride])
	return order


def level_one_shot(samples, tail=0.06, early=False) -> list | None:
	if not samples:
		return None
	if max(abs(s) for s in samples) >= 32600:
		return None  # clipped in the source
	window = int(0.05 * RATE)
	best = 1.0
	loudest_at = 0
	for i in range(0, max(1, len(samples) - window), window // 2):
		block = samples[i:i + window]
		level = math.sqrt(sum(x * x for x in block) / max(1, len(block)))
		if level > best:
			best = level
			loudest_at = i
	# A footstep lands at its start; a scuff that only lands at the end is not one.
	if early and loudest_at > len(samples) * 0.5:
		return None
	gain = 10.0 ** ((IMPACT_DB - 20.0 * math.log10(best / 32768.0)) / 20.0)
	peak = max(abs(s) for s in samples) * gain
	if peak > 32768.0 * CEILING:
		gain *= 32768.0 * CEILING / peak
	out = [s * gain for s in samples]
	fade_in = int(0.003 * RATE)
	fade_out = min(len(out) // 2, int(tail * RATE))
	for k in range(fade_in):
		out[k] *= k / fade_in
	for k in range(fade_out):
		out[-1 - k] *= math.sin(0.5 * math.pi * k / fade_out)
	return out


def cut_events(info: dict, record: dict) -> None:
	counters = {}
	for stem, name, channel, count, settings in EVENTS:
		path = SRC / info[name]["file"]
		scan = decode(path, channel, rate=SCAN_RATE, extra=f"highpass=f={settings['highpass']}")
		env = envelope(scan, SCAN_RATE)
		found = find_events(env, settings["rise"], settings["gap"], settings["length"], settings["span"])
		taken = 0
		for start, end, _peak, chopped in rank(found):
			if taken >= count:
				break
			cut = decode(path, channel, start - 0.005, end - start + (0.0 if chopped else 0.08), extra="highpass=f=40")
			levelled = level_one_shot(list(cut), early=stem.startswith("steps/"))
			if levelled is None:
				continue
			index = counters.get(stem, 0)
			counters[stem] = index + 1
			target = AUDIO / f"{stem}_{index:02d}.wav"
			write_wav(target, levelled)
			record[str(target.relative_to(AUDIO)).replace("\\", "/")] = _credit(info[name], f"{start:.3f}-{end:.3f}s", channel, "levelled one-shot")
			taken += 1
		print(f"{stem:20s} <- {name:20s} {taken}/{count} of {len(found)} events")


def make_beds(info: dict, record: dict) -> None:
	for stem, name, channel, start, length in BEDS:
		path = SRC / info[name]["file"]
		cross = 4.0
		with tempfile.TemporaryDirectory() as scratch:
			raw = pathlib.Path(scratch) / "raw.wav"
			loop = pathlib.Path(scratch) / "loop.wav"
			chain = f"pan=mono|c0=c{channel}," if channel is not None else ""
			ffmpeg(["-ss", f"{start}", "-t", f"{length + cross}", "-i", str(path), "-af", chain + "highpass=f=25", "-ac", "1", "-ar", str(RATE), str(raw)])
			ffmpeg(["-i", str(raw), "-filter_complex",
				f"[0:a]asplit=2[a][b];[a]atrim=start={length}:end={length + cross},asetpts=PTS-STARTPTS[tail];"
				f"[b]atrim=start=0:end={length},asetpts=PTS-STARTPTS[head];"
				f"[tail][head]acrossfade=d={cross}:c1=qsin:c2=qsin", str(loop)])
			level = _mean_db(loop)
			target = AUDIO / f"{stem}.ogg"
			target.parent.mkdir(parents=True, exist_ok=True)
			ffmpeg(["-i", str(loop), "-af", f"volume={BED_DB - level:.2f}dB,alimiter=limit={CEILING}:level=false", "-c:a", "libvorbis", "-q:a", "5", str(target)])
		record[str(target.relative_to(AUDIO)).replace("\\", "/")] = _credit(info[name], f"{start:.1f}-{start + length:.1f}s", channel, "seamless loop, levelled")
		print(f"{stem:20s} <- {name:20s} {length:.0f}s loop")


def make_above(record: dict) -> None:
	stem, from_stem, count, chain = ABOVE
	made = 0
	for source in sorted(AUDIO.glob(from_stem + "_*.wav"))[:count]:
		dulled = decode(source, None, extra=chain)
		levelled = level_one_shot(list(dulled), tail=0.12)
		if levelled is None:
			continue
		target = AUDIO / f"{stem}_{made:02d}.wav"
		write_wav(target, levelled)
		base = record.get(str(source.relative_to(AUDIO)).replace("\\", "/"), {})
		record[str(target.relative_to(AUDIO)).replace("\\", "/")] = dict(base, processing="wood step heard through the floor: low-passed, one early reflection")
		made += 1
	print(f"{stem:20s} <- {from_stem} {made}")


def _mean_db(path: pathlib.Path) -> float:
	run = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"], capture_output=True)
	for line in run.stderr.decode("utf-8", "replace").splitlines():
		if "mean_volume:" in line:
			return float(line.split("mean_volume:")[1].split("dB")[0])
	return -30.0


def _credit(source: dict, span: str, channel, processing: str) -> dict:
	return {
		"source": source["source"],
		"id": source["id"],
		"page": source["page"],
		"title": source.get("title", ""),
		"author": source["author"],
		"license": source["license"],
		"taken": span + ("" if channel is None else f", channel {channel}"),
		"processing": processing,
	}


def main() -> int:
	info = sources()
	for folder in ("steps", "weather", "nature"):
		for old in (AUDIO / folder).glob("*.*"):
			if old.suffix in (".wav", ".ogg"):
				old.unlink()
	record = {}
	cut_events(info, record)
	make_beds(info, record)
	make_above(record)
	manifest = {
		"note": "Recorded sounds for Ophelia's Dream. All sources are CC0 1.0 (public domain); "
			"credit is not required but is kept here. Regenerate with tools/fetch_sounds.py "
			"then tools/make_soundscape.py.",
		"files": dict(sorted(record.items())),
	}
	(AUDIO / "provenance.json").write_text(json.dumps(manifest, indent="\t"), encoding="utf-8")
	print(f"{len(record)} files, provenance in {AUDIO / 'provenance.json'}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
