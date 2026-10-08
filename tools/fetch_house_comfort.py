"""Fetch three CC0 1K glTF props into the existing Poly Haven library."""

import hashlib
import json
import urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "assets/vendor/polyhaven"
ASSETS = ("ArmChair_01", "round_wooden_table_02", "throw_pillows_01")


def get(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "OpheliasDream-asset-fetch/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def main() -> None:
    manifest_path = BANK / "provenance.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for asset in ASSETS:
        info = json.loads(get("https://api.polyhaven.com/info/" + asset))
        files = json.loads(get("https://api.polyhaven.com/files/" + asset))["gltf"]["1k"]["gltf"]
        selected = {asset + "_1k.gltf": files, **files.get("include", {})}
        records = []
        dest = BANK / asset
        for name, metadata in selected.items():
            target = (dest / name).resolve()
            if not target.is_relative_to(dest.resolve()):
                raise ValueError("Asset path escapes its directory: " + name)
            payload = get(metadata["url"])
            if hashlib.md5(payload).hexdigest() != metadata["md5"]:
                raise ValueError("Download checksum mismatch: " + name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(payload)
            records.append({"path": "./" + target.relative_to(ROOT).as_posix(),
                            "sha256": hashlib.sha256(payload).hexdigest(), "bytes": len(payload)})
        entry = {"id": asset, "type": "model", "name": info["name"],
                 "source": "https://polyhaven.com/a/" + asset,
                 "authors": list(info.get("authors", {}).keys()),
                 "license": "CC0 1.0 (https://polyhaven.com/license)",
                 "retrieved": date.today().isoformat(), "files": records}
        manifest = [item for item in manifest if item["id"] != asset] + [entry]
        print(asset, sum(item["bytes"] for item in records), "bytes", flush=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
