class_name Footprints
extends Node3D

const POOL := 80
const LIFE := 20.0

var _quads: Array[MeshInstance3D] = []
var _ages: PackedFloat32Array
var _cursor := 0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_ages.resize(POOL)
	_ages.fill(LIFE)
	var shader := load("res://shaders/footprint.gdshader") as Shader
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	for i in POOL:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("fade", 0.0)
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.visible = false
		add_child(mesh_instance)
		_quads.append(mesh_instance)


func stamp(at: Vector3, yaw: float, heavy: bool, flip: bool) -> void:
	var mesh_instance := _quads[_cursor]
	var width := randf_range(0.13, 0.17)
	var length := randf_range(0.3, 0.38)
	if heavy:
		width *= 1.12
		length *= 1.18
	mesh_instance.position = at + Vector3(0.0, 0.045, 0.0)
	mesh_instance.rotation = Vector3(-PI * 0.5, yaw + randf_range(-0.18, 0.18), 0.0)
	mesh_instance.scale = Vector3(-width if flip else width, length, 1.0)
	mesh_instance.visible = true
	_ages[_cursor] = 0.0
	_set_fade(mesh_instance, 1.0)
	_cursor = (_cursor + 1) % POOL


func _process(delta: float) -> void:
	for i in POOL:
		if not _quads[i].visible:
			continue
		_ages[i] += delta
		var fade := clampf(1.0 - _ages[i] / LIFE, 0.0, 1.0)
		if fade <= 0.0:
			_quads[i].visible = false
			continue
		_set_fade(_quads[i], fade)


func _set_fade(mesh_instance: MeshInstance3D, fade: float) -> void:
	var material := mesh_instance.material_override as ShaderMaterial
	if material:
		material.set_shader_parameter("fade", fade)
