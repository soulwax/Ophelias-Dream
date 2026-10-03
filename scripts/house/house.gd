class_name House
extends Node3D

## The cabin she wakes in, now a real house. Local frame: +Z faces the trail,
## y = 0 is the ground-floor boards, which stand PLINTH above the snow.
##
## Ground floor: bedroom (where she wakes), entry hall with the front door,
## living room and kitchen, and a back hall where a straight stair goes down.
## Cellar: a limewashed landing and corridor, the janitor room, and the
## mortuary ported from merl. The cellar runs out under the snow beyond the
## walls; the terrain is flattened over it and holed only under the house.

const PLINTH := 0.4
# Ground-floor windows: wall centre at the boards and the yaw it faces out.
const WINDOWS := [
	[Vector3(-2.9, 0.0, 3.5), 0.0], [Vector3(2.9, 0.0, 3.5), 0.0], [Vector3(2.9, 0.0, -3.5), PI],
	[Vector3(-4.5, 0.0, 2.0), -PI * 0.5], [Vector3(4.5, 0.0, 1.8), PI * 0.5], [Vector3(4.5, 0.0, -1.5), PI * 0.5],
]
const WINDOW_NAMES := ["FrontWest", "FrontEast", "Back", "West", "EastFront", "EastBack"]
# Someone crossing the boards above the cellar, toward the head of the stair.
const STEPS_ABOVE: Array[Vector3] = [Vector3(-3.2, 0.2, 2.2), Vector3(-1.6, 0.2, 1.9), Vector3(-0.2, 0.2, 1.2), Vector3(0.1, 0.2, 0.0), Vector3(-0.6, 0.2, -1.1), Vector3(0.4, 0.2, -1.9), Vector3(0.9, 0.2, -2.6)]
const CEILING := 2.75
const WALL_TOP := 2.95
const EXTERIOR := 0.24
const PARTITION := 0.12
const MASONRY := 0.3
const CELLAR_FLOOR := -3.4
const CELLAR_CEILING := -0.75
# Kept a hand below the flattened snow so the cellar never shows through it.
const SLAB_TOP := -0.5
# Stair: top front edge at x = STAIR_TOP_X, down along -X to STAIR_BOTTOM_X.
const STAIR_TOP_X := 0.85
const STAIR_BOTTOM_X := -3.9
const STAIR_Z := -2.775
const STAIR_WIDTH := 1.1
const STAIR_STEPS := 19
const FOOTPRINT := Rect2(-4.62, -3.62, 9.24, 7.24)
# Cellar rooms (x/z).
const LANDING := Rect2(-6.2, -3.5, 2.45, 1.9)
const CORRIDOR := Rect2(-6.2, -1.6, 1.6, 7.5)
const JANITOR := Rect2(-9.2, -1.2, 3.0, 3.4)
const MORGUE := Rect2(-4.6, 0.6, 9.4, 5.3)
const MORGUE_DOOR_Z := 3.25
const JANITOR_DOOR_Z := 0.5
# Named spots for RUN_SPAWN, in house-local space: position, facing.
const SPAWNS := {
	"outside": [Vector3(2.5, -PLINTH, 15.0), Vector3(-0.15, 0.0, -1.0)],
	"bedroom": [Vector3(-2.7, 0.05, 1.7), Vector3(1.0, 0.0, 0.25)],
	"living": [Vector3(2.4, 0.05, 2.6), Vector3(0.3, 0.0, -1.0)],
	"stair": [Vector3(1.0, 0.05, -2.775), Vector3(-1.0, 0.0, 0.0)],
	"cellar": [Vector3(-5.2, CELLAR_FLOOR + 0.05, -2.8), Vector3(0.0, 0.0, 1.0)],
	"janitor": [Vector3(-5.6, CELLAR_FLOOR + 0.05, JANITOR_DOOR_Z), Vector3(-1.0, 0.0, 0.0)],
	"morgue": [Vector3(-4.2, CELLAR_FLOOR + 0.05, MORGUE_DOOR_Z), Vector3(1.0, 0.0, 0.1)],
}

var morgue: Morgue
var haunting: Haunting
# For the haunting: every door by name, the lamps of each room, the lantern.
var doors: Dictionary = {}
var room_lights: Dictionary = {}
var lantern_light: OmniLight3D
var _volumes: Array[AABB] = []
# Rooms by name, in house-local x/z; ground floor above y = -0.5.
const GROUND_ROOMS := {
	"bedroom": Rect2(-4.5, 0.4, 3.3, 3.1),
	"hall": Rect2(-1.2, 0.4, 2.4, 3.1),
	"living": Rect2(1.2, -3.5, 3.3, 7.0),
	"backhall": Rect2(-4.5, -3.5, 5.7, 3.9),
}
var _plank_out: Material
var _plank_floor: Material
var _plaster: Material
var _limewash: Material
var _concrete: Material
var _stone: Material
var _timber: Material


func _ready() -> void:
	_plank_out = HouseKit.scan("weathered_plank_siding", Color(0.62, 0.54, 0.47))
	_plank_floor = HouseKit.surface(HouseKit.scan("weathered_plank_siding", Color(0.55, 0.4, 0.29), 0.7), "wood")
	# Clean warm paint upstairs; the scanned plaster is grimy enough for the
	# cellar's limewash once lifted toward white.
	_plaster = HouseKit.paint(Color("d9d2c3"), 0.92)
	_limewash = HouseKit.scan("white_plaster_rough_01", Color(1.0, 1.0, 0.97), 1.4)
	_concrete = HouseKit.surface(HouseKit.scan("white_plaster_rough_01", Color(0.42, 0.42, 0.42), 2.0), "stone")
	_stone = HouseKit.surface(HouseKit.scan("white_plaster_rough_01", Color(0.45, 0.46, 0.48), 0.6), "stone")
	_timber = HouseKit.paint(Color("4a3222"), 0.8)
	_volumes = [
		AABB(Vector3(-4.5, -0.3, -3.5), Vector3(9.0, 3.2, 7.0)),
		AABB(Vector3(STAIR_BOTTOM_X - 0.1, CELLAR_FLOOR - 0.2, -3.5), Vector3(STAIR_TOP_X - STAIR_BOTTOM_X + 0.2, 3.7, 1.4)),
		_room_volume(LANDING),
		_room_volume(CORRIDOR),
		_room_volume(JANITOR),
		_room_volume(MORGUE),
	]
	_build_ground_floor()
	_build_roof()
	_build_stair()
	_build_cellar()
	_furnish()
	_light_house()
	haunting = Haunting.new()
	haunting.name = "Haunting"
	haunting.house = self
	add_child(haunting)


## Every window as [world centre, world outward normal]: where the wind
## whistles in. The Authoring/Windows markers are what you move; the glass
## stays with the wall openings.
func windows() -> Array:
	var found := []
	var markers := get_node_or_null("Authoring/Windows")
	if markers:
		for child in markers.get_children():
			if not child is Node3D:
				continue
			var marker := child as Node3D
			var outward := -marker.global_transform.basis.z
			outward.y = 0.0
			if outward.length_squared() < 0.0001:
				outward = global_transform.basis.z
			found.append([marker.global_position, outward.normalized()])
	if not found.is_empty():
		return found
	for spot in WINDOWS:
		var yaw: float = spot[1]
		var normal := (global_transform.basis * Vector3(sin(yaw), 0.0, cos(yaw))).normalized()
		found.append([to_global((spot[0] as Vector3) + Vector3(0.0, 1.47, 0.0)), normal])
	return found


## How the rooms answer what sounds in them, for Soundscape to build its
## reverb zones from: a short, soft ring in the timber rooms, a longer,
## harder one in the stone cellar. [[name, reverb bus, send, local boxes]].
func acoustic_zones() -> Array:
	return [
		["RoomTone", "Room", 0.32, [_volumes[0]]],
		["CellarTone", "Cellar", 0.5, _volumes.slice(1)],
	]


## Which room a point is in ("" outside the house). The Authoring/Rooms boxes
## are what you drag; the smallest one that holds the point wins.
func room_at(world_point: Vector3) -> String:
	var rooms := get_node_or_null("Authoring/Rooms")
	if rooms and rooms.get_child_count() > 0:
		var best := ""
		var best_volume := INF
		for child in rooms.get_children():
			var shape := child as CollisionShape3D
			if shape == null or not shape.shape is BoxShape3D:
				continue
			var box := shape.shape as BoxShape3D
			var local := shape.to_local(world_point)
			var half := box.size * 0.5
			if absf(local.x) > half.x + 0.06 or absf(local.y) > half.y + 0.06 or absf(local.z) > half.z + 0.06:
				continue
			var volume := box.size.x * box.size.y * box.size.z
			if volume < best_volume:
				best_volume = volume
				best = shape.name
		return best
	var local := to_local(world_point)
	if local.y > -0.6:
		for room in GROUND_ROOMS:
			if (GROUND_ROOMS[room] as Rect2).grow(0.06).has_point(Vector2(local.x, local.z)) and local.y < CEILING + 0.3:
				return room
		return ""
	var flat := Vector2(local.x, local.z)
	if local.x > STAIR_BOTTOM_X and local.x < 0.97 and local.z > -3.5 and local.z < -2.1:
		return "stair"
	for spec in [["landing", LANDING], ["corridor", CORRIDOR], ["janitor", JANITOR], ["morgue", MORGUE]]:
		if (spec[1] as Rect2).grow(0.06).has_point(flat):
			return spec[0]
	return ""


static func is_cellar(room: String) -> bool:
	return room in ["stair", "landing", "corridor", "janitor", "morgue"]


func _keep_light(room: String, lamp: OmniLight3D) -> void:
	if not room_lights.has(room):
		room_lights[room] = []
	(room_lights[room] as Array).append(lamp)


## True for points inside any room, ground floor or cellar.
func contains(world_point: Vector3) -> bool:
	if room_at(world_point) != "":
		return true
	var local := to_local(world_point)
	for volume in _volumes:
		if volume.grow(0.12).has_point(local):
			return true
	return false


## Where she wakes: beside the day bed, facing the bedroom door.
func spawn_point() -> Vector3:
	var spot := dev_spawn("bedroom")
	return spot[0] if not spot.is_empty() else to_global(Vector3(-2.7, 0.05, 1.7))


func spawn_facing() -> Vector3:
	var spot := dev_spawn("bedroom")
	return spot[1] if not spot.is_empty() else global_transform.basis * Vector3(1.0, 0.0, 0.25).normalized()


## Dev hook (RUN_SPAWN): [world position, world facing] for a named spot, or
## an empty array. The Authoring/Spawns markers are those spots.
func dev_spawn(where: String) -> Array:
	var marker := get_node_or_null("Authoring/Spawns/%s" % where) as Marker3D
	if marker:
		var facing := -marker.global_transform.basis.z
		facing.y = 0.0
		if facing.length_squared() < 0.0001:
			facing = global_transform.basis.z
		return [marker.global_position, facing.normalized()]
	if not SPAWNS.has(where):
		return []
	var spot: Array = SPAWNS[where]
	return [to_global(spot[0]), global_transform.basis * (spot[1] as Vector3).normalized()]


## World points along the boards above the cellar. The path is
## Authoring/StepsAbove.
func steps_above() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var path := get_node_or_null("Authoring/StepsAbove") as Path3D
	if path and path.curve and path.curve.point_count > 0:
		for index in path.curve.point_count:
			points.append(path.to_global(path.curve.get_point_position(index)))
		return points
	for point in STEPS_ABOVE:
		points.append(to_global(point))
	return points


## Markers, the overhead path and the reverb areas. Appended last so an
## existing editable level keeps every earlier child where it was.
func add_authoring() -> void:
	if get_node_or_null("Authoring"):
		return
	var root := Node3D.new()
	root.name = "Authoring"
	root.add_to_group(EditableLevel.AUTHORING_GROUP)
	add_child(root)
	var spawns := Node3D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)
	for spot_name in SPAWNS:
		var spot: Array = SPAWNS[spot_name]
		_marker(spawns, spot_name, spot[0], spot[1], 0.45)
	var windows := Node3D.new()
	windows.name = "Windows"
	root.add_child(windows)
	for index in WINDOWS.size():
		var spot: Array = WINDOWS[index]
		var yaw: float = spot[1]
		var outward := Vector3(sin(yaw), 0.0, cos(yaw))
		var label: String = WINDOW_NAMES[index] if index < WINDOW_NAMES.size() else "Window%d" % index
		_marker(windows, label, (spot[0] as Vector3) + Vector3(0.0, 1.47, 0.0), outward, 0.35)
	var path := Path3D.new()
	path.name = "StepsAbove"
	var curve := Curve3D.new()
	for point in STEPS_ABOVE:
		curve.add_point(point)
	path.curve = curve
	root.add_child(path)
	_reverb_area(root, "RoomTone", "Room", 0.32, [_volumes[0]])
	_reverb_area(root, "CellarTone", "Cellar", 0.5, _volumes.slice(1))
	var rooms := Node3D.new()
	rooms.name = "Rooms"
	rooms.add_to_group(EditableLevel.AUTHORING_GROUP)
	root.add_child(rooms)
	for room_name in GROUND_ROOMS:
		_room_box(rooms, room_name, GROUND_ROOMS[room_name] as Rect2, -0.5, CEILING)
	_room_box(rooms, "stair", Rect2(STAIR_BOTTOM_X, -3.5, 0.97 - STAIR_BOTTOM_X, 1.4), CELLAR_FLOOR - 0.2, -0.55)
	_room_box(rooms, "landing", LANDING, CELLAR_FLOOR - 0.2, -0.55)
	_room_box(rooms, "corridor", CORRIDOR, CELLAR_FLOOR - 0.2, -0.55)
	_room_box(rooms, "janitor", JANITOR, CELLAR_FLOOR - 0.2, -0.55)
	_room_box(rooms, "morgue", MORGUE, CELLAR_FLOOR - 0.2, -0.55)
	_marker(root, "Doorstep", Vector3(0.0, -PLINTH, 6.5), Vector3(0.0, 0.0, 1.0), 0.45)
	var doorstep_marker := root.get_node_or_null("Doorstep")
	if doorstep_marker:
		doorstep_marker.add_to_group(EditableLevel.AUTHORING_GROUP)
	_add_traces(root)


## Pages and objects that disagree with the trail notes. Last under Authoring,
## and itself authoring, so an older snapshot keeps the whole set.
func _add_traces(authoring: Node3D) -> void:
	var traces := Node3D.new()
	traces.name = "Traces"
	traces.add_to_group(EditableLevel.AUTHORING_GROUP)
	authoring.add_child(traces)
	_trace_page(traces, "NightstandPage", Vector3(-3.85, 0.68, 2.82), NoteCatalog.bedside())
	var desk := _morgue_desk()
	_trace_page(traces, "Intake", desk + Vector3(0.12, 0.76, -0.08), NoteCatalog.intake())
	var wax := HouseKit.paint(Color(0.86, 0.78, 0.62), 0.55)
	var soot := HouseKit.paint(Color(0.12, 0.1, 0.09), 0.85)
	HouseKit.box(traces, "CandleStub", Vector3(-4.28, 0.655, 2.78), Vector3(0.045, 0.07, 0.045), wax)
	HouseKit.box(traces, "CandleSoot", Vector3(-4.28, 0.695, 2.78), Vector3(0.04, 0.018, 0.04), soot)
	var wool := HouseKit.paint(Color(0.38, 0.16, 0.14), 0.92)
	HouseKit.box(traces, "Mat", Vector3(0.0, -0.004, 3.95), Vector3(0.92, 0.012, 0.48), wool)


func _trace_page(parent: Node3D, page_name: String, at: Vector3, entry: NoteEntry) -> void:
	var page := FieldNote.new()
	page.name = page_name
	page.entry = entry
	page.position = at
	parent.add_child(page)


func _morgue_desk() -> Vector3:
	var room := MORGUE.grow(-MASONRY * 0.5)
	return Vector3(room.position.x + 1.2, CELLAR_FLOOR, room.end.y - 0.55)


func _marker(parent: Node3D, marker_name: String, at: Vector3, facing: Vector3, extent: float) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.gizmo_extents = extent
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	marker.transform = Transform3D(Basis.looking_at(flat.normalized(), Vector3.UP), at)
	parent.add_child(marker)


func _room_box(parent: Node3D, room_name: String, rect: Rect2, y0: float, y1: float) -> void:
	var shape := CollisionShape3D.new()
	shape.name = room_name
	var box := BoxShape3D.new()
	var height := maxf(0.2, y1 - y0)
	box.size = Vector3(rect.size.x, height, rect.size.y)
	shape.shape = box
	shape.position = Vector3(rect.position.x + rect.size.x * 0.5, (y0 + y1) * 0.5, rect.position.y + rect.size.y * 0.5)
	shape.debug_color = Color(0.45, 0.62, 0.85, 0.28)
	shape.debug_fill = true
	parent.add_child(shape)


func _reverb_area(parent: Node3D, area_name: String, bus: String, amount: float, boxes: Array) -> void:
	var area := Area3D.new()
	area.name = area_name
	area.monitoring = false
	area.monitorable = true
	area.collision_layer = 1
	area.collision_mask = 0
	area.reverb_bus_enabled = true
	area.reverb_bus_name = bus
	area.reverb_bus_amount = amount
	area.reverb_bus_uniformity = 0.4
	for box in boxes:
		var volume: AABB = box
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = volume.size
		shape.shape = cube
		shape.position = volume.get_center()
		area.add_child(shape)
	parent.add_child(area)


## Out in the snow in front of the door: where something waits.
func doorstep() -> Vector3:
	var marker := get_node_or_null("Authoring/Doorstep") as Marker3D
	if marker:
		return marker.global_position
	return to_global(Vector3(0.0, -PLINTH, 6.5))


## The stair well, which the terrain must not cross.
static func stair_cut() -> Rect2:
	return Rect2(STAIR_BOTTOM_X - 0.2, -3.6, 0.97 - STAIR_BOTTOM_X + 0.4, 1.6)


## The terrain leaves out whole 3 m cells around the stair well; outside the
## walls this level snow fills them back in, a centimetre under the real snow
## so it only shows where the terrain is gone. Same depth as the field.
func add_snow_patch(snow: Material) -> void:
	var root := _group("SnowPatch")
	# Only as far as a cell the cut can remove: one 3 m cell diagonal.
	var around := stair_cut().grow(4.5)
	var top := -PLINTH - 0.01
	HouseKit.slab(root, "Snow", around, top - Tune.SNOW_DEPTH, top, snow, [FOOTPRINT])


func _room_volume(rect: Rect2) -> AABB:
	return AABB(Vector3(rect.position.x, CELLAR_FLOOR - 0.2, rect.position.y), Vector3(rect.size.x, CELLAR_CEILING - CELLAR_FLOOR + 0.2, rect.size.y))


# --- Ground floor -----------------------------------------------------------

func _build_ground_floor() -> void:
	var root := _group("GroundFloor")
	# Stone plinth from below the snow to the boards.
	for side in [[Vector2(-4.62, 3.62), Vector2(4.62, 3.62)], [Vector2(4.62, -3.62), Vector2(-4.62, -3.62)], [Vector2(-4.62, -3.38), Vector2(-4.62, 3.38)], [Vector2(4.62, 3.38), Vector2(4.62, -3.38)]]:
		# Only a hand under the snow: any deeper and it hangs through the
		# ceiling of the mortuary, which runs out beneath the front of the house.
		HouseKit.wall(root, "Plinth", side[0], side[1], SLAB_TOP, 0.0, EXTERIOR + 0.04, _stone)
	var inner := Rect2(-4.5, -3.5, 9.0, 7.0)
	var stair_hole := Rect2(STAIR_BOTTOM_X, STAIR_Z - STAIR_WIDTH * 0.5, STAIR_TOP_X - STAIR_BOTTOM_X, STAIR_WIDTH)
	HouseKit.slab(root, "Floor", inner, -0.25, 0.0, _plank_floor, [stair_hole])
	HouseKit.slab(root, "Ceiling", inner, CEILING, CEILING + 0.15, HouseKit.scan("weathered_plank_siding", Color(0.7, 0.6, 0.5), 0.7))
	# Exterior walls: planks outside, plaster inside.
	var window := {"width": 0.9, "height": 1.15, "sill": 0.9}
	HouseKit.wall(root, "FrontWall", Vector2(-4.62, 3.5), Vector2(4.62, 3.5), 0.0, WALL_TOP, EXTERIOR, _plank_out, [
		{"at": 4.62, "width": 1.0, "height": 2.1},
		_at(window, 1.72), _at(window, 7.52)], _plaster, _plank_out)
	HouseKit.wall(root, "BackWall", Vector2(4.62, -3.5), Vector2(-4.62, -3.5), 0.0, WALL_TOP, EXTERIOR, _plank_out, [_at(window, 1.72)], _plaster, _plank_out)
	HouseKit.wall(root, "WestWall", Vector2(-4.5, -3.38), Vector2(-4.5, 3.38), 0.0, WALL_TOP, EXTERIOR, _plank_out, [_at(window, 5.38)], _plaster, _plank_out)
	HouseKit.wall(root, "EastWall", Vector2(4.5, 3.38), Vector2(4.5, -3.38), 0.0, WALL_TOP, EXTERIOR, _plank_out, [_at(window, 1.58), _at(window, 4.88)], _plaster, _plank_out)
	for spot in WINDOWS:
		_glaze(root, spot[0], spot[1], window)
	# Partitions.
	HouseKit.wall(root, "BedroomWall", Vector2(-1.2, 0.4), Vector2(-1.2, 3.44), 0.0, CEILING, PARTITION, _plaster, [{"at": 1.6, "width": 0.92, "height": 2.05}])
	HouseKit.wall(root, "LivingWall", Vector2(1.2, -3.44), Vector2(1.2, 3.44), 0.0, CEILING, PARTITION, _plaster, [{"at": 5.44, "width": 0.92, "height": 2.05}, {"at": 2.44, "width": 1.2, "height": 2.15}])
	HouseKit.wall(root, "BackHallWall", Vector2(-4.44, 0.4), Vector2(1.14, 0.4), 0.0, CEILING, PARTITION, _plaster, [{"at": 4.44, "width": 0.92, "height": 2.05}])
	# Doors: front, bedroom, living room, back hall.
	doors["front"] = HouseDoor.make(root, "FrontDoor", Vector3(0.0, 0.0, 3.5), 0.0, Vector3(0.98, 2.08, 0.05), "plank", _timber, -1.0, 100.0, "Front door")
	doors["bedroom"] = HouseDoor.make(root, "BedroomDoor", Vector3(-1.2, 0.0, 2.0), PI * 0.5, Vector3(0.9, 2.03, 0.045), "plank", _timber, 1.0, 95.0, "Bedroom door")
	doors["living"] = HouseDoor.make(root, "LivingDoor", Vector3(1.2, 0.0, 2.0), -PI * 0.5, Vector3(0.9, 2.03, 0.045), "plank", _timber, -1.0, 95.0, "Living room door")
	doors["backhall"] = HouseDoor.make(root, "CellarHallDoor", Vector3(0.0, 0.0, 0.4), 0.0, Vector3(0.9, 2.03, 0.045), "plank", _timber, 1.0, 95.0, "Back hall door")
	# Porch: a landing and a step down to the snow.
	HouseKit.solid(root, "PorchLanding", Vector3(0.0, -0.11, 3.95), Vector3(2.0, 0.2, 0.66), _stone)
	HouseKit.solid(root, "PorchStep", Vector3(0.0, -0.31, 4.46), Vector3(1.8, 0.2, 0.36), _stone)


func _at(spec: Dictionary, along: float) -> Dictionary:
	var copy := spec.duplicate()
	copy["at"] = along
	return copy


func _glaze(root: Node3D, at: Vector3, yaw: float, spec: Dictionary) -> void:
	var center := at + Vector3(0.0, float(spec["sill"]) + float(spec["height"]) * 0.5, 0.0)
	var w: float = spec["width"]
	var h: float = spec["height"]
	HouseKit.box(root, "Glass", center, Vector3(w, h, 0.012), HouseKit.glass(), yaw)
	var frame := HouseKit.paint(Color("e6e0d2"), 0.6)
	var sides := [[Vector3(0.0, h * 0.5, 0.0), Vector3(w + 0.08, 0.06, 0.1)], [Vector3(0.0, -h * 0.5, 0.0), Vector3(w + 0.12, 0.07, 0.18)], [Vector3(w * 0.5, 0.0, 0.0), Vector3(0.06, h, 0.1)], [Vector3(-w * 0.5, 0.0, 0.0), Vector3(0.06, h, 0.1)], [Vector3.ZERO, Vector3(w, 0.035, 0.05)], [Vector3.ZERO, Vector3(0.035, h, 0.05)]]
	var basis := Basis(Vector3.UP, yaw)
	for index in sides.size():
		HouseKit.box(root, "Frame_%d" % index, center + basis * (sides[index][0] as Vector3), sides[index][1], frame, yaw)


# --- Roof -------------------------------------------------------------------

func _build_roof() -> void:
	var root := _group("Roof")
	var slate := HouseKit.scan("roof_slates_02", Color(0.42, 0.44, 0.47))
	var rise := 2.0
	var half := 3.62
	var overhang := 0.5
	var angle := atan2(rise, half)
	var length := (half + overhang) / cos(angle)
	var ridge := Vector3(0.0, WALL_TOP + rise + 0.08, 0.0)
	for side in [1.0, -1.0]:
		var down := Vector3(0.0, -sin(angle), side * cos(angle))
		var plane := MeshInstance3D.new()
		plane.name = "RoofPlane_%d" % int(side)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(FOOTPRINT.size.x + 0.8, 0.14, length)
		plane.mesh = mesh
		plane.material_override = slate
		plane.transform = Transform3D(Basis(Vector3.RIGHT, angle * side), ridge + down * length * 0.5)
		root.add_child(plane)
		var body := StaticBody3D.new()
		body.collision_layer = Tune.LAYER_WORLD
		body.transform = plane.transform
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.size
		shape.shape = box
		body.add_child(shape)
		root.add_child(body)
	HouseKit.box(root, "Ridge", ridge + Vector3(0.0, 0.06, 0.0), Vector3(FOOTPRINT.size.x + 0.85, 0.12, 0.22), HouseKit.paint(Color("2f3236"), 0.7))
	for x in [FOOTPRINT.position.x + 0.05, FOOTPRINT.end.x - 0.05]:
		_gable(root, x, rise, half)
	# A stone chimney stack at the east gable.
	HouseKit.solid(root, "Chimney", Vector3(3.6, WALL_TOP + 1.6, -0.9), Vector3(0.7, 3.4, 0.6), _stone)
	HouseKit.box(root, "ChimneyCap", Vector3(3.6, WALL_TOP + 3.34, -0.9), Vector3(0.82, 0.08, 0.72), HouseKit.paint(Color("2f3236"), 0.7))


## A triangular gable of planks above the wall top.
func _gable(root: Node3D, x: float, rise: float, half: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depth := EXTERIOR * 0.5
	var points := [Vector3(0.0, WALL_TOP, -half), Vector3(0.0, WALL_TOP, half), Vector3(0.0, WALL_TOP + rise, 0.0)]
	for face in [-1.0, 1.0]:
		var ox: float = float(face) * depth
		var a: Vector3 = points[0] + Vector3(ox, 0, 0)
		var b: Vector3 = points[1] + Vector3(ox, 0, 0)
		var c: Vector3 = points[2] + Vector3(ox, 0, 0)
		if face > 0.0:
			for v in [a, c, b]:
				tool.add_vertex(v)
		else:
			for v in [a, b, c]:
				tool.add_vertex(v)
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "Gable"
	mesh.mesh = tool.commit()
	mesh.material_override = _plank_out
	mesh.position.x = x
	root.add_child(mesh)


# --- Stair ------------------------------------------------------------------

func _build_stair() -> void:
	var root := _group("Stair")
	HouseKit.stair(root, "Flight", Vector3(STAIR_TOP_X, 0.0, STAIR_Z), Vector3(STAIR_BOTTOM_X, CELLAR_FLOOR, STAIR_Z), STAIR_WIDTH, STAIR_STEPS, _plank_floor, _timber)
	# Railing along the open side of the well on the ground floor.
	var rail_z := STAIR_Z + STAIR_WIDTH * 0.5 + 0.05
	HouseKit.solid(root, "Handrail", Vector3((STAIR_BOTTOM_X + 0.55) * 0.5, 0.95, rail_z), Vector3(0.55 - STAIR_BOTTOM_X, 0.06, 0.06), _timber)
	HouseKit.blocker(root, "RailGuard", Vector3((STAIR_BOTTOM_X + 0.55) * 0.5, 0.5, rail_z), Vector3(0.55 - STAIR_BOTTOM_X, 1.0, 0.08))
	var post := 0
	var x := STAIR_BOTTOM_X
	while x <= 0.56:
		HouseKit.box(root, "Baluster_%d" % post, Vector3(x, 0.47, rail_z), Vector3(0.035, 0.94, 0.035), _timber)
		x += 0.14
		post += 1


# --- Cellar -----------------------------------------------------------------

func _build_cellar() -> void:
	var root := _group("Cellar")
	var top := SLAB_TOP
	var well_top := -0.25
	var walls := [
		# Landing and stair well.
		["LandingSouth", Vector2(-6.35, -3.5), Vector2(1.12, -3.5), top, []],
		["LandingNorth", Vector2(-4.6, -1.6), Vector2(-3.6, -1.6), well_top, []],
		["WellJog", Vector2(-3.75, -1.6), Vector2(-3.75, -2.1), well_top, []],
		["WellNorth", Vector2(-3.75, -2.1), Vector2(1.12, -2.1), well_top, []],
		["WellEast", Vector2(0.97, -2.1), Vector2(0.97, -3.5), well_top, []],
		# Corridor, with the janitor door to the west.
		["CorridorWest", Vector2(-6.2, -3.65), Vector2(-6.2, 6.05), top, [{"at": JANITOR_DOOR_Z + 3.65, "width": 0.92, "height": 2.05, "sill": 0.2}]],
		["CorridorNorth", Vector2(-6.35, 5.9), Vector2(-4.45, 5.9), top, []],
		["MorgueWest", Vector2(-4.6, -1.6), Vector2(-4.6, 6.05), top, [{"at": MORGUE_DOOR_Z + 1.6, "width": 1.2, "height": 2.15, "sill": 0.2}]],
		# Janitor room.
		["JanitorNorth", Vector2(-9.35, 2.2), Vector2(-6.2, 2.2), top, []],
		["JanitorSouth", Vector2(-9.35, -1.2), Vector2(-6.2, -1.2), top, []],
		["JanitorWest", Vector2(-9.2, -1.2), Vector2(-9.2, 2.2), top, []],
		# Mortuary.
		["MorgueSouth", Vector2(-4.6, 0.6), Vector2(4.95, 0.6), top, []],
		["MorgueEast", Vector2(4.8, 0.6), Vector2(4.8, 5.9), top, []],
		["MorgueNorth", Vector2(-4.6, 5.9), Vector2(4.95, 5.9), top, []],
	]
	for spec in walls:
		HouseKit.wall(root, spec[0], spec[1], spec[2], CELLAR_FLOOR - 0.2, spec[3], MASONRY, _stone, spec[4], _limewash, _limewash)
	var well := Rect2(STAIR_BOTTOM_X, -3.5, STAIR_TOP_X - STAIR_BOTTOM_X + 0.12, 1.4)
	for rect in [LANDING, CORRIDOR, JANITOR, MORGUE, well]:
		HouseKit.slab(root, "CellarFloor", rect, CELLAR_FLOOR - 0.2, CELLAR_FLOOR, _concrete)
	for rect in [LANDING, CORRIDOR, JANITOR, MORGUE]:
		HouseKit.slab(root, "CellarCeiling", rect, CELLAR_CEILING, SLAB_TOP, _limewash)
	doors["janitor"] = HouseDoor.make(root, "JanitorDoor", Vector3(-6.2, CELLAR_FLOOR, JANITOR_DOOR_Z), PI * 0.5, Vector3(0.9, 2.03, 0.045), "plank", HouseKit.paint(Color("3d4a52"), 0.75), 1.0, 95.0, "Janitor's door")
	doors["morgue"] = HouseDoor.make(root, "MorgueDoor", Vector3(-4.6, CELLAR_FLOOR, MORGUE_DOOR_Z), -PI * 0.5, Vector3(1.18, 2.13, 0.05), "steel", null, -1.0, 100.0, "Mortuary door")
	_janitor_room(root)
	morgue = Morgue.new()
	morgue.name = "Morgue"
	# Finishes go on the inner faces of the masonry, not its centre line.
	morgue.room = MORGUE.grow(-MASONRY * 0.5)
	morgue.floor_y = CELLAR_FLOOR
	morgue.ceiling_y = CELLAR_CEILING
	morgue.door_on_west = MORGUE_DOOR_Z
	root.add_child(morgue)
	morgue.build()
	var tubes: Array[Node3D] = morgue.tubes
	WallSwitch.make(root, "MortuaryLightSwitch", Vector3(MORGUE.position.x + MASONRY * 0.5 + 0.02, CELLAR_FLOOR + 1.15, MORGUE_DOOR_Z - 0.85), PI * 0.5, "Mortuary lights", morgue.lights, tubes)


func _janitor_room(root: Node3D) -> void:
	var floor_y := CELLAR_FLOOR
	var room := JANITOR.grow(-MASONRY * 0.5)
	var steel := HouseKit.paint(Color("8f9396"), 0.4, 0.8)
	# A deep slop sink on the north wall, a duckboard, steel shelving.
	var sink_at := Vector3(room.position.x + 0.9, floor_y, room.end.y - 0.35)
	HouseKit.solid(root, "SlopSink", sink_at + Vector3(0.0, 0.45, 0.0), Vector3(0.7, 0.5, 0.5), HouseKit.paint(Color("d8d6cf"), 0.3))
	HouseKit.box(root, "SlopSinkBasin", sink_at + Vector3(0.0, 0.66, 0.0), Vector3(0.6, 0.1, 0.4), HouseKit.paint(Color("6f7276"), 0.25, 0.6))
	HouseKit.box(root, "SlopTap", sink_at + Vector3(0.0, 1.0, -0.2), Vector3(0.03, 0.22, 0.03), steel)
	HouseKit.box(root, "Duckboard", sink_at + Vector3(0.0, 0.02, -0.55), Vector3(0.8, 0.04, 0.5), _timber)
	var shelf_x := room.end.x - 0.32
	for tier in 4:
		HouseKit.box(root, "Shelf_%d" % tier, Vector3(shelf_x, floor_y + 0.3 + tier * 0.45, room.get_center().y - 0.2), Vector3(0.45, 0.025, 1.6), steel)
	for corner in [-0.78, 0.78]:
		for post in [-0.2, 0.2]:
			HouseKit.box(root, "ShelfPost", Vector3(shelf_x + post, floor_y + 0.9, room.get_center().y - 0.2 + corner), Vector3(0.03, 1.8, 0.03), steel)
	HouseKit.blocker(root, "ShelfBody", Vector3(shelf_x, floor_y + 0.9, room.get_center().y - 0.2), Vector3(0.45, 1.8, 1.6))
	HouseKit.prop(root, "bleach_bottle", Vector3(shelf_x, floor_y + 0.765, room.get_center().y - 0.6))
	HouseKit.prop(root, "bleach_bottle", Vector3(shelf_x - 0.05, floor_y + 0.765, room.get_center().y - 0.45), 40.0)
	HouseKit.prop(root, "wicker_basket_01", Vector3(shelf_x, floor_y + 1.215, room.get_center().y + 0.2), 0.0, 0.8)
	HouseKit.prop(root, "metal_trash_can", Vector3(room.position.x + 0.45, floor_y, room.position.y + 0.45))
	HouseKit.prop(root, "trashbag", Vector3(room.position.x + 1.1, floor_y, room.position.y + 0.4), 30.0)
	HouseKit.prop(root, "WetFloorSign_01", Vector3(room.get_center().x, floor_y, room.position.y + 0.8), -20.0)
	# A galvanised mop bucket with the mop leaning in it.
	var bucket := Vector3(room.get_center().x - 0.4, floor_y, room.get_center().y + 0.5)
	HouseKit.solid(root, "MopBucket", bucket + Vector3(0.0, 0.17, 0.0), Vector3(0.38, 0.34, 0.3), HouseKit.paint(Color("9aa0a3"), 0.35, 0.85))
	var mop := HouseKit.box(root, "MopHandle", bucket + Vector3(0.12, 0.85, 0.0), Vector3(0.025, 1.3, 0.025), HouseKit.paint(Color("8a6a4a"), 0.7))
	mop.rotation.z = -0.22


# --- Furniture and lights ---------------------------------------------------

func _furnish() -> void:
	var root := _group("Furniture")
	# Bedroom: where she wakes.
	HouseKit.prop(root, "vintage_day_bed", Vector3(-3.75, 0.0, 1.55), 90.0)
	HouseKit.prop(root, "painted_wooden_nightstand", Vector3(-4.1, 0.0, 2.95), 90.0)
	HouseKit.prop(root, "Lantern_01", Vector3(-4.1, 0.62, 2.95))
	HouseKit.prop(root, "wicker_basket_01", Vector3(-1.75, 0.0, 0.85))
	# Living room and kitchen.
	HouseKit.prop(root, "sofa_02", Vector3(3.85, 0.0, 1.9), -90.0)
	HouseKit.prop(root, "wooden_table_02", Vector3(2.9, 0.0, -1.7))
	HouseKit.prop(root, "painted_wooden_chair_01", Vector3(2.1, 0.0, -1.7), 90.0)
	HouseKit.prop(root, "painted_wooden_chair_01", Vector3(3.7, 0.0, -1.7), -90.0)
	HouseKit.prop(root, "tea_set_01", Vector3(2.9, 0.76, -1.7))
	HouseKit.prop(root, "wooden_bookshelf_worn", Vector3(1.48, 0.0, 0.4), 90.0)
	HouseKit.prop(root, "GothicCabinet_01", Vector3(4.2, 0.0, -2.9), -90.0)
	for blocker in [[Vector3(3.85, 0.4, 1.9), Vector3(0.9, 0.8, 2.0)], [Vector3(2.9, 0.38, -1.7), Vector3(1.4, 0.76, 0.85)], [Vector3(-3.75, 0.3, 1.55), Vector3(0.95, 0.6, 2.0)]]:
		HouseKit.blocker(root, "FurnitureBody", blocker[0], blocker[1])


## Most of the house is dark. The lantern by the bed where she wakes, one
## weak bulb in the hall, one over the kitchen table; the living room and back
## hall are unlit. Below, a bulkhead at the foot of the stair and at the near
## end of the corridor; its far end, by the mortuary door, is dark. The
## janitor's bulb is bare and dim; the mortuary has its fluorescents.
func _light_house() -> void:
	var root := _group("Lights")
	var warm := Color("ffc88a")
	lantern_light = HouseKit.light(root, "LanternLight", Vector3(-4.1, 0.95, 2.95), Color("ffb060"), 1.1, 5.0)
	_keep_light("bedroom", lantern_light)
	for spot in [[Vector3(0.0, CEILING - 0.3, 1.9), "Hall", "hall", 0.45, true], [Vector3(2.85, CEILING - 0.3, -1.6), "Kitchen", "living", 0.6, true], [Vector3(2.85, CEILING - 0.3, 2.0), "Living", "living", 0.6, false], [Vector3(-1.8, CEILING - 0.3, -1.4), "BackHall", "backhall", 0.55, false]]:
		var at: Vector3 = spot[0]
		var lit: bool = spot[4]
		HouseKit.box(root, "%sBulb" % spot[1], at + Vector3(0.0, 0.12, 0.0), Vector3(0.12, 0.14, 0.12), HouseKit.glow(warm, 2.0) if lit else HouseKit.paint(Color("b8ab90"), 0.3))
		HouseKit.box(root, "%sFlex" % spot[1], at + Vector3(0.0, 0.3, 0.0), Vector3(0.01, 0.3, 0.01), HouseKit.paint(Color("1a1a1a"), 0.5))
		if lit:
			_keep_light(spot[2], HouseKit.light(root, "%sLight" % spot[1], at, warm, spot[3], 5.0))
	var cold := Color("ffe2b0")
	for spot in [[Vector3(-5.0, CELLAR_CEILING - 0.12, -2.6), "Landing", "landing", 0.5, true], [Vector3(-5.4, CELLAR_CEILING - 0.12, 0.6), "CorridorSouth", "corridor", 0.45, true], [Vector3(-5.4, CELLAR_CEILING - 0.12, 4.4), "CorridorNorth", "corridor", 0.45, false], [Vector3(-7.7, CELLAR_CEILING - 0.18, 0.5), "Janitor", "janitor", 0.4, true]]:
		var at: Vector3 = spot[0]
		var lit: bool = spot[4]
		HouseKit.box(root, "%sBulkhead" % spot[1], at, Vector3(0.16, 0.1, 0.16), HouseKit.glow(cold, 1.4) if lit else HouseKit.paint(Color("3a3a36"), 0.4))
		if lit:
			_keep_light(spot[2], HouseKit.light(root, "%sLight" % spot[1], at + Vector3(0.0, -0.15, 0.0), cold, spot[3], 5.0))
	for lamp in morgue.lights:
		_keep_light("morgue", lamp as OmniLight3D)


func _group(group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	add_child(node)
	return node
