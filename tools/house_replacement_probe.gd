extends "res://tools/requested_house_probe.gd"

func _initialize() -> void:
	for id in ["modern_ceiling_lamp_01","painted_wooden_bench","modern_wooden_cabinet"]:
		var scene := load("res://assets/vendor/polyhaven/"+id+"/"+id+"_1k.gltf") as PackedScene
		var node := scene.instantiate() as Node3D
		print("REPLACEMENT ",id)
		_inspect(node,Transform3D.IDENTITY)
		node.free()
	quit()
