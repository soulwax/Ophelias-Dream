"""Build a winter-suit albedo from the sculpted body texture.

The face window stays skin. Everywhere else keeps the original light and
shadow, retinted as wool, so the suit still follows the mesh.
"""
import os
from PIL import Image, ImageFilter

SRC = r"C:\Users\soulwax\Workspace\Godot\run\addons\quaternius_ik_rigged\Godot - UE\T_Superhero_Male_Dark.png"
DST = r"C:\Users\soulwax\Workspace\Godot\run\assets\characters\winter_coat.png"

COAT = (0.20, 0.22, 0.25)
PANTS = (0.11, 0.12, 0.14)
GLOVE = (0.16, 0.15, 0.14)


def shade(color, lum: float) -> tuple:
	gain = 0.78 + lum * 0.28
	return tuple(max(0, min(255, int(channel * gain * 255))) for channel in color)


def main() -> None:
	image = Image.open(SRC).convert("RGB")
	w, h = image.size
	src = image.load()
	out = Image.new("RGB", (w, h))
	dst = out.load()
	face = (int(w * 0.015), int(h * 0.012), int(w * 0.30), int(h * 0.30))
	hands = (int(w * 0.34), 0, w, int(h * 0.40))
	for y in range(h):
		for x in range(w):
			r, g, b = src[x, y]
			if face[0] <= x < face[2] and face[1] <= y < face[3]:
				dst[x, y] = (r, g, b)
				continue
			lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
			if hands[0] <= x < hands[2] and hands[1] <= y < hands[3] and lum > 0.34:
				dst[x, y] = shade(GLOVE, lum)
			elif lum < 0.30:
				dst[x, y] = shade(PANTS, lum)
			else:
				dst[x, y] = shade(COAT, lum)
	soft = out.filter(ImageFilter.GaussianBlur(radius=5))
	face_img = image.crop(face)
	mask = Image.new("L", face_img.size, 0)
	mp = mask.load()
	fw, fh = face_img.size
	for y in range(fh):
		for x in range(fw):
			edge = min(x, y, fw - 1 - x, fh - 1 - y) / 36.0
			mp[x, y] = int(max(0.0, min(1.0, edge)) * 255)
	soft.paste(face_img, face[:2], mask)
	os.makedirs(os.path.dirname(DST), exist_ok=True)
	soft.save(DST, optimize=True)
	print("wrote", DST, os.path.getsize(DST))


if __name__ == "__main__":
	main()
