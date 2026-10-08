"""Inspect and locally import a curated subset of the owner's house downloads."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"C:\Users\soulwax\Downloads\requested_assets_and_more")
SELECTED = {
    "loft-16-interior.zip": "loft_room",
    "dauntless-flex-burn-wood-stove.zip": "stove",
    "gas-stove.zip": "cooker",
    "bathroom-furniture-set-game-ready.zip": "bathroom",
    "henrik-wool-rug-160x230cm-mustard-and-grey.zip": "rug",
    "curtain.zip": "curtain",
    "ikea_cabinet.zip": "cabinet",
    "wooden_display_shelves_01_2k.gltf.zip": "shelves",
    "caged_hanging_light_2k.gltf.zip": "pendant",
    "paloma-large-wool-rug.zip": "bed_rug",
    "wooden_lantern_01_2k.gltf.zip": "wood_lantern",
    "side_table_01_2k.gltf.zip": "side_table",
}


def main():
    manifest = {"source_root": str(SOURCE), "local_use_only": True,
                "note": "Owner supplied downloads. Preserve included licenses; unspecified archives have no verified redistribution permission. Selected files stay ignored.", "archives": []}
    for archive in sorted(SOURCE.glob("*.zip")):
        with zipfile.ZipFile(archive) as package:
            names = package.namelist()
            models = [n for n in names if n.lower().endswith((".gltf", ".glb", ".fbx"))]
            licenses = [n for n in names if "license" in n.lower() or "licence" in n.lower()]
            record = {"archive": archive.name, "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(), "models": models,
                      "licenses": {n: package.read(n).decode("utf-8", errors="replace") for n in licenses},
                      "selected": archive.name in SELECTED}
            if record["selected"]:
                role = SELECTED[archive.name]
                target = ROOT / "assets/vendor/requested_house" / role
                files = []
                for entry in package.infolist():
                    if entry.is_dir(): continue
                    # Do not extract import caches or executables; model/texture/license content only.
                    if Path(entry.filename).suffix.lower() not in (".gltf", ".glb", ".fbx", ".bin", ".png", ".jpg", ".jpeg", ".tga", ".bmp", ".txt", ".md"):
                        continue
                    destination = (target / entry.filename).resolve()
                    if not destination.is_relative_to(target.resolve()):
                        raise ValueError("Unsafe archive path: " + entry.filename)
                    payload = package.read(entry)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(payload)
                    files.append({"path": destination.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(payload).hexdigest(), "bytes":len(payload)})
                record["role"] = role
                record["files"] = files
                print(role, models, "texture files", sum(Path(f["path"]).suffix.lower() in (".png", ".jpg", ".tga") for f in files))
            manifest["archives"].append(record)
    target = ROOT / "docs/house/requested_assets_manifest.json"
    target.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n",encoding="utf-8")


if __name__ == "__main__": main()
