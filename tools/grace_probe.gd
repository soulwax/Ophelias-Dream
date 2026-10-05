extends SceneTree

# Renders the elf alone, side on, with and without Grace: walking frames
# (arm swing, elbows, shoulders) and standing long enough to rise onto her
# toes. Needs a window (not --headless). Shots land in build/grace/.
#   godot --path . -s tools/grace_probe.gd

const OUT := "res://build/grace/"

var _skeleton: Skeleton3D
var _grace: Grace
var _player: AnimationPlayer


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
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
	world.add_child(camera)
	camera.fov = 32.0
	camera.look_at_from_position(Vector3(4.2, 0.9, 0.6), Vector3(0, 0.75, 0.0))
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = AnimationPlayer.new()
	_skeleton.get_parent().add_child(_player)
	_player.root_node = NodePath("..")
	_player.add_animation_library("", load("res://assets/characters/styloo_elf/elf_animations.res") as AnimationLibrary)
	_player.add_animation_library("feminine", load("res://assets/characters/styloo_elf/feminine/elf_feminine.res") as AnimationLibrary)
	_grace = Grace.fit(_skeleton)
	for on in [true, false]:
		_grace.active = on
		var tag := "on" if on else "off"
		for gait in [["walk", Stride._resolve(_player, Stride.WALK), Tune.WALK_SPEED], ["sprint", Stride.SPRINT, Tune.SPRINT_SPEED]]:
			var clip: String = gait[1]
			_player.play(clip)
			_grace.speed = gait[2]
			var length := _player.get_animation(clip).length
			for phase in [0.0, 0.25, 0.5, 0.75]:
				_player.seek(length * phase, true)
				_player.pause()
				await _frames(4)
				_shoot("%s_%s_%02d" % [gait[0], tag, int(phase * 100.0)])
		_player.play("Idle")
		_grace.speed = 0.0
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < int((Tune.TIPTOE_AFTER + 2.5) * 1000.0):
			await process_frame
		_shoot("tiptoe_%s" % tag)
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw


func _shoot(name: String) -> void:
	var image := get_root().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved ", name)
