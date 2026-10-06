class_name Conversation
extends Node

## Runs a DialogueTree with someone in the world (docs/DIALOGUE.md). Lines are
## spoken one at a time, each from its speaker, with the authored pause after
## it; then her topics show. The view turns to whoever speaks and the storm is
## ducked while they talk. Leaving, by a topic or Esc, keeps the place: the
## next begin() greets her and picks up at the same node. Movement and look
## are locked in Game.Phase.DIALOGUE; the world keeps going.

signal line_started(line: Dictionary)
signal ended(ending: String)
signal left

## How far the Ambience and Dread buses drop while they talk.
const DUCK := 0.35

var tree: DialogueTree
## Speaks from its head(); faces her while they talk if it has face().
var npc: Node3D
## Set by the caller (what she has examined) and by the tree (node and topic "sets").
var flags: Dictionary = {}
var taken: Dictionary = {}
var heard: Dictionary = {}
var node_id := ""
var active := false
var finished := ""

var _menu: ConversationMenu
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _line_left := 0.0
var _gap_left := 0.0
var _then: Callable
var _topics: Array[Dictionary] = []
var _their_voice: AudioStreamPlayer3D
var _own_voice: AudioStreamPlayer3D
var _duck := 0.0


static func make(tree_path: String, speaker: Node3D) -> Conversation:
	var conversation := Conversation.new()
	conversation.name = "Conversation"
	conversation.tree = DialogueTree.load_from(tree_path)
	conversation.npc = speaker
	return conversation


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_menu = ConversationMenu.new()
	layer.add_child(_menu)
	_menu.chosen.connect(choose)
	_their_voice = Loudness.voice(Tune.VOICE_SPL, "Voice")
	add_child(_their_voice)
	_own_voice = Loudness.voice(Tune.VOICE_SPL, "Voice")
	add_child(_own_voice)


## Starts or resumes the conversation. Only from play.
func begin() -> bool:
	if active or finished != "" or Game.phase != Game.Phase.PLAYING or tree == null:
		return false
	active = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.set_phase(Game.Phase.DIALOGUE)
	_menu.open(tree.name_of(tree.npc))
	if node_id == "":
		_enter(tree.start)
	else:
		_speak(tree.resume + tree.node(node_id).get("say", []), _offer)
	return true


## Cuts the line being spoken, or the pause after it.
func skip() -> void:
	if not _current.is_empty():
		_their_voice.stop()
		_own_voice.stop()
		_line_left = 0.0
		_gap_left = minf(_gap_left, 0.15)
	else:
		_gap_left = 0.0


## Takes the topic at this index of the ones on screen.
func choose(index: int) -> void:
	if not active or not _menu.choices_shown or index < 0 or index >= _topics.size():
		return
	var topic := _topics[index]
	if topic.get("leave", false):
		_speak([str(tree.leave.get("say", ""))] + Array(tree.leave.get("reply", [])), _walk_away)
		return
	taken[str(topic.key)] = true
	for flag in topic.get("sets", []):
		flags[str(flag)] = true
	var then := _offer
	if topic.has("end"):
		then = _finish.bind(str(topic.end))
	elif topic.has("goto"):
		then = _enter.bind(str(topic.goto))
	_speak([str(topic.get("say", ""))] + Array(topic.get("reply", [])), then)


## Leaves at once, without a word: Esc, or the phase changed under it.
func cancel() -> void:
	if active:
		_close()
		left.emit()


func _enter(id: String) -> void:
	node_id = id
	for flag in tree.node(id).get("sets", []):
		flags[str(flag)] = true
	_speak(tree.node(id).get("say", []), _offer)


func _offer() -> void:
	_topics = tree.topics(node_id, flags, taken)
	if not tree.leave.is_empty():
		var goodbye := {"text": str(tree.line(str(tree.leave.get("say", ""))).get("text", "Goodbye.")), "leave": true}
		_topics.append(goodbye)
	_menu.show_choices(_topics)


func _speak(ids: Array, then: Callable) -> void:
	_queue.clear()
	for id in ids:
		var line := tree.line(str(id))
		if not line.is_empty():
			_queue.append(line)
	_then = then
	_current = {}
	_gap_left = 0.0
	_next()


func _next() -> void:
	if _queue.is_empty():
		_current = {}
		var then := _then
		_then = Callable()
		if then.is_valid():
			then.call()
		return
	_current = _queue.pop_front()
	heard[str(_current.id)] = true
	var theirs := str(_current.speaker) == tree.npc
	_menu.show_line(tree.name_of(str(_current.speaker)), str(_current.text), theirs)
	var voice := _their_voice if theirs else _own_voice
	var stream := _clip(_current)
	_line_left = Conversation.spoken_for(str(_current.text))
	if stream:
		voice.stream = stream
		voice.play()
		_line_left = stream.get_length()
	_gap_left = float(_current.get("pause", 0.4))
	line_started.emit(_current)


## How long a line without a clip stays on screen.
static func spoken_for(text: String) -> float:
	return clampf(1.2 + text.length() * 0.055, 1.6, 6.5)


func _clip(line: Dictionary) -> AudioStream:
	var key := Voice.clip_key(str(line.text), str(line.mood))
	for path in [tree.clips + key + ".wav", tree.clips + "draft/" + key + ".wav"]:
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


func _walk_away() -> void:
	_close()
	left.emit()


func _finish(ending: String) -> void:
	finished = ending
	active = false
	_menu.close()
	_restore_audio()
	ended.emit(ending)


func _close() -> void:
	active = false
	_queue.clear()
	_current = {}
	_then = Callable()
	_their_voice.stop()
	_own_voice.stop()
	_menu.close()
	_restore_audio()
	if Game.phase == Game.Phase.DIALOGUE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Game.set_phase(Game.Phase.PLAYING)


func _restore_audio() -> void:
	_duck = 0.0
	if Game.settings:
		Game.settings.apply_audio()


func _process(delta: float) -> void:
	if not active:
		return
	if Game.phase != Game.Phase.DIALOGUE:
		cancel()
		return
	_place_voices()
	if Game.player and is_instance_valid(npc) and npc.has_method("head"):
		Game.player.look_toward(npc.call("head"), delta)
		if npc.has_method("face"):
			npc.call("face", Game.player.global_position, delta)
	_duck = move_toward(_duck, 1.0, delta * 2.0)
	if Game.settings:
		for bus in [["Ambience", Game.settings.ambience_volume], ["Dread", Game.settings.dread_volume]]:
			var index := AudioServer.get_bus_index(bus[0])
			if index >= 0:
				AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(bus[1]) * lerpf(1.0, DUCK, _duck), 0.0001)))
	if _current.is_empty():
		return
	if _line_left > 0.0:
		_line_left -= delta
		return
	if _their_voice.playing or _own_voice.playing:
		return
	_gap_left -= delta
	if _gap_left <= 0.0:
		_next()


func _place_voices() -> void:
	if is_instance_valid(npc):
		_their_voice.global_position = npc.call("head") if npc.has_method("head") else npc.global_position + Vector3.UP * 1.5
	if Game.player:
		_own_voice.global_position = Game.player.global_position + Vector3.UP * 1.55


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		cancel()
	elif _menu.choices_shown:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
			_menu.step(-1)
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
			_menu.step(1)
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			choose(_menu.selected)
		else:
			return
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		skip()
	elif event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
