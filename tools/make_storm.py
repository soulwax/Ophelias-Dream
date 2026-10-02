"""Seamless snowstorm layers: a low wind body, a snow hiss, and a gust."""
import math
import os
import random
import struct
import wave

OUT = r"C:\Users\soulwax\Workspace\Godot\run\assets\audio"
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


def brown(rng: random.Random, n: int, follow: float) -> list:
	value = 0.0
	out = []
	for _i in range(n):
		value = value * follow + rng.uniform(-1.0, 1.0) * (1.0 - follow)
		out.append(value)
	peak = max(1e-6, max(abs(s) for s in out))
	return [s / peak for s in out]


def body() -> list:
	rng = random.Random(11)
	n = RATE * 16
	low = brown(rng, n, 0.992)
	mid = brown(rng, n, 0.85)
	samples = []
	for i in range(n):
		t = i / RATE
		swell = 0.62 + 0.38 * math.sin(t * 0.37) * math.sin(t * 0.11 + 1.2)
		gust = max(0.0, math.sin(t * 0.53 + 0.4)) ** 3
		sample = (low[i] * 0.72 + mid[i] * 0.22) * (0.45 + swell * 0.4 + gust * 0.35)
		samples.append(sample)
	return seamless(samples, 0.6)


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


def gust() -> list:
	rng = random.Random(47)
	n = int(RATE * 4.2)
	low = brown(rng, n, 0.97)
	samples = []
	for i in range(n):
		t = i / RATE
		env = math.sin(min(1.0, t / 4.2) * math.pi) ** 0.65
		env *= 1.0 - math.exp(-t * 6.0)
		samples.append(low[i] * env * 0.9)
	peak = max(1e-6, max(abs(s) for s in samples))
	return [s / peak * 0.95 for s in samples]


if __name__ == "__main__":
	write_wav("storm_body.wav", body())
	write_wav("storm_hiss.wav", hiss())
	write_wav("storm_gust.wav", gust())
