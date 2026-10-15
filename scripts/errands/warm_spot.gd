class_name WarmSpot
extends Node3D

## Somewhere to warm her hands (errands spec, verb 6): the lit stove, Mathilda's
## campfire. Only there while `lit` says the fire burns. Holding interact there
## crouches her (Player.warming, from the active hold), and a finished hold gives
## her Tune.WARM_QUIET seconds of warmth: the cold lines wait and her breath
## slows (Player.warmth). It can be done again whenever she likes.

var noun := "the stove"
## Returns whether the fire burns; when it does not, the spot is hidden and so
## never picked.
var lit: Callable = func() -> bool: return true


static func make(parent: Node3D, spot_name: String, at: Vector3, fire_noun: String, is_lit: Callable) -> WarmSpot:
	var spot := WarmSpot.new()
	spot.name = spot_name
	spot.noun = fire_noun
	spot.lit = is_lit
	parent.add_child(spot)
	spot.global_position = at
	return spot


func _ready() -> void:
	add_to_group("interactables")
	visible = _burning()


func _process(_delta: float) -> void:
	var burning := _burning()
	if visible != burning:
		visible = burning


func _burning() -> bool:
	return lit.is_valid() and bool(lit.call())


## Marks this as something whose hold warms her (Player._tick_hold).
func warms_her() -> bool:
	return true


func interact_label() -> String:
	return "Warm your hands at " + noun


func interact_point() -> Vector3:
	return global_position


func aim_box() -> Array:
	return [global_transform, AABB(Vector3(-0.45, 0.0, -0.45), Vector3(0.9, 0.9, 0.9))]


func interact_hold_seconds() -> float:
	return Tune.WARM_SECONDS


func interact() -> bool:
	var player := ErrandKit.player()
	if player == null or not _burning():
		return false
	player.warmth = Tune.WARM_QUIET
	ErrandKit.play(self, "cloth", Loudness.CLOTH)
	return true
