extends Node

enum Phase { BOOT, INTRO, PLAYING, READING, PAUSED, CAUGHT, ESCAPED, JOURNAL, DIALOGUE }

signal phase_changed(next: Phase)
signal closeness_changed(value: float)
signal interaction_feedback(message: String, succeeded: bool)

# A page went into the journal, or a smudge was solved.
signal journal_changed
signal page_added(entry: NoteEntry)
# Every smudge on this page is solved; the line between the lines shows.
signal page_deciphered(entry: NoteEntry)
# She looked back after the last page (turn_around).
signal turned

enum Reading { LOCKED, WRONG, RIGHT }

var mathilda_pov := false
var phase: Phase = Phase.BOOT
# Threats report here: how near the one that hunts her is (closeness), the
# strongest other pressure (dread) and the HUD line that goes with it. The
# UI never shows distances. There are no threats in the field yet; see
# docs/THREATS.md.
var closeness: float = 0.0
var player: Player
var trail: Trail
var soundscape: Soundscape
var dialogue: DialogueBubble
var voice: Voice
var weather: Weather
var active_note: FieldNote
var intro_left: float = Tune.INTRO_TIME
var notes_found: int = 0
var has_bow := false
var lean_graphics := true
var blackbox: Blackbox
var settings: Settings
# The cabin she wakes in: rooms, cellar and morgue.
var house: House
var dread: float = 0.0
var threat_hint := ""
# Something waiting on the doorstep: the house knocks harder.
var something_at_door := false
# Whatever threat has just shown itself in the open; ravens scold beside it.
var shown_threat: Node3D
# A line from the house, spoken under the breath, gone in a few seconds.
var murmur := ""
var murmur_left := 0.0
# Who is speaking the murmur when it is not the one being played (a passing).
var murmur_speaker := ""
# How many times this run she and the other one have passed each other.
var passings := 0
# Records she has read (NoteEntry.record_of), by code.
var understood: Dictionary = {}
var ending_title := ""
var ending_body := ""
# She opened the page that asks her to finish. The road remembers. The catch does not speak in that voice.
var read_last_page := false
# The journal: pages in the order found, the one to open on, and what she
# knows that makes a smudge legible (NoteEntry.smudges keys).
var journal: Array[NoteEntry] = []
var journal_focus := ""
var read_pages: Dictionary = {}
var visited: Dictionary = {}
var heard_events: Dictionary = {}
# title -> {smudge index: true}
var deciphered: Dictionary = {}
# She looked back after the last page: one set of prints (EndCard, Voice).
var turned_around := false
var _turn_hold := 0.0
# The lookout checkpoint. at_checkpoint is this run's; `checkpoint` keeps what
# she had there across a restart (reset() leaves it), until a new run clears it.
var at_checkpoint := false
var checkpoint: Dictionary = {}
var _resume := false
signal checkpoint_reached
# Ophelia's day: seconds of her clock so far (it runs while she is awake in the
# world), and which hours she has already noticed.
var day_seconds := 0.0
var day_running := false
var _moments_said: Dictionary = {}
# Which ending the run reached: road (the lake), prints, gone, together, shore.
var ending_kind := ""
# Lake sets this while Mathilda waits on the ice: the hole is then a meeting,
# not an ending.
var meeting_waiting := false
var _unready_said := false

var hunt_started := false
var _hunt_seconds := 0.0
var audio_fade := 0.0
var _audio_hold := 4


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var blackbox_path := OS.get_environment("RUN_BLACKBOX")
	if blackbox_path != "":
		blackbox = Blackbox.open(blackbox_path)
		if blackbox:
			add_child(blackbox)
	_bind("move_forward", KEY_W)
	_bind("move_back", KEY_S)
	_bind("move_left", KEY_A)
	_bind("move_right", KEY_D)
	_bind("sprint", KEY_SHIFT)
	_bind("interact", KEY_E)
	_bind("pause", KEY_ESCAPE)
	_bind("restart", KEY_R)
	_bind("jump", KEY_SPACE)
	_bind("slide", KEY_CTRL)
	_bind("slide", KEY_C)
	_bind("walk_slow", KEY_ALT)
	_bind("glance_back", KEY_Q)
	_bind("journal", KEY_J)
	_bind("journal", KEY_TAB)
	_bind_mouse("glance_back", MOUSE_BUTTON_MIDDLE)
	_bind_pad()
	# After the defaults, so it knows what to reset the keys to.
	settings = Settings.new()
	settings.name = "Settings"
	add_child(settings)
	lean_graphics = _wants_lean_graphics()
	print("graphics: ", "lean" if lean_graphics else "full", " on ", RenderingServer.get_video_adapter_name())


func _process(delta: float) -> void:
	if phase != Phase.BOOT and audio_fade < 1.0:
		if _audio_hold > 0:
			_audio_hold -= 1
		else:
			audio_fade = move_toward(audio_fade, 1.0, minf(delta, 0.05) / Tune.INTRO_TIME)
			if settings:
				settings.apply_audio()
	if not mathilda_pov and phase == Phase.PLAYING and player and trail:
		# The lights at the lookout were only lanterns: a checkpoint. The way
		# out is the old hole in the lake ice, further on.
		if _at_exit() and not at_checkpoint:
			reach_checkpoint()
		# The hole: an attempt, if she carries enough of Mathilda to make one.
		if _at_lake() and not meeting_waiting:
			if journal.size() >= Tune.LAKE_PAGES:
				ending_kind = "prints" if turned_around else "road"
				escape()
			elif not _unready_said and voice:
				_unready_said = true
				voice.moment("unready")
	if not mathilda_pov and day_running and awake() and phase != Phase.DIALOGUE:
		_tick_day(delta)
	if awake():
		if not hunt_started and player and trail and not indoors(player.global_position + Vector3.UP * 0.9):
			if trail.offset_of(player.global_position) >= trail.player_start_offset + Tune.HUNT_ROUTE_DISTANCE:
				start_hunt()
		if hunt_started:
			_hunt_seconds += delta
	if awake() and player:
		visit(place_at(player.global_position))
	if phase == Phase.PLAYING and player:
		_watch_turn(delta)
	if phase != Phase.INTRO:
		return
	intro_left -= delta
	if intro_left <= 0.0:
		set_phase(Phase.PLAYING)


func reset() -> void:
	Engine.time_scale = 1.0
	if is_inside_tree():
		get_tree().paused = false
	phase = Phase.BOOT
	closeness = 0.0
	intro_left = Tune.INTRO_TIME
	player = null
	trail = null
	soundscape = null
	dialogue = null
	voice = null
	weather = null
	active_note = null
	notes_found = 0
	has_bow = false
	house = null
	dread = 0.0
	threat_hint = ""
	something_at_door = false
	shown_threat = null
	murmur = ""
	murmur_left = 0.0
	murmur_speaker = ""
	passings = 0
	understood.clear()
	ending_title = ""
	ending_body = ""
	read_last_page = false
	journal.clear()
	journal_focus = ""
	read_pages.clear()
	visited.clear()
	heard_events.clear()
	deciphered.clear()
	turned_around = false
	_turn_hold = 0.0
	at_checkpoint = false
	day_seconds = 0.0
	day_running = false
	_moments_said.clear()
	ending_kind = ""
	meeting_waiting = false
	_unready_said = false
	hunt_started = false
	_hunt_seconds = 0.0
	audio_fade = 0.0
	_audio_hold = 4
	if settings:
		settings.apply_audio()


func begin_intro() -> void:
	intro_left = Tune.INTRO_TIME
	audio_fade = 0.0
	_audio_hold = 4
	if settings:
		settings.apply_audio()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_phase(Phase.INTRO)


func mark(line: String) -> void:
	if blackbox:
		blackbox.write(line)


func set_phase(next: Phase) -> void:
	if phase == next:
		return
	phase = next
	# Her day begins the first time she is in the world.
	if next == Phase.PLAYING and not mathilda_pov and not day_running and player:
		start_day()
	phase_changed.emit(phase)


func set_closeness(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, closeness):
		return
	closeness = next
	closeness_changed.emit(closeness)


func begin_reading() -> void:
	if mathilda_pov:
		return
	if phase != Phase.PLAYING:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var entry := active_note.entry if active_note else null
	if entry and entry.record_of != "":
		active_note.collect()
		understood[entry.record_of] = true
	elif entry and not entry.counts:
		active_note.collect()
	elif active_note and active_note.collect():
		notes_found += 1
		if entry and entry.title == NoteCatalog.LAST_TITLE:
			read_last_page = true
		if notes_found >= Tune.HUNT_NOTES:
			start_hunt()
	if entry:
		add_to_journal(entry)
	if voice and entry:
		voice.heard_page(entry)
	set_phase(Phase.READING)


func reading_last_page() -> bool:
	if phase != Phase.READING or active_note == null or active_note.entry == null:
		return false
	return active_note.entry.title == NoteCatalog.LAST_TITLE


func murmur_line(line: String, speaker := "") -> void:
	murmur = line
	murmur_speaker = speaker
	murmur_left = clampf(2.6 + line.length() * 0.04, 3.2, 7.5)


func seconds_hunting() -> float:
	return _hunt_seconds


func start_hunt() -> void:
	if hunt_started:
		return
	hunt_started = true
	mark("hunt started at %d pages" % notes_found)


func close_reading() -> void:
	if phase != Phase.READING:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_phase(Phase.PLAYING)


## The world keeps going: playing, reading a page or in the journal.
func awake() -> bool:
	return phase == Phase.PLAYING or phase == Phase.READING or phase == Phase.JOURNAL or phase == Phase.DIALOGUE


## Where she is, for her lines and the journal's keys: a house room, the
## lights near the exit, or the snow.
func place_at(point: Vector3) -> String:
	if house:
		var room := house.room_at(point + Vector3(0.0, 0.9, 0.0))
		if room != "":
			return room
	if trail:
		var lake := trail.lake_point
		if Vector2(point.x - lake.x, point.z - lake.z).length() < Tune.LAKE_NEAR:
			return "lake"
		var end := trail.exit_point
		var to_end := Vector2(point.x - end.x, point.z - end.z).length()
		if to_end < Tune.EXIT_RADIUS:
			return "lookout"
		if to_end < Tune.LIGHTS_NEAR:
			return "lights"
	return "snow"


func visit(place: String) -> void:
	if place == "" or visited.has(place):
		return
	visited[place] = true
	journal_changed.emit()


func heard(event: String) -> void:
	if heard_events.has(event):
		return
	heard_events[event] = true
	journal_changed.emit()


## page:<title> read, place:<place> visited, event:<call|echo> heard. With her
## voice off she never calls, so the snow stands in for a call; the echo may
## never come, so the last page stands in for it.
func known(key: String) -> bool:
	var split := key.find(":")
	if split < 0:
		return false
	var what := key.substr(split + 1)
	match key.left(split):
		"page":
			return read_pages.has(what)
		"place":
			return visited.has(what)
		"event":
			if heard_events.has(what):
				return true
			if what == "call":
				return visited.has("snow") and (voice == null or not voice.speaks())
			if what == "echo":
				return read_pages.has(NoteCatalog.LAST_TITLE)
	return false


func add_to_journal(entry: NoteEntry) -> void:
	if entry == null:
		return
	read_pages[entry.title] = true
	for kept in journal:
		if kept.title == entry.title:
			journal_changed.emit()
			return
	journal.append(entry)
	page_added.emit(entry)
	journal_changed.emit()


func solved(entry: NoteEntry, index: int) -> bool:
	return entry != null and deciphered.has(entry.title) and (deciphered[entry.title] as Dictionary).has(index)


func page_solved(entry: NoteEntry) -> bool:
	if entry == null:
		return false
	for index in entry.smudges.size():
		if not solved(entry, index):
			return false
	return true


func all_deciphered() -> bool:
	for entry in NoteCatalog.everything():
		if not page_solved(entry):
			return false
	return true


func decipher(entry: NoteEntry, index: int, reading: String) -> Reading:
	if entry == null or index < 0 or index >= entry.smudges.size():
		return Reading.WRONG
	if solved(entry, index):
		return Reading.RIGHT
	var smudge: Dictionary = entry.smudges[index]
	if not known(str(smudge.key)):
		return Reading.LOCKED
	if reading != str((smudge.readings as Array)[0]):
		if voice:
			voice.misread()
		return Reading.WRONG
	if not deciphered.has(entry.title):
		deciphered[entry.title] = {}
	(deciphered[entry.title] as Dictionary)[index] = true
	journal_changed.emit()
	if page_solved(entry):
		page_deciphered.emit(entry)
		if voice:
			voice.deciphered(entry)
	return Reading.RIGHT


## From play, or from the page she is reading (the journal opens on it).
func open_journal(focus := "") -> void:
	if phase == Phase.READING:
		if focus == "" and active_note and active_note.entry:
			focus = active_note.entry.title
	elif phase != Phase.PLAYING:
		return
	journal_focus = focus
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_phase(Phase.JOURNAL)


func close_journal() -> void:
	if phase != Phase.JOURNAL:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_phase(Phase.PLAYING)


## Dev hook (RUN_JOURNAL): every page in the journal with its first smudge
## solved, opened on title.
# Holding glance-back after the last page, outdoors, is turning around.
func _watch_turn(delta: float) -> void:
	if turned_around or not read_last_page or player == null or player.glance < 0.9 \
			or indoors(player.global_position + Vector3.UP * 0.9):
		_turn_hold = 0.0
		return
	_turn_hold += delta
	if _turn_hold >= Tune.TURN_HOLD:
		turn_around()


func turn_around() -> void:
	if turned_around or not read_last_page:
		return
	if player and indoors(player.global_position + Vector3.UP * 0.9):
		return
	turned_around = true
	_turn_hold = 0.0
	mark("turned around")
	turned.emit()
	if voice:
		voice.turned()


## Starts Ophelia's day clock (and the sky with it) at day_seconds in.
func start_day() -> void:
	if mathilda_pov or day_running:
		return
	day_running = true
	var atmosphere := get_tree().get_first_node_in_group("atmosphere") as Atmosphere if is_inside_tree() else null
	if atmosphere:
		atmosphere.start_clock(fposmod(Tune.OPHELIA_START + day_hours(), 24.0))


## Hours of her day so far.
func day_hours() -> float:
	return day_seconds / (Tune.DAY_MINUTES * 60.0) * 24.0


func _tick_day(delta: float) -> void:
	day_seconds += delta
	var hours := day_hours()
	for moment: String in Tune.DAY_MOMENTS:
		if hours >= float(Tune.DAY_MOMENTS[moment]) and not _moments_said.has(moment):
			_moments_said[moment] = true
			if voice:
				voice.moment(moment)
	if hours >= 24.0 and phase in [Phase.PLAYING, Phase.READING, Phase.JOURNAL]:
		mathilda_gone()


## The day ran out before she made an attempt at the lake.
func mathilda_gone() -> void:
	if phase == Phase.CAUGHT or phase == Phase.ESCAPED:
		return
	if phase == Phase.JOURNAL or phase == Phase.READING:
		set_phase(Phase.PLAYING)
	ending_kind = "gone"
	ending_title = "Mathilda is gone"
	ending_body = "A whole day, and you never went to her. The posts are still standing; the wind has taken the rags. Out on the lake the prints have filled in. Wherever she was waiting, she has stopped."
	if journal.size() < Tune.LAKE_PAGES:
		ending_body += " You never read enough of her to follow."
	mark("mathilda is gone")
	escape()


## Whether Mathilda waits on the ice: every trail page read, the last one
## deciphered, and she never turned around (docs/LAKE_MEETING.md).
func meeting_ready() -> bool:
	if turned_around:
		return false
	for entry in NoteCatalog.all():
		if not read_pages.has(entry.title):
			return false
		if entry.title == NoteCatalog.LAST_TITLE and not page_solved(entry):
			return false
	return true


## The meeting on the ice ended; its ending names the card.
func finish_meeting(ending: String) -> void:
	ending_kind = ending
	match ending:
		"together":
			ending_title = "Together"
			ending_body = "You walk back across the ice side by side. The prints you leave are two sets, close together, all the way to the shore, and neither of you looks back, because nobody is behind you."
		_:
			ending_title = "On the shore"
			ending_body = "You sit on the shore with the lantern lit. Out on the ice she holds very still, and for the first time it does not frighten you. When the light comes up, she is walking in."
	mark("met mathilda: " + ending)
	if phase == Phase.DIALOGUE:
		set_phase(Phase.PLAYING)
	escape()


## She has reached the lookout: keep what she has so a restart can bring her
## back here instead of to the cabin.
func reach_checkpoint() -> void:
	if at_checkpoint or player == null:
		return
	at_checkpoint = true
	var copied_deciphered := {}
	for title in deciphered:
		copied_deciphered[title] = (deciphered[title] as Dictionary).duplicate()
	checkpoint = {
		"at": player.global_transform,
		"journal": journal.duplicate(),
		"read_pages": read_pages.duplicate(),
		"visited": visited.duplicate(),
		"heard_events": heard_events.duplicate(),
		"deciphered": copied_deciphered,
		"understood": understood.duplicate(),
		"read_last_page": read_last_page,
		"turned_around": turned_around,
		"hunt_started": hunt_started,
		"notes_found": notes_found,
		"has_bow": has_bow,
		"day_seconds": day_seconds,
		"moments_said": _moments_said.duplicate(),
	}
	mark("checkpoint: lookout")
	checkpoint_reached.emit()


## Restores the checkpoint into a freshly built run (main.gd calls this once the
## level is in place): her pages, journal and places, and her at the lookout.
func resume_checkpoint() -> bool:
	if not _resume or checkpoint.is_empty() or player == null:
		_resume = false
		return false
	_resume = false
	journal.assign(checkpoint.journal)
	read_pages = (checkpoint.read_pages as Dictionary).duplicate()
	visited = (checkpoint.visited as Dictionary).duplicate()
	heard_events = (checkpoint.heard_events as Dictionary).duplicate()
	deciphered = {}
	for title in checkpoint.deciphered:
		deciphered[title] = (checkpoint.deciphered[title] as Dictionary).duplicate()
	understood = (checkpoint.understood as Dictionary).duplicate()
	read_last_page = checkpoint.read_last_page
	turned_around = checkpoint.turned_around
	hunt_started = checkpoint.hunt_started
	notes_found = checkpoint.notes_found
	has_bow = bool(checkpoint.get("has_bow", false))
	if has_bow:
		player.restore_bow()
		for pickup in get_tree().get_nodes_in_group("bow_pickup"):
			pickup.call("remove_found_bow")
	# The day goes on from where she was, not from the start.
	day_seconds = float(checkpoint.get("day_seconds", 0.0))
	_moments_said = (checkpoint.get("moments_said", {}) as Dictionary).duplicate()
	at_checkpoint = true
	# Pages she already carries are gone from the field.
	if trail:
		for note in trail.find_children("FieldNote_*", "FieldNote", false, false):
			var page := note as FieldNote
			if page.entry and read_pages.has(page.entry.title):
				page.visible = false
				page.remove_from_group("field_notes")
	player.global_transform = checkpoint.at
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	journal_changed.emit()
	mark("resumed at the lookout")
	return true


## Dev hook (RUN_ENDING=road|prints|gone|together|shore): that ending's card.
func dev_ending(kind: String) -> void:
	read_last_page = true
	turned_around = kind == "prints"
	match kind:
		"gone":
			mathilda_gone()
		"together", "shore":
			finish_meeting(kind)
		_:
			ending_kind = kind
			escape()


func dev_journal(title: String) -> void:
	for entry in NoteCatalog.everything():
		add_to_journal(entry)
		if not deciphered.has(entry.title):
			deciphered[entry.title] = {}
		(deciphered[entry.title] as Dictionary)[0] = true
	journal_changed.emit()
	open_journal(title)


func toggle_pause() -> void:
	if phase == Phase.JOURNAL:
		close_journal()
		return
	if phase == Phase.PLAYING:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_phase(Phase.PAUSED)
	elif phase == Phase.PAUSED:
		if settings:
			settings.save()
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		set_phase(Phase.PLAYING)


# title and body are the threat's own ending; empty gives the default card.
func catch_player(title := "", body := "") -> void:
	if phase == Phase.CAUGHT or phase == Phase.ESCAPED:
		return
	ending_title = title
	ending_body = body
	rumble(0.8, 1.0, 0.6)
	Engine.time_scale = 0.4
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_phase(Phase.CAUGHT)
	if soundscape:
		soundscape.play_sting()


func escape() -> void:
	if phase == Phase.CAUGHT or phase == Phase.ESCAPED:
		return
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_phase(Phase.ESCAPED)


## Starts again. With from_checkpoint and a checkpoint kept, she wakes at the
## lookout with what she had there; otherwise the checkpoint is forgotten and
## she wakes in the cabin.
func restart(from_checkpoint := false) -> void:
	if settings:
		settings.save()
	_resume = from_checkpoint and not checkpoint.is_empty()
	if not _resume:
		checkpoint.clear()
	reset()
	# The graphics detail setting is read while the snowfield is built.
	lean_graphics = _wants_lean_graphics()
	get_tree().reload_current_scene()


func quit() -> void:
	if settings:
		settings.save()
	get_tree().quit()


# How hard the world is pressing on her, whichever threat it is.
func threat() -> float:
	return maxf(closeness, dread)


# The lookout: within EXIT_RADIUS of the exit, measured flat.
func _at_exit() -> bool:
	var at := player.global_position
	var end := trail.exit_point
	return Vector2(at.x - end.x, at.z - end.z).length() <= Tune.EXIT_RADIUS


# Out on the lake ice by the old hole, measured flat.
func _at_lake() -> bool:
	var at := player.global_position
	var hole := trail.lake_hole
	return Vector2(at.x - hole.x, at.z - hole.z).length() <= Tune.LAKE_ARRIVE


## Whether a resumed run is waiting to be restored (main.gd skips the menu).
func resuming() -> bool:
	return _resume


func knows(code: String) -> bool:
	return understood.has(code)


func indoors(world_point: Vector3) -> bool:
	return house != null and house.contains(world_point)


func locks_movement() -> bool:
	return phase != Phase.PLAYING


func locks_look() -> bool:
	return phase != Phase.PLAYING and phase != Phase.INTRO


# Integrated GPUs hard-froze on volumetric fog and the full shadow load.
# RUN_GRAPHICS=full or RUN_GRAPHICS=lean overrides the guess, then the
# graphics detail setting.
func _wants_lean_graphics() -> bool:
	var forced := OS.get_environment("RUN_GRAPHICS")
	if forced == "full":
		return false
	if forced == "lean":
		return true
	if settings and settings.graphics != 0:
		return settings.graphics == 1
	return RenderingServer.get_video_adapter_type() != RenderingDevice.DEVICE_TYPE_DISCRETE_GPU


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _bind(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


# A gamepad alongside the keys. The sticks are read with their own radial dead
# zone (Player), so the actions themselves pass even the smallest push.
func _bind_pad() -> void:
	for axis in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0],
			["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["move_back", JOY_AXIS_LEFT_Y, 1.0],
			["look_left", JOY_AXIS_RIGHT_X, -1.0], ["look_right", JOY_AXIS_RIGHT_X, 1.0],
			["look_up", JOY_AXIS_RIGHT_Y, -1.0], ["look_down", JOY_AXIS_RIGHT_Y, 1.0],
			["sprint", JOY_AXIS_TRIGGER_LEFT, 1.0]]:
		_bind_axis(axis[0], axis[1], axis[2])
	for button in [["jump", JOY_BUTTON_A], ["slide", JOY_BUTTON_B], ["interact", JOY_BUTTON_X],
			["sprint", JOY_BUTTON_LEFT_STICK], ["glance_back", JOY_BUTTON_RIGHT_STICK],
			["walk_slow", JOY_BUTTON_LEFT_SHOULDER],
			["journal", JOY_BUTTON_Y], ["pause", JOY_BUTTON_START], ["restart", JOY_BUTTON_BACK]]:
		if not InputMap.has_action(button[0]):
			InputMap.add_action(button[0])
		var event := InputEventJoypadButton.new()
		event.button_index = button[1]
		event.device = -1
		InputMap.action_add_event(button[0], event)


func _bind_axis(action: String, axis: JoyAxis, direction: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_set_deadzone(action, 0.05)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	event.device = -1
	InputMap.action_add_event(action, event)


## A short shake on every connected pad, if she wants it.
func rumble(weak: float, strong: float, seconds: float) -> void:
	if settings == null or not settings.rumble:
		return
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), seconds)
