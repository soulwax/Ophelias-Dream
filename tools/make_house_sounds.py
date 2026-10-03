"""The house's voice: knocks at the door, creaking boards and hinges, a
whisper, dripping taps, a steel tray sliding out of a cold chamber, a heavy
thud upstairs and muffled footsteps overhead. All synthesized from simple
physical models (impulses ringing through resonators, shaped noise), so the
project carries no licensed audio.

    python tools/make_house_sounds.py
"""
import math
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
RATE = 44100


def write_wav(name: str, samples: list, peak: float = 0.85) -> None:
	top = max(1e-6, max(abs(s) for s in samples))
	path = os.path.join(OUT, name)
	with wave.open(path, "w") as handle:
		handle.setnchannels(1)
		handle.setsampwidth(2)
		handle.setframerate(RATE)
		frames = bytearray()
		for sample in samples:
			value = max(-1.0, min(1.0, sample / top * peak))
			frames += struct.pack("<h", int(value * 32767))
		handle.writeframes(frames)
	print(name, round(len(samples) / RATE, 2), "s")


class Resonator:
	"""Two-pole resonant filter: rings at `freq` and decays at `decay` per second."""

	def __init__(self, freq: float, decay: float):
		r = math.exp(-decay / RATE)
		self.a1 = 2.0 * r * math.cos(2.0 * math.pi * freq / RATE)
		self.a2 = -r * r
		self.gain = 1.0 - r
		self.y1 = 0.0
		self.y2 = 0.0

	def step(self, x: float) -> float:
		y = self.a1 * self.y1 + self.a2 * self.y2 + self.gain * x
		self.y2 = self.y1
		self.y1 = y
		return y


def silence(seconds: float) -> list:
	return [0.0] * int(RATE * seconds)


def knock(rng: random.Random, strength: float) -> list:
	"""One knuckle on a heavy timber door: a body thump and a hard click."""
	n = int(RATE * 0.32)
	body = Resonator(rng.uniform(120.0, 150.0), 22.0)
	panel = Resonator(rng.uniform(380.0, 460.0), 70.0)
	out = []
	for i in range(n):
		t = i / RATE
		hit = rng.uniform(-1.0, 1.0) * math.exp(-t * 900.0)
		out.append((body.step(hit) * 9.0 + panel.step(hit) * 4.0 + hit * 0.25) * strength)
	return out


def knocks(seed: int, count: int, gap: float, strength: float) -> list:
	rng = random.Random(seed)
	out = []
	for k in range(count):
		out += knock(rng, strength * rng.uniform(0.85, 1.05))
		out += silence(gap * rng.uniform(0.85, 1.15) - 0.32 if k < count - 1 else 0.3)
	return out


def creak(seed: int, seconds: float, rates: tuple, tones: tuple, decay: float) -> list:
	"""Stick-slip: a train of tiny slips whose rate glides through `rates`,
	ringing through the wood's resonances."""
	rng = random.Random(seed)
	n = int(RATE * seconds)
	rings = [Resonator(f, decay) for f in tones]
	phase = 0.0
	out = []
	for i in range(n):
		t = i / n
		# Rate glides start -> middle -> end.
		if t < 0.5:
			rate = rates[0] + (rates[1] - rates[0]) * (t / 0.5)
		else:
			rate = rates[1] + (rates[2] - rates[1]) * ((t - 0.5) / 0.5)
		phase += rate * rng.uniform(0.6, 1.4) / RATE
		slip = 0.0
		if phase >= 1.0:
			phase -= 1.0
			slip = rng.uniform(0.6, 1.0)
		env = math.sin(math.pi * t) ** 0.6
		mix = sum(ring.step(slip) for ring in rings)
		out.append(mix * env + rng.uniform(-1.0, 1.0) * 0.002 * env)
	return out


def whisper(seed: int) -> list:
	"""Breath through two formants, in four or five ragged syllables."""
	rng = random.Random(seed)
	syllables = []
	cursor = 0.12
	for _ in range(rng.randint(4, 5)):
		length = rng.uniform(0.14, 0.3)
		syllables.append((cursor, length, rng.uniform(1500.0, 2400.0), rng.uniform(2700.0, 3600.0)))
		cursor += length + rng.uniform(0.04, 0.16)
	n = int(RATE * (cursor + 0.3))
	out = [0.0] * n
	for start, length, f1, f2 in syllables:
		a = Resonator(f1, 260.0)
		b = Resonator(f2, 420.0)
		low = Resonator(f1 * 0.35, 180.0)
		for i in range(int(RATE * length)):
			t = i / (RATE * length)
			env = (math.sin(math.pi * t) ** 1.5) * (1.0 - 0.4 * t)
			noise = rng.uniform(-1.0, 1.0)
			sample = (a.step(noise) * 1.0 + b.step(noise) * 0.7 + low.step(noise) * 0.4) * env
			out[int(RATE * start) + i] += sample
	return out


def drip(seed: int) -> list:
	"""A drop into a steel basin: a quick falling chirp and a small ring."""
	rng = random.Random(seed)
	n = int(RATE * 0.35)
	ring = Resonator(rng.uniform(2300.0, 2900.0), 40.0)
	phase = 0.0
	out = []
	for i in range(n):
		t = i / RATE
		freq = 1700.0 * math.exp(-t * 22.0) + 600.0
		phase += 2.0 * math.pi * freq / RATE
		chirp = math.sin(phase) * math.exp(-t * 55.0)
		out.append(chirp * 0.8 + ring.step(chirp) * 6.0)
	return out


def tray(seed: int) -> list:
	"""A steel tray rolling out on dry runners, ending in a clunk."""
	rng = random.Random(seed)
	n = int(RATE * 1.3)
	rings = [Resonator(f, 90.0) for f in (1250.0, 2650.0, 4100.0)]
	thump = Resonator(95.0, 12.0)
	out = []
	for i in range(n):
		t = i / RATE
		slide = min(1.0, t / 0.1) * (1.0 if t < 1.0 else math.exp(-(t - 1.0) * 30.0))
		rattle = 0.5 + 0.5 * math.sin(t * 2.0 * math.pi * rng.uniform(17.0, 21.0))
		grit = rng.uniform(-1.0, 1.0) * slide * (0.4 + 0.6 * rattle)
		hit = rng.uniform(-1.0, 1.0) * math.exp(-max(0.0, t - 1.0) * 400.0) if t >= 1.0 else 0.0
		out.append(sum(r.step(grit) for r in rings) * 3.0 + thump.step(hit) * 30.0)
	return out


def thud(seed: int) -> list:
	"""Something heavy put down on the boards above."""
	rng = random.Random(seed)
	n = int(RATE * 1.1)
	floor = Resonator(58.0, 7.0)
	joist = Resonator(140.0, 16.0)
	out = []
	for i in range(n):
		t = i / RATE
		hit = rng.uniform(-1.0, 1.0) * math.exp(-t * 160.0)
		out.append(floor.step(hit) * 30.0 + joist.step(hit) * 12.0)
	return out


def step_above(seed: int) -> list:
	"""A boot on the floor overhead: all low end, the boards swallow the rest."""
	rng = random.Random(seed)
	n = int(RATE * 0.4)
	floor = Resonator(rng.uniform(80.0, 105.0), 18.0)
	out = []
	for i in range(n):
		t = i / RATE
		hit = rng.uniform(-1.0, 1.0) * math.exp(-t * 260.0)
		out.append(floor.step(hit) * 20.0)
	return out


if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	write_wav("house_knock.wav", knocks(5, 3, 0.75, 1.0))
	write_wav("house_knock_hard.wav", knocks(9, 5, 0.42, 1.0), 0.95)
	write_wav("house_creak_door.wav", creak(11, 2.2, (30.0, 95.0, 45.0), (620.0, 1340.0, 2150.0), 55.0))
	write_wav("house_creak_board.wav", creak(23, 0.7, (55.0, 140.0, 70.0), (480.0, 980.0), 80.0))
	write_wav("house_creak_board_2.wav", creak(31, 0.55, (80.0, 60.0, 110.0), (430.0, 1150.0), 90.0))
	write_wav("house_whisper.wav", whisper(47), 0.6)
	write_wav("house_drip.wav", drip(53), 0.5)
	write_wav("house_tray.wav", tray(61))
	write_wav("house_thud.wav", thud(71))
	for k in range(3):
		write_wav("house_step_above_%d.wav" % k, step_above(80 + k))
