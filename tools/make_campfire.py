"""Synthesize the campfire loop (assets/audio/nature/campfire_loop.wav).

No recordings: a low breathing roar (filtered noise under a slow swell), a
soft hiss, and crackles. Crackles are short decaying noise bursts at a random,
clustered rate, with now and then a louder pop and a ticking settle of embers.
The ends are crossfaded so it loops, and it is levelled to -20 dBFS RMS like
the project's other loops. Standard library only.

  python tools/make_campfire.py
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
SECONDS = 24.0
FADE = 1.5
OUT = Path(__file__).resolve().parents[1] / "assets/audio/nature/campfire_loop.wav"


def lowpass(signal, cutoff):
	a = math.exp(-2.0 * math.pi * cutoff / RATE)
	out, y = [], 0.0
	for x in signal:
		y = (1.0 - a) * x + a * y
		out.append(y)
	return out


def highpass(signal, cutoff):
	low = lowpass(signal, cutoff)
	return [x - l for x, l in zip(signal, low)]


def main() -> None:
	rng = random.Random(1701)
	n = int(RATE * (SECONDS + FADE))
	white = [rng.uniform(-1.0, 1.0) for _ in range(n)]
	# Roar: deep filtered noise breathing on a few slow swells.
	roar = lowpass(lowpass(white, 260.0), 260.0)
	swell = [0.65 + 0.2 * math.sin(2 * math.pi * i / RATE * 0.11) + 0.15 * math.sin(2 * math.pi * i / RATE * 0.37 + 1.3) for i in range(n)]
	# Hiss: gas and steam from the wood.
	hiss = highpass(lowpass(white, 6500.0), 2200.0)
	out = [roar[i] * 1.9 * swell[i] + hiss[i] * 0.05 * swell[i] for i in range(n)]
	# Crackles, clustered: a burst of activity now and then.
	t = 0.0
	while t < SECONDS + FADE:
		busy = 0.5 + 0.5 * math.sin(t * 0.8) * math.sin(t * 0.23 + 2.0)
		t += rng.expovariate(4.0 + 9.0 * max(busy, 0.0))
		start = int(t * RATE)
		pop = rng.random() < 0.06
		size = rng.uniform(0.25, 0.7) * (2.6 if pop else 1.0)
		decay = rng.uniform(0.0015, 0.006) * (2.5 if pop else 1.0)
		tone = rng.uniform(1800.0, 5200.0) * (0.45 if pop else 1.0)
		length = int(decay * 7 * RATE)
		phase = rng.random() * math.tau
		for k in range(length):
			i = start + k
			if i >= n:
				break
			env = math.exp(-k / (decay * RATE))
			grit = rng.uniform(-1.0, 1.0)
			out[i] += size * env * (0.6 * grit + 0.4 * math.sin(phase + math.tau * tone * k / RATE))
		# Embers settling after a pop.
		if pop:
			for _ in range(rng.randint(3, 7)):
				j = start + int(rng.uniform(0.02, 0.25) * RATE)
				for k in range(int(0.004 * RATE)):
					if j + k < n:
						out[j + k] += 0.12 * math.exp(-k / (0.0008 * RATE)) * rng.uniform(-1.0, 1.0)
	# Loop: crossfade the extra tail into the head.
	loop = int(SECONDS * RATE)
	fade = int(FADE * RATE)
	for k in range(fade):
		w = k / fade
		out[k] = out[k] * w + out[loop + k] * (1.0 - w)
	out = out[:loop]
	rms = math.sqrt(sum(x * x for x in out) / len(out))
	gain = 10 ** (-20 / 20) / rms
	peak = max(abs(x) for x in out) * gain
	if peak > 0.97:
		gain *= 0.97 / peak
		peak = 0.97
	OUT.parent.mkdir(parents=True, exist_ok=True)
	with wave.open(str(OUT), "wb") as wav:
		wav.setnchannels(1)
		wav.setsampwidth(2)
		wav.setframerate(RATE)
		wav.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * gain)) * 32767)) for x in out))
	level = 20 * math.log10(rms * gain)
	print(f"wrote {OUT.relative_to(OUT.parents[3])}: {SECONDS:.0f} s, {level:.1f} dBFS RMS, peak {20 * math.log10(peak):.1f} dBFS")


if __name__ == "__main__":
	main()
