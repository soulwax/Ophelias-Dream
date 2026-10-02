"""Short, dry taps of a light boot in snow. No crunch tail."""
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
	print(name, len(samples))


def tap(seed: int, dur: float, body: float, tick: float) -> list:
	rng = random.Random(seed)
	n = int(RATE * dur)
	low = 0.0
	out = []
	for i in range(n):
		t = i / RATE
		attack = 1.0 - math.exp(-t * 900.0)
		env = attack * math.exp(-t * (28.0 + body))
		white = rng.uniform(-1.0, 1.0)
		low += (white - low) * 0.08
		click = white * math.exp(-t * (180.0 + tick * 40.0))
		sample = (low * 0.35 + click * 0.22) * env
		out.append(sample)
	peak = max(1e-6, max(abs(s) for s in out))
	return [s / peak * 0.72 for s in out]


if __name__ == "__main__":
	specs = [
		(3, 0.07, 8.0, 2.0),
		(17, 0.055, 14.0, 6.0),
		(41, 0.08, 6.0, 1.0),
		(63, 0.06, 18.0, 8.0),
		(89, 0.075, 10.0, 3.0),
		(101, 0.05, 22.0, 10.0),
	]
	for i, spec in enumerate(specs):
		write_wav("tap_%d.wav" % i, tap(*spec))
