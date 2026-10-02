"""Build a winter-suit albedo from the sculpted body texture.

The face window stays skin. Everywhere else keeps the original light and
shadow, retinted as wool, so the suit still follows the mesh.
"""
import os
from PIL import Image, ImageFilter

ROOT = r"C:\Users\soulwax\Workspace\Godot\run"


def shade(color, lum: float) -> tuple:
	gain = 0.78 + lum * 0.28
	return tuple(max(0, min(255, int(channel * gain * 255))) for channel in color)


def paint(src_path: str, dst_path: str, coat, trim, glove, face_box, hand_box, blur: float) -> None:
	image = Image.open(src_path).convert("RGB")
	w, h = image.size
	src = image.load()
	out = Image.new("RGB", (w, h))
	dst = out.load()
	face = tuple(int(v) for v in (w * face_box[0], h * face_box[1], w * face_box[2], h * face_box[3]))
	hands = tuple(int(v) for v in (w * hand_box[0], h * hand_box[1], w * hand_box[2], h * hand_box[3]))
	for y in range(h):
		for x in range(w):
			r, g, b = src[x, y]
			if face[0] <= x < face[2] and face[1] <= y < face[3]:
				dst[x, y] = (r, g, b)
				continue
			lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
			if hands[0] <= x < hands[2] and hands[1] <= y < hands[3] and lum > 0.34:
				dst[x, y] = shade(glove, lum)
			elif lum < 0.28:
				dst[x, y] = shade(trim, lum)
			else:
				dst[x, y] = shade(coat, lum)
	soft = out.filter(ImageFilter.GaussianBlur(radius=blur))
	face_img = image.crop(face)
	mask = Image.new("L", face_img.size, 0)
	mp = mask.load()
	fw, fh = face_img.size
	for y in range(fh):
		for x in range(fw):
			edge = min(x, y, fw - 1 - x, fh - 1 - y) / 36.0
			mp[x, y] = int(max(0.0, min(1.0, edge)) * 255)
	soft.paste(face_img, face[:2], mask)
	os.makedirs(os.path.dirname(dst_path), exist_ok=True)
	soft.save(dst_path, optimize=True)
	print("wrote", dst_path, os.path.getsize(dst_path))


def main() -> None:
	tex = ROOT + r"\addons\quaternius_ik_rigged\Godot - UE"
	out = ROOT + r"\assets\characters"
	paint(
		tex + r"\T_Superhero_Female_Dark_BaseColor.png",
		out + r"\girl_coat.png",
		coat=(0.62, 0.16, 0.22),
		trim=(0.32, 0.08, 0.12),
		glove=(0.09, 0.08, 0.08),
		face_box=(0.0, 0.0, 0.40, 0.36),
		hand_box=(0.38, 0.0, 1.0, 0.42),
		blur=2.2,
	)


if __name__ == "__main__":
	main()
