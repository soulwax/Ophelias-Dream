extends SceneTree

# A sprint leap from her left side, eight points through the flight: the clip
# alone (top row), with Leap's line (middle), and the landing dip after a hard
# drop (bottom, about 0.04 s apart). Needs a window.
#   godot-mono --path . -s tools/leap_sheet.gd
# The sheet lands in build/leap/leap_sheet.png.

const OUT := "res://build/leap/"
const CELL := Vector2i(200, 260)
const COLUMNS := 8

var _stride: Stride
var _leap: Leap


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_root().size = Vector2i(600, 780)
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
	var camera := Camera3D.new()
	camera.fov = 30.0
	world.add_child(camera)
	camera.look_at_from_position(Vector3(4.6, 0.95, 0.0), Vector3(0, 0.8, 0.0))
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := AnimationPlayer.new()
	skeleton.get_parent().add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", load("res://assets/characters/styloo_elf/elf_animations.res") as AnimationLibrary)
	_stride = Stride.build(player, skeleton.get_parent())
	_leap = Leap.fit(skeleton)
	_leap.lead_left = true
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * 3, false, Image.FORMAT_RGB8)
	for row in 2:
		for column in COLUMNS:
			var progress := float(column) / float(COLUMNS - 1)
			_stride.leap_pose(1.0, progress, true, 1.0)
			_leap.amount = float(row)
			_leap.progress = progress
			await _frames(3)
			_blit(sheet, column, row)
	_leap.amount = 0.0
	_stride.leap_pose(1.0, 1.0, true, 1.0)
	await _frames(3)
	_leap.dip(1.0, true)
	for column in COLUMNS:
		# Hold the contact frame so only the dip moves her.
		for frame in 2:
			_stride.leap_pose(1.0, 1.0, true, 1.0)
			await process_frame
		await RenderingServer.frame_post_draw
		_blit(sheet, column, 2)
	sheet.save_png(ProjectSettings.globalize_path(OUT + "leap_sheet.png"))
	print("saved ", OUT + "leap_sheet.png")
	quit()


func _blit(sheet: Image, column: int, row: int) -> void:
	var shot := get_root().get_texture().get_image()
	shot.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * column, CELL.y * row))


func _frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw
