class_name Brushable
extends Node3D

## Snow lying on something (a sign, a post, the bench): hold interact to brush it
## off (errands spec, verb 3). Once brushed it stays clean, saved by brush_id,
## and may tell Game a place or an event (place_key / event_key) the journal can
## use as a reading key. The snow is a white slab over the top face of `size`.

var brush_id := ""
var noun := "sign"
var size := Vector3(0.8, 0.5, 0.06)
var place_key := ""
var event_key := ""
var brushed := false
var _snow: MeshInstance3D


static func make(parent: Node3D, id: String, at: Transform3D, surface_size: Vector3, label_noun := "sign") -> Brushable:
	var brush := Brushable.new()
	brush.name = "Brush_" + id
	brush.brush_id = id
	brush.size = surface_size
	brush.noun = label_noun
	parent.add_child(brush)
	brush.global_transform = at
	brush._build()
	if Game.errands:
		Game.errands.register_state("brush:" + id, brush.state, brush.apply_state)
	return brush


func _ready() -> void:
	add_to_group("interactables")


func _build() -> void:
	var snow := HouseKit.paint(Color(0.93, 0.95, 0.98), 0.95)
	# Snow on the top and caked on the face, a little proud of both.
	_snow = HouseKit.box(self, "Snow", Vector3(0.0, size.y * 0.5, size.z * 0.5 + 0.01), Vector3(size.x * 1.02, size.y * 1.02, 0.03), snow)
	HouseKit.box(_snow, "Cap", Vector3(0.0, size.y * 0.5 + 0.02, -size.z * 0.5 - 0.005), Vector3(size.x * 1.04, 0.05, size.z + 0.04), snow)


func interact_label() -> String:
	return "Brush the snow off the " + noun


func interact_point() -> Vector3:
	return global_position + global_basis.y * size.y * 0.5


func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5 - 0.03), size + Vector3(0.0, 0.06, 0.08))]


func interact_hold_seconds() -> float:
	return 0.0 if brushed else Tune.HOLD_DEFAULT


func interact_hold_progress(fraction: float) -> void:
	if _snow and not brushed:
		# The snow thins as she brushes; letting go leaves what is left.
		_snow.scale = Vector3(1.0, maxf(1.0 - fraction * 0.85, 0.15), 1.0)


## A finished hold. Nothing more to do once it is clean.
func interact() -> bool:
	if brushed or (ErrandKit.player() == null and Game.player != null):
		return false
	_set_brushed(true, true)
	return true


func _set_brushed(clean: bool, sound: bool) -> void:
	brushed = clean
	if _snow:
		_snow.visible = not clean
		_snow.scale = Vector3.ONE
	if clean:
		remove_from_group("interactables")
		if sound:
			ErrandKit.play(self, "cloth", Loudness.CLOTH)
		if place_key != "":
			Game.visit(place_key)
		if event_key != "":
			Game.heard(event_key)


func state() -> Variant:
	return brushed


func apply_state(value: Variant) -> void:
	if bool(value):
		_set_brushed(true, false)
