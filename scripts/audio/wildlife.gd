class_name Wildlife
extends Node3D

# The living field, kept subtle: the pines nearest her thrash and creak in
# the gusts, now and then a load of snow slides off a branch, and crows and
# ravens call from distant trees. Everything sounds where it happens, at its
# physical level (Loudness), so it is quiet by nature and lost in a
# blizzard. The birds read the field: while something presses on her they
# fall silent, and a raven scolds from the trees beside the hunter when it
# shows itself.

const NATURE := "res://assets/audio/nature/"
const NEAR_TREES := 3
const RUSTLE_REACH := 45.0

var _trees := PackedVector3Array()
var _rustles: Array[AudioStreamPlayer3D] = []
var _rustle_tree: Array[int] = []
var _rustle_gain: Array[float] = []
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_cursor := 0
var _clips := {}
var _last := {}
var _songbirds: AudioStreamPlayer3D
var _choruses: Array[AudioStream] = []
var _songbird_gain := 0.0
var _next_creak := 6.0
var _next_flump := 18.0
var _next_call := 12.0
var _alarm_in := 0.0
var _retarget := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for kind in ["flump", "tree_creak", "crow", "raven"]:
		_clips[kind] = _load_set(kind)
	for i in NEAR_TREES:
		var rustle := Loudness.voice(Loudness.TREE_RUSTLE, "Outside", true)
		rustle.top_level = true
		rustle.volume_db = -80.0
		rustle.stream = _loop(NATURE + "trees_%d.ogg" % i)
		add_child(rustle)
		if rustle.stream:
			rustle.play(randf() * rustle.stream.get_length())
		_rustles.append(rustle)
		_rustle_tree.append(-1)
		_rustle_gain.append(0.0)
	for i in 6:
		var voice := Loudness.voice(Loudness.CROW, "Outside", true)
		voice.top_level = true
		add_child(voice)
		_voices.append(voice)
	_songbirds = Loudness.voice(Loudness.SONGBIRDS, "Outside", true)
	_songbirds.top_level = true
	add_child(_songbirds)
	for index in 3:
		var chorus := _loop("res://assets/audio/birds_%d.wav" % index)
		if chorus:
			_choruses.append(chorus)


# Streamed loops still playing at quit are reported as leaks.
func _exit_tree() -> void:
	for player in find_children("*", "AudioStreamPlayer3D", false, false):
		(player as AudioStreamPlayer3D).stop()


func _process(delta: float) -> void:
	if Game.trail == null or Game.trail.flora == null or Game.weather == null:
		return
	# Read once the authored level has been laid over the built one.
	if _trees.is_empty():
		_trees = Game.trail.flora.tree_positions()
	var trees := _trees
	if trees.is_empty():
		return
	var listener := get_viewport().get_audio_listener_3d()
	var ears := listener.global_position if listener else Vector3.ZERO
	var gust := Game.weather.gust
	var intensity := Game.weather.intensity
	var walls := Loudness.WALLS * Game.weather.shelter
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.5
		_follow_trees(trees, ears)
	# A pine's needles barely hiss in a lull and roar in a gust.
	var thrash := clampf((intensity - 0.3) * 1.4 + gust * 0.8, 0.0, 1.0)
	for i in _rustles.size():
		var wanted := 1.0 if _rustle_tree[i] >= 0 else 0.0
		_rustle_gain[i] = move_toward(_rustle_gain[i], wanted, delta)
		_rustles[i].volume_db = Loudness.volume(Loudness.TREE_RUSTLE - 22.0 + 22.0 * thrash - walls) + linear_to_db(maxf(_rustle_gain[i], 0.001))
	var threat := Game.threat()
	_wood(trees, ears, gust, walls, delta)
	_birds(trees, ears, intensity, threat, walls, delta)


# Gusts work the trunks; afterwards the branches let go of their snow.
func _wood(trees: PackedVector3Array, ears: Vector3, gust: float, walls: float, delta: float) -> void:
	_next_creak -= delta * (0.25 + gust * 2.0)
	if _next_creak <= 0.0:
		_next_creak = randf_range(5.0, 12.0)
		var tree := _tree_between(trees, ears, 3.0, 28.0)
		if gust > 0.3 and tree != Vector3.INF:
			_shot("tree_creak", tree + Vector3.UP * randf_range(2.0, 3.5), Loudness.TREE_CREAK + randf_range(-4.0, 2.0) - walls, randf_range(0.85, 1.1))
	_next_flump -= delta * (0.4 + gust * 1.6)
	if _next_flump <= 0.0:
		_next_flump = randf_range(14.0, 40.0)
		var tree := _tree_between(trees, ears, 6.0, 40.0)
		if tree != Vector3.INF:
			var side := Vector3(randf_range(-1.5, 1.5), randf_range(1.2, 3.2), randf_range(-1.5, 1.5))
			_shot("flump", tree + side, Loudness.SNOW_FLUMP + randf_range(-5.0, 2.0) - walls, randf_range(0.85, 1.1))


func _birds(trees: PackedVector3Array, ears: Vector3, intensity: float, threat: float, walls: float, delta: float) -> void:
	_next_call -= delta
	if _next_call <= 0.0:
		_next_call = randf_range(16.0, 50.0)
		var tree := _tree_between(trees, ears, 35.0, 150.0)
		if threat < 0.25 and intensity < 0.7 and tree != Vector3.INF:
			var kind := "crow" if randf() < 0.6 else "raven"
			var level := (Loudness.CROW if kind == "crow" else Loudness.RAVEN) - walls
			_series(tree + Vector3.UP * randf_range(5.0, 8.0), kind, randi_range(1, 4), 0.75, level)
	# Something on the field shows itself: a raven in the trees beside it
	# scolds, two or three harsh calls, and the field goes quiet.
	_alarm_in -= delta
	if _alarm_in <= 0.0 and Game.hunter and Game.hunter.model and Game.hunter.model.visible:
		_alarm_in = randf_range(35.0, 60.0)
		var near_it := _tree_between(trees, Game.hunter.global_position, 0.0, 30.0)
		if near_it != Vector3.INF:
			_series(near_it + Vector3.UP * 6.0, "raven", randi_range(2, 3), 0.4, Loudness.RAVEN + 3.0 - walls)
			_next_call = maxf(_next_call, 40.0)
	# Small birds only in the calm, and never with anything near; each time
	# they start up again it is another flock in another tree.
	if not _choruses.is_empty():
		var calm := (1.0 - smoothstep(0.4, 0.62, intensity)) * (1.0 - smoothstep(0.05, 0.25, threat))
		_songbird_gain = move_toward(_songbird_gain, calm, delta * 0.2)
		if _songbird_gain > 0.01 and not _songbirds.playing:
			var perch := _tree_between(trees, ears, 18.0, 50.0)
			if perch != Vector3.INF:
				_songbirds.stream = _choruses[randi() % _choruses.size()]
				_songbirds.global_position = perch + Vector3.UP * 5.0
				_songbirds.play(randf() * _songbirds.stream.get_length())
		elif _songbird_gain <= 0.01 and _songbirds.playing:
			_songbirds.stop()
		_songbirds.volume_db = Loudness.volume(Loudness.SONGBIRDS - walls) + linear_to_db(maxf(_songbird_gain, 0.001))


# The rustling follows her: the nearest pines carry it, and a tree she has
# left fades out before its voice moves to one she is coming to.
func _follow_trees(trees: PackedVector3Array, ears: Vector3) -> void:
	var near := _nearest(trees, ears, NEAR_TREES, RUSTLE_REACH)
	for i in _rustles.size():
		if _rustle_tree[i] >= 0 and near.has(_rustle_tree[i]):
			near.erase(_rustle_tree[i])
		elif _rustle_tree[i] >= 0:
			_rustle_tree[i] = -1
	for i in _rustles.size():
		if _rustle_tree[i] < 0 and _rustle_gain[i] < 0.02 and not near.is_empty():
			_rustle_tree[i] = near.pop_front()
			_rustles[i].global_position = trees[_rustle_tree[i]] + Vector3.UP * 4.0


func _nearest(trees: PackedVector3Array, from: Vector3, count: int, reach: float) -> Array:
	var ranked := []
	for i in trees.size():
		var distance := Vector2(trees[i].x - from.x, trees[i].z - from.z).length()
		if distance <= reach:
			ranked.append([distance, i])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var picked := []
	for entry in ranked.slice(0, count):
		picked.append(entry[1])
	return picked


func _tree_between(trees: PackedVector3Array, from: Vector3, near: float, far: float) -> Vector3:
	for _attempt in 16:
		var tree := trees[randi() % trees.size()]
		var distance := Vector2(tree.x - from.x, tree.z - from.z).length()
		if distance >= near and distance <= far:
			return tree
	return Vector3.INF


func _series(at: Vector3, kind: String, count: int, spacing: float, spl: float) -> void:
	for i in count:
		_shot(kind, at, spl + randf_range(-2.0, 1.0), randf_range(0.95, 1.05))
		await get_tree().create_timer(spacing * randf_range(0.8, 1.3), false).timeout
		if not is_inside_tree():
			return


func _shot(kind: String, at: Vector3, spl: float, pitch: float) -> void:
	var clips: Array = _clips.get(kind, [])
	if clips.is_empty():
		return
	var index := randi() % clips.size()
	if clips.size() > 1 and index == int(_last.get(kind, -1)):
		index = (index + 1) % clips.size()
	_last[kind] = index
	var voice := _voices[_voice_cursor]
	_voice_cursor = (_voice_cursor + 1) % _voices.size()
	Loudness.place(voice, spl, true)
	voice.stream = clips[index]
	voice.global_position = at
	voice.pitch_scale = pitch
	voice.play()


func _load_set(kind: String) -> Array:
	var clips := []
	for index in 32:
		var path := NATURE + "%s_%02d.wav" % [kind, index]
		if not ResourceLoader.exists(path):
			break
		clips.append(load(path))
	return clips


func _loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		stream = wav
	return stream
