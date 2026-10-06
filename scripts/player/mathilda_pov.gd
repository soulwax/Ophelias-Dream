extends Voice

# The end cards of her chapter (docs/MATHILDA_MEETING.md, Endings).
const ENDINGS := {
	"home": ["Walk beside me", "Ophelia steps aside, and you go in together. She sits, and she listens until you have finished, and then a while longer. Two cups on the table, one fitted inside the other. Outside, for the first time since you left, the light moves."],
	"step": ["On the step", "You keep the cup a little longer. Ophelia sits down on the step beside you, in the snow, with the door open behind her and nothing to fix. Neither of you goes in yet. Outside, for the first time since you left, the light moves."],
	"wait": ["With the light", "You stay at the tent with both cups and watch the window. The lantern stays lit. It is still the same afternoon."],
}
const MEETING := "res://assets/dialogue/meeting.json"
const SPEAK_REACH := 3.2

var _lines: Dictionary = {}
var _mathilda_seen: Dictionary = {}
var _pending: Array[Dictionary] = []
var _camp := Vector3.ZERO
var _objects: Array[Vector3] = []
var _object_names := ["cups", "gloves", "note"]
var _inspected: Dictionary = {}
var _caption: Label
var _idle_left := 18.0
var _place := ""
var _chapter_finished := false
# After Return: Ophelia waits at the doorstep and the meeting can begin.
var _going_home := false
var _ophelia: OpheliaNpc
var _meeting: Conversation
var _cup_view: MeshInstance3D


func _ready() -> void:
	Game.voice = self
	_lines = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voice/mathilda/lines.json"))
	_active = true
	_build_speaker()
	_speaker.bus = "Voice"
	_build_ui()
	_start.call_deferred()


func _start() -> void:
	var frame := Game.trail.frame_at(Game.trail.player_start_offset + 98.0)
	_camp = Game.trail.on_ground(frame.origin + frame.basis.x * 7.5)
	var spawn := Game.trail.on_ground(frame.origin + frame.basis.x * 3.0)
	Game.player.global_position = spawn + Vector3.UP * 0.15
	Game.player.velocity = Vector3.ZERO
	Game.player.visual.hide()
	Game.player.reset_physics_interpolation()
	_build_objects(frame)
	# Her afternoon is already ending: the clock starts at early dusk.
	# Dev hook: RUN_HOUR=<hours> starts it at another time.
	var atmosphere := get_tree().get_first_node_in_group("atmosphere") as Atmosphere
	if atmosphere:
		var hour := OS.get_environment("RUN_HOUR")
		atmosphere.start_clock(float(hour) if hour.is_valid_float() else Tune.MATHILDA_DUSK)
	Game.audio_fade = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.set_phase(Game.Phase.PLAYING)
	Game.settings.apply_audio()
	_group("arrival")
	# Dev hook: RUN_MEETING=1 starts at the doorstep, RUN_MEETING=open also opens the meeting.
	var meeting := OS.get_environment("RUN_MEETING")
	if meeting != "":
		for object_name in _object_names:
			_inspected[object_name] = true
		_mathilda_seen["arrival"] = true
		_pending.clear()
		_return_home(false)
		Game.player.global_position = _ophelia.global_position - _ophelia.global_basis.z * 2.2 + Vector3.UP * 0.15
		Game.player.reset_physics_interpolation()
		Game.player.look_toward(_ophelia.head(), 1.0, 100.0)
		if meeting == "open":
			_meeting.begin.call_deferred()


func _build_objects(frame: Transform3D) -> void:
	# The camp lays her things out: cups on the crate, gloves on the stool,
	# the note under the lantern.
	var camp := get_tree().get_first_node_in_group("camp") as Camp
	if camp:
		camp.ensure_built()
		if camp.is_built:
			for object_name in _object_names:
				camp.place_story_prop(object_name)
				_objects.append(camp.spots[object_name])
			return
	for i in 3:
		var at := Game.trail.on_ground(frame.origin + frame.basis.x * (4.7 + i * 0.8) + frame.basis.z * 1.8)
		_objects.append(at)
		var mesh := MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = [Color("a0bcc0"), Color("8d6955"), Color("d0c6ac")][i]
		if i == 0:
			var cup := CylinderMesh.new()
			cup.top_radius = 0.13
			cup.bottom_radius = 0.10
			cup.height = 0.23
			mesh.mesh = cup
		else:
			var prop := BoxMesh.new()
			prop.size = Vector3(0.25, 0.05, 0.34) if i == 1 else Vector3(0.32, 0.015, 0.42)
			mesh.mesh = prop
		mesh.material_override = material
		mesh.position = at + Vector3.UP * 0.18
		add_child(mesh)
		if i == 0:
			var second := mesh.duplicate() as MeshInstance3D
			second.position += frame.basis.z * 0.30
			add_child(second)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 25
	add_child(canvas)
	_caption = UiChrome.label("", 18)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caption.offset_left = -500
	_caption.offset_right = 500
	_caption.offset_top = 24
	_caption.offset_bottom = 84
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(_caption)



func _process(delta: float) -> void:
	if Game.player == null or _chapter_finished:
		return
	_since += delta
	if _speaker.playing:
		Game.murmur_left = maxf(Game.murmur_left, 0.3)
	elif not _current.is_empty() and Game.murmur_left <= 0.0:
		_finished()
	_caption.visible = Game.phase == Game.Phase.PLAYING
	if Game.phase != Game.Phase.PLAYING:
		return
	if not _pending.is_empty() and not _busy() and _since > 1.2:
		_say(_pending.pop_front())
	var here := Game.player.global_position
	var near := _nearest_object(here)
	var bind: String = Game.settings.key_label("interact")
	_caption.text = "MATHILDA · Esc: return to menu"
	if _going_home:
		_caption.text += ("\n%s: speak to Ophelia" % bind) if _near_ophelia() else "\nReturn to the cabin."
	elif near >= 0:
		_caption.text += "\n%s: examine %s" % [bind, _object_names[near]]
	elif _inspected.size() == 3 and here.distance_to(_camp) < 6.0:
		_caption.text += "\n%s: decide whether to return" % bind
	var place := Game.place_at(here)
	if here.distance_to(_camp) < 9.0:
		place = "cold"
	elif place == "lights":
		place = "road"
	elif place != "snow":
		place = "house"
	if place != _place:
		_place = place
		_group(place)
	if here.distance_to(_camp) > 16.0 and here.distance_to(Game.house.spawn_point()) < 65.0:
		_group("lantern")
	_idle_left -= delta
	if _idle_left <= 0.0 and _pending.is_empty():
		_idle_left = 22.0
		var idle: Array = _lines.get("idle", [])
		for i in idle.size():
			if not _mathilda_seen.has("idle/%d" % i):
				_mathilda_seen["idle/%d" % i] = true
				_pending.append(Voice._line(idle[i].text, idle[i].mood, "place", "idle/%d" % i))
				break


func _nearest_object(here: Vector3) -> int:
	for i in _objects.size():
		if here.distance_to(_objects[i]) < 2.1 and not _inspected.has(_object_names[i]):
			return i
	return -1


func _group(group: String) -> void:
	if _mathilda_seen.has(group) or not _lines.has(group):
		return
	_mathilda_seen[group] = true
	var entries: Array = _lines[group]
	for i in entries.size():
		_pending.append(Voice._line(entries[i].text, entries[i].mood, "place", "%s/%d" % [group, i]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_menu()
		get_viewport().set_input_as_handled()
	elif Game.phase == Game.Phase.PLAYING and event.is_action_pressed("interact"):
		var near := _nearest_object(Game.player.global_position)
		if _going_home:
			if _near_ophelia():
				_pending.clear()
				_interrupt()
				_meeting.begin()
		elif near >= 0:
			_inspected[_object_names[near]] = true
			_group(_object_names[near])
		elif _inspected.size() == 3 and Game.player.global_position.distance_to(_camp) < 6.0:
			Game.dialogue.open("Mathilda", "You kept her cup. What do you keep now?", [
				{"id": "return", "text": "Return to Ophelia"},
				{"id": "wait", "text": "Wait with the light"},
			], null, _choose)
		get_viewport().set_input_as_handled()


func _choose(id: String) -> void:
	if id == "return":
		_return_home()
		return
	_pending.clear()
	_interrupt()
	var line: Dictionary = _lines.ending[1]
	_say(Voice._line(line.text, line.mood, "ending", "mathilda"))
	_chapter_finished = true
	_caption.hide()
	get_tree().create_timer(maxf(Game.murmur_left + 1.0, 4.0)).timeout.connect(_end.bind("wait"))


## She chose to go back: Ophelia now waits at the doorstep (docs/MATHILDA_MEETING.md).
func _return_home(say := true) -> void:
	if _going_home:
		return
	_going_home = true
	if say:
		_pending.clear()
		_interrupt()
		var line: Dictionary = _lines.ending[0]
		_say(Voice._line(line.text, line.mood, "ending", "mathilda"))
	_ophelia = OpheliaNpc.new()
	_ophelia.name = "Ophelia"
	add_child(_ophelia)
	# By the door, angled toward the field rather than squarely across it.
	var house := Game.house
	_ophelia.settle(house.doorstep() + house.global_basis.x.normalized() * 0.9)
	var out := house.global_basis.z
	_ophelia.rotation.y = atan2(-out.x, -out.z) + 0.45
	_meeting = Conversation.make(MEETING, _ophelia)
	add_child(_meeting)
	for object_name in _inspected:
		_meeting.flags[object_name] = true
	_meeting.line_started.connect(_on_meeting_line)
	_meeting.ended.connect(_on_meeting_end)


func _near_ophelia() -> bool:
	return is_instance_valid(_ophelia) and Game.player.global_position.distance_to(_ophelia.global_position) < SPEAK_REACH


func _on_meeting_line(line: Dictionary) -> void:
	# The cup she kept shows only once she offers it (line 20).
	if str(line.id) == "20" and _cup_view == null and Game.player.camera:
		_cup_view = OpheliaNpc.cup()
		Game.player.camera.add_child(_cup_view)
		_cup_view.position = Vector3(0.2, -0.22, -0.5)


func _on_meeting_end(ending: String) -> void:
	_chapter_finished = true
	_caption.hide()
	var wait := 2.6
	if ending == "home":
		if _cup_view:
			_cup_view.reparent(self)
			var tween := create_tween()
			tween.tween_property(_cup_view, "global_position", _ophelia.hand(), 0.9)
			tween.tween_callback(_ophelia.take_cup.bind(_cup_view))
		get_tree().create_timer(1.1).timeout.connect(_ophelia.step_aside.bind(_ophelia.global_basis.x.normalized() * 1.1, 1.4))
		wait = 3.4
	else:
		_ophelia.sit()
	get_tree().create_timer(wait).timeout.connect(_end.bind(ending))


func _end(ending: String) -> void:
	Game.ending_title = ENDINGS[ending][0]
	Game.ending_body = ENDINGS[ending][1]
	if Game.phase == Game.Phase.DIALOGUE:
		Game.set_phase(Game.Phase.PLAYING)
	Game.escape()


func _menu() -> void:
	Game.mathilda_pov = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _clip(line: Dictionary) -> AudioStream:
	var path := "res://assets/audio/voice/mathilda/" + Voice.clip_key(line.text, line.mood) + ".wav"
	return load(path) as AudioStream if ResourceLoader.exists(path) else null
