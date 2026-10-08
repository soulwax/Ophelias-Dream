"""Run in Blender: extract only the CC0 Styloo bow, keeping its materials.

blender --background --python tools/extract_elf_bow.py -- <original elf.glb>
"""
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

source = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
out = Path(__file__).resolve().parents[1] / "assets/props/bow"
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
kept = []
for obj in meshes:
    groups = {g.index for g in obj.vertex_groups if g.name.startswith("DEF-bow")}
    gear = {v.index for v in obj.data.vertices
            if any(g.group in groups and g.weight > 0.1 for g in v.groups)}
    if not gear:
        continue
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in gear], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.modifiers.clear()
    matrix = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = matrix
    kept.append(obj)
if not kept:
    raise RuntimeError("No DEF-bow vertices in source")
points = [obj.matrix_world @ v.co for obj in kept for v in obj.data.vertices]
low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
print("BOW bounds", low, high, "size", high - low)
centre = (low + high) * 0.5
for obj in kept:
    # GLB's upright Y becomes Blender Z; centre the separate prop at its grip.
    for vertex in obj.data.vertices:
        point = obj.matrix_world @ vertex.co - centre
        # Bow's long X axis becomes glTF Y, curvature glTF X, depth glTF Z.
        vertex.co = Vector((point.y, point.z, point.x))
    obj.matrix_world.identity()
    obj.name = "StylooBow"
for obj in list(bpy.context.scene.objects):
    if obj not in kept:
        bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.object.select_all(action="SELECT")
editable = out / "source"
editable.mkdir(exist_ok=True)
(editable / ".gdignore").write_text("", encoding="utf-8")
bpy.ops.wm.save_as_mainfile(filepath=str(editable / "bow.blend"))
bpy.ops.export_scene.gltf(filepath=str(out / "bow.glb"), export_format="GLB",
                          use_selection=True, export_animations=False)
print("Exported", out / "bow.glb")
