class_name SnowBranch
extends StaticBody3D

## A low pine branch loaded with snow (errands spec, verb 5). A press, or an
## arrow into it (receive_arrow), drops the snow in a puff with the woods' own
## flump; it loads up again after Tune.SNOW_BRANCH_REFILL seconds of her day.
## It is a small world collider above head height, so arrows find it and she
## walks under it. Saved by branch_id. `dropped` fires each time it lets go
## (a thread snag hidden in it shows then, red_thread).

signal dropped

const HEIGHT := 2.15

var branch_id := ""
var loaded := true
var _refill_at := 0.0
var _snow: MeshInstance3D
var _bough: MeshInstance3D


static func make(parent: Node3D, id: String, at: Vector3, yaw: float) -> SnowBranch:
	var branch := SnowBranch.new()
	branch.name = "Branch_" + id
	branch.branch_id = id
	parent.add_child(branch)
	branch.global_position = at
	branch.rotation.y = yaw
	branch._build()
	if Game.errands:
		Game.errands.register_state("branch:" + id, branch.state, branch.apply_state)
	return branch


func _ready() -> void:
	collision_layer = Tune.LAYER_WORLD
	collision_mask = 0
	add_to_group("interactables")


func _build() -> void:
	_bough = HouseKit.box(self, "Bough", Vector3(0.0, HEIGHT, 0.0), Vector3(1.4, 0.07, 0.5), HouseKit.paint(Color("2c3a2a"), 0.9))
	_snow = MeshInstance3D.new()
	_snow.name = "Snow"
	var lump := SphereMesh.new()
	lump.radius = 0.6
	lump.height = 0.32
	_snow.mesh = lump
	_snow.material_override = HouseKit.paint(Color(0.94, 0.96, 0.99), 0.95)
	_snow.position = Vector3(0.0, HEIGHT + 0.12, 0.0)
	add_child(_snow)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 0.4, 0.55)
	shape.shape = box
	shape.position = Vector3(0.0, HEIGHT + 0.08, 0.0)
	add_child(shape)


func _physics_process(_delta: float) -> void:
	if not loaded and Game.day_seconds >= _refill_at and Game.day_running:
		_set_loaded(true)


func interact_label() -> String:
	return "Knock the snow down"


func interact_point() -> Vector3:
	return global_position + Vector3.UP * HEIGHT


func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.7, HEIGHT - 0.1, -0.3), Vector3(1.4, 0.45, 0.6))]


func interact() -> bool:
	if ErrandKit.player() == null and Game.player != null:
		return false
	return knock()


## An arrow into the branch knocks the snow down too.
func receive_arrow(_at: Vector3, _velocity: Vector3) -> void:
	knock()


func knock() -> bool:
	if not loaded:
		return false
	_set_loaded(false)
	_refill_at = Game.day_seconds + Tune.SNOW_BRANCH_REFILL
	var at := global_position + Vector3.UP * HEIGHT
	_puff(at)
	if Game.wildlife:
		Game.wildlife.flump(at)
	else:
		ErrandKit.play(self, "snow_dump", Loudness.SNOW_DUMP)
	dropped.emit()
	return true


func _set_loaded(full: bool) -> void:
	loaded = full
	_snow.visible = full
	if full:
		add_to_group("interactables")
	else:
		remove_from_group("interactables")


# A short fall of powder under the branch, built in code like SnowKick.
func _puff(at: Vector3) -> void:
	var puff := CPUParticles3D.new()
	puff.name = "Puff"
	puff.one_shot = true
	puff.amount = 60 if not Game.lean_graphics else 30
	puff.lifetime = 1.3
	puff.explosiveness = 0.85
	puff.direction = Vector3.DOWN
	puff.spread = 35.0
	puff.initial_velocity_min = 0.4
	puff.initial_velocity_max = 1.4
	puff.gravity = Vector3(0.0, -3.0, 0.0)
	puff.scale_amount_min = 0.04
	puff.scale_amount_max = 0.1
	var flake := SphereMesh.new()
	flake.radius = 0.5
	flake.height = 1.0
	flake.radial_segments = 6
	flake.rings = 3
	flake.material = HouseKit.paint(Color(0.95, 0.97, 1.0), 1.0)
	puff.mesh = flake
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	puff.emission_box_extents = Vector3(0.6, 0.05, 0.25)
	puff.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(puff)
	puff.global_position = at
	puff.emitting = true
	puff.finished.connect(puff.queue_free)


func state() -> Variant:
	return {"loaded": loaded, "refill_at": _refill_at}


func apply_state(value: Variant) -> void:
	if value is Dictionary:
		_refill_at = float((value as Dictionary).get("refill_at", 0.0))
		_set_loaded(bool((value as Dictionary).get("loaded", true)))
