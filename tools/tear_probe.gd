extends Node

## Checks the title-menu tear layer with project autoloads available.
const MENU := preload("res://scripts/ui/dream_menu.gd")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + description)
	if not condition:
		_failures += 1


func _run() -> void:
	OS.set_environment("RUN_TEAR_TIME", "36")
	var menu: Control = MENU.new()
	menu.size = Vector2(1600, 900)
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var layer: ColorRect = menu.get("_tear_glass")
	var material: ShaderMaterial = menu.get("_tear_material")
	_check(is_instance_valid(layer) and layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tear layer leaves menu input reachable")
	_check(is_instance_valid(material) and material.shader.resource_path == "res://shaders/tear_layer.gdshader", "tear shader is attached")
	if is_instance_valid(material):
		_check(is_equal_approx(float(material.get_shader_parameter("menu_time")), 36.0), "menu sends forced tear time to shader")
		_check(float(material.get_shader_parameter("aspect")) > 0.0, "menu sends a valid aspect ratio")
		var light := float(material.get_shader_parameter("light_level"))
		_check(light >= 0.0 and light <= 1.0, "menu sends bounded light level")
	var shot := OS.get_environment("RUN_TEAR_SHOT")
	if not shot.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(shot.get_base_dir())
		_check(get_viewport().get_texture().get_image().save_png(shot) == OK, "tear preview was captured")
	OS.unset_environment("RUN_TEAR_TIME")
	menu.queue_free()
	get_tree().quit(1 if _failures else 0)
