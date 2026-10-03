"""Print what Blender sees in the rig's source glTF: objects, transforms,
mesh sizes, shape keys, and where the eyes are.

    blender -b --factory-startup -P tools/blender/inspect_rig.py
"""
import os
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "addons", "quaternius_ik_rigged", "Godot - UE", "Superhero_Female_FullBody.gltf")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SOURCE)
for obj in bpy.context.scene.objects:
	line = f"OBJ {obj.name} type={obj.type} parent={obj.parent.name if obj.parent else '-'} loc={tuple(round(v, 4) for v in obj.location)} rot={tuple(round(v, 4) for v in obj.rotation_euler)} scale={tuple(round(v, 4) for v in obj.scale)}"
	if obj.type == "MESH":
		mesh = obj.data
		keys = [k.name for k in mesh.shape_keys.key_blocks] if mesh.shape_keys else []
		xs = [v.co for v in mesh.vertices]
		lo = [min(c[i] for c in xs) for i in range(3)]
		hi = [max(c[i] for c in xs) for i in range(3)]
		line += f" verts={len(mesh.vertices)} faces={len(mesh.polygons)} shape_keys={keys} groups={len(obj.vertex_groups)} lo={tuple(round(v, 4) for v in lo)} hi={tuple(round(v, 4) for v in hi)}"
	print(line)
