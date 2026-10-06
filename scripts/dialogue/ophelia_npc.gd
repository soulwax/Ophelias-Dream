class_name OpheliaNpc
extends Node3D

## Ophelia as someone met, in Mathilda's chapter: her body at the doorstep,
## idling, turning toward whoever she talks to (Conversation calls head() and
## face()). She can take a cup, step aside, or sit on the step.

var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var _head := -1
var _hand := -1
var _cup: MeshInstance3D


func _ready() -> void:
	var path := "res://assets/characters/styloo_elf/elf.glb"
	if ResourceLoader.exists(path):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		model.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
		model.rotation.y = PI
		add_child(model)
		skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		_head = skeleton.find_bone("DEF-spine.006")
		_hand = skeleton.find_bone("DEF-hand.R")
		animation_player = AnimationPlayer.new()
		skeleton.get_parent().add_child(animation_player)
		animation_player.root_node = NodePath("..")
		animation_player.add_animation_library("", load("res://assets/characters/styloo_elf/elf_animations.res") as AnimationLibrary)
		animation_player.play("Idle")
	# Mathilda walks up to her, not through her.
	var body := StaticBody3D.new()
	body.collision_layer = Tune.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	body.add_child(shape)
	add_child(body)


## Stands on whatever is under this spot: the porch stone or the snow.
func settle(at: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, Tune.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	global_position = hit.position if not hit.is_empty() else at
	reset_physics_interpolation()


## Where her voice comes from and where the camera looks.
func head() -> Vector3:
	if skeleton and _head >= 0:
		return skeleton.global_transform * skeleton.get_bone_global_pose(_head).origin
	return global_position + Vector3.UP * 1.45


## Turns her toward a point, gently; she looks, she does not square up.
func face(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() < 0.1:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-delta * 2.0))


func hand() -> Vector3:
	if skeleton and _hand >= 0:
		return skeleton.global_transform * skeleton.get_bone_global_pose(_hand).origin
	return global_position + global_basis * Vector3(0.25, 1.0, -0.2)


## The cup arrives in her hand.
func take_cup(cup: MeshInstance3D) -> void:
	_cup = cup


func step_aside(offset: Vector3, seconds: float) -> void:
	if animation_player and animation_player.has_animation("Walk_Formal"):
		animation_player.play("Walk_Formal", 0.3)
	var tween := create_tween()
	tween.tween_property(self, "global_position", global_position + offset, seconds)
	tween.tween_callback(func() -> void:
		if animation_player:
			animation_player.play("Idle", 0.4))


func sit() -> void:
	if animation_player and animation_player.has_animation("Crouch_Idle"):
		animation_player.play("Crouch_Idle", 0.6)


func _process(_delta: float) -> void:
	if is_instance_valid(_cup):
		_cup.global_position = hand()


static func cup() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.045
	shape.bottom_radius = 0.035
	shape.height = 0.09
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("a0bcc0")
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh
