class_name Breath
extends Node3D

# Frosted breath at the mouth. strain (0 calm .. 1 gasping) sets the rhythm:
# a slow breath at rest, short hard puffs when spent. The steam is only the
# out-breath. It leaves as a jet, then turbulence tears it apart and it is
# gone in well under a second. The puffs live in world space, so they hang
# behind her when she runs.

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
	_motion.direction = Vector3(0.0, 0.05, 1.0)
	_motion.spread = 22.0
	_motion.flatness = 0.35
	_motion.gravity = Vector3(0.0, 0.35, 0.0)
	_motion.damping_min = 1.6
	_motion.damping_max = 2.8
	_motion.radial_velocity_min = 0.15
	_motion.radial_velocity_max = 0.55
	_motion.angular_velocity_min = -4.0
	_motion.angular_velocity_max = 4.0
	_motion.turbulence_enabled = true
	_motion.turbulence_noise_strength = 1.4
	_motion.turbulence_noise_scale = 1.6
	_motion.turbulence_noise_speed = Vector3(0.4, 0.8, 0.3)
	_motion.turbulence_noise_speed_random = 1.2
	_motion.turbulence_influence_min = 0.15
	_motion.turbulence_influence_max = 0.85
	_motion.angle_min = -180.0
	_motion.angle_max = 180.0
	_motion.scale_min = 0.45
	_motion.scale_max = 0.85
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.25))
	grow.add_point(Vector2(0.18, 0.7))
	grow.add_point(Vector2(0.45, 1.15))
	grow.add_point(Vector2(1.0, 1.6))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	_motion.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.06, Color(0.98, 0.99, 1.0, 0.55))
	fade.add_point(0.22, Color(0.96, 0.98, 1.0, 0.22))
	fade.add_point(0.48, Color(0.94, 0.97, 1.0, 0.04))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	_motion.color_ramp = fade_texture

	_puff = GPUParticles3D.new()
	_puff.name = "Steam"
	_puff.amount = 72
	_puff.lifetime = 0.62
	_puff.explosiveness = 0.35
	_puff.randomness = 0.65
	_puff.local_coords = false
	_puff.amount_ratio = 0.0
	_puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puff.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	_puff.process_material = _motion
	_puff.draw_pass_1 = _cloud()
	add_child(_puff)


## How full her lungs are, 0 emptied .. 1 full. The in-breath is the longer,
## easing rise. The out-breath drops sooner and a little faster, and she
## stays full while she holds it.
func fullness() -> float:
	if held:
		return 1.0
	if _burst_left > 0.0:
		return 0.12
	if _phase < 0.58:
		return smoothstep(0.0, 0.58, _phase)
	return 1.0 - smoothstep(0.58, 0.92, _phase)


# The breath she was holding comes out at once: a big, fast cloud.
func gasp(power: float) -> void:
	_burst_left = lerpf(0.35, 0.8, clampf(power, 0.0, 1.0))
	_phase = 0.5


func _process(delta: float) -> void:
	var effort := clampf(strain, 0.0, 1.0)
	var out := 0.0
	var push := lerpf(0.55, 1.15, effort)
	if _burst_left > 0.0:
		_burst_left -= delta
		out = clampf(_burst_left / 0.35, 0.0, 1.0)
		push = 1.6
	elif not held:
		var rate := lerpf(CALM_RATE, GASP_RATE, pow(effort, 0.8))
		_phase = fposmod(_phase + rate * delta, 1.0)
		# Steam is the front of the out-breath. It thins as the lungs empty
		# instead of pouring for the whole exhale.
		var exhale := lerpf(0.28, 0.16, effort)
		var along := (_phase - 0.58) / exhale
		if along >= 0.0 and along < 1.0:
			out = pow(1.0 - along, 1.7)
	_puff.amount_ratio = out
	_motion.initial_velocity_min = push * 0.45
	_motion.initial_velocity_max = push
	_motion.spread = lerpf(18.0, 42.0, effort) + (1.0 - out) * 10.0
	_motion.turbulence_noise_strength = lerpf(1.1, 2.4, effort)
	# The cloud is gone about as fast as the puffs shred.
	var target := 0.0
	if out > 0.05:
		target = out * lerpf(0.35, 1.05, effort)
	plume = move_toward(plume, target, delta * (6.0 if target > plume else 3.2))


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
