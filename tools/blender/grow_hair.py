"""Grows the walker's hair on her real scalp, anatomically, and drapes it.

Follicles: only inside a real hairline, measured around the head (angle 0 at
the back, 180 deg at the face): the nape line with its slight V, up behind
the ear, arching over it, a narrow sideburn in front of it, up to the temple
with a slight recession, and the frontal line across the forehead.

Strands: each leaves its follicle in the combed direction (away from a side
part, back off the face, down at the back), then drapes under gravity with a
stiffness that fades from root to tip, colliding with the real head, neck and
shoulders (allowing for the coat and scarf over them). Guide strands are grown
first; the rest clump partly onto their nearest guide toward the tips, as
real hair groups.

Cards: one tapered card per strand, its face turned outward; shading normals
point away from the head and body so the hair reads as one volume; vertex
colours run from darker roots to lighter tips with a tone per clump.

Output (Godot rest space): assets/characters/hair.glb

    blender -b --factory-startup -P tools/blender/grow_hair.py
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
OUT = os.path.join(ROOT, "assets", "characters", "hair.glb")
OUT_GUIDES = os.path.join(ROOT, "assets", "characters", "hair_guides.json")

SEED = 1907
GUIDES = 96          # simulated in Godot; every strand blends its three nearest
SIM_EVERY = 2        # a guide particle every other grown point
SIM_POINTS = 15      # particles per guide
GUIDE_LENGTH = (SIM_POINTS - 1) * SIM_EVERY * 0.022
STRANDS = 900
SEGMENT = 0.022
LENGTH = 0.6          # crown to tip: mid-back
PART_X = 0.028        # side part, on her left
HAIR_ROOT = (0.075, 0.038, 0.024)
HAIR_TIP = (0.27, 0.145, 0.075)
DOWN = Vector((0.0, -1.0, 0.0))


def to_godot(v: Vector) -> Vector:
	return Vector((v.x, v.z, -v.y))


def to_blender(v: Vector) -> Vector:
	return Vector((v.x, -v.z, v.y))


def smoothstep(e0: float, e1: float, x: float) -> float:
	t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
	return t * t * (3.0 - 2.0 * t)


# --- Her body ----------------------------------------------------------------

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SOURCE)
body = bpy.data.objects["Superhero_Female"]
bones = bpy.data.objects["Armature"].data.bones
head_y = to_godot(bones["Head"].head_local).y
neck_y = to_godot(bones["neck_01"].head_local).y
verts = [to_godot(v.co) for v in body.data.vertices]
polys = [list(p.vertices) for p in body.data.polygons]


def region(test) -> list:
	return [p for p in polys if all(test(verts[i]) for i in p)]


# Head and neck, collided with closely; shoulders and back, with room for
# the coat and scarf. The rest pose holds the arms out, so the torso stops
# short of the shoulder joints.
head_polys = region(lambda v: v.y > neck_y - 0.03 and abs(v.x) < 0.16)
head_bvh = BVHTree.FromPolygons(verts, head_polys)

top_y = max(v.y for v in verts if abs(v.x) < 0.16)
widest = [v for v in verts if abs(v.y - (head_y + 0.1)) < 0.012 and abs(v.x) < 0.16]
cz = (min(v.z for v in widest) + max(v.z for v in widest)) * 0.5
head_centre = Vector((0.0, head_y + 0.08, cz))


def around(p: Vector) -> float:
	"""Degrees round the head: 0 at the back, 180 at the face."""
	return abs(math.degrees(math.atan2(p.x, -(p.z - cz))))


# The hairline: (degrees from the back, height). Heights above the head
# joint except the nape, which is measured from the neck joint.
HAIRLINE = [
	(0.0, neck_y + 0.035),     # nape, centre of its V
	(30.0, neck_y + 0.05),
	(60.0, head_y + 0.015),    # behind the ear, low
	(78.0, head_y + 0.11),     # arching up behind the ear
	(92.0, head_y + 0.125),    # over the ear
	(100.0, head_y + 0.075),   # down the sideburn, in front of the ear
	(104.0, head_y + 0.07),
	(112.0, head_y + 0.135),   # up to the temple
	(128.0, head_y + 0.158),   # temple, a slight recession
	(150.0, head_y + 0.163),
	(180.0, head_y + 0.168),   # the middle of the forehead
]


def hairline(p: Vector) -> float:
	a = around(p)
	for (a0, y0), (a1, y1) in zip(HAIRLINE, HAIRLINE[1:]):
		if a <= a1:
			t = (a - a0) / (a1 - a0)
			return y0 + (y1 - y0) * t
	return HAIRLINE[-1][1]


def band_of(y0: float, y1: float, width: float = 0.3) -> tuple:
	pts = [v for v in verts if y0 < v.y < y1 and abs(v.x) < width]
	zs = [v.z for v in pts]
	return (min(zs) + max(zs)) * 0.5, (max(zs) - min(zs)) * 0.5, max(abs(v.x) for v in pts)


# Her standing shape below the head, as capsules (the source is in a T-pose,
# whose horizontal arm roots would catch the hair): the scarfed neck, sloping
# shoulders, and the upper back and chest, all allowing for the coat.
neck_cz, neck_depth, neck_half = band_of(neck_y - 0.03, neck_y + 0.03, 0.09)
chest_cz, chest_depth, _chest_half = band_of(1.25, 1.33, 0.2)
COAT = 0.03
BODY = [
	(Vector((0.0, neck_y - 0.12, neck_cz)), Vector((0.0, head_y, neck_cz)), max(neck_half, neck_depth) + 0.035),
	# Shoulders slope from the base of the neck down to the shoulder point.
	(Vector((-0.04, neck_y - 0.075, chest_cz)), Vector((-0.165, neck_y - 0.15, chest_cz)), 0.06 + COAT),
	(Vector((0.04, neck_y - 0.075, chest_cz)), Vector((0.165, neck_y - 0.15, chest_cz)), 0.06 + COAT),
	(Vector((-0.055, 1.02, chest_cz)), Vector((-0.055, neck_y - 0.13, chest_cz)), chest_depth + COAT),
	(Vector((0.055, 1.02, chest_cz)), Vector((0.055, neck_y - 0.13, chest_cz)), chest_depth + COAT),
]


def push_out(p: Vector, layer: float) -> Vector:
	"""Keep a point outside the head (by its layer) and outside her standing,
	clothed shape below it."""
	hit, normal, _i, _d = head_bvh.find_nearest(p)
	if hit is not None:
		normal = normal.normalized()
		out = p - hit
		room = 0.003 + layer
		if out.dot(normal) < room:
			p = hit + normal * room + (out - normal * out.dot(normal))
	for a, b, radius in BODY:
		ab = b - a
		t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
		q = a + ab * t
		d = p - q
		r = radius + layer * 0.6
		if d.length < r:
			d = d.normalized() if d.length > 1e-6 else Vector((0.0, 0.0, -1.0))
			p = q + d * r
	return p

def outward(p: Vector) -> Vector:
	"""Shading normal: from the head centre on the head, from the body axis below."""
	if p.y > neck_y:
		n = p - head_centre
	else:
		n = Vector((p.x, 0.0, p.z - cz + 0.02))
	return n.normalized() if n.length > 1e-6 else Vector((0.0, 0.0, -1.0))


def combed(p: Vector, normal: Vector, side: float) -> Vector:
	"""How the hair lies at p on the scalp: back off the face, away from the
	part (on the root's side of it), and down. 'Front' is judged by depth,
	since the angle round the head is unstable at the crown."""
	face = smoothstep(cz + 0.01, cz + 0.085, p.z)
	top = smoothstep(head_y + 0.12, top_y - 0.01, p.y)
	lateral = 0.25 + 0.55 * max(face, top)
	wish = Vector((side * lateral, -(0.35 + 0.5 * (1.0 - face)), -(0.15 + 0.9 * face)))
	wish -= normal * wish.dot(normal)
	return wish.normalized() if wish.length > 1e-6 else DOWN

# --- Follicles ---------------------------------------------------------------

def scalp() -> list:
	faces = []
	for poly in head_polys:
		pts = [verts[i] for i in poly]
		mid = sum(pts, Vector()) / len(pts)
		if mid.y < hairline(mid) or mid.y < neck_y:
			continue
		area = sum(((pts[k] - pts[0]).cross(pts[k + 1] - pts[0]).length * 0.5 for k in range(1, len(pts) - 1)), 0.0)
		faces.append((pts, area))
	return faces


def follicle(rng: random.Random, faces: list, total: float):
	for _attempt in range(40):
		pick = rng.uniform(0.0, total)
		for pts, area in faces:
			pick -= area
			if pick <= 0.0:
				k = rng.randint(1, len(pts) - 2)
				a, b = rng.random(), rng.random()
				if a + b > 1.0:
					a, b = 1.0 - a, 1.0 - b
				p = pts[0] + (pts[k] - pts[0]) * a + (pts[k + 1] - pts[0]) * b
				if p.y >= hairline(p):
					normal = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
					if normal.dot(p - head_centre) < 0.0:
						normal = -normal
					return p, normal
				break
	return None


# --- Growth -------------------------------------------------------------------

def grow(root: Vector, normal: Vector, length: float, layer: float) -> list:
	"""A strand. Where the skull faces up or sideways, gravity holds the hair
	against it, so it slides over the surface as combed; where the surface
	turns downward it leaves the head and hangs, colliding with the clothed
	shoulders and back."""
	room = 0.003 + layer
	side = 1.0 if root.x > PART_X else -1.0
	points = [root + normal * room]
	direction = combed(root, normal, side)
	travelled = 0.0
	on_head = True
	count = max(3, int(length / SEGMENT))
	for _i in range(count):
		p = points[-1]
		if on_head:
			hit, n, _x, _d = head_bvh.find_nearest(p)
			if hit is None:
				on_head = False
			else:
				n = n.normalized()
				if n.dot(p - head_centre) < 0.0:
					n = -n
				# The hair leaves the head where the surface turns downward.
				if n.y < -0.12 or p.y < neck_y:
					on_head = False
				else:
					gravity = DOWN - n * DOWN.dot(n)
					gravity = gravity.normalized() if gravity.length > 1e-6 else DOWN
					give = smoothstep(0.0, 0.16, travelled) * 0.55
					along = (combed(p, n, side) * (1.0 - give) + gravity * give).normalized()
					q = p + along * SEGMENT
					hit2, n2, _x, _d = head_bvh.find_nearest(q)
					if hit2 is not None:
						n2 = n2.normalized()
						if n2.dot(q - head_centre) < 0.0:
							n2 = -n2
						q = hit2 + n2 * room
					direction = (q - p).normalized()
					points.append(p + direction * SEGMENT)
					travelled += SEGMENT
					continue
		# Hanging: it straightens quickly under its own weight, and nothing
		# keeps it moving sideways once it is off the head.
		direction = Vector((direction.x * 0.35, direction.y, direction.z * 0.5))
		direction = (direction * 0.5 + DOWN * 0.5).normalized()
		q = push_out(p + direction * SEGMENT, layer)
		step = q - p
		if step.length < 1e-6:
			break
		direction = step.normalized()
		points.append(p + direction * SEGMENT)
		travelled += SEGMENT
	return points

def clump(child: list, guide: list, root_offset: Vector, amount: float) -> list:
	"""Draw a strand toward its guide, more toward the tip."""
	out = [child[0]]
	for i in range(1, len(child)):
		t = i / (len(child) - 1)
		g = guide[min(i, len(guide) - 1)] + root_offset * (1.0 - t * 0.8)
		out.append(child[i].lerp(g, amount * t ** 1.4))
	return out


# --- Cards ----------------------------------------------------------------------

def card(bm, uv_layer, guide_layer, color_layer, normals: list, points: list, width: float, tone: float, guide: int) -> None:
	rows = []
	count = len(points)
	for i, p in enumerate(points):
		along = points[min(i + 1, count - 1)] - points[max(i - 1, 0)]
		n = outward(p)
		across = along.cross(n)
		across = across.normalized() if across.length > 1e-8 else Vector((1.0, 0.0, 0.0))
		v = i / (count - 1)
		# Full width over the head, tapering to a few strands at the tip.
		half = width * 0.5 * (1.0 - 0.65 * v ** 1.3)
		rows.append((bm.verts.new(to_blender(p - across * half)), bm.verts.new(to_blender(p + across * half)), n, v))
	for i in range(count - 1):
		a0, a1, n0, v0 = rows[i]
		b0, b1, n1, v1 = rows[i + 1]
		face = bm.faces.new((a0, a1, b1, b0))
		for loop, (u, v, n) in zip(face.loops, ((0.0, v0, n0), (1.0, v0, n0), (1.0, v1, n1), (0.0, v1, n1))):
			loop[uv_layer].uv = (u, 1.0 - v)
			# Which guide this point follows, and how far along it (0 root, 1 tip).
			along = min(1.0, (v * (count - 1)) * SEGMENT / GUIDE_LENGTH)
			# Three guides packed exactly into one float: g0 + 96 g1 + 9216 g2.
			loop[guide_layer].uv = (float(guide[0] + GUIDES * guide[1] + GUIDES * GUIDES * guide[2]), 1.0 - along)
			mix = smoothstep(0.05, 1.0, v)
			loop[color_layer] = tuple(min(1.0, (HAIR_ROOT[c] + (HAIR_TIP[c] - HAIR_ROOT[c]) * mix) * tone) for c in range(3)) + (1.0,)
			normals.append(to_blender(n))


def main() -> None:
	rng = random.Random(SEED)
	faces = scalp()
	total = sum(area for _pts, area in faces)
	# Guides first, then every strand clumps toward its nearest guide.
	# Guides all share one length, so each is SIM_POINTS particles in Godot.
	guides = []
	while len(guides) < GUIDES:
		spot = follicle(rng, faces, total)
		if spot is None:
			continue
		root, normal = spot
		path = grow(root, normal, GUIDE_LENGTH + SEGMENT, 0.004)
		while len(path) < (SIM_POINTS - 1) * SIM_EVERY + 1:
			path.append(path[-1] + DOWN * SEGMENT)
		guides.append((root, path, rng.uniform(0.85, 1.12)))
	mesh = bpy.data.meshes.new("Hair")
	bm = bmesh.new()
	uv_layer = bm.loops.layers.uv.new("UVMap")
	guide_layer = bm.loops.layers.uv.new("Guide")
	color_layer = bm.loops.layers.float_color.new("Col")
	normals = []
	made = 0
	while made < STRANDS:
		spot = follicle(rng, faces, total)
		if spot is None:
			continue
		root, normal = spot
		layer = rng.choice((0.0, 0.004, 0.008))
		nearest = sorted(range(len(guides)), key=lambda g: (guides[g][0] - root).length)[:3]
		guide = tuple(nearest)
		guide_root, guide_path, tone = guides[nearest[0]]
		# Hair at the face and nape is shorter and finer.
		edge = 1.0 - smoothstep(0.0, 0.03, root.y - hairline(root))
		length = LENGTH * rng.uniform(0.86, 1.04) * (1.0 - 0.25 * edge)
		path = grow(root, normal, length, layer)
		path = clump(path, guide_path, root - guide_root, rng.uniform(0.35, 0.7))
		path = [path[0]] + [push_out(p, layer) for p in path[1:]]
		width = rng.uniform(0.012, 0.022) * (1.0 - 0.4 * edge)
		card(bm, uv_layer, guide_layer, color_layer, normals, path, width, tone * rng.uniform(0.92, 1.06) * (0.9 + 0.1 * layer / 0.008), guide)
		made += 1
	bm.to_mesh(mesh)
	bm.free()
	mesh.normals_split_custom_set(normals)
	mesh.color_attributes.active_color = mesh.color_attributes["Col"]
	mesh.color_attributes.render_color_index = 0
	obj = bpy.data.objects.new("Hair", mesh)
	bpy.context.scene.collection.objects.link(obj)
	mesh.materials.append(bpy.data.materials.new("Hair"))
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	kwargs = dict(filepath=OUT, export_format="GLB", use_selection=True, export_normals=True, export_texcoords=True)
	props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
	if "export_vertex_color" in props:
		kwargs["export_vertex_color"] = "ACTIVE"
	if "export_all_vertex_colors" in props:
		kwargs["export_all_vertex_colors"] = True
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	bpy.ops.export_scene.gltf(**kwargs)
	records = []
	for root, path, _tone in guides:
		sim = path[::SIM_EVERY][:SIM_POINTS]
		on_scalp = 1
		for p in sim[1:]:
			hit, n, _x, _d = head_bvh.find_nearest(p)
			if hit is None or (p - hit).length > 0.02 or p.y < neck_y:
				break
			on_scalp += 1
		records.append({"points": [[p.x, p.y, p.z] for p in sim], "scalp": on_scalp})
	with open(OUT_GUIDES, "w") as handle:
		json.dump({"space": "godot_rest", "segment": SEGMENT * SIM_EVERY, "guides": records}, handle)
	print(f"GUIDES {len(records)} x {SIM_POINTS}, scalp points avg {sum(r['scalp'] for r in records) / len(records):.1f} -> {OUT_GUIDES}")
	wide = max((abs(v.co.x) for v in mesh.vertices if v.co.z < 1.45), default=0.0)
	low_wide = [round(v.co.z, 3) for v in mesh.vertices if abs(v.co.x) > 0.22][:6]
	print(f"HAIRWIDE max|x| below 1.45 = {wide:.3f}; heights of the widest: {low_wide}")
	print(f"HAIR guides={len(guides)} strands={made} verts={len(mesh.vertices)} faces={len(mesh.polygons)} -> {OUT}")


main()
