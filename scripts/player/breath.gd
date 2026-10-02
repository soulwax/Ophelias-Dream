class_name Breath
extends Node3D

# Frosted breath at the mouth. strain (0 calm .. 1 gasping) sets the rhythm:
# a slow cloud every few seconds at rest, short hard puffs when spent. The
# puffs live in world space, so they hang behind her when she runs.

const CALM_RATE := 0.24
const GASP_RATE := 1.45

var strain := 0.0
# Holding her breath: no steam at all until she lets go.
var held := false
# How much visible breath hangs in the air right now, 0..~1.4. This is what
# the Listener perceives.
var plume := 0.0

var _phase := 0.35
var _burst_left := 0.0
var _puff: GPUParticles3D
var _motion: ParticleProcessMaterial


func _ready() -> void:
	_motion = ParticleProcessMaterial.new()
	_motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_motion.emission_sphere_radius = 0.008
	_motion.direction = Vector3(0.0, -0.25, 1.0)
	_motion.spread = 16.0
	_motion.gravity = Vector3(0.0, 0.07, 0.0)
	_motion.damping_min = 0.9
	_motion.damping_max = 1.4
	_motion.angle_min = -180.0
	_motion.angle_max = 180.0
	_motion.scale_min = 1.1
	_motion.scale_max = 1.7
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.15))
	grow.add_point(Vector2(0.35, 0.5))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	_motion.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.12, Color(0.97, 0.98, 1.0, 0.42))
	fade.add_point(0.5, Color(0.95, 0.97, 1.0, 0.2))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	_motion.color_ramp = fade_texture

	_puff = GPUParticles3D.new()
	_puff.name = "Steam"
	_puff.amount = 48
	_puff.lifetime = 1.6
	_puff.local_coords = false
	_puff.amount_ratio = 0.0
	_puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puff.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	_puff.process_material = _motion
	_puff.draw_pass_1 = _cloud()
	add_child(_puff)


# The breath she was holding comes out at once: a big, fast cloud.
func gasp(power: float) -> void:
	_burst_left = lerpf(0.35, 0.8, clampf(power, 0.0, 1.0))
	_phase = 0.5


func _process(delta: float) -> void:
	var effort := clampf(strain, 0.0, 1.0)
	var out := false
	var push := lerpf(0.32, 0.85, effort)
	if _burst_left > 0.0:
		_burst_left -= delta
		out = true
		push = 1.25
	elif not held:
		var rate := lerpf(CALM_RATE, GASP_RATE, pow(effort, 0.8))
		_phase = fposmod(_phase + rate * delta, 1.0)
		# Out-breath is the second part of the cycle; panting shortens it.
		var exhale := lerpf(0.42, 0.3, effort)
		out = _phase > 0.5 and _phase < 0.5 + exhale
	_puff.amount_ratio = 1.0 if out else 0.0
	_motion.initial_velocity_min = push * 0.7
	_motion.initial_velocity_max = push
	# The cloud lingers about as long as the puffs live.
	var target := 0.0
	if out:
		target = lerpf(0.3, 1.0, effort) + (0.4 if _burst_left > 0.0 else 0.0)
	plume = move_toward(plume, target, delta * (3.0 if target > plume else 0.65))


func _cloud() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.11)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var soft := GradientTexture2D.new()
	soft.gradient = gradient
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 64
	soft.height = 64
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = soft
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = material
	return quad
