class_name Errands
extends Node3D

## Small things the house and the field ask of Ophelia (docs/superpowers/specs/
## 2026-10-14-errands-and-interactions-design.md). There is no objective on the
## HUD: an errand she has noticed shows in the journal's Undone list, in her
## words, and its prose changes as she gets on with it. Nothing is required.
##
## Only in Ophelia's chapter: in the dream or Mathilda's chapter it frees itself
## at once and Game.errands stays null, so callers check Game.errands first.
##
## State: each Errand (assets/errands/errands.json) is UNKNOWN until learn(),
## KNOWN at a step (advance() moves it on by step id, never back), then DONE
## (finish(), refused until its `requires` are done) or LET_GO (she turned
## around, or the day ran out: every known errand is let go). Every change
## emits Game.errand_changed(id).
##
## World pieces: Errands builds them under world_root() (its own child World,
## in world coordinates), once main.gd has applied the editable level, never
## under House or Trail, so snapshots still line up child for child. Pieces that
## must survive a save register here with a stable id:
## - register_item(item): a Carryable with a unique item_id. capture() records
##   where each one is: in a socket, loose on the ground (its transform), or in
##   her arms; restore() puts it back without replaying picked/placed signals.
## - register_socket(socket): a CarrySocket with a unique socket_id; capture()
##   keeps which item_ids sit in it, in order.
## - register_maker(prefix, make): items that appear in play (a fresh armful
##   from the woodpile) are remade on restore by make.call(item_id), which must
##   build, add and register_item() a Carryable with that id.
## - consume(item): an item used up (the oil tin into the lamp) is freed and
##   remembered as gone, so a restore frees it too.
## - register_state(id, getter, setter): anything else a piece keeps (brushed,
##   wound, opened, fuel). getter.call() returns plain data; setter.call(value)
##   applies it on restore, before items are put back.
## Dev hook: RUN_ERRAND=<id>[:<step>] learns it (and advances to that step).

signal built

const DATA := "res://assets/errands/errands.json"

## main.gd sets this before adding the node and calls ensure_built() itself
## once the snapshot is applied; on its own it builds deferred, like Camp.
var wait_for_level := false
var is_built := false
var errands: Dictionary = {}
var _order: PackedStringArray = []
var _world: Node3D
var _items: Dictionary = {}
var _sockets: Dictionary = {}
var _states: Dictionary = {}
var _makers: Dictionary = {}
var _gone: Dictionary = {}


func _ready() -> void:
	name = "Errands"
	if Game.dream_mode or Game.mathilda_pov:
		queue_free()
		return
	add_to_group("errands")
	Game.errands = self
	for errand in load_catalog():
		errands[errand.id] = errand
		_order.append(errand.id)
	Game.turned.connect(_let_go_all)
	Game.day_ran_out.connect(_let_go_all)
	if not wait_for_level:
		ensure_built.call_deferred()


func _exit_tree() -> void:
	if Game.errands == self:
		Game.errands = null


## Every errand in the data file, fresh (UNKNOWN), in order.
static func load_catalog() -> Array[Errand]:
	var result: Array[Errand] = []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not data is Dictionary:
		push_error("Errands: could not read " + DATA)
		return result
	for entry: Variant in data.get("errands", []):
		if entry is Dictionary:
			result.append(Errand.from_data(entry))
	return result


func ensure_built() -> void:
	if is_built or Game.trail == null:
		return
	world_root()
	_build_verbs()
	is_built = true
	built.emit()
	_dev_hook()


## The verbs that stand on their own (MASTERPLAN W06): the lookout bell and the
## two places to warm her hands. Cupboards, brushable snow and snow branches are
## placed by the errands that use them.
func _build_verbs() -> void:
	var trail := Game.trail
	var lake := get_tree().get_first_node_in_group("lake")
	if lake and not bool(lake.get("is_built")):
		lake.call("_build")
	# On its own post a step in front of the tower, below the two lanterns that
	# read as headlights, facing back down the path she came by.
	var lanterns: Array = lake.get("_lanterns") if lake else []
	var front := trail.exit_point
	if lanterns.size() >= 2:
		front = ((lanterns[0] as Node3D).global_position + (lanterns[1] as Node3D).global_position) * 0.5
	var back_down := trail.position_at(trail.offset_of(trail.exit_point) - 12.0) - front
	back_down.y = 0.0
	back_down = back_down.normalized() if back_down.length() > 0.1 else Vector3.FORWARD
	Bell.make(world_root(), trail.on_ground(front + back_down * 1.6), atan2(back_down.x, back_down.z))
	var house := trail.house
	var stove := house.find_child("StoveChore", true, false) as Chore if house else null
	if stove:
		WarmSpot.make(world_root(), "StoveWarmth", house.to_global(Vector3(4.75, 0.15, -1.2)), "the stove",
			func() -> bool: return is_instance_valid(stove) and stove.done)
	var camp := get_tree().get_first_node_in_group("camp") as Camp
	if camp:
		camp.ensure_built()
		if camp.fire_light:
			WarmSpot.make(world_root(), "CampfireWarmth", trail.on_ground(camp.fire_light.global_position), "the fire",
				func() -> bool: return true)


## Where errand pieces live: a plain Node3D under Errands, at the world origin.
func world_root() -> Node3D:
	if _world == null:
		_world = Node3D.new()
		_world.name = "World"
		add_child(_world)
	return _world


# ---------------------------------------------------------------- state

func get_errand(id: String) -> Errand:
	return errands.get(id) as Errand


## Errands in the data file's order (the journal lists them so).
func ordered() -> Array[Errand]:
	var result: Array[Errand] = []
	for id in _order:
		result.append(errands[id])
	return result


func state_of(id: String) -> Errand.State:
	var errand := get_errand(id)
	return errand.state if errand else Errand.State.UNKNOWN


func is_done(id: String) -> bool:
	return state_of(id) == Errand.State.DONE


func is_known(id: String) -> bool:
	return state_of(id) == Errand.State.KNOWN


## She has noticed it. Nothing new is taken on once she has turned around.
func learn(id: String) -> bool:
	var errand := get_errand(id)
	if errand == null:
		push_warning("Errands: no errand " + id)
		return false
	if errand.state != Errand.State.UNKNOWN or Game.turned_around:
		return false
	errand.state = Errand.State.KNOWN
	errand.step = 0
	_changed(id)
	return true


## On to the step with this id (learning it first if need be). Never back.
func advance(id: String, step_id: String) -> bool:
	var errand := get_errand(id)
	if errand == null:
		push_warning("Errands: no errand " + id)
		return false
	var index := errand.step_index(step_id)
	if index < 0:
		push_warning("Errands: %s has no step %s" % [id, step_id])
		return false
	if errand.state == Errand.State.UNKNOWN:
		learn(id)
	if errand.state != Errand.State.KNOWN or index <= errand.step:
		return false
	errand.step = index
	_changed(id)
	return true


## Done, if everything it needs is done first.
func finish(id: String) -> bool:
	var errand := get_errand(id)
	if errand == null:
		push_warning("Errands: no errand " + id)
		return false
	if errand.state in [Errand.State.DONE, Errand.State.LET_GO]:
		return false
	for other in errand.requires:
		if not is_done(other):
			return false
	errand.state = Errand.State.DONE
	_changed(id)
	return true


## Crossed out in her own words, not failed. Only a known errand can be let go.
func let_go(id: String) -> bool:
	var errand := get_errand(id)
	if errand == null or errand.state != Errand.State.KNOWN:
		return false
	errand.state = Errand.State.LET_GO
	_changed(id)
	return true


func flag(id: String, key: String, default: Variant = null) -> Variant:
	var errand := get_errand(id)
	return errand.flags.get(key, default) if errand else default


func set_flag(id: String, key: String, value: Variant) -> void:
	var errand := get_errand(id)
	if errand == null or errand.flags.get(key) == value:
		return
	errand.flags[key] = value
	_changed(id)


func _let_go_all() -> void:
	for id in _order:
		let_go(id)


func _changed(id: String) -> void:
	Game.mark("errand %s: %s" % [id, Errand.State.keys()[get_errand(id).state].to_lower()])
	Game.errand_changed.emit(id)


# ---------------------------------------------------------------- registry

func register_item(piece: Carryable) -> void:
	if piece.item_id.is_empty() or (item(piece.item_id) != null and item(piece.item_id) != piece):
		push_error("Errands: item needs a unique item_id (%s)" % piece.item_id)
		return
	_items[piece.item_id] = piece
	_gone.erase(piece.item_id)


func register_socket(spot: CarrySocket) -> void:
	if spot.socket_id.is_empty() or (socket(spot.socket_id) != null and socket(spot.socket_id) != spot):
		push_error("Errands: socket needs a unique socket_id (%s)" % spot.socket_id)
		return
	_sockets[spot.socket_id] = spot


func register_state(id: String, getter: Callable, setter: Callable) -> void:
	if _states.has(id):
		push_error("Errands: state %s registered twice" % id)
		return
	_states[id] = [getter, setter]


func register_maker(prefix: String, make: Callable) -> void:
	_makers[prefix] = make


func item(item_id: String) -> Carryable:
	var found: Variant = _items.get(item_id)
	return found as Carryable if is_instance_valid(found) else null


func socket(socket_id: String) -> CarrySocket:
	var found: Variant = _sockets.get(socket_id)
	return found as CarrySocket if is_instance_valid(found) else null


## Used up for good: freed now, and freed again on any restore.
func consume(used: Carryable) -> void:
	if not is_instance_valid(used):
		return
	_gone[used.item_id] = true
	_items.erase(used.item_id)
	if Game.player and Game.player.carrying == used:
		Game.player.call("_clear_carried")
	if is_instance_valid(used.socket):
		used.socket.remove_item(used)
	used.queue_free()


# ---------------------------------------------------------------- saving

## Plain data for RunSave and the lookout checkpoint.
func capture() -> Dictionary:
	var states := {}
	for id in _order:
		var errand: Errand = errands[id]
		states[id] = {"state": int(errand.state), "step": errand.step, "flags": errand.flags.duplicate(true)}
	var held := {}
	for socket_id: String in _sockets:
		var where := socket(socket_id)
		if where:
			held[socket_id] = where.held.filter(func(thing: Carryable) -> bool: return is_instance_valid(thing)).map(func(thing: Carryable) -> String: return thing.item_id)
	var carrying := ""
	var loose := {}
	for item_id: String in _items:
		var thing := item(item_id)
		if thing == null:
			continue
		if thing.carrier != null:
			carrying = item_id
		elif not is_instance_valid(thing.socket):
			loose[item_id] = thing.global_transform
	var pieces := {}
	for id: String in _states:
		# A piece freed since it registered (used up, rebuilt) has nothing to keep.
		var getter := _states[id][0] as Callable
		if getter.is_valid():
			pieces[id] = getter.call()
	return {"version": 1, "errands": states, "sockets": held, "loose": loose, "carrying": carrying,
		"gone": _gone.keys(), "pieces": pieces}


## Puts a capture() back: states, pieces, then every item where it was.
func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	ensure_built()
	var states: Dictionary = data.get("errands", {})
	for id in _order:
		var errand: Errand = errands[id]
		var saved: Dictionary = states.get(id, {})
		errand.state = clampi(int(saved.get("state", 0)), 0, Errand.State.size() - 1) as Errand.State
		errand.step = clampi(int(saved.get("step", 0)), 0, maxi(errand.steps.size() - 1, 0))
		errand.flags = (saved.get("flags", {}) as Dictionary).duplicate(true)
	var pieces: Dictionary = data.get("pieces", {})
	for id: String in pieces:
		if _states.has(id) and (_states[id][1] as Callable).is_valid():
			(_states[id][1] as Callable).call(pieces[id])
	var held: Dictionary = data.get("sockets", {})
	var loose: Dictionary = data.get("loose", {})
	var player := Game.player
	var carrying := str(data.get("carrying", ""))
	if player and not player.carrying_item_id.is_empty():
		carrying = player.carrying_item_id
	# Remake anything that appeared in play, and free what was used up.
	var wanted: Array = loose.keys()
	for ids: Variant in held.values():
		wanted.append_array(ids)
	if carrying != "":
		wanted.append(carrying)
	for item_id: Variant in wanted:
		_make(str(item_id))
	for item_id: Variant in data.get("gone", []):
		var used := item(str(item_id))
		if used:
			consume(used)
		_gone[str(item_id)] = true
	# Everything comes out of the sockets and her arms first, then goes back.
	for socket_id: String in _sockets:
		var where := socket(socket_id)
		if where:
			for thing in where.held.duplicate():
				where.remove_item(thing)
	if player and is_instance_valid(player.carrying) and _items.values().has(player.carrying):
		var was := player.carrying
		player.call("_clear_carried")
		was.return_visual()
	for socket_id: String in held:
		var where := socket(socket_id)
		if where == null:
			continue
		for item_id: Variant in held[socket_id]:
			var thing := item(str(item_id))
			if thing and where.held.size() < where.capacity:
				thing.global_transform = where.item_transform(where.held.size())
				where.add_item(thing)
	for item_id: String in loose:
		var thing := item(item_id)
		if thing and loose[item_id] is Transform3D:
			thing.global_transform = loose[item_id]
			thing.refresh_interaction()
	if player:
		var thing := item(carrying)
		if thing:
			player.restore_carried(thing)
		elif not is_instance_valid(player.carrying):
			player.carrying_item_id = ""
	for id in _order:
		Game.errand_changed.emit(id)


func _make(item_id: String) -> void:
	if item(item_id) != null or _gone.has(item_id):
		return
	for prefix: String in _makers:
		if item_id.begins_with(prefix):
			(_makers[prefix] as Callable).call(item_id)
			return


# Dev hook: RUN_ERRAND=<id>[:<step>].
func _dev_hook() -> void:
	var asked := OS.get_environment("RUN_ERRAND")
	if asked == "":
		return
	var id := asked.get_slice(":", 0)
	learn(id)
	if asked.contains(":"):
		advance(id, asked.get_slice(":", 1))
