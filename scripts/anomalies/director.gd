class_name AnomalyDirector
extends Node

# Picks which anomalies walk the snowfield this run, lays out their records,
# and reports the strongest pressure among them to the HUD and soundscape.

var trail: Trail
var anomalies: Array[Anomaly] = []
var _laid := false


func _ready() -> void:
	Game.director = self
	# Markers have to exist before the editable level is saved. Where they
	# stand is read after that level has been laid over the built one.
	_ensure_markers()


# After EditableLevel.apply, so a marker moved in the editor is where it stands.
func layout() -> void:
	if _laid or trail == null:
		return
	_laid = true
	var pool := roster()
	pool.shuffle()
	var picks: Array[Anomaly] = []
	for make in pool:
		picks.append((make as Callable).call())
	# Dev hooks: RUN_ANOMALY=<code> forces one, RUN_ANOMALY_NEAR=1 stands it
	# in front of her so it can be looked at (with RUN_CAPTURE for a shot).
	var forced := OS.get_environment("RUN_ANOMALY")
	if forced != "":
		picks = picks.filter(func(a: Anomaly) -> bool: return a.code == forced)
	var markers := trail.get_node_or_null("Anomalies")
	var count := mini(Tune.ANOMALIES_PER_RUN, picks.size())
	for index in count:
		var anomaly := picks[index]
		anomaly.trail = trail
		add_child(anomaly)
		anomalies.append(anomaly)
		var stand: Marker3D = markers.get_node_or_null(anomaly.code) as Marker3D if markers else null
		if stand:
			anomaly.adopt_marker(stand)
		_lay_record(anomaly, index)
		Game.mark("anomaly %s" % anomaly.code)
	if OS.get_environment("RUN_ANOMALY_NEAR") == "1" and Game.player:
		var ahead := -Game.player.global_transform.basis.z
		for anomaly in anomalies:
			anomaly.place_near(Game.player.global_position + ahead * 7.0, Game.player.global_position)


# Every anomaly that can appear. Add new ones here.
static func roster() -> Array[Callable]:
	return [
		func() -> Anomaly: return Listener.new(),
	]


func _process(_delta: float) -> void:
	var strongest := 0.0
	var line := ""
	var loudest := -1.0
	for anomaly in anomalies:
		strongest = maxf(strongest, anomaly.dread)
		if anomaly.hint != "" and anomaly.dread > loudest:
			loudest = anomaly.dread
			line = anomaly.hint
	Game.dread = strongest
	Game.anomaly_hint = line


func _ensure_markers() -> void:
	if trail == null:
		return
	var root := trail.get_node_or_null("Anomalies") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "Anomalies"
		root.add_to_group(EditableLevel.AUTHORING_GROUP)
		trail.add_child(root)
	var index := 0
	for make in roster():
		var sample := (make as Callable).call() as Anomaly
		sample.trail = trail
		if root.get_node_or_null(sample.code) == null:
			var stand := Marker3D.new()
			stand.name = sample.code
			stand.gizmo_extents = 0.8
			root.add_child(stand)
			stand.global_transform = sample.stand_transform(trail)
		var page_name := "%s_Record" % sample.code
		if root.get_node_or_null(page_name) == null:
			var page := Marker3D.new()
			page.name = page_name
			page.gizmo_extents = 0.35
			root.add_child(page)
			page.global_position = sample.record_position(trail, index)
		sample.free()
		index += 1


func _lay_record(anomaly: Anomaly, index: int) -> void:
	var entry := anomaly.record()
	if entry == null or trail == null:
		return
	var markers := trail.get_node_or_null("Anomalies")
	var page_marker: Marker3D = markers.get_node_or_null("%s_Record" % anomaly.code) as Marker3D if markers else null
	var at := page_marker.global_position if page_marker else anomaly.record_position(trail, index)
	# The page stays on the director. A note parented into the trail would be
	# matched against the editable level and hidden.
	var page := FieldNote.new()
	page.entry = entry
	add_child(page)
	page.global_position = at
