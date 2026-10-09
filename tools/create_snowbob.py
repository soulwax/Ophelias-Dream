"""Create the enhanced Snow Bob as a separate, head-rigged creator hairstyle.

blender --background --factory-startup --python-exit-code 1 --python tools/create_snowbob.py
"""
from math import cos, pi, sin
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
CREATOR = ROOT / "assets/characters/creator"
SOURCE = ROOT / "assets/characters/hairstyles/cropped_bob.glb"
sys.path.insert(0, str(ROOT / "tools"))
sys.dont_write_bytecode = True
from create_hair_variants import hair_components


def material(name: str, color: tuple[float, float, float], metallic: float, roughness: float):
	mat = bpy.data.materials.new(name)
	mat.diffuse_color = (*color, 1.0)
	mat.use_nodes = True
	bsdf = mat.node_tree.nodes.get("Principled BSDF")
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Metallic"].default_value = metallic
	bsdf.inputs["Roughness"].default_value = roughness
	return mat


def head_skinned_mesh(name: str, vertices: list[tuple[float, float, float]], faces: list[tuple[int, ...]], mat: bpy.types.Material, armature: bpy.types.Object):
	mesh = bpy.data.meshes.new(name)
	mesh.from_pydata(vertices, [], faces)
	mesh.update()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.collection.objects.link(obj)
	obj.data.materials.append(mat)
	for polygon in mesh.polygons:
		polygon.use_smooth = True
	group = obj.vertex_groups.new(name="DEF-spine.006")
	group.add(list(range(len(vertices))), 1.0, "REPLACE")
	modifier = obj.modifiers.new("Existing elf head rig", "ARMATURE")
	modifier.object = armature
	obj.parent = armature
	return obj


def tapered_strand(name: str, centers: list[tuple[float, float, float]], radius: float, mat: bpy.types.Material, armature: bpy.types.Object, sides: int = 10):
	vertices: list[tuple[float, float, float]] = []
	faces: list[tuple[int, ...]] = []
	for index, center in enumerate(centers):
		point = Vector(center)
		tangent = Vector(centers[min(index + 1, len(centers) - 1)]) - Vector(centers[max(0, index - 1)])
		if tangent.length_squared < 1e-10:
			tangent = Vector((0, 0, 1))
		tangent.normalize()
		axis = Vector((0, 1, 0)) if abs(tangent.dot(Vector((0, 1, 0)))) < 0.9 else Vector((1, 0, 0))
		normal = tangent.cross(axis).normalized()
		binormal = tangent.cross(normal).normalized()
		t = index / max(1, len(centers) - 1)
		taper = 0.14 + 0.86 * (sin(pi * t) ** 0.38)
		for side in range(sides):
			angle = side * 2.0 * pi / sides
			groove = 1.0 + 0.035 * cos(angle * 4.0)
			vertex = point + radius * taper * groove * (cos(angle) * normal + sin(angle) * binormal)
			vertices.append(tuple(vertex))
		if index:
			for side in range(sides):
				prior = (index - 1) * sides + side
				next_prior = (index - 1) * sides + (side + 1) % sides
				next_current = index * sides + (side + 1) % sides
				current = index * sides + side
				faces.append((prior, next_prior, next_current, current))
	faces.append(tuple(reversed(range(sides))))
	faces.append(tuple((len(centers) - 1) * sides + side for side in range(sides)))
	return head_skinned_mesh(name, vertices, faces, mat, armature)


def interpolate_path(points: list[tuple[float, float, float]], steps: int = 32) -> list[tuple[float, float, float]]:
	controls = [Vector(point) for point in points]
	result: list[tuple[float, float, float]] = []
	for step in range(steps):
		t = step / (steps - 1)
		segment = min(int(t * (len(controls) - 1)), len(controls) - 2)
		local = t * (len(controls) - 1) - segment
		p0 = controls[max(0, segment - 1)]
		p1 = controls[segment]
		p2 = controls[segment + 1]
		p3 = controls[min(len(controls) - 1, segment + 2)]
		value = 0.5 * ((2 * p1) + (-p0 + p2) * local + (2 * p0 - 5 * p1 + 4 * p2 - p3) * local**2 + (-p0 + 3 * p1 - 3 * p2 + p3) * local**3)
		result.append(tuple(value))
	return result


def snowflake(armature: bpy.types.Object, ice: bpy.types.Material, pearl: bpy.types.Material) -> None:
	# Small six-spoke crystal pin at the left temple, facing the character's front (-Y).
	center = Vector((-0.077, -0.150, 1.988))
	for spoke in range(6):
		angle = spoke * pi / 3.0 + pi / 2.0
		direction = Vector((cos(angle), 0, sin(angle)))
		end = center + direction * 0.021
		path = [center + direction * 0.003, center + direction * 0.012, end]
		tapered_strand("Snow Crystal Ray %02d" % spoke, [tuple(point) for point in path], 0.0021, ice, armature, 7)
		# Fine forked tips make the motif read as a snow crystal instead of a star.
		for sign in (-1, 1):
			fork = Quaternion(Vector((0, 1, 0)), sign * pi / 4.0) @ direction
			branch_start = center + direction * 0.011
			branch_end = branch_start + fork * 0.008
			tapered_strand("Snow Crystal Fork %02d %d" % (spoke, sign), [tuple(branch_start), tuple((branch_start + branch_end) * 0.5), tuple(branch_end)], 0.00105, pearl, armature, 6)
	# A rounded center catches the key light without becoming a bright, oversized ornament.
	bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1.0, location=tuple(center))
	_jewel = bpy.context.object
	_jewel.name = "Snow Crystal Heart"
	_jewel.scale = (0.0052, 0.0030, 0.0052)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	_jewel.data.materials.append(pearl)
	for polygon in _jewel.data.polygons:
		polygon.use_smooth = True
	group = _jewel.vertex_groups.new(name="DEF-spine.006")
	group.add(list(range(len(_jewel.data.vertices))), 1.0, "REPLACE")
	modifier = _jewel.modifiers.new("Existing elf head rig", "ARMATURE")
	modifier.object = armature
	_jewel.parent = armature


def build() -> None:
	CREATOR.mkdir(parents=True, exist_ok=True)
	(CREATOR / "sources").mkdir(parents=True, exist_ok=True)
	for obj in list(bpy.data.objects):
		bpy.data.objects.remove(obj, do_unlink=True)
	bpy.ops.import_scene.gltf(filepath=str(SOURCE))
	body = bpy.data.objects["elfBody"]
	armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
	bones = [(bone.name, tuple(tuple(row) for row in bone.matrix_local)) for bone in armature.data.bones]
	# The authoring GLB carries unskinned glTF helper primitives at unit scale.
	# They are not part of the character and would expand the preview bounds.
	for obj in list(bpy.data.objects):
		if obj not in (body, armature):
			bpy.data.objects.remove(obj, do_unlink=True)

	# Keep an untouched copy of the source model inside the editable authoring file.
	reference = bpy.data.collections.new("Reference - untouched Frost Bob")
	bpy.context.scene.collection.children.link(reference)
	for obj in list(bpy.context.scene.objects):
		if obj == body or obj == armature:
			copy = obj.copy()
			if obj.type == "MESH":
				copy.data = obj.data.copy()
			reference.objects.link(copy)
			copy.name = "Reference - " + obj.name
			copy.hide_render = True
			copy.hide_viewport = True

	selected = hair_components(body)
	bm = bmesh.new()
	bm.from_mesh(body.data)
	bm.faces.ensure_lookup_table()
	remove = [bm.faces[polygon.index] for polygon in body.data.polygons if not all(index in selected for index in polygon.vertices)]
	bmesh.ops.delete(bm, geom=remove, context="FACES")
	bm.to_mesh(body.data)
	bm.free()
	body.data.update()
	body.name = "Snow Bob base mesh - Frost Bob hair component"
	body.parent = armature

	ice = material("SnowbobIce", (0.34, 0.76, 0.91), 0.08, 0.3)
	pearl = material("SnowbobPearl", (0.82, 0.96, 1.0), 0.06, 0.24)
	# Fine raised locks follow the existing bob's part and frame the face. Their
	# cool inlays stay icy when the character's hair colour is changed in the UI.
	paths = [
		[(0.002, -0.124, 2.055), (-0.026, -0.143, 2.038), (-0.062, -0.149, 2.013), (-0.089, -0.128, 1.979), (-0.101, -0.095, 1.943)],
		[(0.012, -0.120, 2.055), (0.040, -0.143, 2.037), (0.073, -0.145, 2.010), (0.094, -0.118, 1.976), (0.103, -0.086, 1.940)],
		[(-0.014, -0.119, 2.050), (-0.043, -0.140, 2.029), (-0.070, -0.142, 1.997), (-0.091, -0.119, 1.965)],
		[(0.025, -0.116, 2.050), (0.052, -0.137, 2.030), (0.078, -0.135, 1.999), (0.096, -0.108, 1.965)],
	]
	for index, points in enumerate(paths):
		centers = interpolate_path(points)
		tapered_strand("Snow Bob sculpted lock %02d" % index, centers, 0.0054 if index < 2 else 0.0034, pearl if index % 2 else ice, armature)
	# Delicate crown inlays arc backward over the scalp rather than sitting above it.
	for index, x in enumerate((-0.043, 0.0, 0.043)):
		path = [(x * 0.35, -0.080, 2.055), (x * 0.72, -0.020, 2.064), (x, 0.045, 2.053), (x * 0.84, 0.085, 2.027)]
		tapered_strand("Snow Bob crown inlay %02d" % index, interpolate_path(path, 24), 0.0020, ice if index != 1 else pearl, armature, 8)
	snowflake(armature, ice, pearl)

	assert bones == [(bone.name, tuple(tuple(row) for row in bone.matrix_local)) for bone in armature.data.bones], "Base armature rest data changed"
	bpy.context.preferences.filepaths.save_version = 0
	bpy.ops.wm.save_as_mainfile(filepath=str(CREATOR / "sources" / "snowbob.blend"))
	# The editable source keeps its untouched reference collection; this export
	# pass contains only the component and the matching armature.
	for obj in list(reference.objects):
		bpy.data.objects.remove(obj, do_unlink=True)
	bpy.data.collections.remove(reference)
	bpy.ops.export_scene.gltf(
		filepath=str(CREATOR / "hair_snowbob.glb"),
		export_format="GLB",
		export_animations=False,
		export_skins=True,
		export_def_bones=False,
		export_leaf_bone=False,
		export_all_influences=True,
	)
	print("Built Enhanced Snow Bob: %d base hair vertices, %d bone rests preserved" % (len(selected), len(bones)))


if __name__ == "__main__":
	build()
