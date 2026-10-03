class_name Listener
extends Anomaly

# OBJECT 2-117, "the Listener". A tall figure of hoarfrost with no ears that
# perceives one thing only: visible breath. It glides to where it last saw
# steam, not to where she is, so she can stand beside it unharmed as long as
# nothing leaves her mouth. Calm breath carries about ten metres; panting
# after a sprint carries forty. Holding her breath hides her but drains her.

enum Mood { STILL, DRIFT, HUNT, LISTEN }

const RIG := "res://addons/quaternius_ik_rigged/Models_with_rigging/Master_Rigged.tscn"
const HEAR_CALM := 10.0
const HEAR_PLUME := 30.0
const NOTICE := 0.08
const DRIFT_SPEED := 0.55
const HUNT_SPEED := 3.3
const REACH := 1.6
const WAKE_AFTER := 18.0

var _mood := Mood.STILL
var _memory := Vector3.ZERO
var _linger := 0.0
var _roam_in := 0.0
var _wake_in := WAKE_AFTER
var _tilt := 0.0
var _skeleton: Skeleton3D
var _head := -1
var _head_rest := Quaternion.IDENTITY
var _crack: AudioStreamPlayer3D
var _hiss: AudioStreamPlayer3D


func _init() -> void:
	code = "2-117"
	name = "Listener"


func record() -> NoteEntry:
	return make_record(
		"OBJECT 2-117 — \"THE LISTENER\"",
		"Class: Persistent. Recovery: refused. The refusal is not dated.\n\n"
		+ "Description: Humanoid accretion of hoarfrost. First sheet, 2.4 m. The sheet clipped under it, 1.9 m, same hand. No auditory organs entered. Eyes: \"none found.\" Under that, another hand: \"do not look for them.\"\n\n"
		+ "A field page was in the pack with the strap stamp. It says the contact waved. No observation log contains a wave. The page is filed under this number because the pack was. That may be an error.\n\n"
		+ "The contact at the tree line has no number. The tree-line pages and this sheet disagree about the hand. Do not merge the files.\n\n"
		+ "It responds to visible exhaled vapour. Calm vapour in this weather carries about ten metres. Vapour after exertion carries further. The margin says \"across the kitchen,\" which is not a measure.\n\n"
		+ "Incident, signed M.: stood in reach for one minute and forty seconds, breath held. A crossed line under it reads \"until the lantern.\" When the breath was released the object turned. The log does not record contact. The crossed line does.\n\n"
		+ "Procedure, this number only: If it has turned its head, stop running. Running feeds the vapour. Hold the breath. Walk. Choose where you will let it out."
	)


func record_offset() -> float:
	return 14.0


func _ready() -> void:
	_build()
	_place()


func _physics_process(delta: float) -> void:
	if not awake() or Game.player == null:
		dread = 0.0
		hint = ""
		return
	if _wake_in > 0.0:
		_wake_in -= delta
		if _wake_in <= 0.0:
			_mood = Mood.DRIFT
		return
	var breath := Game.player.breath
	var plume := breath.plume if breath else 0.0
	# Walls hide the cloud: indoors there is nothing for it to perceive.
	if Game.indoors(Game.player.global_position + Vector3(0.0, 0.9, 0.0)):
		plume = 0.0
	var mouth := breath.global_position if breath else Game.player.global_position + Vector3(0, 1.6, 0)
	var distance := _flat(Game.player.global_position - global_position).length()
	# It perceives the cloud itself; a bigger cloud carries further.
	if plume > NOTICE and distance < HEAR_CALM + HEAR_PLUME * plume:
		if _mood != Mood.HUNT:
			_notice()
		_mood = Mood.HUNT
		_memory = mouth
	match _mood:
		Mood.HUNT:
			_glide(_memory, HUNT_SPEED, delta)
			if _flat(_memory - global_position).length() < 0.8:
				_mood = Mood.LISTEN
				_linger = randf_range(2.5, 4.0)
		Mood.LISTEN:
			_linger -= delta
			if _linger <= 0.0:
				_mood = Mood.DRIFT
				_roam_in = 0.0
		Mood.DRIFT:
			_roam_in -= delta
			if _roam_in <= 0.0:
				# It wanders the part of the field where breath was last seen.
				_roam_in = randf_range(9.0, 15.0)
				var away := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
				_memory = Game.player.global_position + away * randf_range(14.0, 28.0)
			_glide(_memory, DRIFT_SPEED, delta)
	if distance < REACH and plume > 0.1:
		catch("It heard you breathe", "The cloud left your mouth and it was already there. The cold went in where the air came out.")
		return
	var pressure := clampf(1.0 - distance / 32.0, 0.0, 1.0)
	match _mood:
		Mood.HUNT:
			dread = pressure
		Mood.LISTEN:
			dread = pressure * 0.75
		_:
			dread = pressure * 0.35
	hint = ""
	# It only announces itself once it has turned toward a breath. Drifting,
	# it is just a figure, and the one in the trees keeps the warning.
	if distance < 30.0 and _mood in [Mood.HUNT, Mood.LISTEN]:
		hint = "Hold your breath." if understood() else "Something is listening."
	_listen_pose(delta)
	if _hiss:
		var hunting := _mood == Mood.HUNT
		if hunting and not _hiss.playing:
			_hiss.play()
		elif not hunting and _hiss.playing:
			_hiss.stop()


func _notice() -> void:
	if _crack and _crack.stream:
		_crack.pitch_scale = randf_range(0.42, 0.5)
		_crack.play()


# It never walks. It slides over the snow, feet still, and turns slowly.
func _glide(target: Vector3, speed: float, delta: float) -> void:
	var to := _flat(target - global_position)
	if to.length() > 0.05:
		var step := minf(speed * delta, to.length())
		var next := global_position + to.normalized() * step
		next.x = clampf(next.x, Tune.FENCE_MIN_X + 3.0, Tune.FENCE_MAX_X - 3.0)
		next.z = clampf(next.z, Tune.FENCE_MIN_Z + 3.0, Tune.FENCE_MAX_Z - 3.0)
		next.y = trail.ground.height_at(next.x, next.z) if trail and trail.ground else next.y
		global_position = next
		var yaw := atan2(to.x, to.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 1.5))


# Head cocked toward the breath while it listens; level otherwise.
func _listen_pose(delta: float) -> void:
	if _skeleton == null or _head < 0:
		return
	var target := 0.0
	if _mood == Mood.LISTEN or _mood == Mood.HUNT:
		target = 0.55
	_tilt = lerpf(_tilt, target, 1.0 - exp(-delta * 2.0))
	_skeleton.set_bone_pose_rotation(_head, _head_rest * Quaternion(Vector3(0, 0, 1), _tilt))


func stand_transform(host: Trail) -> Transform3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = host.seed_value + 2117
	var start := host.position_at(host.player_start_offset)
	var at := start
	for _attempt in 20:
		var angle := rng.randf() * TAU
		at = start + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(55.0, 95.0)
		if at.x > Tune.FENCE_MIN_X + 8.0 and at.x < Tune.FENCE_MAX_X - 8.0 and at.z > Tune.FENCE_MIN_Z + 8.0 and at.z < Tune.FENCE_MAX_Z - 8.0:
			break
	at.x = clampf(at.x, Tune.FENCE_MIN_X + 8.0, Tune.FENCE_MAX_X - 8.0)
	at.z = clampf(at.z, Tune.FENCE_MIN_Z + 8.0, Tune.FENCE_MAX_Z - 8.0)
	at = host.on_ground(at)
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at)


func adopt_marker(marker: Node3D) -> void:
	super.adopt_marker(marker)
	_memory = global_position


func place_near(at: Vector3, facing: Vector3) -> void:
	super.place_near(at, facing)
	_memory = global_position


func _place() -> void:
	# Far out in the field, off the trail, somewhere ahead of the cabin.
	var start := trail.position_at(trail.player_start_offset) if trail else Vector3.ZERO
	var at := start
	for _attempt in 20:
		var angle := randf() * TAU
		at = start + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(55.0, 95.0)
		if at.x > Tune.FENCE_MIN_X + 8.0 and at.x < Tune.FENCE_MAX_X - 8.0 and at.z > Tune.FENCE_MIN_Z + 8.0 and at.z < Tune.FENCE_MAX_Z - 8.0:
			break
	at.x = clampf(at.x, Tune.FENCE_MIN_X + 8.0, Tune.FENCE_MAX_X - 8.0)
	at.z = clampf(at.z, Tune.FENCE_MIN_Z + 8.0, Tune.FENCE_MAX_Z - 8.0)
	at.y = trail.ground.height_at(at.x, at.z) if trail and trail.ground else 0.0
	position = at
	_memory = at
	rotation.y = randf() * TAU


func _build() -> void:
	if not ResourceLoader.exists(RIG):
		return
	var model := (load(RIG) as PackedScene).instantiate() as Node3D
	# Too tall and too thin. The rig faces +Z, the way it glides.
	model.scale = Vector3(0.62, 1.3, 0.62)
	add_child(model)
	# Dark grey-blue ice with a bright frosted rim: it has to read against
	# white snow at forty metres, or the rule cannot be learned.
	var frost := StandardMaterial3D.new()
	frost.albedo_color = Color(0.2, 0.24, 0.3)
	frost.roughness = 0.3
	frost.rim_enabled = true
	frost.rim = 1.0
	frost.rim_tint = 0.1
	frost.clearcoat_enabled = true
	frost.clearcoat = 0.6
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		(mesh_instance as MeshInstance3D).material_override = frost
	var animation := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation:
		# One held pose: arms hanging, nothing moving but the head.
		for clip in animation.get_animation_list():
			if clip.ends_with("Idle") or clip.ends_with("Idle_Talking"):
				animation.play(clip)
				animation.seek(0.0, true)
				animation.pause()
				break
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D
		# A neck that is too long, and a head stretched to match.
		var neck := _skeleton.find_bone("Neck")
		if neck >= 0:
			_skeleton.set_bone_pose_scale(neck, Vector3(0.75, 2.1, 0.75))
		_head = _skeleton.find_bone("Head")
		if _head >= 0:
			_skeleton.set_bone_pose_scale(_head, Vector3(0.7, 1.35, 0.8))
			_head_rest = _skeleton.get_bone_pose_rotation(_head)
	_shed()
	_crack = AudioStreamPlayer3D.new()
	_crack.bus = "Dread"
	_crack.stream = _sound("snap.wav")
	_crack.volume_db = 2.0
	_crack.unit_size = 8.0
	_crack.max_distance = 60.0
	add_child(_crack)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.bus = "Dread"
	var hiss := _sound("wind.wav")
	if hiss is AudioStreamWAV:
		hiss = (hiss as AudioStreamWAV).duplicate()
		(hiss as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_hiss.stream = hiss
	_hiss.pitch_scale = 2.1
	_hiss.volume_db = -6.0
	_hiss.unit_size = 5.0
	_hiss.max_distance = 45.0
	_hiss.position = Vector3(0, 2.2, 0)
	add_child(_hiss)


# Frost sheds off it as it moves and hangs in the air behind it.
func _shed() -> void:
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(0.18, 1.1, 0.14)
	motion.gravity = Vector3(0.0, -0.35, 0.0)
	motion.initial_velocity_min = 0.0
	motion.initial_velocity_max = 0.08
	motion.scale_min = 0.5
	motion.scale_max = 1.0
	var shed := GPUParticles3D.new()
	shed.amount = 40
	shed.lifetime = 3.0
	shed.local_coords = false
	shed.position = Vector3(0, 1.4, 0)
	shed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shed.visibility_aabb = AABB(Vector3(-4, -3, -4), Vector3(8, 6, 8))
	shed.process_material = motion
	var flake := QuadMesh.new()
	flake.size = Vector2(0.012, 0.012)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	white.albedo_color = Color(0.92, 0.95, 1.0)
	flake.material = white
	shed.draw_pass_1 = flake
	add_child(shed)


func _sound(file_name: String) -> AudioStream:
	var path := "res://assets/audio/" + file_name
	return load(path) as AudioStream if ResourceLoader.exists(path) else null


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
