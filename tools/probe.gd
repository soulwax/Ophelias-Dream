extends SceneTree

func _initialize() -> void:
	call_deferred("_probe")


func _probe() -> void:
	_mesh("res://assets/environment/SM_Env_Pine_01.fbx", "PINE")
	_mesh("res://assets/environment/SM_Env_Background_Trees_02.fbx", "FAR")
	_mesh("res://assets/environment/SM_Prop_Cabin_01.fbx", "CABIN")
	_mesh("res://assets/environment/SM_Gen_Prop_Papers_01.fbx", "PAPER")
	var rig := load("res://addons/quaternius_ik_rigged/Models_with_rigging/Master_Rigged.tscn") as PackedScene
	var model := rig.instantiate()
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	print("ANIMS ", player.get_animation_list())
	_bounds(model, "BODY")
	quit()


func _mesh(path: String, label: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		print(label, " MISSING")
		return
	_bounds(packed.instantiate(), label)


func _bounds(node: Node, label: String) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		print(label, " ", mesh_instance.name, " pos ", mesh_instance.get_aabb().position, " size ", mesh_instance.get_aabb().size)
