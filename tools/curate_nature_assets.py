"""Curate proprietary nature assets from the owner's asset bank into build/vendor/requested_nature/.

The bank packs are proprietary/commercial with no redistribution permission,
so all files stay strictly inside the git-ignored `build/vendor/requested_nature/` directory.
The manifest in `docs/nature/requested_nature_manifest.json` records sources and hashes.

Usage:
  python tools/curate_nature_assets.py ["<bank root>"]
"""

import hashlib
import json
import shutil
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BANK = Path(r"C:\Users\soulwax\OneDrive - Biz\Desktop\Assets")
BANK = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_BANK
OUT = ROOT / "build/vendor/requested_nature"
MANIFEST = ROOT / "docs/nature/requested_nature_manifest.json"

ITEMS = {
	"flowers": {
		"folder": BANK / "MVV_FlowerSet_Flowers_01_B_447d267c/MVV_FlowerSet_Flowers_01_B/Unity/Rocket/MVV_FlowerSet_Flowers_01_B",
		"mesh": "SM_MVV_Flowers_01_B_c1_LOD0.fbx",
		"stem": "T_MVV_Flowers_2048",
	},
	"ivy": {
		"folder": BANK / "PAD_MV_IvySet_Ivy01e_66d6f637/PAD_MV_IvySet_Ivy01e/Unity/Rocket/PAD_MV_IvySet_Ivy01e",
		"mesh": "SM_PAD_MV_Ivy01e_c1_LOD0.fbx",
		"stem": "T_PAD_IvySet_2048",
	},
}


def sha(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
	if not BANK.exists():
		sys.exit(f"Asset bank not found at {BANK}")

	OUT.mkdir(parents=True, exist_ok=True)
	sources = []

	for key, info in ITEMS.items():
		folder = info["folder"]
		if not folder.exists():
			print(f"Skipping {key}: folder {folder} does not exist")
			continue

		dest = OUT / key
		dest.mkdir(parents=True, exist_ok=True)

		# Copy FBX mesh
		mesh_src = folder / "HDRP" / info["mesh"]
		if mesh_src.exists():
			mesh_dst = dest / info["mesh"]
			shutil.copy2(mesh_src, mesh_dst)
			sources.append({
				"source": str(mesh_src.relative_to(BANK)),
				"sha256": sha(mesh_src),
				"to": f"{key}/{info['mesh']}"
			})
			print(f"[{key}] copied {info['mesh']}")

		# Textures
		tex_dir = folder / "Textures"
		stem = info["stem"]

		# Albedo & Normal
		for suffix, out_name in (("B", "albedo"), ("OpenGL_N", "normal")):
			tex_src = tex_dir / f"{stem}_{suffix}.png"
			if tex_src.exists():
				tex_dst = dest / f"{key}_{out_name}.png"
				shutil.copy2(tex_src, tex_dst)
				sources.append({
					"source": str(tex_src.relative_to(BANK)),
					"sha256": sha(tex_src),
					"to": f"{key}/{key}_{out_name}.png"
				})
				print(f"[{key}] copied {tex_src.name} -> {key}_{out_name}.png")

		# Pack ORM (Occlusion=R, Roughness=G=1-Smooth, Metallic=B)
		ao_path = tex_dir / f"{stem}_AO.png"
		ms_path = tex_dir / f"{stem}_MS.png"
		if ao_path.exists() and ms_path.exists():
			ao_img = Image.open(ao_path).convert("L")
			ms_img = Image.open(ms_path).convert("RGBA")
			metal, _, _, smooth = ms_img.split()
			rough = smooth.point(lambda v: 255 - v)
			orm_dst = dest / f"{key}_orm.png"
			Image.merge("RGB", (ao_img, rough, metal)).save(orm_dst, optimize=True)
			sources.append({
				"source": str(ao_path.relative_to(BANK)),
				"sha256": sha(ao_path),
				"to": f"{key}/{key}_orm.png (AO channel)"
			})
			sources.append({
				"source": str(ms_path.relative_to(BANK)),
				"sha256": sha(ms_path),
				"to": f"{key}/{key}_orm.png (Roughness & Metallic channels)"
			})
			print(f"[{key}] packed ORM -> {key}_orm.png")

	MANIFEST.parent.mkdir(parents=True, exist_ok=True)
	manifest_data = {
		"source_root": str(BANK),
		"local_use_only": True,
		"note": "Owner-supplied asset bank. Nature scans (Alpine Flowers, Ivy); no verified redistribution permission, so all assets remain in build/vendor/requested_nature/. Flora falls back gracefully if absent.",
		"files": sources,
	}
	MANIFEST.write_text(json.dumps(manifest_data, indent=2) + "\n", encoding="utf-8")
	print(f"Manifest written to {MANIFEST.relative_to(ROOT)} ({len(sources)} items)")


if __name__ == "__main__":
	main()
