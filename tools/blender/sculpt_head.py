"""Sculpts the walker's head in Blender, from the rig's own source model:

1. Hair: strands rooted on her real scalp polygons (area-weighted), combed
   away from a side part along the surface (re-projected onto the head every
   step, so they hug it), framing the face at the front, in three layers.
   Each strand becomes a tapered card: UVs across x / root-to-tip y, normals
   taken from the scalp so the whole cap shades as one mass, vertex colours
   darker at the roots and in the deeper layers.
   -> assets/characters/hair_crown.glb   (rest space, attached to Head in Godot)

2. Face: eyelid and brow offsets for blend shapes (blink per eye, a strained
   squint, a frightened inner-brow lift), keyed by rest position so Godot can
   apply them to its imported copy of the mesh without touching the rig.
   -> assets/characters/face_shapes.json

Coordinates: Blender (x, y, z) of the imported glTF = Godot rest (x, -z, y),
so Godot rest = (bx, bz, -by).

    blender -b --factory-startup -P tools/blender/sculpt_head.py
"""
import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "addons", "quaternius_ik_rigged", "Godot - UE", "Superhero_Female_FullBody.gltf")
OUT_HAIR = os.path.join(ROOT, "assets", "characters", "hair_crown.glb")
OUT_FACE = os.path.join(ROOT, "assets", "characters", "face_shapes.json")

HAIR_ROOT = (0.09, 0.045, 0.028)
HAIR_TIP = (0.3, 0.16, 0.08)
PART_X = 0.032
STRANDS = 520
SEED = 7311


def to_godot(v: Vector) -> Vector:
	return Vector((v.x, v.z, -v.y))


def to_blender(v: Vector) -> Vector:
	return Vector((v.x, -v.z, v.y))


# --- Load ---------------------------------------------------------------------

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SOURCE)
body = bpy.data.objects["Superhero_Female"]
brows = bpy.data.objects["Eyebrows"]
eyes = bpy.data.objects["Eyes"]
armature = bpy.data.objects["Armature"]
bones = armature.data.bones
head_y = to_godot(bones["Head"].head_local).y
# The source keeps Unreal-style names (Godot's importer renames them).
neck_y = to_godot(bones["neck_01"].head_local).y

# Head geometry only, in Godot space, for the BVH the strands crawl over.
head_verts = [to_godot(v.co) for v in body.data.vertices]
head_polys = [list(p.vertices) for p in body.data.polygons if min(head_verts[i].y for i in p.vertices) > neck_y - 0.02 and max(abs(head_verts[i].x) for i in p.vertices) < 0.16]
bvh = BVHTree.FromPolygons(head_verts, head_polys)

top_y = max(v.y for v in head_verts if abs(v.x) < 0.16)
widest_y = head_y + 0.1
band = [v for v in head_verts if abs(v.y - widest_y) < 0.012 and abs(v.x) < 0.16]
cz = (min(v.z for v in band) + max(v.z for v in band)) * 0.5
centre = Vector((0.0, widest_y - 0.02, cz))
front_line = head_y + 0.165
side_line = head_y + 0.105
back_line = neck_y + 0.08


def smoothstep(e0: float, e1: float, x: float) -> float:
	t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
	return t * t * (3.0 - 2.0 * t)


def around(p: Vector) -> float:
	"""Angle round the head, 0 at the back, as in outfit.gd."""
	return math.atan2(p.x, -(p.z - cz))


def hairline(angle: float) -> float:
	c = math.cos(angle)
	face = smoothstep(-0.25, -0.6, c)
	nape = smoothstep(0.0, 0.9, c)
	base = side_line + (back_line - side_line) * nape
	return base + (front_line - base) * face


def on_scalp(p: Vector) -> bool:
	return p.y > hairline(around(p)) + 0.004


# --- Hair -----------------------------------------------------------------------

def scalp_polys() -> list:
	polys = []
	for poly in head_polys:
		pts = [head_verts[i] for i in poly]
		mid = sum(pts, Vector()) / len(pts)
		if on_scalp(mid):
			area = 0.0
			for k in range(1, len(pts) - 1):
				area += (pts[k] - pts[0]).cross(pts[k + 1] - pts[0]).length * 0.5
			polys.append((pts, area))
	return polys


def sample_root(rng: random.Random, polys: list, total: float) -> Vector:
	pick = rng.uniform(0.0, total)
	for pts, area in polys:
		pick -= area
		if pick <= 0.0:
			k = rng.randint(1, len(pts) - 2)
			a, b = rng.random(), rng.random()
			if a + b > 1.0:
				a, b = 1.0 - a, 1.0 - b
			return pts[0] + (pts[k] - pts[0]) * a + (pts[k + 1] - pts[0]) * b
	return polys[-1][0][0]


def comb(p: Vector, normal: Vector) -> Vector:
	"""The direction the hair lies at p: down and back, away from the part,
	sweeping sideways toward the temples at the front."""
	angle = around(p)
	front = max(0.0, -math.cos(angle))
	side = 1.0 if p.x > PART_X else -1.0
	wish = Vector((side * (0.35 + 1.6 * front), -(1.0 - 0.55 * front), -0.55 * (1.0 - front) + 0.15 * front))
	# On the surface.
	wish -= normal * wish.dot(normal)
	return wish.normalized() if wish.length > 1e-6 else Vector((0.0, -1.0, 0.0))


def grow(rng: random.Random, root: Vector, layer: int) -> list:
	lift = 0.0035 + 0.0045 * layer
	length = rng.uniform(0.07, 0.15) * (1.15 if math.cos(around(root)) > 0.3 else 1.0)
	step = 0.011
	points = []
	p = root
	for _ in range(int(length / step) + 1):
		hit, normal, _index, _dist = bvh.find_nearest(p)
		if hit is None:
			break
		normal = normal.normalized()
		if (hit - centre).dot(normal) < 0.0:
			normal = -normal
		points.append((hit + normal * lift, normal))
		p = hit + comb(hit, normal) * step
		# Front hair stops at the hairline instead of falling on the face.
		if math.cos(around(p)) < -0.3 and p.y < front_line - 0.012:
			break
	return points


def build_hair() -> None:
	rng = random.Random(SEED)
	polys = scalp_polys()
	total = sum(area for _pts, area in polys)
	mesh = bpy.data.meshes.new("HairCrown")
	bm = bmesh.new()
	uv_layer = bm.loops.layers.uv.new("UVMap")
	color_layer = bm.loops.layers.float_color.new("Col")
	normals = []
	strands = 0
	for n in range(STRANDS):
		layer = n % 3
		points = grow(rng, sample_root(rng, polys, total), layer)
		if len(points) < 3:
			continue
		strands += 1
		width = rng.uniform(0.014, 0.024) * (1.25 if layer == 2 else 1.0)
		tone = rng.uniform(0.85, 1.12) * (0.82, 0.92, 1.0)[layer]
		rows = []
		count = len(points)
		for i, (p, normal) in enumerate(points):
			along = points[min(i + 1, count - 1)][0] - points[max(i - 1, 0)][0]
			across = along.cross(normal)
			across = across.normalized() if across.length > 1e-8 else Vector((1.0, 0.0, 0.0))
			v = i / (count - 1)
			half = width * 0.5 * (1.0 - 0.5 * v)
			rows.append((bm.verts.new(to_blender(p - across * half)), bm.verts.new(to_blender(p + across * half)), normal, v))
		for i in range(count - 1):
			a0, a1, normal0, v0 = rows[i]
			b0, b1, normal1, v1 = rows[i + 1]
			face = bm.faces.new((a0, a1, b1, b0))
			for loop, (u, v, normal) in zip(face.loops, ((0.0, v0, normal0), (1.0, v0, normal0), (1.0, v1, normal1), (0.0, v1, normal1))):
				loop[uv_layer].uv = (u, 1.0 - (0.25 + v * 0.75))
				mix = v * 0.4
				loop[color_layer] = tuple(min(1.0, (HAIR_ROOT[c] + (HAIR_TIP[c] - HAIR_ROOT[c]) * mix) * tone) for c in range(3)) + (1.0,)
				normals.append(to_blender(normal))
	bm.to_mesh(mesh)
	bm.free()
	# The glTF exporter only writes the active colour attribute.
	mesh.color_attributes.active_color = mesh.color_attributes["Col"]
	mesh.color_attributes.render_color_index = 0
	# Scalp normals: the cap shades as one volume, not as separate cards.
	mesh.normals_split_custom_set(normals)
	obj = bpy.data.objects.new("HairCrown", mesh)
	bpy.context.scene.collection.objects.link(obj)
	material = bpy.data.materials.new("Hair")
	mesh.materials.append(material)
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	os.makedirs(os.path.dirname(OUT_HAIR), exist_ok=True)
	kwargs = dict(filepath=OUT_HAIR, export_format="GLB", use_selection=True, export_normals=True, export_texcoords=True)
	props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
	if "export_vertex_color" in props:
		kwargs["export_vertex_color"] = "ACTIVE"
	if "export_all_vertex_colors" in props:
		kwargs["export_all_vertex_colors"] = True
	if "export_colors" in props:
		kwargs["export_colors"] = True
	bpy.ops.export_scene.gltf(**kwargs)
	print(f"HAIR strands={strands} verts={len(mesh.vertices)} faces={len(mesh.polygons)} -> {OUT_HAIR}")


# --- Face -----------------------------------------------------------------------

def eye_centres() -> list:
	pts = [to_godot(v.co) for v in eyes.data.vertices]
	result = []
	for side in (1.0, -1.0):
		mine = [p for p in pts if p.x * side > 0.0]
		lo = Vector((min(p.x for p in mine), min(p.y for p in mine), min(p.z for p in mine)))
		hi = Vector((max(p.x for p in mine), max(p.y for p in mine), max(p.z for p in mine)))
		centre_eye = (lo + hi) * 0.5
		radius = max((hi - lo).x, (hi - lo).y) * 0.5
		# The ball's centre sits behind its visible front.
		result.append((side, Vector((centre_eye.x, centre_eye.y, hi.z - radius)), radius, hi.z))
	return result


def build_face() -> None:
	verts = [to_godot(v.co) for v in body.data.vertices]
	shapes = {"blink_L": [], "blink_R": [], "squint": [], "brow_fear": []}
	for side, c, radius, front_z in eye_centres():
		name = "blink_L" if side > 0.0 else "blink_R"
		half_w = radius * 1.45
		for p in verts:
			dx = p.x - c.x
			dy = p.y - c.y
			if abs(dx) > half_w or abs(dy) > radius * 2.4 or p.z < c.z - radius * 0.2:
				continue
			across = max(0.0, 1.0 - (dx / half_w) ** 2)
			if across <= 0.0:
				continue
			if dy > -radius * 0.15:
				# Upper lid: closes down past the middle, onto the ball.
				reach = 1.0 - smoothstep(radius * 1.05, radius * 2.2, dy)
				target_y = c.y - radius * 0.18
				close = (target_y - p.y) * across * reach
				squint = close * 0.22
			else:
				# Lower lid: a little up.
				reach = 1.0 - smoothstep(radius * 1.0, radius * 1.9, -dy)
				close = (c.y - radius * 0.25 - p.y) * 0.3 * across * reach
				squint = close * 1.2
			for key, amount in ((name, close), ("squint", squint)):
				if abs(amount) < 1e-5:
					continue
				moved = Vector((p.x, p.y + amount, p.z))
				# Stay on the outside of the eyeball.
				out = moved - c
				if out.length < radius + 0.0015:
					moved = c + out.normalized() * (radius + 0.0015)
				shapes[key].append([p.x, p.y, p.z, moved.x - p.x, moved.y - p.y, moved.z - p.z])
	# Inner ends of the brows lift and draw together: fear.
	for v in brows.data.vertices:
		p = to_godot(v.co)
		inner = 1.0 - smoothstep(0.012, 0.05, abs(p.x))
		if inner <= 0.0:
			continue
		shapes["brow_fear"].append([p.x, p.y, p.z, -math.copysign(0.0025, p.x) * inner, 0.0055 * inner, 0.0008 * inner])
	os.makedirs(os.path.dirname(OUT_FACE), exist_ok=True)
	with open(OUT_FACE, "w") as handle:
		json.dump({"space": "godot_rest", "shapes": shapes}, handle)
	print("FACE " + " ".join(f"{k}={len(v)}" for k, v in shapes.items()) + f" -> {OUT_FACE}")


# The hair is grown by tools/blender/grow_hair.py now; this script only makes the face shapes.
build_face()
