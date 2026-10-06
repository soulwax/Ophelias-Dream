"""Download three CC0 replacements with their declared texture/buffer dependencies."""
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ("modern_ceiling_lamp_01", "painted_wooden_bench", "modern_wooden_cabinet")

def get(url):
    request = urllib.request.Request(url,headers={"User-Agent":"OpheliasDream-house-replacements/1.0"})
    return urllib.request.urlopen(request,timeout=45).read()

def main():
    records = []
    for id in ASSETS:
        info = json.loads(get("https://api.polyhaven.com/info/"+id))
        definition = json.loads(get("https://api.polyhaven.com/files/"+id))["gltf"]["1k"]["gltf"]
        entries = {id+"_1k.gltf":definition,**definition.get("include",{})}
        destination = ROOT/"assets/vendor/polyhaven"/id
        files = []
        for name, metadata in entries.items():
            target = (destination/name).resolve()
            if not target.is_relative_to(destination.resolve()): raise ValueError(name)
            payload = get(metadata["url"])
            if hashlib.md5(payload).hexdigest()!=metadata["md5"]: raise ValueError("Checksum mismatch: "+name)
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(payload)
            files.append({"path":target.relative_to(ROOT).as_posix(),"sha256":hashlib.sha256(payload).hexdigest(),"bytes":len(payload)})
        records.append({"id":id,"authors":list(info.get("authors",{})),"license":"CC0 1.0",
                        "source":"https://polyhaven.com/a/"+id,"retrieved":"2026-10-06",
                        "dimensions_mm":info.get("dimensions"),"files":files})
        print(id,len(files),"files downloaded",flush=True)
    (ROOT/"docs/house/replacement_provenance.json").write_text(json.dumps(records,indent=2)+"\n",encoding="utf8")

if __name__=="__main__": main()
