class_name WarmHouse
extends RefCounted

## The warm_house errand (errands spec; MASTERPLAN W07). The stove will not
## light while the woodbox by it is empty: the first try says so, and she knows
## the errand. Under the eaves by the front door is the woodpile; it gives out
## one armful at a time while the box still wants wood, never more than one
## loose. Three armfuls in the box, and the stove lights as it always did, and
## the errand is done. Steps: cold (learned), carry (first armful taken), light
## (box full). Without Errands (the dream, Mathilda's chapter) none of this is
## built and the stove lights at once, as before.

const ID := "warm_house"
const ARMFUL := "wood_armful_"
const WOODBOX := "woodbox"
## House-local spots: under the eaves right of the front door, and against the
## east wall beside the stove.
const PILE_AT := Vector3(3.3, 0.0, 5.55)
const BOX_AT := Vector3(5.85, 0.07, -0.35)

var errands: Errands
var house: House
var stove: Chore
var box: CarrySocket
var pile: Node3D
var _made := 0


static func build(on: Errands) -> WarmHouse:
	var house := Game.trail.house if Game.trail else null
	var stove := house.find_child("StoveChore", true, false) as Chore if house else null
	if house == null or stove == null:
		return null
	var warm := WarmHouse.new()
	warm.errands = on
	warm.house = house
	warm.stove = stove
	warm._build_box()
	warm._build_pile()
	stove.gate = warm._stove_gate
	stove.blocked.connect(warm._stove_refused)
	stove.tree_exiting.connect(func() -> void: warm.stove = null)
	on.register_maker(ARMFUL, warm._make_armful)
	on.register_state("chore:stove", warm._stove_state, warm._apply_stove)
	on.register_state("warm_house:pile", func() -> Variant: return warm._made, func(value: Variant) -> void: warm._made = int(value))
	on.watch(warm)
	return warm


func _build_box() -> void:
	var at := house.to_global(BOX_AT)
	var crate := ErrandKit.prop(errands.world_root(), "SM_Crate", Vector3(0.62, 0.42, 0.44), Color("5b432f"))
	crate.name = "Woodbox"
	crate.global_position = at
	crate.rotation.y = house.global_rotation.y + PI * 0.5
	box = CarrySocket.new()
	box.name = "WoodboxSocket"
	box.socket_id = WOODBOX
	box.accepts = PackedStringArray(["wood"])
	box.capacity = Tune.ERRAND_WOOD_ARMFULS
	box.allow_take = false
	errands.world_root().add_child(box)
	box.global_position = at + Vector3.UP * 0.12
	box.rotation.y = crate.rotation.y
	box.filled.connect(_on_filled)
	errands.register_socket(box)


# A stack of split logs against the wall, five rows narrowing upward. The
# Leartes firewood is a single log, so the pile is built from it (or from a
# bark-coloured cylinder without the vendor set).
func _build_pile() -> void:
	pile = Node3D.new()
	pile.name = "Woodpile"
	errands.world_root().add_child(pile)
	pile.global_position = Game.trail.on_ground(house.to_global(PILE_AT))
	pile.rotation.y = house.global_rotation.y
	var bark := HouseKit.paint(Color("5e4430"), 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 731
	var spacing := 0.13
	for row in 5:
		var count := 7 - row
		for index in count:
			var piece := VendorLoader.load_model(ErrandKit.LEARTES + "SM_Firewood.gltf")
			if piece == null:
				piece = MeshInstance3D.new()
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.06
				cylinder.bottom_radius = 0.065
				cylinder.height = 0.8
				cylinder.radial_segments = 7
				(piece as MeshInstance3D).mesh = cylinder
				(piece as MeshInstance3D).material_override = bark
				piece.rotation.x = PI * 0.5
			pile.add_child(piece)
			# Logs run away from the wall; rows sit in the gaps of the row below.
			piece.position = Vector3((float(index) - float(count - 1) * 0.5) * spacing, 0.065 + float(row) * 0.11, rng.randf_range(-0.04, 0.04))
			piece.rotation.y += PI * 0.5 + rng.randf_range(-0.06, 0.06)
	# Snow lying on top, so the stack reads against the dark wall from the path.
	var snow := HouseKit.paint(Color(0.93, 0.95, 0.98), 0.95)
	HouseKit.box(pile, "SnowCap", Vector3(0.0, 0.065 + 4.0 * 0.11 + 0.08, 0.0), Vector3(3.0 * spacing + 0.14, 0.06, 0.86), snow)
	HouseKit.box(pile, "SnowShoulder", Vector3(0.0, 0.065 + 3.0 * 0.11 + 0.1, 0.0), Vector3(5.0 * spacing + 0.1, 0.035, 0.84), snow)


## Called each frame by Errands while this errand is open: a fresh armful lies on
## the pile whenever the box still wants wood and none is loose or carried.
func tick() -> void:
	if errands.is_done(ID) or errands.state_of(ID) == Errand.State.LET_GO:
		return
	if stove and stove.done:
		on_stove_lit()
		return
	if box == null or box.held.size() >= box.capacity:
		return
	for item_id: String in errands.get("_items"):
		if item_id.begins_with(ARMFUL):
			var armful := errands.item(item_id)
			if armful and armful.socket == null:
				return
	_make_armful(ARMFUL + str(_made))


func _make_armful(item_id: String) -> void:
	if errands.item(item_id) != null:
		return
	var armful := Carryable.new()
	armful.name = item_id
	armful.item_id = item_id
	armful.kind = "wood"
	armful.noun = "firewood"
	armful.heavy = true
	armful.visual = _logs()
	armful.add_child(armful.visual)
	errands.world_root().add_child(armful)
	armful.global_position = pile.global_position + pile.global_basis.y * 0.6
	armful.rotation.y = pile.global_rotation.y
	armful.picked.connect(_on_picked)
	errands.register_item(armful)
	_made = maxi(_made, int(item_id.trim_prefix(ARMFUL)) + 1)


# Three split logs bound together: what she carries and what the box stacks.
func _logs() -> Node3D:
	var bundle := Node3D.new()
	bundle.name = "Logs"
	var bark := HouseKit.paint(Color("5e4430"), 0.9)
	for index in 3:
		var piece := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.055
		cylinder.bottom_radius = 0.06
		cylinder.height = 0.42
		cylinder.radial_segments = 7
		piece.mesh = cylinder
		piece.material_override = bark
		piece.rotation.z = PI * 0.5
		piece.position = Vector3(0.0, 0.06 + (0.1 if index == 2 else 0.0), (float(index % 2) - 0.5) * 0.12 if index < 2 else 0.0)
		bundle.add_child(piece)
	return bundle


func _on_picked() -> void:
	if not errands.is_known(ID):
		errands.learn(ID)
	errands.advance(ID, "carry")


func _on_filled(_item: Carryable) -> void:
	ErrandKit.play(box, "wood_stack", Loudness.WOOD_DROP)
	if box.held.size() >= box.capacity:
		errands.advance(ID, "light")


func _stove_gate() -> String:
	if errands == null or errands.is_done(ID) or box == null or box.held.size() >= box.capacity:
		return ""
	return "No wood in the box"


func _stove_refused() -> void:
	if not errands.is_known(ID):
		errands.learn(ID)


## The stove lit (the chore ran): the errand is done.
func on_stove_lit() -> void:
	if errands.is_known(ID) or (box and box.held.size() >= box.capacity):
		errands.finish(ID)


func _stove_state() -> Variant:
	return stove != null and stove.done


func _apply_stove(value: Variant) -> void:
	if bool(value) and stove:
		stove.restore_done()
