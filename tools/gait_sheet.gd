extends SceneTree

# Contact sheets of her clips without Grace: one row per clip, four phases
# of the cycle from the front and from the side. Needs a window.
#   godot --path . -s tools/gait_sheet.gd
# Sheets land in build/gait/.

const OUT := "res://build/gait/"
const CLIPS := ["Walk", "Walk_Formal", "Jog_Fwd", "Sprint"]
const CELL := Vector2i(240, 300)

var _player: AnimationPlayer
var _camera: Camera3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_root().size = Vector2i(720, 900)
	var world := Node3D.new()
	get_root().add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.72, 0.76, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.82, 0.86)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(30.0), 0.0)
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(6, 6)
	world.add_child(floor_mesh)
	var model := (load("res://assets/characters/styloo_elf/elf.glb") as PackedScene).instantiate()
	model.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
	world.add_child(model)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	world.add_child(_camera)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = AnimationPlayer.new()
	skeleton.get_parent().add_child(_player)
	_player.root_node = NodePath("..")
	_player.add_animation_library("", load("res://assets/characters/styloo_elf/elf_animations.res") as AnimationLibrary)
	for clip: String in CLIPS:
		if not _player.has_animation(clip):
			print("missing ", clip)
			continue
		var sheet := Image.create(CELL.x * 4, CELL.y * 2, false, Image.FORMAT_RGB8)
		var length := _player.get_animation(clip).length
		for view in 2:
			if view == 0:
				_camera.look_at_from_position(Vector3(0.0, 0.95, 4.6), Vector3(0, 0.8, 0.0))
			else:
				_camera.look_at_from_position(Vector3(4.6, 0.95, 0.0), Vector3(0, 0.8, 0.0))
			for phase in 4:
				_player.play(clip)
				_player.seek(length * float(phase) / 4.0, true)
				_player.pause()
				await _frames(3)
				var shot := get_root().get_texture().get_image()
				shot.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
				sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * phase, CELL.y * view))
		var name := clip.replace("feminine/", "fem_")
		sheet.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		print("saved ", name)
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw
