class_name HouseDoor
extends Node3D

## A hinged door you open with E. The node sits at the bottom centre of its
## opening; the leaf swings on a pivot at the hinge edge, carrying its own
## collision, driven by merl's DoorHingeDynamics so it cannot swing through
## walls or props. Styles: "plank" (timber, ledged), "steel" (flush stainless,
## wired-glass vision panel, kick plates) and "chamber" (a cold-chamber door).

var label := "Door"
var _pivot: Node3D
var _leaf: Node3D
var _body: StaticBody3D
var _shape: CollisionShape3D
var _motion := DoorHingeDynamics.new()
var _audio: Dictionary = {}
var _open := false
var _was_moving := false
var _was_blocked := false
var _size := Vector3.ONE
var _handle_at := Vector3.ZERO
var _hinge := -1.0
var _swing_angle := 0.0
var _one_sided := false
var _handles: Array[Node3D] = []
var _handle_tweens: Array[Tween] = []


## size: width, height, thickness. hinge: -1 hinges on local -X, +1 on +X.
## swing: open angle in degrees, positive swings the leaf toward local -Z.
static func make(parent: Node3D, name: String, at: Vector3, yaw: float, size: Vector3, style: String, material: Material, hinge: float = -1.0, swing: float = 95.0, door_label: String = "Door") -> HouseDoor:
	var door := HouseDoor.new()
	door.name = name
	door.label = door_label
	door.position = at
	door.rotation.y = yaw
	parent.add_child(door)
	door._build(size, style, material, hinge, swing)
	return door


func interact_label() -> String:
	if not _open and blocked_label() != "":
		return blocked_label()
	return ("Close the " if _open else "Open the ") + label.to_lower()


func interact_point() -> Vector3:
	return to_global(_handle_at)


## The leaf, a little thicker than it is, wherever it has swung to.
func aim_box() -> Array:
	var bounds := AABB(Vector3(-_size.x * 0.5, -_size.y * 0.5, -0.06), Vector3(_size.x, _size.y, 0.12))
	if _leaf == null:
		return [global_transform.translated_local(Vector3(0.0, _size.y * 0.5, 0.0)), bounds]
	return [_leaf.global_transform, bounds]


func interact() -> bool:
	if not _open and not _aim_open_away_from_player():
		return false
	_open = not _open
	_motion.request(_open)
	_press_handle()
	_play("handle")
	return true


var is_open: bool:
	get:
		return _open


## The house moves it: slowly, no hand on the handle, a long creak.
func drift(open: bool, creak: AudioStream = null) -> void:
	if open == _open:
		return
	if open and not _aim_open_away_from_player():
		return
	_open = open
	_motion.request(open, 0.22)
	var player := _audio.get("creak") as AudioStreamPlayer3D
	if player and creak:
		player.stream = creak
	_was_moving = true
	if player and player.stream:
		Loudness.sound(player, Loudness.DOOR_DRIFT)
		player.play()


func _ready() -> void:
	add_to_group("interactables")


func _physics_process(delta: float) -> void:
	if _pivot == null:
		return
	var before := _motion.angle
	_motion.step(delta, _pivot, _body, _shape)
	if _motion.blocked and not _was_blocked and _motion.pace > 0.9:
		Game.interaction_feedback.emit("Door is blocked", false)
	_was_blocked = _motion.blocked
	var moving := absf(_motion.angle - before) > 0.0005
	if moving and not _was_moving:
		_play("creak")
	if not moving and _was_moving and not _open and absf(_motion.angle) < 0.01:
		_play("latch")
	_was_moving = moving


func _build(size: Vector3, style: String, material: Material, hinge: float, swing: float) -> void:
	_size = size
	_hinge = hinge
	_swing_angle = absf(deg_to_rad(swing))
	_one_sided = style == "chamber"
	_pivot = Node3D.new()
	_pivot.name = "HingePivot"
	_pivot.position = Vector3(hinge * size.x * 0.5, 0.0, 0.0)
	add_child(_pivot)
	var leaf := Node3D.new()
	leaf.name = "Leaf"
	leaf.position = Vector3(-hinge * size.x * 0.5, size.y * 0.5, 0.0)
	_pivot.add_child(leaf)
	_leaf = leaf
	match style:
		"steel":
			_steel_leaf(leaf, size, hinge)
		"chamber":
			_chamber_leaf(leaf, size, hinge)
		_:
			_plank_leaf(leaf, size, hinge, material)
	_body = StaticBody3D.new()
	_body.name = "LeafBody"
	_body.collision_layer = Tune.LAYER_WORLD
	_body.collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x - 0.01, size.y - 0.01, size.z)
	_shape.shape = box
	_body.add_child(_shape)
	leaf.add_child(_body)
	# Positive swing turns the free edge toward -Z.
	_motion.configure(_swing_angle * -hinge)
	_handle_at = Vector3(-hinge * size.x * 0.36, minf(1.0, size.y * 0.5), 0.0)
	_audio = DoorAudio.add_cues(self, "steel" if style != "plank" else ("front" if size.x > 0.95 else "light"), _handle_at)


func _aim_open_away_from_player() -> bool:
	if blocked_label() != "":
		return false
	# Pick a side only while shut; changing the stop mid-swing would snap the leaf.
	if not _one_sided and Game.player and absf(_motion.angle) <= 0.002:
		_motion.open_rotation = _away_angle()
	return true


func blocked_label() -> String:
	if _one_sided or Game.player == null:
		return ""
	if absf(to_local(Game.player.global_position).z) < 0.05:
		return "Step clear of the door"
	if absf(_motion.angle) > 0.002 and _motion.angle * _away_angle() < 0.0:
		return "Let the door close first"
	return ""


func _away_angle() -> float:
	var player_z := to_local(Game.player.global_position).z
	return _swing_angle * _hinge * (-1.0 if player_z > 0.0 else 1.0)


func _press_handle() -> void:
	for tween in _handle_tweens:
		if tween and tween.is_running():
			tween.kill()
	_handle_tweens.clear()
	for handle in _handles:
		var tween := create_tween()
		tween.tween_property(handle, "rotation:z", -_hinge * 0.32, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(handle, "rotation:z", 0.0, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_handle_tweens.append(tween)


func _play(cue: String) -> void:
	var player := _audio.get(cue) as AudioStreamPlayer3D
	if player and player.stream:
		Loudness.sound(player, DoorAudio.LEVELS.get(cue, Loudness.DOOR_CREAK))
		player.play()


func _plank_leaf(leaf: Node3D, size: Vector3, hinge: float, material: Material) -> void:
	var timber: Material = material if material else HouseKit.paint(Color("5b3d27"), 0.8)
	var dark := HouseKit.paint(Color("2a1c12"), 0.85)
	HouseKit.box(leaf, "Boards", Vector3.ZERO, Vector3(size.x - 0.01, size.y - 0.01, size.z), timber)
	# Ledges and a brace on the back, vertical board joints on the front.
	for y in [-size.y * 0.33, 0.0, size.y * 0.33]:
		HouseKit.box(leaf, "Ledge_%d" % int(y * 10.0), Vector3(0.0, y, -size.z * 0.5 - 0.012), Vector3(size.x - 0.08, 0.1, 0.024), timber)
	for joint in range(1, 5):
		var x := -size.x * 0.5 + size.x * float(joint) / 5.0
		HouseKit.box(leaf, "Joint_%d" % joint, Vector3(x, 0.0, size.z * 0.5 + 0.001), Vector3(0.008, size.y - 0.04, 0.004), dark)
	_lever(leaf, size, hinge, HouseKit.paint(Color("2b2b2b"), 0.4, 0.8))


func _steel_leaf(leaf: Node3D, size: Vector3, hinge: float) -> void:
	# Ported from merl's _build_steel_leaf.
	var steel := HouseKit.paint(Color("a7abae"), 0.32, 0.9)
	var brushed := HouseKit.paint(Color("8e9296"), 0.45, 0.85)
	var window := Vector2(0.26, 0.4)
	var window_y := -size.y * 0.5 + 1.55
	var bottom := window_y - window.y * 0.5
	var top := window_y + window.y * 0.5
	HouseKit.box(leaf, "PanelLower", Vector3(0.0, (-size.y * 0.5 + bottom) * 0.5, 0.0), Vector3(size.x, bottom + size.y * 0.5, size.z), steel)
	HouseKit.box(leaf, "PanelUpper", Vector3(0.0, (top + size.y * 0.5) * 0.5, 0.0), Vector3(size.x, size.y * 0.5 - top, size.z), steel)
	var side := (size.x - window.x) * 0.5
	for s in [-1.0, 1.0]:
		HouseKit.box(leaf, "PanelBeside_%d" % int(s), Vector3(s * (window.x + side) * 0.5, window_y, 0.0), Vector3(side, window.y, size.z), steel)
	var wired := HouseKit.paint(Color(0.55, 0.62, 0.62, 0.55), 0.2)
	wired.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	HouseKit.box(leaf, "VisionPanel", Vector3(0.0, window_y, 0.0), Vector3(window.x + 0.01, window.y + 0.01, 0.01), wired)
	for face in [-1.0, 1.0]:
		HouseKit.box(leaf, "KickPlate_%d" % int(face), Vector3(0.0, -size.y * 0.5 + 0.15, face * (size.z * 0.5 + 0.002)), Vector3(size.x - 0.08, 0.25, 0.004), brushed)
	_lever(leaf, size, hinge, steel)


func _chamber_leaf(leaf: Node3D, size: Vector3, hinge: float) -> void:
	# Ported from merl's _add_cold_chamber_door.
	var steel := HouseKit.paint(Color("a7abae"), 0.32, 0.9)
	HouseKit.box(leaf, "Panel", Vector3.ZERO, Vector3(size.x - 0.01, size.y - 0.01, size.z), steel)
	HouseKit.box(leaf, "Gasket", Vector3(0.0, 0.0, -size.z * 0.5 - 0.005), Vector3(size.x - 0.03, size.y - 0.03, 0.01), HouseKit.paint(Color("111214"), 0.8))
	HouseKit.box(leaf, "LatchBase", Vector3(-hinge * size.x * 0.36, 0.0, size.z * 0.5 + 0.01), Vector3(0.05, 0.16, 0.02), steel)
	HouseKit.box(leaf, "LatchHandle", Vector3(-hinge * size.x * 0.36, 0.0, size.z * 0.5 + 0.04), Vector3(0.035, 0.24, 0.035), steel)
	HouseKit.box(leaf, "CardHolder", Vector3(hinge * size.x * 0.12, size.y * 0.3, size.z * 0.5 + 0.005), Vector3(0.16, 0.08, 0.008), HouseKit.paint(Color("d8d6cf"), 0.8))


func _lever(leaf: Node3D, size: Vector3, hinge: float, metal: Material) -> void:
	var x := -hinge * (size.x * 0.5 - 0.09)
	var y := -size.y * 0.5 + 1.0
	for face in [-1.0, 1.0]:
		var z: float = float(face) * (size.z * 0.5 + 0.03)
		HouseKit.box(leaf, "Rose_%d" % int(face), Vector3(x, y, face * (size.z * 0.5 + 0.006)), Vector3(0.06, 0.06, 0.012), metal)
		var handle := HouseKit.box(leaf, "Lever_%d" % int(face), Vector3(x + hinge * 0.055, y, z), Vector3(0.12, 0.022, 0.022), metal)
		_handles.append(handle)
