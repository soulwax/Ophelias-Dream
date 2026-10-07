class_name Lake
extends Node3D

## The end of Ophelia's walk, past the false lead.
##
## At the lookout the "headlights" were only two lanterns hung on its rail, and
## the lookout is a checkpoint (Game.reach_checkpoint). Posts with red rags lead
## on along the leg Trail adds past the drawn route, to the frozen lake from her
## memory: clear ice with cracks and drifts, the old hole frozen over, two sets
## of prints going out to it and back, dry reeds at the shore. The run ends on
## the ice by the hole (Game._at_lake).
##
## Like Camp, it is built after the snapshot is applied, and it hides Trail's
## headlight spots instead of removing them so the editable level lines up.
## Dev hook: RUN_SPAWN=lookout|lake starts her there.

const GRASS := "res://assets/vendor/sketchfab_forest/meshes/grass_card.res"
const WOOD := "res://assets/vendor/requested_camp/leartes/T_Wooden_B.png"

const MEETING := "res://assets/dialogue/lake.json"
# Pages she has read, as the meeting's flags (assets/dialogue/lake.json).
const PAGE_FLAGS := {"from the pack": "pack", "on the post": "post", "torn page": "torn",
	"the handwriting changes": "handwriting", "intake": "intake", "by the bed": "bed"}

var is_built := false
var mathilda: OpheliaNpc
var meeting: Conversation
var _sighted := false
# She has to walk away before coming back opens the conversation again.
var _away := true
var _lanterns: Array[OmniLight3D] = []
var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	name = "Lake"
	add_to_group("lake")
	_noise.seed = 3301
	_noise.frequency = 1.0
	_build.call_deferred()


func _process(delta: float) -> void:
	if not is_built:
		return
	_time += delta
	for index in _lanterns.size():
		_lanterns[index].light_energy = 3.0 * (1.0 + _noise.get_noise_1d(_time * 9.0 + index * 50.0) * 0.14)
	_watch_meeting()


# ---------------------------------------------------------------- the meeting

## Mathilda waits on the ice when Game.meeting_ready(): placed as Ophelia nears
## the lake, gone again if she turns around, and talked to by walking up to her.
func _watch_meeting() -> void:
	var trail := Game.trail
	if Game.mathilda_pov or Game.player == null or trail == null:
		return
	var here := Game.player.global_position
	var to_lake := Vector2(here.x - trail.lake_point.x, here.z - trail.lake_point.z).length()
	if mathilda == null:
		if to_lake < Tune.LAKE_NEAR + 40.0 and Game.phase == Game.Phase.PLAYING and Game.meeting_ready():
			_place_mathilda(trail)
		return
	if not mathilda.visible:
		return
	if Game.turned_around and not meeting.active:
		# She looked back. There is only one of them out here now.
		_withdraw()
		return
	if not _sighted and to_lake < Tune.LAKE_NEAR and Game.voice:
		_sighted = true
		Game.voice.moment("sighted")
	var to_her := Vector2(here.x - mathilda.global_position.x, here.z - mathilda.global_position.z).length()
	if to_her > Tune.MEETING_REACH + 3.0:
		_away = true
	elif to_her <= Tune.MEETING_REACH and _away and Game.phase == Game.Phase.PLAYING and meeting.finished == "":
		_away = false
		meeting.begin()


func _place_mathilda(trail: Trail) -> void:
	var shore := trail.position_at(trail.lake_offset - Tune.LAKE_RADIUS)
	var toward_shore := Vector3(shore.x - trail.lake_hole.x, 0.0, shore.z - trail.lake_hole.z).normalized()
	mathilda = OpheliaNpc.new()
	mathilda.name = "Mathilda"
	add_child(mathilda)
	mathilda.settle(trail.lake_hole + toward_shore * 1.4)
	mathilda.rotation.y = atan2(-toward_shore.x, -toward_shore.z) + PI
	meeting = Conversation.make(MEETING, mathilda)
	add_child(meeting)
	for title: String in PAGE_FLAGS:
		if Game.read_pages.has(title):
			meeting.flags[PAGE_FLAGS[title]] = true
	meeting.ended.connect(Game.finish_meeting)
	Game.meeting_waiting = true
	Game.mark("mathilda waits on the ice")


func _withdraw() -> void:
	mathilda.visible = false
	for body in mathilda.find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 0
	Game.meeting_waiting = false
	Game.mark("mathilda gone from the ice")


func _build() -> void:
	var trail := Game.trail
	if trail == null or is_built:
		return
	_tower(trail)
	_posts(trail)
	_ice(trail)
	is_built = true
	_dev_spawn(trail)


# ---------------------------------------------------------------- the lookout

func _tower(trail: Trail) -> void:
	for child in trail.get_children():
		if child is SpotLight3D and (child as Node3D).global_position.distance_to(trail.exit_point) < 6.0:
			(child as SpotLight3D).visible = false
			child.set_meta("replaced_by", "Lake")
	var tower := trail.get_node_or_null("SM_Prop_Lookout_01") as Node3D
	var bounds := AABB()
	if tower:
		for mi in tower.find_children("*", "MeshInstance3D", true, false):
			var piece := mi as MeshInstance3D
			if not piece.is_visible_in_tree():
				continue
			var box := piece.global_transform * piece.get_aabb()
			bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	if bounds.size == Vector3.ZERO:
		var at := trail.on_ground(trail.exit_point)
		bounds = AABB(at + Vector3(4.5, 0.0, -1.5), Vector3(3.0, 4.0, 3.0))
	# The two corners of the rail that face back down the path: from the field
	# they read as a car's headlights.
	var toward := trail.exit_point - bounds.get_center()
	toward.y = 0.0
	toward = toward.normalized()
	var across := toward.cross(Vector3.UP)
	# Hung from the top rail, at the two corners facing back down the path.
	var rail_y := bounds.end.y - 0.08
	var half := minf(bounds.size.x, bounds.size.z) * 0.44
	for side: float in [-1.0, 1.0]:
		var at := Vector3(bounds.get_center().x, rail_y, bounds.get_center().z) + toward * half + across * side * half
		var lantern := HouseKit.prop(self, "Lantern_01", Vector3.ZERO, 0.0, 1.2)
		lantern.global_position = at - Vector3.UP * 0.32
		var flame := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.016
		sphere.height = 0.045
		flame.mesh = sphere
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.0, 0.62, 0.32)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.5, 0.22)
		glow.emission_energy_multiplier = 8.0
		flame.material_override = glow
		add_child(flame)
		flame.global_position = at - Vector3.UP * 0.18
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.52, 0.28)
		light.light_energy = 3.0
		light.omni_range = 26.0
		light.omni_attenuation = 1.6
		light.light_volumetric_fog_energy = 1.6
		light.light_specular = 0.2
		add_child(light)
		light.global_position = at - Vector3.UP * 0.12
		_lanterns.append(light)


# ---------------------------------------------------------------- the posts

## Every LAKE_POST_SPACING metres from the lookout to the shore: a weathered
## post with a red rag tied near the top and snow on its cap.
func _posts(trail: Trail) -> void:
	var wood := _wood()
	var rag := StandardMaterial3D.new()
	rag.albedo_color = Color("7a2420")
	rag.roughness = 1.0
	rag.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cap := HouseKit.paint(Color(0.9, 0.93, 0.97), 0.85)
	var post := CylinderMesh.new()
	post.top_radius = 0.05
	post.bottom_radius = 0.06
	post.height = 1.55
	var cloth := BoxMesh.new()
	cloth.size = Vector3(0.11, 0.2, 0.012)
	var snow := CylinderMesh.new()
	snow.top_radius = 0.045
	snow.bottom_radius = 0.06
	snow.height = 0.035
	var along := trail.exit_offset + 10.0
	var last := trail.lake_offset - Tune.LAKE_RADIUS - 1.0
	var index := 0
	while along <= last:
		var frame := trail.frame_at(along)
		var side := Vector3(frame.basis.x.x, 0.0, frame.basis.x.z).normalized()
		var base := trail.on_ground(frame.origin + side * 2.2)
		var lean := Basis(Vector3(1, 0, 0.3).normalized(), deg_to_rad(4.0 if index % 2 == 0 else -3.0))
		var holder := Node3D.new()
		add_child(holder)
		holder.global_transform = Transform3D(lean, base)
		var stake := MeshInstance3D.new()
		stake.mesh = post
		stake.material_override = wood
		stake.position.y = 0.72
		holder.add_child(stake)
		var top := MeshInstance3D.new()
		top.mesh = snow
		top.material_override = cap
		top.position.y = 1.51
		holder.add_child(top)
		var tied := MeshInstance3D.new()
		tied.mesh = cloth
		tied.material_override = rag
		tied.position = Vector3(0.04, 1.22, 0.05)
		tied.rotation = Vector3(0.0, 0.6, 0.35)
		holder.add_child(tied)
		along += Tune.LAKE_POST_SPACING
		index += 1


func _wood() -> Material:
	var material := StandardMaterial3D.new()
	if ResourceLoader.exists(WOOD):
		material.albedo_texture = load(WOOD)
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 1.8
		material.albedo_color = Color(0.8, 0.78, 0.75)
	else:
		material.albedo_color = Color("5a4a3a")
	material.roughness = 0.92
	return material


# ---------------------------------------------------------------- the lake

func _ice(trail: Trail) -> void:
	var centre := trail.on_ground(trail.lake_point)
	var radius := Tune.LAKE_RADIUS
	# The ice: a disc with a ragged shore, just over the level pad.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := FastNoiseLite.new()
	edge.seed = 911
	edge.frequency = 0.9
	var segments := 96
	var rim: Array[Vector3] = []
	for k in segments:
		var a := TAU * k / segments
		var r := radius * (1.0 + edge.get_noise_1d(float(k) / segments * 6.0) * 0.08)
		rim.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for k in segments:
		var a := rim[k]
		var b := rim[(k + 1) % segments]
		for v in [Vector3.ZERO, b, a]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)
	var ice := MeshInstance3D.new()
	ice.name = "Ice"
	ice.mesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/lake_ice.gdshader")
	material.set_shader_parameter("noise", _noise_texture(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02))
	material.set_shader_parameter("cells", _cells_texture())
	material.set_shader_parameter("centre", centre)
	material.set_shader_parameter("radius", radius)
	material.set_shader_parameter("hole", Vector2(trail.lake_hole.x, trail.lake_hole.z))
	ice.material_override = material
	add_child(ice)
	ice.global_position = centre + Vector3.UP * 0.03
	_prints(trail, centre)
	_reeds(trail, centre)


## Two sets of prints from the shore to the old hole: one going out, one coming
## back, close together. The ending card says whose they are.
func _prints(trail: Trail, centre: Vector3) -> void:
	var shore := trail.on_ground(trail.position_at(trail.lake_offset - Tune.LAKE_RADIUS + 1.0))
	var hole := trail.lake_hole
	hole.y = centre.y
	shore.y = centre.y
	var texture := _print_texture()
	for set_index in 2:
		var from := shore if set_index == 0 else hole
		var to := hole if set_index == 0 else shore
		var dir := (to - from)
		dir.y = 0.0
		var span := dir.length()
		dir = dir.normalized()
		var side := dir.cross(Vector3.UP)
		var lane := side * (0.32 if set_index == 0 else -0.32)
		var steps := int(span / 0.72)
		for step in steps:
			var foot := 1.0 if step % 2 == 0 else -1.0
			var at := from + dir * (0.6 + step * 0.72) + lane + side * foot * 0.11
			if Vector2(at.x - hole.x, at.z - hole.z).length() < 1.6:
				continue
			var decal := Decal.new()
			decal.texture_albedo = texture
			decal.size = Vector3(0.13, 0.5, 0.31)
			decal.modulate = Color(0.62, 0.68, 0.78, 0.85)
			decal.upper_fade = 0.3
			decal.lower_fade = 0.3
			add_child(decal)
			decal.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP).rotated(Vector3.UP, foot * 0.06), at + Vector3.UP * 0.05)


func _print_texture() -> ImageTexture:
	var image := Image.create(48, 112, false, Image.FORMAT_RGBA8)
	for y in 112:
		for x in 48:
			var p := Vector2((x - 24.0) / 24.0, (y - 56.0) / 56.0)
			var sole := Vector2(p.x / 0.85, (p.y + 0.3) / 0.62).length()
			var heel := Vector2(p.x / 0.72, (p.y - 0.62) / 0.3).length()
			var inside := 1.0 - smoothstep(0.8, 1.0, minf(sole, heel))
			image.set_pixel(x, y, Color(0.5, 0.56, 0.66, inside))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Dry reeds and grass standing out of the snow round the shore.
func _reeds(trail: Trail, centre: Vector3) -> void:
	if not ResourceLoader.exists(GRASS):
		return
	var mesh := load(GRASS) as Mesh
	if mesh == null:
		return
	var straw := mesh.duplicate() as Mesh
	for s in straw.get_surface_count():
		var base := straw.surface_get_material(s) as BaseMaterial3D
		if base:
			var dry := base.duplicate() as BaseMaterial3D
			dry.albedo_color = Color(0.86, 0.74, 0.5)
			straw.surface_set_material(s, dry)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = straw
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var count := 40 if Game.lean_graphics else 80
	multi.instance_count = count
	var entry := trail.position_at(trail.lake_offset - Tune.LAKE_RADIUS)
	for k in count:
		var a := rng.randf() * TAU
		var r := Tune.LAKE_RADIUS + rng.randf_range(-1.0, 3.5)
		var at := centre + Vector3(cos(a) * r, 0.0, sin(a) * r)
		# Leave the way in clear.
		if Vector2(at.x - entry.x, at.z - entry.z).length() < 5.0:
			at += Vector3(cos(a), 0.0, sin(a)) * 6.0
		at = trail.on_ground(at)
		var scale := rng.randf_range(0.6, 1.15)
		multi.set_instance_transform(k, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), at))
	var reeds := MultiMeshInstance3D.new()
	reeds.name = "Reeds"
	reeds.multimesh = multi
	add_child(reeds)


func _noise_texture(kind: int, frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = kind
	noise.seed = 4120
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	return texture


func _cells_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise.seed = 77
	noise.frequency = 0.02
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.normalize = true
	texture.noise = noise
	return texture


# ---------------------------------------------------------------- dev hook

func _dev_spawn(trail: Trail) -> void:
	var where := OS.get_environment("RUN_SPAWN")
	if Game.player == null or not where in ["lookout", "lake"]:
		return
	var offset := trail.exit_offset - 18.0 if where == "lookout" else trail.lake_offset - Tune.LAKE_RADIUS - 8.0
	Game.player.global_position = trail.on_ground(trail.position_at(offset)) + Vector3.UP * 0.2
	Game.player.velocity = Vector3.ZERO
	Game.player.reset_physics_interpolation()
