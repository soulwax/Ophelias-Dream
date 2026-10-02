class_name Footprints
extends Node3D

const POOL := 96
const HOLD := 14.0
const FADE := 18.0

var _quads: Array[MeshInstance3D] = []
var _ages: PackedFloat32Array
var _cursor := 0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_ages.resize(POOL)
	_ages.fill(HOLD + FADE)
	var shader := load("res://shaders/footprint.gdshader") as Shader
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	for i in POOL:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("fade", 0.0)
		material.set_shader_parameter("press", 0.7)
		material.render_priority = 2
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.visible = false
		add_child(mesh_instance)
		_quads.append(mesh_instance)


func stamp(at: Vector3, yaw: float, heavy: bool, flip: bool) -> void:
	var mesh_instance := _quads[_cursor]
	var width := randf_range(0.11, 0.125)
	var length := randf_range(0.30, 0.34)
	var press := 0.62
	if heavy:
		width *= 1.06
		length *= 1.04
		press = 0.92
	yaw += randf_range(-0.06, 0.06)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(forward.z, 0.0, -forward.x)
	var normal := Vector3.UP
	var planted := Vector3(at.x, at.y + 0.018, at.z)
	if Game.trail != null and Game.trail.ground != null:
		var ground: Ground = Game.trail.ground
		planted.y = ground.height_at(at.x, at.z) + 0.012
		var hx := ground.height_at(at.x + 0.3, at.z) - ground.height_at(at.x - 0.3, at.z)
		var hz := ground.height_at(at.x, at.z + 0.3) - ground.height_at(at.x, at.z - 0.3)
		normal = Vector3(-hx, 0.6, -hz).normalized()
		forward = (forward - normal * forward.dot(normal)).normalized()
		right = normal.cross(forward).normalized()
	var basis := Basis()
	basis.x = right * (-width if flip else width)
	basis.y = forward * length
	basis.z = normal
	mesh_instance.transform = Transform3D(basis, planted - forward * 0.02)
	mesh_instance.visible = true
	_ages[_cursor] = 0.0
	var material := mesh_instance.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("fade", 1.0)
		material.set_shader_parameter("press", press)
	_cursor = (_cursor + 1) % POOL


func _process(delta: float) -> void:
	for i in POOL:
		if not _quads[i].visible:
			continue
		_ages[i] += delta
		var fade := 1.0 if _ages[i] < HOLD else clampf(1.0 - (_ages[i] - HOLD) / FADE, 0.0, 1.0)
		if fade <= 0.0:
			_quads[i].visible = false
			continue
		_set_fade(_quads[i], fade)


func _set_fade(mesh_instance: MeshInstance3D, fade: float) -> void:
	var material := mesh_instance.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("fade", fade)
