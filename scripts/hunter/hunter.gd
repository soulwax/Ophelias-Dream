class_name Hunter
extends Node3D

var trail: Trail
var offset: float = 0.0
var model: Node3D
var eyes: Node3D
var animation_player: AnimationPlayer
var _clip: String = ""
var _snap_in: float = 4.0


func _ready() -> void:
	_build_model()
	if trail:
		offset = 0.0
		global_position = trail.position_at(0.0)
	Game.hunter = self


func _physics_process(delta: float) -> void:
	if trail == null or Game.player == null:
		return
	if Game.phase == Game.Phase.INTRO or Game.phase == Game.Phase.PAUSED:
		return
	if Game.phase == Game.Phase.CAUGHT or Game.phase == Game.Phase.ESCAPED:
		_play("Idle")
		return

	var player_offset := trail.offset_of(Game.player.global_position)
	if player_offset >= trail.exit_offset:
		Game.escape()
		return

	offset = minf(offset + Tune.HUNTER_SPEED * delta, trail.length)
	var frame := trail.frame_at(offset)
	global_position = trail.to_global(frame.origin)
	var forward := -frame.basis.z
	forward.y = 0.0
	if forward.length() > 0.01:
		look_at(global_position + forward, Vector3.UP)

	var gap := player_offset - offset
	Game.set_closeness(clampf(1.0 - gap / Tune.REVEAL_EYES, 0.0, 1.0))
	_reveal(gap)
	_play("Sprint" if gap < Tune.REVEAL_BODY else "Jog_Fwd")
	_ambience(delta, gap)

	if gap < Tune.CATCH_GAP:
		Game.catch_player()


func _reveal(gap: float) -> void:
	if eyes:
		eyes.visible = gap < Tune.REVEAL_EYES
	if model:
		model.visible = gap < Tune.REVEAL_BODY


func _ambience(delta: float, gap: float) -> void:
	if gap > Tune.REVEAL_BODY and Game.soundscape:
		_snap_in -= delta
		if _snap_in <= 0.0:
			_snap_in = randf_range(5.0, 11.0)
			Game.soundscape.play_snap()


func _build_model() -> void:
	var path := "res://addons/quaternius_ik_rigged/Models_with_rigging/Master_Rigged.tscn"
	if ResourceLoader.exists(path):
		model = (load(path) as PackedScene).instantiate()
		model.scale = Vector3.ONE * Tune.ACTOR_SCALE * 1.08
		model.rotation.y = PI
		add_child(model)
		_cloak(model)
		animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	eyes = Node3D.new()
	eyes.name = "Eyes"
	add_child(eyes)
	_eye(Vector3(-0.06, 1.68, -0.12))
	_eye(Vector3(0.06, 1.68, -0.12))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.85, 0.08, 0.05)
	glow.light_energy = 0.7
	glow.omni_range = 4.5
	glow.position = Vector3(0, 1.68, -0.08)
	glow.light_volumetric_fog_energy = 1.2
	eyes.add_child(glow)
	eyes.visible = false


func _eye(at: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.03
	sphere.height = 0.06
	mesh_instance.mesh = sphere
	mesh_instance.position = at
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0.2, 0.12)
	material.emission_enabled = true
	material.emission = Color(1, 0.04, 0.02)
	material.emission_energy_multiplier = 6.0
	mesh_instance.material_override = material
	eyes.add_child(mesh_instance)


func _cloak(root: Node) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.01, 0.01, 0.014)
	material.roughness = 0.42
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		(mesh_instance as MeshInstance3D).material_override = material


func _play(clip: String) -> void:
	if animation_player == null:
		return
	var resolved := clip
	if not animation_player.has_animation(resolved):
		var suffix := "/" + clip
		resolved = ""
		for name in animation_player.get_animation_list():
			if name.ends_with(suffix):
				resolved = name
				break
		if resolved == "" and clip == "Jog_Fwd":
			_play("Walk")
			return
	if resolved == "" or resolved == _clip:
		return
	var animation := animation_player.get_animation(resolved)
	if animation:
		animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(resolved, 0.2)
	_clip = resolved
