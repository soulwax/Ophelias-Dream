@tool
extends SceneTree

func _init() -> void:
	print("--- Running tear probe ---")
	var img := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	var root := Control.new()
	root.size = Vector2(1600, 900)

	var menu := preload("res://scripts/ui/dream_menu.gd").new()
	root.add_child(menu)

	# Simulate 36 seconds
	menu.set("_menu_time", 36.0)
	menu.size = Vector2(1600, 900)

	print("Menu initialized. Checking tear parameters...")
	var tear_mat: ShaderMaterial = menu.get("_tear_material")
	if tear_mat:
		print("tear_mat is present! Shader path:", tear_mat.shader.resource_path)
		tear_mat.set_shader_parameter("menu_time", 36.0)
		tear_mat.set_shader_parameter("aspect", 1600.0 / 900.0)
		tear_mat.set_shader_parameter("light_level", 0.45)
		print("Uniforms set successfully.")
	else:
		print("ERROR: tear_mat is null!")
	quit(0)
