class_name WallSwitch
extends Node3D

## A wall switch: E toggles a set of lights and anything that glows with
## them (tubes, bulbs). Sits flat on a wall, facing local +Z.

var label := "Lights"
var lights: Array[Light3D] = []
var glowing: Array[Node3D] = []
var on := true
var _toggle: Node3D
var _click: AudioStreamPlayer3D
var _toggle_tween: Tween
var _light_tween: Tween
var _light_energy: Dictionary = {}


static func make(parent: Node3D, name: String, at: Vector3, yaw: float, switch_label: String, switched: Array[Light3D], lit: Array[Node3D] = []) -> WallSwitch:
	var switch := WallSwitch.new()
	switch.name = name
	switch.label = switch_label
	switch.lights = switched
	switch.glowing = lit
	switch.position = at
	switch.rotation.y = yaw
	parent.add_child(switch)
	switch._build()
	return switch


func interact_label() -> String:
	return ("Switch off the " if on else "Switch on the ") + label.to_lower()


func interact_point() -> Vector3:
	return global_position


## Twice the plate, so a switch on a wall is not a pixel hunt.
func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.09, -0.11, -0.02), Vector3(0.18, 0.22, 0.09))]


func interact() -> bool:
	on = not on
	if _toggle_tween and _toggle_tween.is_running():
		_toggle_tween.kill()
	_toggle_tween = create_tween()
	_toggle_tween.tween_property(_toggle, "rotation:x", -0.35 if on else 0.35, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _light_tween and _light_tween.is_running():
		_light_tween.kill()
	_light_tween = create_tween().set_parallel(true)
	for lamp in lights:
		if is_instance_valid(lamp):
			if not _light_energy.has(lamp):
				_light_energy[lamp] = lamp.light_energy
			if on:
				lamp.visible = true
			_light_tween.tween_property(lamp, "light_energy", float(_light_energy[lamp]) if on else 0.0, 0.12)
	for node in glowing:
		if is_instance_valid(node):
			node.visible = on
	if _click and _click.stream:
		_click.pitch_scale = randf_range(1.32, 1.48)
		Loudness.sound(_click, Loudness.SWITCH)
		_click.play()
	return true


func _ready() -> void:
	add_to_group("interactables")


func _build() -> void:
	HouseKit.box(self, "Plate", Vector3(0.0, 0.0, 0.004), Vector3(0.09, 0.13, 0.008), HouseKit.paint(Color("d9d4c8"), 0.5))
	_toggle = Node3D.new()
	_toggle.name = "Toggle"
	_toggle.position = Vector3(0.0, 0.0, 0.012)
	_toggle.rotation.x = -0.35
	add_child(_toggle)
	HouseKit.box(_toggle, "Dolly", Vector3(0.0, 0.0, 0.01), Vector3(0.02, 0.045, 0.02), HouseKit.paint(Color("1c1c1c"), 0.5))
	_click = AudioStreamPlayer3D.new()
	_click.bus = "Effects"
	_click.stream = load(DoorAudio.HANDLE) as AudioStream if ResourceLoader.exists(DoorAudio.HANDLE) else null
	_click.volume_db = -8.0
	_click.pitch_scale = 1.4
	add_child(_click)
