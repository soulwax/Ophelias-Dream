class_name Footprints
extends Node3D

const POOL := 96
const HOLD := 14.0
const FADE := 18.0
# Her own prints before the snow is allowed to be wrong, once, behind her.
const LIE_AFTER := 10

enum Mark { HERS, SOLE, BERM, PAIR }

var _quads: Array[MeshInstance3D] = []
var _ages: PackedFloat32Array
var _cursor := 0
var _hers: Array[Vector3] = []
var _lied := false


func _ready() -> void:
	top_level = true
	# Prints are pooled and jump to each new step; never interpolate the jump.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	global_transform = Transform3D.IDENTITY
	_ages.resize(POOL)
	_ages.fill(HOLD + FADE)
	var shader := load("res://shaders/footprint.gdshader") as Shader
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	# Enough verts for the sole to sink and the berm to rise.
	quad.subdivide_width = 16
	quad.subdivide_depth = 24
	for i in POOL:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("fade", 0.0)
		material.set_shader_parameter("press", 0.7)
		material.set_shader_parameter("mark", 0.0)
		material.render_priority = 2
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.extra_cull_margin = 0.2
		mesh_instance.visible = false
		add_child(mesh_instance)
		_quads.append(mesh_instance)


func stamp(at: Vector3, yaw: float, heavy: bool, flip: bool, mark: Mark = Mark.HERS) -> void:
	if mark == Mark.PAIR:
		# Both boots planted, not a stride apart. That count is not hers.
		var side := Vector3(cos(yaw), 0.0, -sin(yaw))
		_lay(at + side * 0.11, yaw, heavy, false, Mark.HERS, false)
		_lay(at - side * 0.11, yaw, heavy, true, Mark.HERS, false)
		return
	_lay(at, yaw, heavy, flip, mark, mark == Mark.HERS)


func _lay(at: Vector3, yaw: float, heavy: bool, flip: bool, mark: Mark, remember: bool) -> void:
	var mesh_instance := _quads[_cursor]
	var width := randf_range(0.11, 0.125)
	var length := randf_range(0.30, 0.34)
	var press := 0.62
	if heavy:
		width *= 1.06
		length *= 1.04
		press = 0.92
	if mark == Mark.HERS:
		yaw += randf_range(-0.06, 0.06)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(forward.z, 0.0, -forward.x)
	var normal := Vector3.UP
	# Clear of the deepest part of the sole, so the bowl sits in the snow
	# and the berm is what rises out of it.
	var lift := 0.026
	var planted := Vector3(at.x, at.y + lift, at.z)
	if Game.trail != null and Game.trail.ground != null:
		var ground: Ground = Game.trail.ground
		planted.y = ground.height_at(at.x, at.z) + lift
		var hx := ground.height_at(at.x + 0.3, at.z) - ground.height_at(at.x - 0.3, at.z)
		var hz := ground.height_at(at.x, at.z + 0.3) - ground.height_at(at.x, at.z - 0.3)
		normal = Vector3(-hx, 0.6, -hz).normalized()
		forward = (forward - normal * forward.dot(normal)).normalized()
		right = normal.cross(forward).normalized()
	var basis := Basis()
	basis.x = right * (-width if flip else width)
	basis.y = forward * length
	basis.z = normal
	# A newer print sits a hair above an older one, so two steps do not fight.
	planted.y += float(_cursor) * 0.00025
	mesh_instance.transform = Transform3D(basis, planted - forward * 0.02)
	mesh_instance.visible = true
	_ages[_cursor] = 0.0
	var material := mesh_instance.material_override as ShaderMaterial
	var shader_mark := 0.0
	if mark == Mark.SOLE:
		shader_mark = 1.0
	elif mark == Mark.BERM:
		shader_mark = 2.0
	if material:
		material.set_shader_parameter("fade", 1.0)
		material.set_shader_parameter("press", press)
		material.set_shader_parameter("mark", shader_mark)
		material.set_shader_parameter("span", Vector2(width, length))
	if remember:
		_hers.append(Vector3(at.x, 0.0, at.z))
		if _hers.size() > 24:
			_hers.pop_front()
	_cursor = (_cursor + 1) % POOL


func _process(delta: float) -> void:
	_lie_once()
	for i in POOL:
		if not _quads[i].visible:
			continue
		_ages[i] += delta
		var fade := 1.0 if _ages[i] < HOLD else clampf(1.0 - (_ages[i] - HOLD) / FADE, 0.0, 1.0)
		if fade <= 0.0:
			_quads[i].visible = false
			continue
		_set_fade(_quads[i], fade)


# Once she has left a stretch behind her, one mark in it is not her stride.
func _lie_once() -> void:
	if _lied or _hers.size() < LIE_AFTER:
		return
	if Game.phase != Game.Phase.PLAYING or Game.player == null:
		return
	if Game.indoors(Game.player.global_position):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var look := -camera.global_basis.z
	look.y = 0.0
	if look.length_squared() < 0.0001:
		return
	look = look.normalized()
	for at in _hers:
		var to := at - camera.global_position
		to.y = 0.0
		var reach := to.length()
		if reach < 5.0 or reach > 16.0:
			continue
		if to.normalized().dot(look) > -0.2:
			continue
		var side := Vector3(look.z, 0.0, -look.x)
		stamp(Vector3(at.x, 0.0, at.z) + side * 0.55, atan2(side.x, side.z), false, false, Mark.PAIR)
		_lied = true
		return


func _set_fade(mesh_instance: MeshInstance3D, fade: float) -> void:
	var material := mesh_instance.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("fade", fade)
