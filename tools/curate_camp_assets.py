"""Copy Mathilda's camp props from the owner's asset bank into the project.

The bank's packs are commercial downloads with no verified redistribution
permission, so, like the requested house assets, everything lands in the
ignored assets/vendor/requested_camp/ and the game falls back to its own
built camp when it is missing. The manifest in docs/camp/ records sources and
hashes; it holds no licensed data.

  python tools/curate_camp_assets.py ["<bank root>"]
  godot-mono --headless --path . --import

Leartes Carpenter's Workshop (glTF, 2K Unreal textures): firewood, stool, axe,
crate, cup, rope. Their B/N/ORM targas become PNGs beside each glTF.
WW2 note sheet (photoscan, FBX LOD0): 2K base colour and OpenGL normals are
copied; AO and the Unity metal/smoothness map are packed into an ORM PNG
(R occlusion, G roughness = 1 - smoothness, B metal). The lantern is Poly
Haven's CC0 Lantern_01, already in the repository.
"""

import hashlib
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BANK = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(r"C:\Users\soulwax\OneDrive - Biz\Desktop\Assets")
OUT = ROOT / "assets/vendor/requested_camp"
MANIFEST = ROOT / "docs/camp/requested_camp_manifest.json"
LEARTES = BANK / "CarpentersWorkshopForward/Carpenters_Workshop_Forward/Assets/LeartesStudios/CarpentersWorkshop/Art"
LEARTES_MESHES = ["SM_Firewood", "SM_Stool", "SM_Axe", "SM_Crate", "SM_Cup", "SM_Rope_01"]
SCANS = {
	"note":(BANK / "WW2_NoteSheet01_6a54d6c3/WW2_NoteSheet01/Unity/Rocket/WW2_NoteSheet", "SM_WW2_NoteSheet01_c1_LOD0.fbx", "T_WW2_NoteSheets_2048"),
}


def sha(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
	if not LEARTES.exists():
		sys.exit(f"No asset bank at {BANK}")
	OUT.mkdir(parents=True, exist_ok=True)
	sources = []

	leartes = OUT / "leartes"
	leartes.mkdir(exist_ok=True)
	sets = set()
	for name in LEARTES_MESHES:
		for ext in (".gltf", ".bin"):
			src = LEARTES / "Meshes" / (name + ext)
			shutil.copy2(src, leartes / src.name)
			sources.append({"source": str(src.relative_to(BANK)), "sha256": sha(src), "to": f"leartes/{src.name}"})
		gltf = json.loads((LEARTES / "Meshes" / f"{name}.gltf").read_text(encoding="utf-8"))
		for image in gltf.get("images", []):
			sets.add(image["uri"].rsplit("_", 1)[0])
	for stem in sorted(sets):
		for suffix in ("B", "N", "ORM"):
			src = LEARTES / "Textures" / f"{stem}_{suffix}.tga"
			if not src.exists():
				print("missing", src.name)
				continue
			Image.open(src).convert("RGB").save(leartes / f"{stem}_{suffix}.png", optimize=True)
			sources.append({"source": str(src.relative_to(BANK)), "sha256": sha(src), "to": f"leartes/{stem}_{suffix}.png"})
			print("texture", src.name)

	for key, (folder, mesh, stem) in SCANS.items():
		dest = OUT / key
		dest.mkdir(exist_ok=True)
		src = folder / "HDRP" / mesh
		shutil.copy2(src, dest / mesh)
		sources.append({"source": str(src.relative_to(BANK)), "sha256": sha(src), "to": f"{key}/{mesh}"})
		textures = folder / "Textures"
		for suffix, out_name in (("B", "albedo"), ("OpenGL_N", "normal")):
			tex = textures / f"{stem}_{suffix}.png"
			shutil.copy2(tex, dest / f"{key}_{out_name}.png")
			sources.append({"source": str(tex.relative_to(BANK)), "sha256": sha(tex), "to": f"{key}/{key}_{out_name}.png"})
		ao = Image.open(textures / f"{stem}_AO.png").convert("L")
		ms = Image.open(textures / f"{stem}_MS.png").convert("RGBA")
		metal, _, _, smooth = ms.split()
		rough = smooth.point(lambda v: 255 - v)
		Image.merge("RGB", (ao, rough, metal)).save(dest / f"{key}_orm.png", optimize=True)
		for part in ("AO", "MS"):
			tex = textures / f"{stem}_{part}.png"
			sources.append({"source": str(tex.relative_to(BANK)), "sha256": sha(tex), "to": f"{key}/{key}_orm.png"})
		print("scan", key)

	MANIFEST.parent.mkdir(parents=True, exist_ok=True)
	MANIFEST.write_text(json.dumps({
		"source_root": str(BANK),
		"local_use_only": True,
		"note": "Owner-supplied asset bank. Leartes Studios Carpenter's Workshop and the WW2 note sheet scan; no verified redistribution permission, so the files stay ignored under assets/vendor/requested_camp/. Camp falls back to its built props without them.",
		"files": sources,
	}, indent=2) + "\n", encoding="utf-8")
	print(f"{len(sources)} files recorded in {MANIFEST.relative_to(ROOT)}")


if __name__ == "__main__":
	main()
