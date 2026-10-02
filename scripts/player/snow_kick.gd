class_name SnowKick
extends Node

# Powder thrown up by her boots: a small pool of one-shot bursts, reused
# round-robin. A sprint stride kicks a real spray; a walk barely dusts.

const POOL := 8

var _bursts: Array[GPUParticles3D] = []
var _cursor := 0


func _ready() -> void:
	var cloud := _cloud()
	for i in POOL:
		var motion := ParticleProcessMaterial.new()
		motion.direction = Vector3(0.0, 1.0, 0.0)
		motion.spread = 55.0
		motion.initial_velocity_min = 0.3
		motion.initial_velocity_max = 1.0
		motion.gravity = Vector3(0.0, -2.4, 0.0)
		motion.damping_min = 1.2
		motion.damping_max = 2.0
		motion.scale_min = 0.6
		motion.scale_max = 1.3
		var grow := Curve.new()
		grow.add_point(Vector2(0.0, 0.4))
		grow.add_point(Vector2(1.0, 1.0))
		var grow_texture := CurveTexture.new()
		grow_texture.curve = grow
		motion.scale_curve = grow_texture
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0.75))
		fade.set_color(1, Color(1, 1, 1, 0.0))
		var fade_texture := GradientTexture1D.new()
		fade_texture.gradient = fade
		motion.color_ramp = fade_texture
		var burst := GPUParticles3D.new()
		burst.amount = 14
		burst.lifetime = 0.8
		burst.one_shot = true
		burst.explosiveness = 0.92
		burst.local_coords = false
		burst.emitting = false
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		burst.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4))
		burst.process_material = motion
		burst.draw_pass_1 = cloud
		add_child(burst)
		_bursts.append(burst)


# power 0..1: how hard the boot came down. drift tilts the spray; pass the
# direction behind her so a running stride flings it backward.
func kick(at: Vector3, power: float, drift: Vector3) -> void:
	if _bursts.is_empty():
		return
	var burst := _bursts[_cursor]
	_cursor = (_cursor + 1) % _bursts.size()
	var motion := burst.process_material as ParticleProcessMaterial
	motion.initial_velocity_min = lerpf(0.15, 0.6, power)
	motion.initial_velocity_max = lerpf(0.4, 1.6, power)
	motion.direction = (Vector3.UP + drift * 0.35).normalized()
	burst.amount_ratio = lerpf(0.3, 1.0, power)
	burst.global_position = at
	burst.restart()


func _cloud() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var soft := GradientTexture2D.new()
	soft.gradient = gradient
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 32
	soft.height = 32
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = soft
	material.albedo_color = Color(0.95, 0.97, 1.0)
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = material
	return quad
