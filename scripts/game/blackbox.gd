class_name Blackbox
extends Node

# Streams debug lines to a file while the game runs, so something survives a
# machine freeze. Enabled by RUN_BLACKBOX=<path>. Godot can only flush to the
# OS cache; tools/blackbox_monitor.ps1 tails this file and forces it to disk.

const BEAT := 0.5
const EARLY_FRAMES := 30

var _file: FileAccess
var _since_beat := 0.0
var _frames := 0
var _started_msec := 0


static func open(path: String) -> Blackbox:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("blackbox: cannot open %s (%s)" % [path, FileAccess.get_open_error()])
		return null
	var box := Blackbox.new()
	box.name = "Blackbox"
	box._file = file
	box._started_msec = Time.get_ticks_msec()
	return box


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	write("start %s" % Time.get_datetime_string_from_system())
	write("godot %s" % Engine.get_version_info().string)
	write("adapter %s | %s | api %s" % [
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_api_version(),
	])
	write("driver %s" % ", ".join(OS.get_video_adapter_driver_info()))
	write("method %s | lean %s | window %s | max_fps %d | vsync %d" % [
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		Game.lean_graphics,
		DisplayServer.window_get_size(),
		Engine.max_fps,
		DisplayServer.window_get_vsync_mode(),
	])
	Game.phase_changed.connect(func(next: Game.Phase) -> void: write("phase %s" % Game.Phase.keys()[next]))


func _process(delta: float) -> void:
	_frames += 1
	if _frames <= EARLY_FRAMES:
		write("frame %d dt %.1fms" % [_frames, delta * 1000.0])
	_since_beat += delta
	if _since_beat < BEAT:
		return
	_since_beat = 0.0
	write(_beat())


func write(line: String) -> void:
	if _file == null:
		return
	_file.store_line("%9.3f %s" % [float(Time.get_ticks_msec() - _started_msec) / 1000.0, line])
	_file.flush()


func _beat() -> String:
	var text := "beat f%d fps %d | draws %d prims %d objs %d | vram %.0fMB tex %.0fMB buf %.0fMB | mem %.0fMB nodes %d" % [
		_frames,
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	]
	text += " | %s notes %d close %.2f" % [Game.Phase.keys()[Game.phase], Game.notes_found, Game.closeness]
	if Game.player:
		var at := Game.player.global_position
		text += " pos (%.0f,%.0f,%.0f)" % [at.x, at.y, at.z]
	if Game.weather:
		text += " storm %.2f" % Game.weather.intensity
	return text
