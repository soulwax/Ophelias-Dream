class_name TwoCups
extends RefCounted

## W08: one cup in the cupboard, the other on the porch. Set both on the
## kitchen table, then warm the kettle on the stove. Every piece has a stable
## Errands id; completion is optional evidence, never a base-ending gate.
const ID := "two_cups"
const OWN_CUP := "cups_ophelia"
const HER_CUP := "cups_mathilda"
const KETTLE := "cups_kettle"
const CUPBOARD_AT := Vector3(5.8, 1.38, -4.47)
const TABLE_AT := Vector3(4.45, 0.78, -2.7)
const RAIL_AT := Vector3(1.16, 0.0, 5.4)
const KETTLE_AT := Vector3(3.68, 0.96, -4.48)
const STOVE_AT := Vector3(5.25, 0.985, -1.2)
const SHELF_CUP_AT := Vector3(-0.205, 0.035, 0.05)

class Cup extends Carryable:
	func can_take() -> bool:
		return is_visible_in_tree() and super.can_take()

class CupTable extends CarrySocket:
	func item_transform(index: int) -> Transform3D:
		# Her near cup and Mathilda's farther one sit by their chairs, at casual
		# angles. Stable item identities keep the other cup still when one is
		# taken away, regardless of placement order or a saved socket's order.
		var hers := held[index].item_id == TwoCups.HER_CUP if index < held.size() else index == 1
		var at := Vector3(0.29, 0.0, -0.16) if hers else Vector3(-0.31, 0.0, 0.13)
		var yaw := deg_to_rad(28.0 if hers else -17.0)
		return global_transform * Transform3D(Basis(Vector3.UP, yaw), at)

class KettleHeat extends Node3D:
	var cups: TwoCups
	func _ready() -> void:
		add_to_group("interactables")
	func interact_point() -> Vector3:
		return global_position
	func aim_box() -> Array:
		return [global_transform, AABB(Vector3(-0.2, 0.0, -0.2), Vector3(0.4, 0.32, 0.4))]
	func blocked_label() -> String:
		return cups.heat_gate()
	func interact_label() -> String:
		var why := blocked_label()
		return why if why != "" else "Warm the kettle"
	func interact_hold_seconds() -> float:
		return Tune.HOLD_DEFAULT if blocked_label() == "" else 0.0
	func interact() -> bool:
		return cups.warm_kettle()

var errands: Errands
var house: House
var stove: Chore
var cupboard: HouseDrawer
var table: CupTable
var hotplate: CarrySocket
var heat: KettleHeat
var rail: Node3D
var snow: MeshInstance3D
var steam: CPUParticles3D
var cupboard_taken := false
var cup_found := false


static func build(on: Errands) -> TwoCups:
	var home := Game.trail.house if Game.trail else null
	var fire := home.find_child("StoveChore", true, false) as Chore if home else null
	if home == null or fire == null:
		return null
	var cups := TwoCups.new()
	cups.errands = on
	cups.house = home
	cups.stove = fire
	cups._build()
	on.register_state("two_cups:pieces", cups.capture, cups.restore)
	on.watch(cups)
	return cups


func _build() -> void:
	var world := errands.world_root()
	# Leave the authored hierarchy intact; the interactive pair replaces only
	# the decorative tea set on this table, after the editable snapshot applies.
	var furniture := house.get_node_or_null("Furniture")
	if furniture:
		for child in furniture.get_children():
			if child is Node3D and (str(child.name).begins_with("tea_set_01") or child.scene_file_path.contains("/tea_set_01/")) and child.position.distance_to(Vector3(4.45, 0.76, -2.7)) < 0.5:
				child.hide()
	cupboard = HouseDrawer.make(world, "cups", house.global_transform * Transform3D(Basis.IDENTITY, CUPBOARD_AT), Vector3(0.8, 0.58, 0.36))
	cupboard.opened.connect(_opened)
	var own := _cup(OWN_CUP, "cup", Color("dfd6bb"))
	cupboard.hold(own, SHELF_CUP_AT)
	own.global_rotation.y = house.global_rotation.y + deg_to_rad(-11.0)
	own.picked.connect(_own_picked)
	# A bare ring beside hers makes the absent pair visible when she opens it.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.045
	torus.outer_radius = 0.06
	ring.mesh = torus
	ring.scale.y = 0.04
	ring.material_override = HouseKit.paint(Color("362b24"), 0.95)
	world.add_child(ring)
	cupboard.hold(ring, Vector3(0.125, 0.028, -0.035))
	# A short rail on the east edge of the existing landing, clear of the door.
	rail = Node3D.new()
	rail.name = "CupPorchRail"
	world.add_child(rail)
	rail.global_transform = house.global_transform * Transform3D(Basis.IDENTITY, RAIL_AT)
	var wood := house._timber
	for z in [-0.32, 0.32]:
		HouseKit.solid(rail, "Post", Vector3(0.0, 0.44, z), Vector3(0.07, 0.88, 0.07), wood)
	HouseKit.solid(rail, "Rail", Vector3(0.0, 0.88, 0.0), Vector3(0.18, 0.06, 0.75), wood)
	var hers := _cup(HER_CUP, "Mathilda's cup", Color("768e9a"))
	hers.global_transform = rail.global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(31.0)), Vector3(0.012, 0.91, 0.19))
	snow = MeshInstance3D.new()
	snow.name = "Snow"
	var drift := SphereMesh.new()
	drift.radius = 0.075
	drift.height = 0.13
	snow.mesh = drift
	snow.scale = Vector3(1.0, 1.0, 0.75)
	snow.position = Vector3(0.0, 0.065, -0.035)
	snow.material_override = HouseKit.paint(Color("edf0f5"), 0.95)
	hers.visual.add_child(snow)
	# Wind has banked an uneven skirt around one side, rather than a centred
	# cap. These small lobes disappear with the main snow when she takes it.
	for spec in [Vector3(-0.04, -0.035, 0.025), Vector3(0.035, -0.04, 0.015)]:
		var skirt := MeshInstance3D.new()
		skirt.mesh = drift
		skirt.material_override = snow.material_override
		skirt.position = spec
		skirt.scale = Vector3(0.75, 0.35, 0.9)
		snow.add_child(skirt)
	hers.picked.connect(_her_picked)
	table = CupTable.new()
	table.name = "TwoCupTable"
	table.socket_id = "cups_table"
	table.accepts = PackedStringArray(["cup"])
	table.capacity = 2
	world.add_child(table)
	table.global_transform = house.global_transform * Transform3D(Basis.IDENTITY, TABLE_AT)
	table.filled.connect(_table_filled)
	errands.register_socket(table)
	var kettle := Carryable.new()
	kettle.item_id = KETTLE
	kettle.name = "Kettle"
	kettle.kind = "kettle"
	kettle.noun = "kettle"
	kettle.visual = _kettle_visual()
	kettle.add_child(kettle.visual)
	world.add_child(kettle)
	kettle.global_transform = house.global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(-24.0)), KETTLE_AT)
	errands.register_item(kettle)
	hotplate = CarrySocket.new()
	hotplate.name = "KettleOnStove"
	hotplate.socket_id = "cups_stove"
	hotplate.accepts = PackedStringArray(["kettle"])
	hotplate.allow_take = false
	world.add_child(hotplate)
	hotplate.global_transform = house.global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(19.0)), _stove_surface())
	hotplate.filled.connect(func(_item: Carryable) -> void: ErrandKit.play(hotplate, "kettle", Loudness.CUPBOARD))
	errands.register_socket(hotplate)
	heat = KettleHeat.new()
	heat.name = "WarmKettle"
	heat.cups = self
	world.add_child(heat)
	heat.global_transform = hotplate.global_transform
	steam = CPUParticles3D.new()
	steam.name = "KettleSteam"
	steam.emitting = false
	steam.amount = 12
	steam.lifetime = 1.4
	steam.direction = Vector3.UP
	steam.spread = 12.0
	steam.gravity = Vector3.ZERO
	steam.initial_velocity_min = 0.1
	steam.initial_velocity_max = 0.18
	steam.scale_amount_min = 0.4
	steam.scale_amount_max = 1.3
	var puff := QuadMesh.new()
	puff.size = Vector2(0.1, 0.1)
	steam.mesh = puff
	steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mist := StandardMaterial3D.new()
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mist.vertex_color_use_as_albedo = true
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = Gradient.new()
	texture.gradient.colors = PackedColorArray([Color(0.9, 0.92, 0.95, 0.22), Color(0.9, 0.92, 0.95, 0.0)])
	mist.albedo_texture = texture
	steam.color_ramp = Gradient.new()
	steam.color_ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	steam.color_ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0)])
	steam.material_override = mist
	kettle.visual.add_child(steam)
	steam.position = Vector3(0.15, 0.2, 0.0)


func _cup(item_id: String, noun: String, colour: Color) -> Cup:
	var cup := Cup.new()
	cup.item_id = item_id
	cup.name = item_id
	cup.kind = "cup"
	cup.noun = noun
	cup.visual = _fitted_model("SM_Cup", 0.13)
	if cup.visual == null:
		cup.visual = Node3D.new()
		var ceramic := HouseKit.paint(colour, 0.35)
		_cylinder(cup.visual, 0.055, 0.12, Vector3(0, 0.06, 0), ceramic)
		_cylinder(cup.visual, 0.045, 0.002, Vector3(0, 0.121, 0), HouseKit.paint(Color("302c28"), 0.8))
		_handle(cup.visual, Vector3(0.06, 0.065, 0), 0.025, 0.037, ceramic)
	cup.add_child(cup.visual)
	errands.world_root().add_child(cup)
	errands.register_item(cup)
	return cup


func _kettle_visual() -> Node3D:
	var body := _fitted_model("SM_Jar", 0.2)
	if body == null:
		body = Node3D.new()
	var metal := HouseKit.paint(Color("57666a"), 0.4, 0.5)
	if body.get_child_count() == 0:
		_cylinder(body, 0.105, 0.18, Vector3(0, 0.09, 0), metal)
	_cylinder(body, 0.09, 0.025, Vector3(0, 0.205, 0), metal)
	_cylinder(body, 0.023, 0.035, Vector3(0, 0.235, 0), metal)
	var spout := _cylinder(body, 0.025, 0.14, Vector3(0.115, 0.14, 0), metal)
	spout.rotation.z = -0.8
	_handle(body, Vector3(-0.115, 0.13, 0), 0.055, 0.072, metal)
	return body


static func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


static func _handle(parent: Node3D, at: Vector3, inner: float, outer: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.rotation.x = PI * 0.5
	parent.add_child(node)


## The curated models use their source scale/origin. Fit only this instance;
## the wrapper leaves later handles and steam in metres, including fallback.
static func _fitted_model(model_name: String, height: float) -> Node3D:
	var model := VendorLoader.load_model(ErrandKit.LEARTES + model_name + ".gltf")
	if model == null:
		return null
	var bounds := _bounds(model, Transform3D.IDENTITY)
	if bounds.size.y < 0.001:
		model.free()
		return null
	var wrapper := Node3D.new()
	wrapper.add_child(model)
	var factor := height / bounds.size.y
	model.scale *= factor
	model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	return wrapper


static func _bounds(node: Node3D, parent_transform: Transform3D) -> AABB:
	var transform := parent_transform * node.transform
	var bounds := transform * (node as MeshInstance3D).get_aabb() if node is MeshInstance3D else AABB()
	for child in node.get_children():
		if child is Node3D:
			var box := _bounds(child, transform)
			if box.size != Vector3.ZERO:
				bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	return bounds


func _opened() -> void:
	if errands.learn(ID):
		_say("cups_missing")


func _own_picked() -> void:
	cupboard_taken = true
	cupboard.release(errands.item(OWN_CUP))
	_opened()


func _her_picked() -> void:
	if not cup_found:
		cup_found = true
		snow.hide()
		errands.advance(ID, "found")
		_say("cups_found")


func _table_filled(_item: Carryable) -> void:
	ErrandKit.play(table, "cup", Loudness.CUPBOARD)
	if table.held.size() == 2 and errands.advance(ID, "kettle"):
		_say("cups_set")


func heat_gate() -> String:
	if errands.state_of(ID) == Errand.State.LET_GO:
		return "Leave the kettle"
	if errands.is_done(ID):
		return "The kettle is warm"
	if not stove.done or not errands.is_done(WarmHouse.ID):
		return "The stove is cold"
	if table.held.size() != 2:
		return "Set both cups on the table"
	if hotplate.held.is_empty():
		return "Put the kettle on the stove"
	return ""


func warm_kettle() -> bool:
	if heat_gate() != "" or not errands.finish(ID):
		return false
	# Keep the completed scene true for the lake's line, also after a load.
	Game.heard("cups")
	_say("cups_kettle")
	tick()
	return true


func tick() -> void:
	var done := errands.is_done(ID)
	if table.allow_take == done:
		table.allow_take = not done
		for cup in table.held:
			cup.refresh_interaction()
	steam.emitting = done
	if done:
		heat.remove_from_group("interactables")
		Game.heard("cups")
	else:
		# Only the real kettle is a heating target. The empty hotplate is a
		# placement socket while carried, so it cannot steal that interaction.
		if not hotplate.held.is_empty() and Game.player and not is_instance_valid(Game.player.carrying):
			heat.add_to_group("interactables")
		else:
			heat.remove_from_group("interactables")


func capture() -> Variant:
	return {"cupboard_taken": cupboard_taken, "cup_found": cup_found}


func restore(value: Variant) -> void:
	if not value is Dictionary:
		return
	cupboard_taken = bool(value.get("cupboard_taken", false))
	cup_found = bool(value.get("cup_found", false))
	if cupboard_taken:
		cupboard.release(errands.item(OWN_CUP))
	else:
		var own := errands.item(OWN_CUP)
		cupboard.release(own)
		cupboard.hold(own, SHELF_CUP_AT)
	snow.visible = not cup_found


func _stove_surface() -> Vector3:
	var at := STOVE_AT
	var top := house.get_node_or_null("Domestic/Imported_stove/top2") as MeshInstance3D
	if top:
		var bounds := (house.global_transform.affine_inverse() * top.global_transform) * top.get_aabb()
		at = Vector3(bounds.get_center().x - 0.1, bounds.end.y + 0.005, bounds.get_center().z)
	# The old broad blocker reached above the real top, hiding anything placed
	# on it from Aim. Match its height after the editable snapshot has applied;
	# use a private shape so the saved scene's shared resource is untouched.
	var body := house.get_node_or_null("Domestic/StoveBody") as StaticBody3D
	if body:
		var shape := body.get_child(0) as CollisionShape3D
		if shape and shape.shape is BoxShape3D:
			var box := shape.shape.duplicate() as BoxShape3D
			box.size.y = at.y - 0.005
			shape.shape = box
			body.position.y = box.size.y * 0.5
	return at


func _say(id: String) -> void:
	if Game.voice:
		Game.voice.errand(id)
