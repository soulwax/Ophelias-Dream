"""Copy the errand props from the owner's asset bank into the project.

The bank's packs are commercial downloads with no verified redistribution
permission, so everything lands in build/vendor/requested_errands/, which
git ignores and Godot never imports (build/ has a .gdignore). The game reads
it at runtime through VendorLoader, and every errand prop has a built
fallback when it is missing. The manifest in docs/errands/ records sources and
hashes; it holds no licensed data. The one exception is Poly Haven's CC0
wooden lantern, which is unzipped into the tracked assets/vendor/polyhaven/
and credited in its provenance.json.

  python tools/curate_errand_assets.py ["<bank root>"]
  godot-mono --headless --path . --import

Leartes Carpenter's Workshop (glTF, 2K Unreal textures): woodbox, chest,
firewood, cup, jar, bucket, oil tin, bottle, sign, bench, hook, ropes and the
small cupboard. Their B/N/ORM targas become PNGs beside each glTF; the glTFs
reference the B and N PNGs by the same names. Two of them (jar, bottle) point
at the engine's grid placeholder, which the pack does not ship, so those
images are dropped from the copied glTF and that material keeps its flat
factors.
WW2 storm lamp (photoscan, FBX LOD0): 2K base colour and OpenGL normals are
copied; AO and the Unity metal/smoothness map are packed into an ORM PNG
(R occlusion, G roughness = 1 - smoothness, B metal).
"""

import hashlib
import json
import shutil
import sys
import urllib.request
import zipfile
from datetime import date
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BANK = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(r"C:\Users\soulwax\OneDrive - Biz\Desktop\Assets")
OUT = ROOT / "build/vendor/requested_errands"
MANIFEST = ROOT / "docs/errands/requested_errands_manifest.json"
LEARTES = BANK / "CarpentersWorkshopForward/Carpenters_Workshop_Forward/Assets/LeartesStudios/CarpentersWorkshop/Art"
LEARTES_MESHES = [
	"SM_Crate", "SM_Chest_01", "SM_Firewood", "SM_Cup", "SM_Jar", "SM_Bucket", "SM_Tin_03",
	"SM_Bottle", "SM_Sign", "SM_Bench", "SM_Hook", "SM_Rope_02", "SM_Rope_03", "SM_Cuboard_Small",
]
SCANS = {
	"ww2_lamp":(BANK / "WW2_Lamp_f0243220/WW2_Lamp/Unity/Rocket/WW2_Lamp", "SM_WW2_Lamp_c1_LOD0.fbx", "T_WW2_Lamp_2048"),
}
POLYHAVEN = ROOT / "assets/vendor/polyhaven"
POLYHAVEN_ZIPS = {"wooden_lantern_01": BANK / "wooden_lantern_01_2k.gltf.zip"}


def sha(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def record(sources: list, src: Path, to: str) -> None:
	sources.append({"source": str(src.relative_to(BANK)), "sha256": sha(src), "to": to})


def curate_leartes(sources: list) -> None:
	leartes = OUT / "leartes"
	leartes.mkdir(exist_ok=True)
	made = set()
	gltfs = {}
	for name in LEARTES_MESHES:
		gltf_src = LEARTES / "Meshes" / f"{name}.gltf"
		bin_src = LEARTES / "Meshes" / f"{name}.bin"
		if not gltf_src.exists() or not bin_src.exists():
			print("missing", name)
			continue
		shutil.copy2(bin_src, leartes / bin_src.name)
		record(sources, bin_src, f"leartes/{bin_src.name}")
		record(sources, gltf_src, f"leartes/{gltf_src.name}")
		gltfs[name] = json.loads(gltf_src.read_text(encoding="utf-8"))
		for image in gltfs[name].get("images", []):
			stem = image["uri"].rsplit("_", 1)[0]
			for suffix in ("B", "N", "ORM"):
				out_name = f"{stem}_{suffix}.png"
				if out_name in made:
					continue
				src = LEARTES / "Textures" / f"{stem}_{suffix}.tga"
				if not src.exists():
					continue
				Image.open(src).convert("RGB").save(leartes / out_name, optimize=True)
				record(sources, src, f"leartes/{out_name}")
				made.add(out_name)
				print("texture", src.name)

	for name, gltf in gltfs.items():
		missing = [i for i, image in enumerate(gltf.get("images", [])) if image["uri"] not in made]
		if not missing:
			shutil.copy2(LEARTES / "Meshes" / f"{name}.gltf", leartes / f"{name}.gltf")
			print("mesh", name)
			continue
		for i in missing:
			print("missing", gltf["images"][i]["uri"], "for", name, "(dropped from the copy)")
		_drop_images(gltf, set(missing))
		(leartes / f"{name}.gltf").write_text(json.dumps(gltf, separators=(",", ":")), encoding="utf-8", newline="\n")
		print("mesh", name, "(rewritten)")


def _drop_images(gltf: dict, gone: set) -> None:
	"""Removes images (and the textures and material slots using them), reindexing the rest."""
	images = gltf.get("images", [])
	image_map = {}
	kept_images = []
	for i, image in enumerate(images):
		if i not in gone:
			image_map[i] = len(kept_images)
			kept_images.append(image)
	texture_map = {}
	kept_textures = []
	for i, texture in enumerate(gltf.get("textures", [])):
		if texture.get("source") in image_map:
			texture["source"] = image_map[texture["source"]]
			texture_map[i] = len(kept_textures)
			kept_textures.append(texture)
	gltf["images"] = kept_images
	gltf["textures"] = kept_textures

	def remap(holder: dict, key: str) -> None:
		slot = holder.get(key)
		if slot is None:
			return
		if slot["index"] in texture_map:
			slot["index"] = texture_map[slot["index"]]
		else:
			del holder[key]

	for material in gltf.get("materials", []):
		for key in ("normalTexture", "occlusionTexture", "emissiveTexture"):
			remap(material, key)
		pbr = material.get("pbrMetallicRoughness", {})
		for key in ("baseColorTexture", "metallicRoughnessTexture"):
			remap(pbr, key)


def curate_scans(sources: list) -> None:
	for key, (folder, mesh, stem) in SCANS.items():
		dest = OUT / key
		dest.mkdir(exist_ok=True)
		src = folder / "HDRP" / mesh
		if not src.exists():
			print("missing", mesh)
			continue
		shutil.copy2(src, dest / mesh)
		record(sources, src, f"{key}/{mesh}")
		textures = folder / "Textures"
		for suffix, out_suffix in (("B", "B"), ("OpenGL_N", "N")):
			tex = textures / f"{stem}_{suffix}.png"
			if not tex.exists():
				print("missing", tex.name)
				continue
			shutil.copy2(tex, dest / f"{stem}_{out_suffix}.png")
			record(sources, tex, f"{key}/{stem}_{out_suffix}.png")
		ao_path = textures / f"{stem}_AO.png"
		ms_path = textures / f"{stem}_MS.png"
		if not ao_path.exists() or not ms_path.exists():
			print("missing", ao_path.name if not ao_path.exists() else ms_path.name)
			continue
		ao = Image.open(ao_path).convert("L")
		ms = Image.open(ms_path).convert("RGBA")
		metal, _, _, smooth = ms.split()
		rough = smooth.point(lambda v: 255 - v)
		if ao.size != metal.size:
			ao = ao.resize(metal.size, Image.BILINEAR)
		Image.merge("RGB", (ao, rough, metal)).save(dest / f"{stem}_ORM.png", optimize=True)
		for tex in (ao_path, ms_path):
			record(sources, tex, f"{key}/{stem}_ORM.png")
		print("scan", key)


def _bounds_mm(gltf: dict, folder: Path) -> list:
	"""Scene bounds from accessor min/max and node translation/scale, in Poly Haven's x, depth, height order."""
	lo = [float("inf")] * 3
	hi = [float("-inf")] * 3
	for node in gltf.get("nodes", []):
		if "mesh" not in node:
			continue
		t = node.get("translation", [0, 0, 0])
		s = node.get("scale", [1, 1, 1])
		for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
			accessor = gltf["accessors"][primitive["attributes"]["POSITION"]]
			for k in range(3):
				a = accessor["min"][k] * s[k] + t[k]
				b = accessor["max"][k] * s[k] + t[k]
				lo[k] = min(lo[k], a, b)
				hi[k] = max(hi[k], a, b)
	size = [(hi[k] - lo[k]) * 1000.0 for k in range(3)]
	return [size[0], size[2], size[1]]


def _polyhaven_info(asset_id: str) -> dict:
	try:
		request = urllib.request.Request(f"https://api.polyhaven.com/info/{asset_id}", headers={"User-Agent": "OpheliasDream-curation/1.0"})
		with urllib.request.urlopen(request, timeout=15) as response:
			return json.load(response)
	except Exception as error:  # offline: keep what the files tell us
		print("no Poly Haven info for", asset_id, f"({error})")
		return {}


def curate_polyhaven() -> None:
	provenance_path = POLYHAVEN / "provenance.json"
	provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
	for asset_id, archive in POLYHAVEN_ZIPS.items():
		if not archive.exists():
			print("missing", archive.name)
			continue
		dest = POLYHAVEN / asset_id
		dest.mkdir(parents=True, exist_ok=True)
		files = []
		with zipfile.ZipFile(archive) as z:
			for info in z.infolist():
				if info.is_dir():
					continue
				target = (dest / info.filename).resolve()
				if dest.resolve() not in target.parents:
					print("skipped unsafe path", info.filename)
					continue
				target.parent.mkdir(parents=True, exist_ok=True)
				target.write_bytes(z.read(info))
				files.append(target)
		gltf_path = next((f for f in files if f.suffix == ".gltf"), None)
		info = _polyhaven_info(asset_id)
		entry = {
			"id": asset_id,
			"type": "model",
			"name": info.get("name", asset_id.replace("_", " ").title()),
			"source": f"https://polyhaven.com/a/{asset_id}",
			"authors": sorted(info.get("authors", {}).keys()),
			"license": "CC0 1.0 (https://polyhaven.com/license)",
			"retrieved": date.today().isoformat(),
			"dimensions_mm": info.get("dimensions") or (_bounds_mm(json.loads(gltf_path.read_text(encoding="utf-8")), dest) if gltf_path else []),
			"files": [{
				"path": "./" + f.relative_to(ROOT).as_posix(),
				"sha256": sha(f),
				"bytes": f.stat().st_size,
			} for f in sorted(files)],
		}
		old = next((i for i, item in enumerate(provenance) if item.get("id") == asset_id), None)
		if old is None:
			provenance.append(entry)
		else:
			entry["retrieved"] = provenance[old].get("retrieved", entry["retrieved"]) if provenance[old].get("files") == entry["files"] else entry["retrieved"]
			provenance[old] = entry
		print("polyhaven", asset_id, f"({len(files)} files)")
	provenance_path.write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8", newline="\n")


def main() -> None:
	if not LEARTES.exists():
		sys.exit(f"No asset bank at {BANK}")
	OUT.mkdir(parents=True, exist_ok=True)
	sources = []
	curate_leartes(sources)
	curate_scans(sources)
	curate_polyhaven()

	MANIFEST.parent.mkdir(parents=True, exist_ok=True)
	MANIFEST.write_text(json.dumps({
		"source_root": str(BANK),
		"local_use_only": True,
		"note": "Owner-supplied asset bank. Leartes Studios Carpenter's Workshop and the WW2 storm lamp scan; no verified redistribution permission, so the files stay ignored under build/vendor/requested_errands/. Errand props fall back to built stand-ins without them. Poly Haven's CC0 wooden_lantern_01 is tracked and credited in assets/vendor/polyhaven/provenance.json instead.",
		"sources": sources,
	}, indent=2) + "\n", encoding="utf-8", newline="\n")
	print(f"{len(sources)} files recorded in {MANIFEST.relative_to(ROOT)}")


if __name__ == "__main__":
	main()
