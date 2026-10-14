extends SceneTree

## Contact sheet and visual inspection probe for the lantern pickup animation,
## front-wear anatomy, and darkness illumination.
## Saves to build/lantern/lantern_sheet.png.

const OUT := "res://build/lantern/"
const CELL := Vector2i(240, 320)
const COLUMNS := 8

var _world: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _anim_player: AnimationPlayer
var _lantern_hold: LanternHold
var _lantern: Lantern
var _camera: Camera3D
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _stand: MeshInstance3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_root().size = Vector2i(CELL.x * COLUMNS, CELL.y * 2)

	_world = Node3D.new()
	get_root().add_child(_world)

	_env = WorldEnvironment.new()
	_env.environment = Environment.new()
	_env.environment.background_mode = Environment.BG_COLOR
	_env.environment.background_color = Color(0.18, 0.22, 0.28)
	_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.environment.ambient_light_color = Color(0.45, 0.48, 0.55)
	_world.add_child(_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(35.0), 0.0)
	_sun.light_energy = 0.85
	_sun.shadow_enabled = true
	_world.add_child(_sun)

	# Ground snow floor.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 10.0)
	floor_mesh.mesh = plane
	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.85, 0.89, 0.94)
	snow_mat.roughness = 0.8
	floor_mesh.material_override = snow_mat
	_world.add_child(floor_mesh)

	# Wooden pedestal for the lantern (placed conveniently at Ophelia's right hand side).
	_stand = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.18
	cyl.height = 0.65
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.25, 0.18, 0.12)
	wood.roughness = 0.9
	cyl.material = wood
	_stand.mesh = cyl
	_stand.position = Vector3(-0.24, 0.325, 0.45)
	_world.add_child(_stand)

	# Spawn the elf model.
	var model_scene := load("res://assets/characters/styloo_elf/elf.glb") as PackedScene
	_model = model_scene.instantiate()
	_model.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
	_world.add_child(_model)

	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_anim_player = AnimationPlayer.new()
	_model.add_child(_anim_player)
	_anim_player.root_node = NodePath("..")
	if ResourceLoader.exists("res://assets/characters/styloo_elf/elf_animations.res"):
		_anim_player.add_animation_library("", load("res://assets/characters/styloo_elf/elf_animations.res") as AnimationLibrary)

	# Attach LanternHold modifier.
	_lantern_hold = LanternHold.new()
	_lantern_hold.name = "LanternHold"
	_skeleton.add_child(_lantern_hold)
	_lantern_hold.Configure(Tune.LANTERN_HOIST_SECONDS, Tune.LANTERN_TOGGLE_SECONDS, Tune.LANTERN_CHEST_POSITION, Tune.LANTERN_HIP_POSITION)

	# Create the lantern.
	_lantern = Lantern.new()
	_lantern.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
	_lantern.position = Vector3(-0.24, 0.65, 0.45)
	_world.add_child(_lantern)

	# Setup Camera (focused on Ophelia's right side and the lantern).
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_world.add_child(_camera)
	_camera.look_at_from_position(Vector3(-1.15, 1.15, 1.55), Vector3(-0.1, 0.95, 0.25))

	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * 2, false, Image.FORMAT_RGB8)

	# -------------------------------------------------------------
	# ROW 0: The 8-phase Pickup Animation (Reach, Grasp, Lift, Attach)
	# -------------------------------------------------------------
	if _anim_player.has_animation("Idle"):
		_anim_player.play("Idle")
		_anim_player.seek(0.0, true)

	_lantern_hold.BeginPickup(_lantern, 1.0)
	var steps := [0.0, 0.14, 0.28, 0.42, 0.56, 0.70, 0.85, 1.0]

	for col in COLUMNS:
		var target_t: float = steps[col]
		if _anim_player.has_animation("Idle"):
			_anim_player.seek(0.0, true)
		_lantern_hold.set("_elapsed", target_t * 1.0)
		_lantern_hold._ProcessModificationWithDelta(0.016)
		await _frames(2)
		_blit(sheet, col, 0)

	# -------------------------------------------------------------
	# ROW 1: Front-Wear & Lighting Angles (Front, 3/4, Profile, Night)
	# -------------------------------------------------------------
	_lantern_hold.AttachChest()
	_stand.visible = false
	if _anim_player.has_animation("Idle"):
		_anim_player.play("Idle")
		_anim_player.seek(0.0, true)

	# Col 0: Front view (direct camera)
	_camera.fov = 34.0
	_camera.look_at_from_position(Vector3(0.0, 1.1, 1.7), Vector3(0.0, 1.0, 0.0))
	_lantern_hold._ProcessModificationWithDelta(0.016)
	await _frames(2)
	_blit(sheet, 0, 1)

	# Col 1: 3/4 Right view
	_camera.fov = 34.0
	_camera.look_at_from_position(Vector3(-1.25, 1.1, 1.25), Vector3(0.0, 1.0, 0.0))
	_lantern_hold._ProcessModificationWithDelta(0.016)
	await _frames(2)
	_blit(sheet, 1, 1)

	# Col 2: Side Profile view (checking chest clearance)
	_camera.fov = 34.0
	_camera.look_at_from_position(Vector3(-1.6, 1.1, 0.0), Vector3(0.0, 1.0, 0.0))
	_lantern_hold._ProcessModificationWithDelta(0.016)
	await _frames(2)
	_blit(sheet, 2, 1)

	# Col 3: Close-up on lantern brass, flame, and harness
	_camera.fov = 24.0
	_camera.look_at_from_position(Vector3(-0.10, 1.12, 0.72), Vector3(0.0, 1.08, 0.18))
	_lantern_hold._ProcessModificationWithDelta(0.016)
	await _frames(2)
	_blit(sheet, 3, 1)

	# Col 4: Walking pose with front wear
	_camera.fov = 35.0
	_camera.look_at_from_position(Vector3(-1.25, 1.1, 1.35), Vector3(0.0, 0.95, 0.0))
	if _anim_player.has_animation("Walk"):
		_anim_player.play("Walk")
		_anim_player.seek(0.35, true)
	_lantern_hold._ProcessModificationWithDelta(0.016)
	await _frames(2)
	_blit(sheet, 4, 1)

	# Col 5: Jog pose with dynamic lantern sway
	if _anim_player.has_animation("Jog_Fwd"):
		_anim_player.play("Jog_Fwd")
		_anim_player.seek(0.42, true)
	_lantern_hold.set("_swayAngle", Vector2(0.18, 0.12))
	_lantern_hold._ProcessModificationWithDelta(0.016)
	await _frames(2)
	_blit(sheet, 5, 1)

	# Col 6: Night twilight (low ambient, full lantern light cast)
	_sun.light_energy = 0.02
	_env.environment.background_color = Color(0.01, 0.02, 0.03)
	_env.environment.ambient_light_color = Color(0.03, 0.03, 0.05)
	_camera.look_at_from_position(Vector3(-1.3, 1.05, 1.8), Vector3(0.0, 0.85, 0.2))
	_lantern_hold.set("_swayAngle", Vector2.ZERO)
	_lantern_hold._ProcessModificationWithDelta(0.016)
	await _frames(3)
	_blit(sheet, 6, 1)

	# Col 7: Stowed on hip
	_sun.light_energy = 0.85
	_env.environment.background_color = Color(0.18, 0.22, 0.28)
	_env.environment.ambient_light_color = Color(0.45, 0.48, 0.55)
	_lantern_hold.AttachHip()
	_lantern_hold._ProcessModificationWithDelta(0.016)
	await _frames(2)
	_blit(sheet, 7, 1)

	var path := ProjectSettings.globalize_path(OUT + "lantern_sheet.png")
	sheet.save_png(path)
	print("Contact sheet saved to ", path)
	quit(0)


func _blit(sheet: Image, column: int, row: int) -> void:
	var shot := get_root().get_texture().get_image()
	shot.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * column, CELL.y * row))


func _frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw

