extends Node3D

@export var appearance_texture: Texture2D
@export var outfit_texture: Texture2D


func _ready() -> void:
	var packed := load("res://assets/characters/styloo_elf/elf.glb") as PackedScene
	var model := packed.instantiate() as Node3D
	add_child(model)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface: int in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material := original.duplicate() as StandardMaterial3D
			match original.resource_name.to_lower():
				"elffirst":
					material.albedo_texture = appearance_texture
				"elfsecond":
					material.albedo_texture = outfit_texture
				_:
					push_warning("Unrecognized character material: " + original.resource_name)
					continue
			mesh.set_surface_override_material(surface, material)
