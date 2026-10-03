extends SceneTree

var _frames: int = 0
var _camera: Camera3D


func _initialize() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.35, 0.42, 0.5)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.82, 0.9)
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)
	var plants: Array[String] = ["SM_Env_Bush_01.fbx", "SM_Env_Grass_01.fbx", "SM_Env_Moss_Lumps_01.fbx", "SM_Env_Moss_Lumps_02.fbx", "SM_Env_Moss_Lumps_03.fbx", "SM_Env_Pine_02.fbx", "SM_Env_Pine_03.fbx"]
	for index in plants.size():
		var plant := PropFactory.spawn(plants[index])
		plant.position = Vector3(float(index % 5) * 2.0 - 4.0, 0, -6.0 if index >= 5 else 0.0)
		stage.add_child(plant)
	_camera = Camera3D.new()
	stage.add_child(_camera)
	_camera.position = Vector3(6, 4, 9)
	_camera.look_at_from_position(_camera.position, Vector3(0, 1, -1))
	_camera.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		_capture.call_deferred()
	return false


func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/premium_plants.png")
	quit()
