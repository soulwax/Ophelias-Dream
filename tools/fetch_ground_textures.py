"""Fetch the biome's CC0 1K albedo/OpenGL normal maps, verifying API MD5s.

Existing files must match: never silently replace a modified vendor asset.
The provenance array is extended without removing or rewriting older records.
Run from any directory with: py tools/fetch_ground_textures.py
"""

import hashlib
import json
import urllib.request
from datetime import date
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "assets/vendor/polyhaven"
ASSETS = ("forrest_ground_01", "aerial_grass_rock", "brown_mud_leaves_01")


def get(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "OpheliasDream-ground-fetch/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def fetch_file(target: Path, metadata: dict) -> bytes:
    existed = target.exists()
    payload = target.read_bytes() if existed else get(metadata["url"])
    if hashlib.md5(payload).hexdigest() != metadata["md5"]:
        raise ValueError(f"{'Existing file' if existed else 'Download'} MD5 mismatch: {target}")
    if not existed:
        target.parent.mkdir(parents=True, exist_ok=True)
        # Exclusive creation protects a concurrently authored/downloaded file.
        with target.open("xb") as stream:
            stream.write(payload)
    print(f"{'Verified existing' if existed else 'Downloaded'} {target.name}", flush=True)
    return payload


def main() -> None:
    manifest_path = BANK / "provenance.json"
    original = manifest_path.read_text(encoding="utf-8")
    manifest = json.loads(original)
    if not isinstance(manifest, list):
        raise ValueError("Poly Haven provenance must remain an array")
    additions = []
    for asset in ASSETS:
        info = json.loads(get("https://api.polyhaven.com/info/" + asset))
        api_url = "https://api.polyhaven.com/files/" + asset
        maps = json.loads(get(api_url))
        old = next((entry for entry in manifest if entry["id"] == asset), None)
        retrieved = old["retrieved"] if old else date.today().isoformat()
        records = []
        for kind in ("Diffuse", "nor_gl"):
            metadata = maps[kind]["1k"]["jpg"]
            name = Path(urlparse(metadata["url"]).path).name
            target = BANK / asset / name
            payload = fetch_file(target, metadata)
            records.append({"path": "./" + target.relative_to(ROOT).as_posix(),
                            "source_url": metadata["url"], "retrieved": retrieved,
                            "license": "CC0 1.0", "md5": metadata["md5"],
                            "sha256": hashlib.sha256(payload).hexdigest(), "bytes": len(payload)})
        if old:
            # Preserve all prior provenance. Reject a changed file record instead.
            for record in records:
                previous = next((f for f in old["files"] if f["path"] == record["path"]), None)
                if previous != record:
                    raise ValueError(f"Existing provenance differs for {record['path']}")
        else:
            additions.append({"id": asset, "type": "texture", "name": info["name"],
                              "source": "https://polyhaven.com/a/" + asset, "api_source": api_url,
                              "authors": list(info.get("authors", {}).keys()),
                              "license": "CC0 1.0 (https://polyhaven.com/license)",
                              "retrieved": retrieved, "resolution": "1k", "files": records})
    if additions:
        # Check that another asset process has not changed the shared manifest.
        if manifest_path.read_text(encoding="utf-8") != original:
            raise ValueError("Provenance changed during fetch; rerun to preserve concurrent records")
        manifest_path.write_text(json.dumps(manifest + additions, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
