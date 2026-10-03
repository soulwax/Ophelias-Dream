class_name Haunting
extends Node3D

## The house is not one of the things in the field. It keeps her inside, where
## the one on the step can wait. Tension builds the longer she stays
## and drains away outside; at intervals that shorten with it, the house does
## something, chosen for the room she is in:
##
##   flicker   the lamps of her room stutter
##   door      a door she can see drifts open or shut on its own
##   knock     three knocks at the front door (frantic if the hunter waits there)
##   steps     footsteps cross the floor above her while she is in the cellar
##   chamber   a cold chamber swings open behind her, its tray sliding out
##   creak     a board gives somewhere behind her
##   whisper   close to her ear
##
## And some things are kept: the lantern goes out when she leaves the bedroom
## and is lit again when she returns; the first time she leaves the mortuary,
## something is laid out on the table for when she comes back. The taps drip.

const AUDIO := "res://assets/audio/%s.wav"

var house: House
var tension := 0.0
var room := ""

var _cooldown := 14.0
var _drip_in := 3.0
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_cursor := 0
var _sounds: Dictionary = {}
var _flickering: Dictionary = {}
var _left_morgue := false
var _body_laid := false
var _lantern_out := false
var _first_cellar := true


func _ready() -> void:
	top_level = true
	if OS.get_environment("RUN_HAUNT") != "":
		_cooldown = 2.0
	for i in 6:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = "Effects"
		voice.unit_size = 4.0
		voice.max_distance = 30.0
		voice.attenuation_filter_cutoff_hz = 6000.0
		add_child(voice)
		_voices.append(voice)
	for id in ["house_knock", "house_knock_hard", "house_creak_door", "house_creak_board", "house_creak_board_2", "house_whisper", "house_drip", "house_tray", "house_thud", "house_step_above_0", "house_step_above_1", "house_step_above_2"]:
		var path: String = AUDIO % id
		if ResourceLoader.exists(path):
			_sounds[id] = load(path)
	# Recorded boots on the boards above, dulled by the floor between.
	for index in 6:
		var above := "res://assets/audio/steps/above_%02d.wav" % index
		if ResourceLoader.exists(above):
			_sounds["steps_above_%d" % index] = load(above)


func _process(delta: float) -> void:
	_update_flicker(delta)
	if house == null or Game.player == null:
		return
	if Game.phase != Game.Phase.PLAYING and Game.phase != Game.Phase.READING:
		return
	var here := house.room_at(Game.player.global_position + Vector3(0.0, 0.9, 0.0))
	if here != room:
		_enter(here, room)
		room = here
	var inside := room != ""
	tension = clampf(tension + delta * (1.0 / 100.0 if inside else -1.0 / 45.0), 0.0, 1.0)
	_ambient(delta)
	if not inside:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var event := _pick()
	# Dev hook: RUN_HAUNT=<event> fires that event every couple of seconds.
	var forced := OS.get_environment("RUN_HAUNT")
	if forced != "":
		event = forced
	if event != "":
		call("_" + event)
		Game.mark("haunting %s in %s (tension %.2f)" % [event, room, tension])
		if forced != "":
			print("HAUNT ", event, " in ", room)
	_cooldown = 2.0 if forced != "" else lerpf(24.0, 8.0, tension) * randf_range(0.75, 1.3)


# --- What the house keeps -----------------------------------------------------

func _enter(next: String, previous: String) -> void:
	if previous == "bedroom" and next != "bedroom" and house.lantern_light and not _lantern_out:
		# Behind her, the lantern goes out.
		_lantern_out = true
		house.lantern_light.visible = false
	if next == "bedroom" and _lantern_out:
		_lantern_out = false
		house.lantern_light.visible = true
		_stutter(house.lantern_light, 6)
	if previous == "morgue" and next != "morgue":
		_left_morgue = true
	if next == "morgue" and _left_morgue and not _body_laid and house.morgue and house.morgue.body:
		# It was not there the first time.
		_body_laid = true
		house.morgue.body.visible = true
	if House.is_cellar(next) and _first_cellar:
		# The first time down, it waits for her to settle, then walks overhead.
		_first_cellar = false
		_cooldown = minf(_cooldown, 5.0)


func _ambient(delta: float) -> void:
	_drip_in -= delta
	if _drip_in > 0.0 or house.morgue == null:
		return
	_drip_in = randf_range(1.6, 4.5)
	if room in ["morgue", "corridor", "janitor"]:
		var at := house.to_global(house.morgue.sink_at) if room != "janitor" else house.to_global(Vector3(House.JANITOR.position.x + 0.9, House.CELLAR_FLOOR + 0.8, House.JANITOR.end.y - 0.35))
		_play("house_drip", at, Loudness.DRIP, randf_range(0.9, 1.15))


# --- Choosing --------------------------------------------------------------------

func _pick() -> String:
	var options: Array = [["flicker", 3.0], ["creak", 2.0], ["door", 2.0]]
	if House.is_cellar(room):
		options.append(["steps", 3.0 + tension * 3.0])
		if room == "morgue":
			options.append(["chamber", 2.5 + tension * 3.0])
	else:
		options.append(["knock", 1.5 + (3.0 if _hunter_waiting() else 0.0)])
	if tension > 0.45:
		options.append(["whisper", tension * 1.5])
	var total := 0.0
	for option in options:
		total += float(option[1])
	var roll := randf() * total
	for option in options:
		roll -= float(option[1])
		if roll <= 0.0:
			return option[0]
	return ""


func _hunter_waiting() -> bool:
	return Game.hunter != null and Game.notes_found >= Tune.HUNT_NOTES and Game.hunter.global_position.distance_to(house.doorstep()) < 6.0


# --- Events -------------------------------------------------------------------------

func _flicker() -> void:
	for lamp in house.room_lights.get(room, []):
		_stutter(lamp, randi_range(5, 11))


func _creak() -> void:
	# A board gives a few metres behind her.
	var behind := _behind(randf_range(2.0, 4.0))
	_play("house_creak_board" if randf() < 0.5 else "house_creak_board_2", behind, Loudness.BOARD_CREAK, randf_range(0.85, 1.1))


func _door() -> void:
	# A door she can see, not one she is standing in, moves on its own.
	var best: HouseDoor = null
	var best_score := -1.0
	var eye := _eye()
	var look := _look()
	for key in house.doors:
		var door := house.doors[key] as HouseDoor
		var to := door.global_position + Vector3(0.0, 1.0, 0.0) - eye
		var reach := to.length()
		if reach < 2.2 or reach > 12.0:
			continue
		var seen := to.normalized().dot(look)
		if seen > best_score:
			best_score = seen
			best = door
	if best == null:
		_creak()
		return
	best.drift(not best.is_open, _sounds.get("house_creak_door"))


func _knock() -> void:
	var front := house.doors.get("front") as HouseDoor
	if front == null:
		return
	var hard := _hunter_waiting() or tension > 0.75
	_play("house_knock_hard" if hard else "house_knock", front.global_position + Vector3(0.0, 1.2, 0.4), Loudness.KNOCK_HARD if hard else Loudness.KNOCK, randf_range(0.92, 1.05))


func _steps() -> void:
	# Someone crosses the room above, toward the head of the stair.
	var path := house.steps_above()
	if path.is_empty():
		return
	var count := randi_range(mini(5, path.size()), path.size())
	var start := path.size() - count
	for i in range(start, path.size()):
		var tread := "steps_above_%d" % (i % 6)
		if not _sounds.has(tread):
			tread = "house_step_above_%d" % (i % 3)
		_play(tread, path[i], Loudness.STEP_ABOVE, randf_range(0.9, 1.1))
		await get_tree().create_timer(randf_range(0.5, 0.68)).timeout
		if not is_inside_tree():
			return
	if randf() < 0.45:
		_play("house_creak_board", path[path.size() - 1], Loudness.BOARD_CREAK + 2.0, 0.8)
	elif randf() < 0.5:
		await get_tree().create_timer(0.9).timeout
		_play("house_thud", path[path.size() - 1], Loudness.THUD, 1.0)


func _chamber() -> void:
	# Behind her back, never while she watches.
	if house.morgue == null:
		return
	var look := _look()
	var eye := _eye()
	var shut: Array[HouseDoor] = []
	for chamber in house.morgue.chambers:
		if chamber.is_open:
			continue
		if (chamber.global_position - eye).normalized().dot(look) < 0.15:
			shut.append(chamber)
	if shut.is_empty():
		_creak()
		return
	var chamber := shut[randi() % shut.size()]
	chamber.drift(true, _sounds.get("house_creak_door"))
	await get_tree().create_timer(1.1).timeout
	_play("house_tray", chamber.global_position, Loudness.TRAY, randf_range(0.9, 1.05))


func _whisper() -> void:
	# Close at her ear, a little behind, on one side.
	var side := Game.player.camera.global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0) if Game.player.camera else Vector3.RIGHT
	var at := _eye() + side * 0.45 - _look() * 0.25
	_play("house_whisper", at, Loudness.WHISPER, randf_range(0.9, 1.0))


# --- Helpers -------------------------------------------------------------------------

## A lamp stutters for a few beats, then steadies again.
func _stutter(lamp: Light3D, beats: int) -> void:
	if lamp == null:
		return
	if not _flickering.has(lamp):
		_flickering[lamp] = [lamp.light_energy, beats, 0.0]
	else:
		(_flickering[lamp] as Array)[1] = beats


func _update_flicker(delta: float) -> void:
	for lamp in _flickering.keys():
		var state: Array = _flickering[lamp]
		if not is_instance_valid(lamp):
			_flickering.erase(lamp)
			continue
		state[2] = float(state[2]) - delta
		if float(state[2]) > 0.0:
			continue
		if int(state[1]) <= 0:
			(lamp as Light3D).light_energy = state[0]
			_flickering.erase(lamp)
			continue
		state[1] = int(state[1]) - 1
		var dim := int(state[1]) % 2 == 1
		(lamp as Light3D).light_energy = float(state[0]) * (randf_range(0.0, 0.25) if dim else randf_range(0.8, 1.1))
		state[2] = randf_range(0.04, 0.16)


# spl: how loud the thing is at 1 m (Loudness); her distance does the rest.
func _play(id: String, at: Vector3, spl: float, pitch: float) -> void:
	var stream: AudioStream = _sounds.get(id)
	if stream == null:
		return
	var voice := _voices[_voice_cursor]
	_voice_cursor = (_voice_cursor + 1) % _voices.size()
	voice.stream = stream
	Loudness.sound(voice, spl)
	voice.global_position = at
	voice.pitch_scale = pitch
	voice.play()


# Her head, where she hears from.
func _eye() -> Vector3:
	if Game.player.ears:
		return Game.player.ears.global_position
	return Game.player.camera.global_position if Game.player.camera else Game.player.global_position + Vector3(0.0, 1.6, 0.0)


func _look() -> Vector3:
	if Game.player.camera == null:
		return Vector3.FORWARD
	var look := -Game.player.camera.global_transform.basis.z
	look.y = 0.0
	return look.normalized()


func _behind(distance: float) -> Vector3:
	return Game.player.global_position - _look() * distance + Vector3(0.0, 0.3, 0.0)
