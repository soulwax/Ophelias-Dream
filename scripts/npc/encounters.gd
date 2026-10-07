class_name Encounters
extends Node

## The one not being played is out on her own afternoon, and now and then the two
## of them pass each other (docs/MATHILDA_STORY.md, "When they pass each other").
## Wanderer (C#) walks her and notices; this node gives it her path and the places
## she stops, and stages what gets said: three passings at most, none finished.
## Dev hook: RUN_WANDER=off leaves her out, RUN_WANDER=now brings her out at once.

const SPEAK_HOLD := 0.5

var wanderer: Wanderer
var body: OpheliaNpc
## "mathilda" in Ophelia's chapter, "ophelia" in Mathilda's: the one met.
var other := ""
var _her_lines := {}
var _her_dir := ""
var _her_voice: AudioStreamPlayer3D
var _ticket := 0
var _in_passing := false
var _can_speak := false
var _spoke := false
var _spots: Array[Vector3] = []
var _after_said := 0
var _hint: Label


func _ready() -> void:
	if OS.get_environment("RUN_WANDER") == "off":
		return
	_build.call_deferred()


func _build() -> void:
	# The camp and Mathilda's chapter both settle a frame or two after the tree is ready.
	for i in 3:
		await get_tree().process_frame
	if Game.trail == null or Game.house == null or Game.player == null:
		return
	other = "ophelia" if Game.mathilda_pov else "mathilda"
	_load_her_lines()
	body = OpheliaNpc.new()
	body.name = other.capitalize()
	wanderer = Wanderer.new()
	wanderer.name = "Wanderer"
	add_child(wanderer)
	wanderer.add_child(body)
	_her_voice = Loudness.voice(Tune.VOICE_SPL, "Voice")
	body.add_child(_her_voice)
	_her_voice.position = Vector3(0.0, 1.5, 0.0)
	var first: Vector2 = Tune.PASS_FIRST_MATHILDA if Game.mathilda_pov else Tune.PASS_FIRST
	if OS.get_environment("RUN_WANDER") == "now":
		first = Vector2(2.0, 3.0)
	var path := _path()
	var haunts := _haunts(path)
	wanderer.Setup(body, path, haunts, first)
	wanderer.AheadBias = not Game.mathilda_pov
	wanderer.connect("PassingBegan", _on_passing)
	wanderer.connect("PassingEnded", _on_ended)
	wanderer.connect("Stepped", _on_step)
	_build_hint()
	if OS.get_environment("RUN_WANDER") == "now":
		wanderer.ForceEnterNear(Game.player.global_position + Game.player.global_basis.z * -24.0)


# ---------------------------------------------------------------- where she walks

## Outdoors along the route, where the woods keep clear. Ophelia keeps to the
## house end and never quite reaches the tent; Mathilda walks the whole trail.
func _path() -> PackedVector3Array:
	var trail := Game.trail
	var door := Game.house.doorstep()
	var home := trail.offset_of(door)
	var points := PackedVector3Array()
	var from := home + 4.0
	var to := home + 84.0
	if not Game.mathilda_pov:
		from = home + 20.0
		to = trail.lake_offset - Tune.LAKE_RADIUS - 3.0
	else:
		points.append(door)
	var offset := from
	while offset <= to:
		points.append(trail.on_ground(trail.position_at(offset)))
		offset += 4.0
	return points


func _haunts(path: PackedVector3Array) -> Array[Dictionary]:
	var trail := Game.trail
	var house_at := Game.house.doorstep() + Vector3.UP * 1.2
	var home := trail.offset_of(Game.house.doorstep())
	var camp := get_tree().get_first_node_in_group("camp") as Camp
	var camp_at := trail.on_ground(trail.frame_at(trail.player_start_offset + 98.0).origin \
		+ trail.frame_at(trail.player_start_offset + 98.0).basis.x * 7.5)
	var fire := camp.fire_light.global_position if camp and camp.fire_light else camp_at
	var list: Array[Dictionary] = []
	if Game.mathilda_pov:
		# Ophelia: the porch, the path, halfway to the tent and back.
		list.append({"at": path[0], "act": "gaze", "look": fire})
		list.append({"at": _beside(home + 6.0, 2.2), "act": "still", "look": fire})
		list.append({"at": _beside(home + 18.0, -1.0), "act": "crouch", "look": trail.position_at(home + 22.0)})
		list.append({"at": _beside(home + 38.0, 1.4), "act": "gaze", "look": fire})
		list.append({"at": _beside(home + 58.0, -1.2), "act": "gaze", "look": house_at})
		list.append({"at": _beside(home + 80.0, 0.8), "act": "still", "look": fire})
		return list
	# Mathilda: along the whole trail, by her own fire, at the posts, at the shore.
	var acts := ["gaze", "crouch", "gaze", "still"]
	var offset := home + 26.0
	var end := trail.lake_offset - Tune.LAKE_RADIUS - 4.0
	var i := 0
	while offset < end:
		var act: String = acts[i % acts.size()]
		var look := house_at if act == "still" or i % 2 == 0 else trail.position_at(offset + 30.0) + Vector3.UP * 1.2
		if act == "crouch":
			look = trail.position_at(offset + 3.0)
		list.append({"at": _beside(offset, (1.6 if i % 2 == 0 else -1.6)), "act": act, "look": look})
		offset += 44.0
		i += 1
	list.append({"at": camp_at.lerp(fire, 0.55), "act": "warm", "look": fire})
	list.append({"at": _beside(end, 0.0), "act": "still", "look": trail.lake_hole})
	return list


func _beside(offset: float, side: float) -> Vector3:
	var frame := Game.trail.frame_at(offset)
	return Game.trail.on_ground(frame.origin + frame.basis.x * side)


func _load_her_lines() -> void:
	if other == "mathilda":
		_her_dir = "res://assets/audio/voice/mathilda/"
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_her_dir + "lines.json"))
		if typeof(data) == TYPE_DICTIONARY:
			for entry in (data as Dictionary).get("passing", []):
				_her_lines[str(entry.get("id", ""))] = entry
	else:
		_her_dir = "res://assets/audio/voice/"
		var group: Variant = Voice.read_lines().get("encounters", {})
		if typeof(group) == TYPE_DICTIONARY:
			_her_lines = group


# ---------------------------------------------------------------- every frame

func _process(_delta: float) -> void:
	if wanderer == null:
		return
	var allowed := Game.phase == Game.Phase.PLAYING or Game.phase == Game.Phase.READING \
		or Game.phase == Game.Phase.JOURNAL
	if Game.mathilda_pov:
		if Game.voice and Game.voice.get("_going_home"):
			wanderer.Retire()
			allowed = false
	else:
		if Game.turned_around or Game.meeting_waiting:
			# There is only one of them out here now, or she is waiting on the ice.
			wanderer.Retire()
			allowed = false
		elif Game.indoors(Game.player.global_position + Vector3.UP * 0.9):
			allowed = false
	wanderer.Allowed = allowed
	_hint.visible = _can_speak and not _spoke and _close_enough() and Game.phase == Game.Phase.PLAYING
	if _hint.visible:
		_hint.text = "%s  say something" % Game.settings.key_label("interact")
	_aftermath()


func _close_enough() -> bool:
	return Game.player.global_position.distance_to(wanderer.global_position) < Tune.PASS_SPEAK


## Where she stood, after she has gone: no prints, not even hers.
func _aftermath() -> void:
	if _spots.is_empty() or _after_said >= 2 or _in_passing:
		return
	var here := Game.player.global_position
	for spot in _spots:
		if Vector2(here.x - spot.x, here.z - spot.z).length() < 1.6 \
				and (not wanderer.Present or here.distance_to(wanderer.global_position) > 12.0):
			_spots.erase(spot)
			_after_said += 1
			_me(("o_after" if _after_said == 1 else "o_after2") if other == "mathilda" \
				else ("m_after" if _after_said == 1 else "m_after2"))
			return


func _unhandled_input(event: InputEvent) -> void:
	if _can_speak and not _spoke and Game.phase == Game.Phase.PLAYING \
			and event.is_action_pressed("interact") and _close_enough():
		get_viewport().set_input_as_handled()
		_say_something()


# ---------------------------------------------------------------- a passing

func _on_passing(number: int) -> void:
	Game.passings = number
	Game.mark("passing %d with %s" % [number, other])
	_in_passing = true
	_spoke = false
	if Game.voice:
		Game.voice.hushed = true
	_ticket += 1
	_play(_script(number), _ticket)


func _on_ended(_number: int, spot: Vector3, broken: bool) -> void:
	if broken:
		_ticket += 1
	_spots.append(spot)
	_close()


func _close() -> void:
	_in_passing = false
	_can_speak = false
	if Game.voice:
		Game.voice.hushed = false


## Beats: ["wait", s], ["me", id, hold], ["her", id, hold], ["both", my id, her id, hold],
## ["away", s], ["crouch", s]. Every passing ends before anything is settled.
func _script(number: int) -> Array:
	if other == "mathilda":
		match number:
			1:
				return [["wait", 1.6], ["me", "o_name", 1.2], ["away", 1.6], ["wait", 0.8],
					["her", "w_up", 1.0], ["me", "o_door", 0.8], ["her", "w_does", 0.4], ["wait", 2.6]]
			2:
				return [["wait", 1.2], ["her", _what_she_knows(), 0.9], ["me", "o_how", 0.6], ["away", 1.8],
					["her", "w_cold", 1.0], ["me", "o_come", 0.4], ["wait", 1.8], ["crouch", 2.4], ["wait", 2.6]]
			_:
				return [["wait", 2.0], ["her", "w_go", 1.2], ["me", "o_said", 0.8], ["her", "w_know", 0.2],
					["wait", 2.8], ["both", "o_didnt", "w_didnt", 0.6], ["wait", 1.0], ["her", "w_first", 0.6], ["wait", 3.4]]
	match number:
		1:
			return [["wait", 1.4], ["me", "m_name", 1.0], ["her", "n_oh", 0.8], ["me", "m_hi", 0.4],
				["wait", 2.4], ["away", 1.6], ["her", "n_wood", 0.6], ["crouch", 2.0], ["wait", 1.8]]
		2:
			return [["wait", 1.0], ["her", _what_she_knows(), 0.8], ["me", "m_watching", 0.6], ["away", 1.4],
				["her", "n_no", 0.6], ["me", "m_how", 0.2], ["wait", 2.8]]
		_:
			return [["wait", 1.8], ["her", "n_dont", 1.0], ["me", "m_mine", 0.6], ["her", "n_isit", 0.4],
				["wait", 3.0], ["both", "m_im", "n_didnt", 0.6], ["wait", 0.9], ["her", "n_sorry", 0.6], ["wait", 3.4]]


## The second time, she knows something she could not know.
func _what_she_knows() -> String:
	if other == "mathilda":
		var window := Game.house.find_child("WindowChore", true, false)
		if window and window.get("done"):
			return "w_thread"
		var stove := Game.house.find_child("StoveChore", true, false)
		return "w_stove_lit" if stove and stove.get("done") else "w_stove_cold"
	var inspected: Variant = Game.voice.get("_inspected") if Game.voice else null
	if typeof(inspected) == TYPE_DICTIONARY and (inspected as Dictionary).has("fire"):
		return "n_fire_on"
	return "n_fire_low"


func _play(beats: Array, ticket: int) -> void:
	# Pressing to speak is possible once the first look has happened.
	_can_speak = true
	for beat in beats:
		if ticket != _ticket or not is_instance_valid(wanderer):
			return
		var hold := 0.0
		match str(beat[0]):
			"wait":
				hold = float(beat[1])
			"me":
				hold = _me(str(beat[1])) + float(beat[2])
			"her":
				hold = _her(str(beat[1])) + float(beat[2])
			"both":
				# Both start the same sentence; she is the one whose words show.
				_me(str(beat[1]))
				hold = _her(str(beat[2])) + float(beat[3])
			"away":
				wanderer.LookAway(float(beat[1]))
			"crouch":
				wanderer.Crouch(float(beat[1]))
		if hold > 0.0:
			await get_tree().create_timer(hold, false).timeout
	if ticket == _ticket and is_instance_valid(wanderer):
		wanderer.Leave()


## Pressed to speak: half a word, a "hm?", nothing after it, and she goes.
func _say_something() -> void:
	_spoke = true
	_ticket += 1
	var ticket := _ticket
	var halves := ["o_half1", "o_half2", "o_half3"] if other == "mathilda" else ["m_half1", "m_half2", "m_half3"]
	var hold := _me(str(halves.pick_random())) + 0.7
	await get_tree().create_timer(hold, false).timeout
	if ticket != _ticket:
		return
	hold = _her("w_hm" if other == "mathilda" else "n_hm") + 1.8
	await get_tree().create_timer(hold, false).timeout
	if ticket == _ticket and is_instance_valid(wanderer):
		wanderer.Leave()


func _me(id: String) -> float:
	if Game.voice == null:
		return SPEAK_HOLD
	return maxf(Game.voice.encounter(id), SPEAK_HOLD)


func _her(id: String) -> float:
	var line: Dictionary = _her_lines.get(id, {})
	if line.is_empty():
		return SPEAK_HOLD
	var text := str(line.get("text", ""))
	Game.murmur_line(text, other.capitalize())
	var path := _her_dir + Voice.clip_key(text, str(line.get("mood", "steady"))) + ".wav"
	if ResourceLoader.exists(path):
		_her_voice.stream = load(path)
		_her_voice.play()
		Game.murmur_left = maxf(_her_voice.stream.get_length() + 0.3, 1.2)
	return Game.murmur_left


func _on_step(at: Vector3) -> void:
	if Game.soundscape == null:
		return
	var surface := "snow"
	var ground: Ground = Game.trail.ground if Game.trail else null
	if ground:
		var weight := ground.snow_at(at.x, at.z)
		surface = "snow" if weight > 0.65 else ("thaw" if weight > 0.35 else "grass")
	Game.soundscape.play_step(at, surface, 0.5)


func _build_hint() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 24
	add_child(canvas)
	_hint = UiChrome.label("", 15, Color(0.86, 0.82, 0.76, 0.75))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -240
	_hint.offset_right = 240
	_hint.offset_top = -250
	_hint.offset_bottom = -222
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false
	canvas.add_child(_hint)
