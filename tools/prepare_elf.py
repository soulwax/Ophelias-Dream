"""Remove bow and arrow triangles from Styloo's elf GLB before Godot import.

Usage: python tools/prepare_elf.py <original-elf.glb>
The source pack is CC0; its license is copied to assets/characters/styloo_elf/.
"""

import json
import struct
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets/characters/styloo_elf/elf.glb"


def accessor(doc, binary, index):
    spec = doc["accessors"][index]
    view = doc["bufferViews"][spec["bufferView"]]
    shape = {"SCALAR": 1, "VEC4": 4}[spec["type"]]
    code = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[spec["componentType"]]
    width = struct.calcsize(code) * shape
    start = view.get("byteOffset", 0) + spec.get("byteOffset", 0)
    stride = view.get("byteStride", width)
    return [struct.unpack_from("<" + code * shape, binary, start + i * stride)
            for i in range(spec["count"])]


def prepare(source):
    data = Path(source).read_bytes()
    magic, version, _ = struct.unpack_from("<4sII", data)
    if (magic, version) != (b"glTF", 2):
        raise ValueError("Expected a GLB v2 file")
    json_length, json_type = struct.unpack_from("<I4s", data, 12)
    if json_type != b"JSON":
        raise ValueError("Missing GLB JSON chunk")
    doc = json.loads(data[20:20 + json_length])
    binary_at = 20 + json_length
    bin_length, bin_type = struct.unpack_from("<I4s", data, binary_at)
    if bin_type != b"BIN\0":
        raise ValueError("Missing GLB binary chunk")
    binary = bytearray(data[binary_at + 8:binary_at + 8 + bin_length])
    joints = [doc["nodes"][i]["name"] for i in doc["skins"][0]["joints"]]
    removed = 0
    for primitive in doc["meshes"][0]["primitives"]:
        attrs = primitive["attributes"]
        weights = accessor(doc, binary, attrs["WEIGHTS_0"])
        assigned = accessor(doc, binary, attrs["JOINTS_0"])
        gear = {i for i, (bones, values) in enumerate(zip(assigned, weights))
                if any(value > 0.1 and joints[bone].startswith(("DEF-bow", "DEF-arrow"))
                       for bone, value in zip(bones, values))}
        indices = [value[0] for value in accessor(doc, binary, primitive["indices"])]
        kept = [index for offset in range(0, len(indices), 3)
                for triangle in [indices[offset:offset + 3]]
                if not any(vertex in gear for vertex in triangle)
                for index in triangle]
        removed += (len(indices) - len(kept)) // 3
        if len(kept) == len(indices):
            continue
        while len(binary) % 4:
            binary.append(0)
        start = len(binary)
        binary.extend(struct.pack("<" + "I" * len(kept), *kept))
        view = len(doc["bufferViews"])
        doc["bufferViews"].append({"buffer": 0, "byteOffset": start,
                                   "byteLength": len(kept) * 4, "target": 34963})
        accessor_id = len(doc["accessors"])
        doc["accessors"].append({"bufferView": view, "componentType": 5125,
                                 "count": len(kept), "type": "SCALAR",
                                 "min": [min(kept)], "max": [max(kept)]})
        primitive["indices"] = accessor_id
    doc["buffers"][0]["byteLength"] = len(binary)
    encoded = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    encoded += b" " * (-len(encoded) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    payload = (struct.pack("<I4s", len(encoded), b"JSON") + encoded
               + struct.pack("<I4s", len(binary), b"BIN\0") + binary)
    OUT.write_bytes(struct.pack("<4sII", b"glTF", 2, len(payload) + 12) + payload)
    print(f"Removed {removed} equipment triangles; wrote {OUT}")


if __name__ == "__main__":
    prepare(sys.argv[1])
