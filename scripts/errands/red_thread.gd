class_name RedThread
extends RefCounted

## W09: a small, continuous trail of wool, from the loose window to a glove
## beneath an inscribed birch. Progress is saved as a piece; the glove uses the
## ordinary Carryable save path so a dropped one is never replaced by a new one.
const ID := "red_thread"
const GLOVE := "thread_glove"

class Snag extends StaticBody3D:
	var walk: RedThread
	var index := 0
	func _ready() -> void:
		collision_layer = Tune.LAYER_WORLD
		collision_mask = 0
		add_to_group("interactables")
	func interact_point() -> Vector3:
		return global_position + Vector3.UP * 0.95
	func aim_box() -> Array:
		return [global_transform, AABB(Vector3(-0.3, 0.55, -0.3), Vector3(0.6, 0.8, 0.6))]
	func interact_label() -> String:
		return "Wind the red thread loose"
	func interact_hold_seconds() -> float:
		return Tune.HOLD_DEFAULT
	func interact() -> bool:
		return walk.wind(index)

class Glove extends Carryable:
	var walk: RedThread
	func can_take() -> bool:
		return walk.wound == 5 and walk.initials.brushed and super.can_take()

class CampSpot extends CarrySocket:
	func item_transform(_index: int) -> Transform3D:
		return global_transform

var errands: Errands
var trail: Trail
var window: Chore
var camp: Camp
var wound := 0
var snags: Array[Snag] = []
var anchors: Array[Vector3] = []
var strands: Array[Node3D] = []
var glove: Glove
var birch: Node3D
var camp_spot: CarrySocket
var snow_branch: SnowBranch
var initials: Brushable
var branch_revealed := false
var _window_was_done := false


static func build(on: Errands) -> RedThread:
	var route := Game.trail
	var latch := route.house.find_child("WindowChore", true, false) as Chore if route and route.house else null
	if latch == null or route.flora == null:
		return null
	var walk := RedThread.new()
	walk.errands = on
	walk.trail = route
	walk.window = latch
	walk.camp = on.get_tree().get_first_node_in_group("camp") as Camp
	walk._build()
	on.register_state("red_thread:walk", walk.capture, walk.restore)
	on.watch(walk)
	return walk


func _build() -> void:
	var world := errands.world_root()
	var start := window.global_position
	anchors.append(start)
	var end_frame := trail.frame_at(trail.player_start_offset + 62.0)
	var end_target := end_frame.origin + end_frame.basis.x * -16.0
	var end := _nearest_tree(end_target, 20.0)
	if end == Vector3.INF:
		end = trail.on_ground(end_target)
	else:
		# The authored birch stands beside the existing conifer, instead of
		# planting a second trunk through its multimesh trunk.
		var apart := end_target - end
		apart.y = 0.0
		end = trail.on_ground(end + apart.normalized() * 2.4)
	var previous := start
	var across := Vector3(-(end.z - start.z), 0.0, end.x - start.x).normalized()
	# Interpolate between the real window and a tree near the route's wooded
	# shoulder. This keeps every next length in view even in sparse flora seeds.
	var sway: Array[float] = [0.0, 0.7, -0.9, 0.8, -0.6, 0.0]
	for i in range(1, 7):
		var target := start.lerp(end, float(i) / 6.0) + across * sway[i - 1]
		var anchor := end if i == 6 else _tree_near(target, previous, end)
		anchors.append(anchor)
		previous = anchor
	# Five hand-worked snags; the last anchor is the birch and its glove.
	for i in 5:
		var snag := Snag.new()
		snag.name = "ThreadSnag_%d" % (i + 1)
		snag.walk = self
		snag.index = i
		world.add_child(snag)
		snag.global_position = anchors[i + 1]
		var at_tree := not trail.flora.nearest_indices(anchors[i + 1], 1, 0.4).is_empty()
		if not at_tree:
			var peg := CylinderMesh.new()
			peg.top_radius = 0.045 if i < 3 else 0.14
			peg.bottom_radius = 0.055 if i < 3 else 0.17
			peg.height = 1.05
			var stem := MeshInstance3D.new()
			stem.mesh = peg
			stem.material_override = HouseKit.paint(Color("3b332a"), 0.92)
			stem.position.y = 0.53
			snag.add_child(stem)
		var loop := MeshInstance3D.new()
		loop.name = "WoolCaughtOnBark"
		var ring := TorusMesh.new()
		ring.inner_radius = 0.13
		ring.outer_radius = 0.15
		loop.mesh = ring
		loop.material_override = HouseKit.paint(Color("9e3239"), 0.9)
		loop.position.y = 0.95
		snag.add_child(loop)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.19
		capsule.height = 1.1
		shape.shape = capsule
		shape.position.y = 0.7
		snag.add_child(shape)
		snags.append(snag)
	snow_branch = SnowBranch.make(world, "thread", anchors[2], 0.35)
	snow_branch.dropped.connect(func() -> void:
		branch_revealed = true
		_refresh())
	_build_birch(world, anchors[6])
	initials = Brushable.make(world, "thread_initials", Transform3D(Basis.IDENTITY, anchors[6] + Vector3(0, 1.12, 0.18)), Vector3(0.3, 0.20, 0.02), "letters")
	for i in 6:
		strands.append(_strand(world, anchors[i] + Vector3.UP * (1.3 if i == 0 else 0.95), anchors[i + 1] + Vector3.UP * 0.95))
	glove = Glove.new()
	glove.name = "ThreadGlove"
	glove.item_id = GLOVE
	glove.kind = "glove"
	glove.noun = "Mathilda's glove"
	glove.walk = self
	glove.visual = _mitten(Color("8a3335"))
	glove.add_child(glove.visual)
	world.add_child(glove)
	glove.global_position = anchors[6] + Vector3(0.48, 0.04, 0.22)
	glove.picked.connect(_found_glove)
	errands.register_item(glove)
	if camp:
		camp.ensure_built()
		camp_spot = CampSpot.new()
		camp_spot.name = "ThreadGloveAtCamp"
		camp_spot.socket_id = "thread_camp"
		camp_spot.accepts = PackedStringArray(["glove"])
		world.add_child(camp_spot)
		camp_spot.global_position = camp.world_at(Camp.CRATE, 0.39) + Vector3(0.21, 0.0, 0.12)
		errands.register_socket(camp_spot)
	_refresh()


func _nearest_tree(target: Vector3, reach: float) -> Vector3:
	var near := trail.flora.nearest_indices(target, 1, reach)
	return trail.on_ground(trail.flora.trees[near[0]]) if not near.is_empty() else Vector3.INF


func _tree_near(target: Vector3, previous: Vector3, end: Vector3) -> Vector3:
	var best := trail.on_ground(target)
	for index: int in trail.flora.nearest_indices(target, 24, 8.5):
		var at: Vector3 = trail.flora.trees[index]
		var distance := Vector2(at.x - previous.x, at.z - previous.z).length()
		if distance >= 5.0 and distance <= 20.0 and at.distance_to(end) < previous.distance_to(end) - 3.0 and _ground_clearance(previous, at) > 0.35:
			return trail.on_ground(at)
	if _ground_clearance(previous, best) > 0.35:
		return best
	# A crest can hide a mathematically short next snag. Move it to the
	# near side of the rise, staying on the actual snow surface.
	var forward := (end - previous).normalized()
	forward.y = 0.0
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var best_score := INF
	for along in [-5.0, -3.0, 0.0, 3.0, 5.0]:
		for side in [-6.0, -3.0, 0.0, 3.0, 6.0]:
			var candidate := trail.on_ground(target + forward * along + right * side)
			var gap := Vector2(candidate.x - previous.x, candidate.z - previous.z).length()
			if gap < 4.0 or gap > 20.0 or _ground_clearance(previous, candidate) <= 0.35:
				continue
			var score := candidate.distance_to(target) + absf(gap - 10.0) * 0.2
			if score < best_score:
				best_score = score
				best = candidate
	return best


func _ground_clearance(from: Vector3, to: Vector3) -> float:
	var lowest := INF
	for sample in range(1, 20):
		var at := (from + Vector3.UP * 1.6).lerp(to + Vector3.UP * 0.95, float(sample) / 20.0)
		lowest = minf(lowest, at.y - trail.ground.height_at(at.x, at.z))
	return lowest


func _build_birch(world: Node3D, at: Vector3) -> void:
	birch = Node3D.new()
	birch.name = "ThreadBirch"
	world.add_child(birch)
	birch.global_position = at
	var bark := HouseKit.paint(Color("d0c9ae"), 0.98)
	var dark := HouseKit.paint(Color("39362f"), 0.9)
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.10
	shaft.bottom_radius = 0.17
	shaft.height = 3.6
	trunk.mesh = shaft
	trunk.material_override = bark
	trunk.position.y = 1.8
	birch.add_child(trunk)
	for y in [0.7, 1.15, 1.55, 2.1, 2.6]:
		HouseKit.box(birch, "BarkMark", Vector3(0, y, 0.14), Vector3(0.16, 0.02, 0.006), dark)
	for side in [-1.0, 1.0]:
		var branch := MeshInstance3D.new()
		branch.name = "BareBranch"
		var limb := CylinderMesh.new()
		limb.top_radius = 0.018
		limb.bottom_radius = 0.045
		limb.height = 1.65
		branch.mesh = limb
		branch.material_override = bark
		branch.position = Vector3(side * 0.55, 3.2, 0)
		branch.rotation.z = side * -0.7
		birch.add_child(branch)
	var initials := Label3D.new()
	initials.name = "Initials"
	initials.text = "O + M"
	initials.font_size = 32
	initials.pixel_size = 0.002
	initials.modulate = Color("33302b")
	initials.position = Vector3(0, 1.22, 0.17)
	birch.add_child(initials)


func _strand(world: Node3D, from: Vector3, to: Vector3) -> Node3D:
	var strand := Node3D.new()
	strand.name = "RedWool"
	world.add_child(strand)
	var wool := HouseKit.paint(Color("862b32"), 0.96)
	var last := from
	for segment in range(1, 5):
		var t := float(segment) / 4.0
		var next := from.lerp(to, t) - Vector3.UP * sin(t * PI) * 0.24
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.006
		mesh.bottom_radius = 0.006
		mesh.height = last.distance_to(next)
		var fibre := MeshInstance3D.new()
		fibre.mesh = mesh
		fibre.material_override = wool
		fibre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strand.add_child(fibre)
		fibre.global_position = (last + next) * 0.5
		fibre.basis = Basis(Quaternion(Vector3.UP, (next - last).normalized()))
		last = next
	return strand


func _mitten(colour: Color) -> Node3D:
	var root := Node3D.new()
	var material := HouseKit.paint(colour, 1.0)
	HouseKit.box(root, "Palm", Vector3(0, 0.035, 0), Vector3(0.15, 0.07, 0.21), material)
	HouseKit.box(root, "Thumb", Vector3(0.10, 0.032, -0.025), Vector3(0.08, 0.06, 0.09), material)
	HouseKit.box(root, "Cuff", Vector3(0, 0.035, 0.14), Vector3(0.16, 0.07, 0.07), material)
	return root


func wind(index: int) -> bool:
	if not window.done or errands.state_of(ID) == Errand.State.LET_GO or index != wound:
		return false
	if wound == 0 and errands.learn(ID) and Game.voice:
		Game.voice.errand("thread_first")
	wound += 1
	if wound == 1:
		errands.advance(ID, "follow")
	if wound == 5:
		errands.advance(ID, "birch")
	if wound == 2 and Game.voice:
		Game.voice.errand("thread_winding")
	ErrandKit.play(snags[index], "cloth", Loudness.CLOTH)
	_refresh()
	return true


func _found_glove() -> void:
	if wound != 5 or not errands.finish(ID):
		return
	Game.add_to_journal(NoteCatalog.thread())
	if Game.voice:
		Game.voice.errand("thread_glove")
	_refresh()


func tick() -> void:
	if window.done != _window_was_done or (initials and initials.brushed and glove and not glove.visible and wound == 5):
		_refresh()


func capture() -> Variant:
	return {"wound": wound, "branch_revealed": branch_revealed}


func restore(value: Variant) -> void:
	if value is Dictionary:
		wound = clampi(int(value.get("wound", 0)), 0, 5)
		branch_revealed = bool(value.get("branch_revealed", false))
	else:
		wound = clampi(int(value), 0, 5)
	_refresh()


func _refresh() -> void:
	_window_was_done = window.done
	for i in snags.size():
		var revealed := i != 1 or branch_revealed
		var active := window.done and i == wound and revealed and errands.state_of(ID) != Errand.State.LET_GO
		if active:
			snags[i].add_to_group("interactables")
		else:
			snags[i].remove_from_group("interactables")
		snags[i].visible = i == wound and revealed
	for i in strands.size():
		strands[i].visible = window.done and i >= wound and i <= wound
	initials.visible = wound == 5 and not initials.brushed
	if initials.visible:
		initials.add_to_group("interactables")
	else:
		initials.remove_from_group("interactables")
	glove.visible = (wound == 5 and initials.brushed) or errands.is_done(ID)
	glove.refresh_interaction()
