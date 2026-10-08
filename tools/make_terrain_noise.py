"""Bake the ground shader's gradient noise as periodic linear data.

Requires Pillow. Run from the repository root; no vendor assets are modified.
The shader decodes red as 2*r-1 and retains its rotated, warped coordinates.
"""

import math
from pathlib import Path

from PIL import Image


PERIOD = 64
SIZE = 1024
OUT = Path(__file__).resolve().parents[1] / "assets/environment/terrain_noise.png"


def fract(value: float) -> float:
    return value - math.floor(value)


def gradient(x: int, y: int) -> tuple[float, float]:
    a, b = fract(x * 123.34), fract(y * 345.45)
    dot = a * (a + 34.345) + b * (b + 34.345)
    angle = fract((a + dot) * (b + dot)) * math.tau
    return math.cos(angle), math.sin(angle)


def bake() -> None:
    gradients = [[gradient(x, y) for x in range(PERIOD)] for y in range(PERIOD)]
    pixels = bytearray(SIZE * SIZE)
    for y in range(SIZE):
        py = (y + 0.5) * PERIOD / SIZE
        iy, fy = math.floor(py), fract(py)
        uy = fy * fy * fy * (fy * (fy * 6.0 - 15.0) + 10.0)
        row_a, row_b = gradients[iy % PERIOD], gradients[(iy + 1) % PERIOD]
        for x in range(SIZE):
            px = (x + 0.5) * PERIOD / SIZE
            ix, fx = math.floor(px), fract(px)
            ux = fx * fx * fx * (fx * (fx * 6.0 - 15.0) + 10.0)
            a, b = row_a[ix % PERIOD], row_a[(ix + 1) % PERIOD]
            c, d = row_b[ix % PERIOD], row_b[(ix + 1) % PERIOD]
            n00 = a[0] * fx + a[1] * fy
            n10 = b[0] * (fx - 1.0) + b[1] * fy
            n01 = c[0] * fx + c[1] * (fy - 1.0)
            n11 = d[0] * (fx - 1.0) + d[1] * (fy - 1.0)
            low = n00 + (n10 - n00) * ux
            high = n01 + (n11 - n01) * ux
            value = low + (high - low) * uy
            pixels[y * SIZE + x] = max(0, min(255, round((value * 0.5 + 0.5) * 255)))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.frombytes("L", (SIZE, SIZE), bytes(pixels)).save(OUT, optimize=True)
    print(f"Saved {OUT} ({SIZE}x{SIZE}, {PERIOD}-cell seamless period)")


if __name__ == "__main__":
    bake()
