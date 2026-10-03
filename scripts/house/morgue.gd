class_name Morgue
extends Node3D

## The mortuary in the cellar, ported from merl's prototype house: coved grey
## floor tile with a drain, white glazed wall tile with a pale green band at
## eye level, a stainless autopsy table, a three-tap scrub trough, an
## instrument trolley, a records desk, and a bank of six refrigerated body
## chambers whose doors open on dark chambers with sliding trays. Cold
## fluorescent tubes hang in pairs; one fitting stutters now and then.
##
## Built inside `room` (x/z, local to the house) between floor_y and
## ceiling_y; the house supplies the masonry walls and the door.

var room := Rect2()
var floor_y := 0.0
var ceiling_y := 2.7
var door_on_west := 0.0
var lights: Array[Light3D] = []
var tubes: Array[Node3D] = []
# For the haunting: the chamber doors, the trough taps that drip, and a body
# under a sheet on the table that is not there the first time she comes down.
var chambers: Array[HouseDoor] = []
var sink_at := Vector3.ZERO
var body: Node3D

var _flicker: OmniLight3D
var _flicker_energy := 1.0
var _flicker_timer := 3.0
var _flicker_burst := 0
var _steel: StandardMaterial3D


func build() -> void:
	_steel = HouseKit.paint(Color("a7abae"), 0.32, 0.9)
	_finishes()
	var center := Vector3(room.get_center().x, floor_y, room.get_center().y)
	var drain := center + Vector3(0.6, 0.013, -0.1)
	HouseKit.box(self, "DrainRecess", drain, Vector3(0.34, 0.004, 0.34), HouseKit.paint(Color("0e0f10"), 0.6))
	for bar in range(7):
		HouseKit.box(self, "DrainBar_%d" % bar, drain + Vector3(-0.15 + bar * 0.05, 0.004, 0.0), Vector3(0.018, 0.006, 0.32), _steel)
	_autopsy_table(center + Vector3(0.6, 0.0, -0.1))
	# Trough along the east wall, facing into the room.
	_scrub_sink(Vector3(room.end.x, floor_y, center.z - 0.6), PI)
	sink_at = Vector3(room.end.x - 0.3, floor_y + 0.95, center.z - 0.6)
	_instrument_trolley(Vector3(room.end.x - 1.6, floor_y, room.position.y + 0.7))
	# The chamber bank against the far wall, doors facing back into the room.
	_cold_chambers(Vector3(center.x + 1.4, floor_y, room.end.y), PI)
	var desk := HouseKit.prop(self, "metal_office_desk", Vector3(room.position.x + 1.2, floor_y, room.end.y - 0.55), 180.0, 0.8)
	desk.name = "RecordsDesk"
	HouseKit.prop(self, "WetFloorSign_01", Vector3(center.x - 1.6, floor_y, room.position.y + 0.9), 28.0)
	HouseKit.prop(self, "bleach_bottle", Vector3(room.end.x - 1.33, floor_y + 0.91, room.position.y + 0.65))
	HouseKit.prop(self, "medical_box", Vector3(room.end.x - 1.75, floor_y + 0.91, room.position.y + 0.7), 0.0, 0.8)
	_fluorescents()


func _process(delta: float) -> void:
	# Occasional stutter: long steady spells broken by a few rapid dips.
	if _flicker == null or not _flicker.visible:
		return
	_flicker_timer -= delta
	if _flicker_timer > 0.0:
		return
	if _flicker_burst > 0:
		_flicker_burst -= 1
		var dim := _flicker_burst % 2 == 1
		_flicker.light_energy = _flicker_energy * (randf_range(0.05, 0.4) if dim else 1.0)
		_flicker_timer = randf_range(0.03, 0.14)
	else:
		_flicker.light_energy = _flicker_energy
		_flicker_burst = randi_range(4, 8)
		_flicker_timer = randf_range(4.0, 11.0)


func _finishes() -> void:
	# Cool clinical grey floor tile, white glazed wall tile with a softened
	# normal so the tubes do not draw moire arcs, a pale green band, paint above.
	var floor_tile := HouseKit.scan("floor_tiles_08", Color(0.6, 0.66, 0.7)).duplicate() as ORMMaterial3D
	var wall_tile := HouseKit.scan("long_white_tiles", Color(0.96, 0.98, 0.98)).duplicate() as ORMMaterial3D
	wall_tile.normal_scale = 0.25
	var band := HouseKit.paint(Color("9fb8ae"), 0.25)
	var ceiling := HouseKit.paint(Color("dfe2de"), 0.85)
	var center := room.get_center()
	var height := ceiling_y - floor_y
	HouseKit.box(self, "FloorTile", Vector3(center.x, floor_y + 0.006, center.y), Vector3(room.size.x, 0.012, room.size.y), floor_tile)
	HouseKit.box(self, "CeilingPaint", Vector3(center.x, ceiling_y - 0.004, center.y), Vector3(room.size.x, 0.008, room.size.y), ceiling)
	var mid := floor_y + height * 0.5
	var band_y := floor_y + 1.45
	# Tile and band on all four faces; the west face leaves the doorway clear.
	var faces := [
		[Vector3(center.x, mid, room.end.y - 0.006), Vector3(room.size.x, height, 0.012), Vector3(0.0, 0.0, -0.008)],
		[Vector3(center.x, mid, room.position.y + 0.006), Vector3(room.size.x, height, 0.012), Vector3(0.0, 0.0, 0.008)],
		[Vector3(room.end.x - 0.006, mid, center.y), Vector3(0.012, height, room.size.y), Vector3(-0.008, 0.0, 0.0)],
	]
	for index in faces.size():
		var face: Array = faces[index]
		HouseKit.box(self, "Tile_%d" % index, face[0], face[1], wall_tile)
		var band_size: Vector3 = face[1]
		band_size.y = 0.07
		HouseKit.box(self, "TileBand_%d" % index, Vector3((face[0] as Vector3).x, band_y, (face[0] as Vector3).z) + face[2], band_size, band)
	# West face, split around the door at door_on_west (z), 1.2 m wide.
	var door_half := 0.6
	for part in [[room.position.y, door_on_west - door_half], [door_on_west + door_half, room.end.y]]:
		var z0: float = part[0]
		var z1: float = part[1]
		if z1 - z0 < 0.02:
			continue
		HouseKit.box(self, "TileWest_%d" % int(z0 * 10.0), Vector3(room.position.x + 0.006, mid, (z0 + z1) * 0.5), Vector3(0.012, height, z1 - z0), wall_tile)
		HouseKit.box(self, "TileBandWest_%d" % int(z0 * 10.0), Vector3(room.position.x + 0.014, band_y, (z0 + z1) * 0.5), Vector3(0.004, 0.07, z1 - z0), band)
	HouseKit.box(self, "TileWestHead", Vector3(room.position.x + 0.006, (floor_y + 2.15 + ceiling_y) * 0.5, door_on_west), Vector3(0.012, ceiling_y - floor_y - 2.15, door_half * 2.0), wall_tile)


func _autopsy_table(base: Vector3) -> void:
	var table := Node3D.new()
	table.name = "AutopsyTable"
	table.position = base
	add_child(table)
	HouseKit.solid(table, "Pedestal", Vector3(0.0, 0.42, 0.0), Vector3(0.42, 0.84, 0.36), _steel)
	HouseKit.box(table, "Foot", Vector3(0.0, 0.02, 0.0), Vector3(0.7, 0.04, 0.55), _steel)
	HouseKit.solid(table, "Top", Vector3(0.0, 0.88, 0.0), Vector3(2.2, 0.06, 0.78), _steel)
	for side in [-1.0, 1.0]:
		HouseKit.box(table, "LipLong_%d" % int(side), Vector3(0.0, 0.93, side * 0.38), Vector3(2.2, 0.05, 0.02), _steel)
		HouseKit.box(table, "LipEnd_%d" % int(side), Vector3(side * 1.09, 0.93, 0.0), Vector3(0.02, 0.05, 0.78), _steel)
	HouseKit.box(table, "DrainBasin", Vector3(1.25, 0.8, 0.0), Vector3(0.3, 0.16, 0.5), _steel)
	HouseKit.box(table, "Faucet", Vector3(1.32, 1.08, 0.0), Vector3(0.03, 0.3, 0.03), _steel)
	HouseKit.box(table, "FaucetSpout", Vector3(1.24, 1.22, 0.0), Vector3(0.18, 0.03, 0.03), _steel)
	HouseKit.box(table, "HeadRest", Vector3(-0.95, 0.94, 0.0), Vector3(0.14, 0.06, 0.2), HouseKit.paint(Color("2a2c2e"), 0.6))
	_sheeted_body(table)


## A body under a sheet: head on the rest, chest, the rise of the feet.
## Hidden until the haunting lays it out.
func _sheeted_body(table: Node3D) -> void:
	body = Node3D.new()
	body.name = "SheetedBody"
	body.visible = false
	table.add_child(body)
	var sheet := HouseKit.paint(Color("d6d3c9"), 0.95)
	var lying := Basis(Vector3.BACK, PI * 0.5)
	var torso := CapsuleMesh.new()
	torso.radius = 0.21
	torso.height = 1.35
	var trunk := MeshInstance3D.new()
	trunk.mesh = torso
	trunk.material_override = sheet
	trunk.transform = Transform3D(lying.scaled(Vector3(1.0, 1.0, 0.75)), Vector3(-0.1, 1.08, 0.0))
	body.add_child(trunk)
	var head := MeshInstance3D.new()
	var skull := SphereMesh.new()
	skull.radius = 0.13
	skull.height = 0.24
	head.mesh = skull
	head.material_override = sheet
	head.position = Vector3(-0.88, 1.07, 0.0)
	body.add_child(head)
	for side in [-1.0, 1.0]:
		var foot := MeshInstance3D.new()
		var toe := SphereMesh.new()
		toe.radius = 0.07
		toe.height = 0.16
		foot.mesh = toe
		foot.material_override = sheet
		foot.position = Vector3(0.78, 1.12, side * 0.09)
		body.add_child(foot)
	# The sheet falls over the table's edges.
	for side in [-1.0, 1.0]:
		HouseKit.box(body, "SheetDrop_%d" % int(side), Vector3(-0.05, 0.98, side * 0.36), Vector3(1.9, 0.14, 0.02), sheet)


func _scrub_sink(wall_base: Vector3, yaw: float) -> void:
	var sink := Node3D.new()
	sink.name = "ScrubSink"
	sink.position = wall_base
	sink.rotation.y = yaw
	add_child(sink)
	HouseKit.solid(sink, "Trough", Vector3(0.32, 0.8, 0.0), Vector3(0.55, 0.26, 2.0), _steel)
	HouseKit.box(sink, "Basin", Vector3(0.34, 0.88, 0.0), Vector3(0.45, 0.12, 1.9), HouseKit.paint(Color("5c6064"), 0.2, 0.9))
	HouseKit.box(sink, "Upstand", Vector3(0.03, 1.1, 0.0), Vector3(0.04, 0.35, 2.0), _steel)
	for leg_z in [-0.9, 0.9]:
		HouseKit.box(sink, "Leg_%d" % int(leg_z * 10.0), Vector3(0.5, 0.34, leg_z), Vector3(0.04, 0.68, 0.04), _steel)
	for tap in range(3):
		var tap_z := -0.6 + tap * 0.6
		HouseKit.box(sink, "Tap_%d" % tap, Vector3(0.1, 1.2, tap_z), Vector3(0.03, 0.18, 0.03), _steel)
		HouseKit.box(sink, "Spout_%d" % tap, Vector3(0.2, 1.28, tap_z), Vector3(0.2, 0.025, 0.025), _steel)
		HouseKit.box(sink, "ElbowLever_%d" % tap, Vector3(0.12, 1.3, tap_z + 0.08), Vector3(0.02, 0.02, 0.2), _steel)


func _instrument_trolley(base: Vector3) -> void:
	var trolley := Node3D.new()
	trolley.name = "InstrumentTrolley"
	trolley.position = base
	add_child(trolley)
	for shelf_y in [0.3, 0.9]:
		HouseKit.box(trolley, "Shelf_%d" % int(shelf_y * 10.0), Vector3(0.0, shelf_y, 0.0), Vector3(0.8, 0.02, 0.5), _steel)
	for corner in [Vector2(-0.38, -0.23), Vector2(0.38, -0.23), Vector2(-0.38, 0.23), Vector2(0.38, 0.23)]:
		HouseKit.box(trolley, "Post_%d_%d" % [int(corner.x * 10.0), int(corner.y * 10.0)], Vector3(corner.x, 0.5, corner.y), Vector3(0.025, 0.9, 0.025), _steel)
		HouseKit.box(trolley, "Castor_%d_%d" % [int(corner.x * 10.0), int(corner.y * 10.0)], Vector3(corner.x, 0.04, corner.y), Vector3(0.05, 0.08, 0.05), HouseKit.paint(Color("202224"), 0.6))
	HouseKit.blocker(trolley, "Collision", Vector3(0.0, 0.47, 0.0), Vector3(0.8, 0.94, 0.5))


## The refrigerated bank: two rows of three square doors, each opening on a
## real dark chamber with a steel tray. Built facing +Z, then turned by yaw.
func _cold_chambers(base: Vector3, yaw: float) -> void:
	var bank := Node3D.new()
	bank.name = "ColdChambers"
	bank.position = base
	bank.rotation.y = yaw
	add_child(bank)
	var door_size := Vector2(0.72, 0.72)
	var column_x: Array[float] = [-1.0, 0.0, 1.0]
	var row_y: Array[float] = [0.62, 1.52]
	var width := 3.1
	var height := 2.1
	var depth := 0.9
	var half := width * 0.5
	var chamber_dark := HouseKit.paint(Color("1a1d20"), 0.4, 0.5)
	HouseKit.box(bank, "Plinth", Vector3(0.0, 0.08, depth * 0.5), Vector3(width, 0.16, depth), HouseKit.paint(Color("2a2c2e"), 0.6))
	HouseKit.box(bank, "Top", Vector3(0.0, height - 0.06, depth * 0.5), Vector3(width, 0.12, depth), _steel)
	HouseKit.box(bank, "Back", Vector3(0.0, height * 0.5, 0.02), Vector3(width, height, 0.04), _steel)
	var edges: Array[float] = [-half, column_x[0] - door_size.x * 0.5, column_x[0] + door_size.x * 0.5, column_x[1] - door_size.x * 0.5, column_x[1] + door_size.x * 0.5, column_x[2] - door_size.x * 0.5, column_x[2] + door_size.x * 0.5, half]
	for stile in range(4):
		var x0 := edges[stile * 2]
		var x1 := edges[stile * 2 + 1]
		HouseKit.box(bank, "Stile_%d" % stile, Vector3((x0 + x1) * 0.5, (height + 0.16) * 0.5, depth * 0.5), Vector3(x1 - x0, height - 0.16, depth), _steel)
	var levels: Array[float] = [0.16, row_y[0] - door_size.y * 0.5, row_y[0] + door_size.y * 0.5, row_y[1] - door_size.y * 0.5, row_y[1] + door_size.y * 0.5, height - 0.12]
	for shelf in range(3):
		var y0 := levels[shelf * 2]
		var y1 := levels[shelf * 2 + 1]
		HouseKit.box(bank, "Shelf_%d" % shelf, Vector3(0.0, (y0 + y1) * 0.5, depth * 0.5), Vector3(width, y1 - y0, depth), _steel)
	HouseKit.blocker(bank, "Collision", Vector3(0.0, height * 0.5, (depth - 0.08) * 0.5), Vector3(width, height, depth - 0.08))
	var index := 0
	for y in row_y:
		for x in column_x:
			index += 1
			var opening := Vector3(x, y, 0.0)
			HouseKit.box(bank, "Chamber_%d" % index, opening + Vector3(0.0, 0.0, depth * 0.5 + 0.02), Vector3(door_size.x - 0.01, door_size.y - 0.01, depth - 0.06), chamber_dark)
			HouseKit.box(bank, "Tray_%d" % index, opening + Vector3(0.0, -door_size.y * 0.5 + 0.06, depth * 0.5 + 0.02), Vector3(door_size.x - 0.08, 0.03, depth - 0.12), _steel)
			# The door's node sits at the bottom centre of its opening and
			# swings outward (toward +Z of the bank, -Z of the door).
			chambers.append(HouseDoor.make(bank, "ColdChamberDoor_%d" % index, Vector3(x, y - door_size.y * 0.5, depth + 0.03), PI, Vector3(door_size.x, door_size.y, 0.06), "chamber", null, 1.0, 100.0, "Cold chamber %d" % index))


func _fluorescents() -> void:
	# Batten fittings: an aluminium channel with a bare tube beneath. (The
	# scanned fitting's raw mesh loses its node scale outside its scene.)
	var aluminium := HouseKit.paint(Color("b9bdc0"), 0.4, 0.7)
	var center := room.get_center()
	var spots: Array[Vector2] = []
	for k in 4:
		spots.append(Vector2(lerpf(room.position.x + 1.3, room.end.x - 1.3, float(k) / 3.0), center.y))
	for fixture in spots.size():
		var at := Vector3(spots[fixture].x, ceiling_y, spots[fixture].y)
		for tube in range(2):
			var tube_at := at + Vector3(0.0, -0.05, -0.15 + tube * 0.3)
			HouseKit.box(self, "Batten_%d_%d" % [fixture, tube], tube_at + Vector3(0.0, 0.015, 0.0), Vector3(1.24, 0.05, 0.08), aluminium)
			var lit := HouseKit.box(self, "TubeGlow_%d_%d" % [fixture, tube], tube_at + Vector3(0.0, -0.025, 0.0), Vector3(1.18, 0.028, 0.028), HouseKit.glow(Color("eef6ff"), 3.0))
			tubes.append(lit)
		# No shadows: hung just under its own fitting, a shadowed wash throws
		# the fitting across the ceiling as a huge black wedge.
		var wash := HouseKit.light(self, "FluorescentWash_%d" % fixture, at + Vector3(0.0, -0.35, 0.0), Color("e6f0ff"), 1.1, 5.2)
		lights.append(wash)
	_flicker = lights[3] as OmniLight3D
	_flicker_energy = _flicker.light_energy
