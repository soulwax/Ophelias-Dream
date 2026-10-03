"""A seamless snow hiss: the powder under her boots while she slides.

The storm itself is recorded now (tools/fetch_sounds.py, make_soundscape.py).
"""
import math
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
RATE = 44100


def write_wav(name: str, samples: list) -> None:
	path = os.path.join(OUT, name)
	with wave.open(path, "w") as handle:
		handle.setnchannels(1)
		handle.setsampwidth(2)
		handle.setframerate(RATE)
		frames = bytearray()
		for sample in samples:
			value = max(-1.0, min(1.0, sample))
			frames += struct.pack("<h", int(value * 32767))
		handle.writeframes(frames)
	print(name, len(samples), os.path.getsize(path))


def seamless(samples: list, fade_seconds: float) -> list:
	fade = int(RATE * fade_seconds)
	out = samples[:-fade]
	for i in range(fade):
		weight = i / fade
		out[i] = samples[i] * weight + samples[-fade + i] * (1.0 - weight)
	return out


def hiss() -> list:
	rng = random.Random(29)
	n = RATE * 12
	grain = 0.0
	samples = []
	for i in range(n):
		t = i / RATE
		white = rng.uniform(-1.0, 1.0)
		grain = grain * 0.35 + white * 0.65
		flutter = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * 1.7 + math.sin(t * 0.4) * 2.0))
		spark = grain if rng.random() < 0.08 else grain * 0.25
		samples.append(spark * flutter * 0.55)
	return seamless(samples, 0.4)


if __name__ == "__main__":
	write_wav("storm_hiss.wav", hiss())
