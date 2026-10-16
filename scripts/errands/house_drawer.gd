class_name HouseDrawer
extends Node3D

signal opened

## A cupboard or drawer (errands spec, verb 4: open and look inside). A press
## opens it on a hinge (the door swings about its left edge) or a slide (the
## front pulls out along local +Z); a press closes it. Whatever is put inside
## with hold() is only seen, picked and taken while it stands open.
## Local frame: +Z is its front, y 0 its foot. Saved by drawer_id.

var drawer_id := ""
var noun := "cupboard"
var slide := false
var size := Vector3(0.6, 0.8, 0.4)
var is_open := false
var _front: Node3D
var _held: Array[Node3D] = []
var _tween: Tween


static func make(parent: Node3D, id: String, at: Transform3D, cupboard_size: Vector3, slides := false, label_noun := "cupboard") -> HouseDrawer:
	var drawer := HouseDrawer.new()
	drawer.name = "Drawer_" + id
	drawer.drawer_id = id
	drawer.size = cupboard_size
	drawer.slide = slides
	drawer.noun = label_noun
	parent.add_child(drawer)
	drawer.global_transform = at
	drawer._build()
	if Game.errands:
		Game.errands.register_state("drawer:" + id, drawer.state, drawer.apply_state)
	return drawer


func _ready() -> void:
	add_to_group("interactables")


func _build() -> void:
	var wood := HouseKit.paint(Color("6b4e36"), 0.75)
	var inside := HouseKit.paint(Color("2a2019"), 0.9)
	# The carcass: back, sides, top and bottom, open at the front.
	var t := 0.025
	HouseKit.solid(self, "Back", Vector3(0.0, size.y * 0.5, -size.z * 0.5 + t * 0.5), Vector3(size.x, size.y, t), inside)
	HouseKit.solid(self, "Left", Vector3(-size.x * 0.5 + t * 0.5, size.y * 0.5, 0.0), Vector3(t, size.y, size.z), wood)
	HouseKit.solid(self, "Right", Vector3(size.x * 0.5 - t * 0.5, size.y * 0.5, 0.0), Vector3(t, size.y, size.z), wood)
	HouseKit.solid(self, "Top", Vector3(0.0, size.y - t * 0.5, 0.0), Vector3(size.x, t, size.z), wood)
	HouseKit.solid(self, "Bottom", Vector3(0.0, t * 0.5, 0.0), Vector3(size.x, t, size.z), wood)
	# The front: a door hinged at the left edge, or a drawer front.
	_front = Node3D.new()
	_front.name = "Front"
	add_child(_front)
	if slide:
		_front.position = Vector3(0.0, 0.0, size.z * 0.5)
		HouseKit.box(_front, "Panel", Vector3(0.0, size.y * 0.5, -t * 0.5), Vector3(size.x - 0.01, size.y - 0.01, t), wood)
	else:
		_front.position = Vector3(-size.x * 0.5, 0.0, size.z * 0.5)
		HouseKit.box(_front, "Panel", Vector3(size.x * 0.5, size.y * 0.5, -t * 0.5), Vector3(size.x - 0.01, size.y - 0.01, t), wood)
		HouseKit.box(_front, "Knob", Vector3(size.x - 0.06, size.y * 0.5, 0.01), Vector3(0.025, 0.025, 0.025), HouseKit.paint(Color("2b2b2b"), 0.4, 0.6))


## Puts a thing inside (a cup, the oil tin): it shows and can be taken only while open.
func hold(thing: Node3D, local_at: Vector3) -> void:
	_held.append(thing)
	thing.global_position = to_global(local_at)
	_show_contents()


func interact_label() -> String:
	return ("Close the " if is_open else "Open the ") + noun


func interact_point() -> Vector3:
	return _front.global_position + global_basis.y * size.y * 0.5


## The front panel wherever it has swung or slid to, like HouseDoor's leaf, so
## what stands inside an open cupboard can still be aimed at.
func aim_box() -> Array:
	var centre := Vector3(0.0 if slide else size.x * 0.5, size.y * 0.5, -0.0125)
	return [_front.global_transform, AABB(centre - Vector3(size.x, size.y, 0.06) * 0.5, Vector3(size.x, size.y, 0.06))]


func interact() -> bool:
	if ErrandKit.player() == null and Game.player != null:
		return false
	_set_open(not is_open, true)
	if is_open:
		opened.emit()
	return true


## Once taken, closing this cupboard must never hide the item again, even
## after she drops it elsewhere. Save owners call this before restoring it.
func release(thing: Node3D) -> void:
	_held.erase(thing)
	thing.show()


func _set_open(open: bool, animate: bool) -> void:
	is_open = open
	var to_rotation := -1.75 if open and not slide else 0.0
	var to_z := size.z * 0.5 + (size.z * 0.7 if open and slide else 0.0)
	if _tween and _tween.is_running():
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(_front, "rotation:y", to_rotation, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_front, "position:z", to_z, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ErrandKit.play(self, "cupboard_open" if open else "cupboard_close", Loudness.CUPBOARD)
	else:
		_front.rotation.y = to_rotation
		_front.position.z = to_z
	_show_contents()


func _show_contents() -> void:
	for thing in _held:
		if is_instance_valid(thing):
			# A thing someone took out is hers now, not the cupboard's.
			if thing is Carryable and ((thing as Carryable).carrier != null or (thing as Carryable).socket != null):
				continue
			thing.visible = is_open
	_held = _held.filter(func(thing: Node3D) -> bool: return is_instance_valid(thing) and not (thing is Carryable and ((thing as Carryable).carrier != null or (thing as Carryable).socket != null)))


func state() -> Variant:
	return is_open


func apply_state(value: Variant) -> void:
	_set_open(bool(value), false)
