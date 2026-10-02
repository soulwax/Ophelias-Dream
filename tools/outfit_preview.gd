extends SceneTree

# Renders the dressed walker from a few angles into PNGs. Moving shots carry
# her forward at running speed so the cloth shows its drag.
#   godot --path . --resolution 800x900 -s tools/outfit_preview.gd -- <out_dir>

const RIG := "res://addons/quaternius_ik_rigged/Models_with_rigging/Female_Rigged.tscn"
const SETTLE := 50

# name, clip, camera yaw (deg, 0 = in front), speed m/s, camera distance, look height
var _shots: Array = [
	["front", "Idle_Talking", 0.0, 0.0, 3.6, 0.95],
	["back", "Idle_Talking", 180.0, 0.0, 3.6, 0.95],
	["three_quarter", "Idle_Talking", 35.0, 0.0, 3.2, 0.95],
	["face", "Idle_Talking", 20.0, 0.0, 1.1, 1.6],
	["feet", "Idle_Talking", 30.0, 0.0, 0.9, 0.1],
	["walk_side", "Walk_Formal", 90.0, 2.5, 3.6, 0.95],
	["sprint_side", "Sprint", 90.0, 6.8, 3.8, 0.95],
	["sprint_back", "Sprint", 160.0, 6.8, 3.8, 1.1],
]

var _out := "user://"
var _holder: Node3D
var _model: Node3D
var _camera: Camera3D
var _animation: AnimationPlayer
var _index := -1
var _wait := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_stage()


func _process(delta: float) -> bool:
	if _index >= 0 and _index < _shots.size():
		var shot: Array = _shots[_index]
		_holder.position.z += (shot[3] as float) * delta
		_aim(shot)
	if _wait > 0:
		_wait -= 1
		return false
	if _index >= 0:
		var path := _out.path_join("outfit_%s.png" % _shots[_index][0])
		root.get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	_index += 1
	if _index >= _shots.size():
		return true
	_holder.position = Vector3.ZERO
	_pose(_shots[_index][1], (_shots[_index][3] as float) > 0.0)
	_wait = SETTLE
	return false


func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.7, 0.76, 0.82)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.77, 0.84)
	env.environment.ambient_light_energy = 0.85
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.86, 0.9, 0.95)
	floor_mesh.material_override = snow
	root.add_child(floor_mesh)

	_holder = Node3D.new()
	root.add_child(_holder)
	_model = (load(RIG) as PackedScene).instantiate()
	_holder.add_child(_model)
	# Same base layer as Player._cloak (Player needs the Game autoload, absent under -s).
	var suit := StandardMaterial3D.new()
	suit.albedo_texture = load("res://assets/characters/girl_coat.png")
	suit.roughness = 0.9
	var brows := StandardMaterial3D.new()
	brows.albedo_color = Color(0.16, 0.09, 0.06)
	for mesh_instance in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_name := mesh_instance.name.to_lower()
		if "brow" in mesh_name:
			(mesh_instance as MeshInstance3D).material_override = brows
		elif not "eye" in mesh_name:
			(mesh_instance as MeshInstance3D).material_override = suit
	var outfit := Outfit.dress(_model)
	if outfit:
		var breath := Breath.new()
		breath.strain = 0.9
		outfit.attach("Head", breath, Transform3D(Basis(), outfit.mouth_rest))
	_animation = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_camera = Camera3D.new()
	_camera.fov = 40.0
	root.add_child(_camera)
	_camera.current = true


func _aim(shot: Array) -> void:
	var yaw: float = deg_to_rad(shot[2])
	var distance: float = shot[4]
	var look := _holder.position + Vector3(0, shot[5] as float, 0)
	_camera.position = look + Vector3(sin(yaw) * distance, 0.15, cos(yaw) * distance)
	_camera.look_at(look, Vector3.UP)


func _pose(clip: String, moving: bool) -> void:
	if _animation == null:
		return
	for name in _animation.get_animation_list():
		if name == clip or name.ends_with("/" + clip):
			var animation := _animation.get_animation(name)
			animation.loop_mode = Animation.LOOP_LINEAR
			_animation.play(name, 0.0)
			if not moving:
				_animation.seek(animation.length * 0.6, true)
				_animation.pause()
			return
