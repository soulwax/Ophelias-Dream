class_name AnomalyDirector
extends Node

# Picks which anomalies walk the snowfield this run, lays out their records,
# and reports the strongest pressure among them to the HUD and soundscape.

var trail: Trail
var anomalies: Array[Anomaly] = []


func _ready() -> void:
	Game.director = self
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
	var count := mini(Tune.ANOMALIES_PER_RUN, picks.size())
	for index in count:
		var anomaly := picks[index]
		anomaly.trail = trail
		add_child(anomaly)
		anomalies.append(anomaly)
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


func _lay_record(anomaly: Anomaly, index: int) -> void:
	var entry := anomaly.record()
	if entry == null or trail == null:
		return
	# Records sit on the side opposite the field notes near them.
	var along := trail.player_start_offset + anomaly.record_offset() + float(index) * 9.0
	var frame := trail.frame_at(along)
	var at := trail.on_ground(frame.origin + frame.basis.x * 3.4)
	at.y += 0.04
	var page := FieldNote.new()
	page.entry = entry
	page.position = trail.to_local(at)
	trail.add_child(page)
