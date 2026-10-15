class_name Bell
extends Node3D

## The bell at the lookout (errands spec, verb 7), hung from its own post in
## front of the tower, since the tower's rail is out of her reach. A press
## rings it: it swings, and the sound rolls out over the field. The first ring
## of each visit gets an answer a heartbeat later (Tune.BELL_ECHO_DELAY) from
## the far trees, in her own voice (Voice.answer_bell). A visit ends when she
## walks well away. The post's foot is the node's origin.

const VISIT_RADIUS := 30.0
const POST_HEIGHT := 2.05

var answered := false
var _bell: Node3D
var _swing: Tween


static func make(parent: Node3D, at: Vector3, yaw: float) -> Bell:
	var bell := Bell.new()
	bell.name = "LookoutBell"
	parent.add_child(bell)
	bell.global_position = at
	bell.rotation.y = yaw
	bell._build()
	return bell


func _ready() -> void:
	add_to_group("interactables")


func _build() -> void:
	var iron := HouseKit.paint(Color("3b3a36"), 0.45, 0.75)
	var bronze := HouseKit.paint(Color("6e5a35"), 0.35, 0.85)
	var timber := HouseKit.paint(Color("5a3f2b"), 0.85)
	HouseKit.solid(self, "Post", Vector3(0.0, POST_HEIGHT * 0.5, 0.0), Vector3(0.12, POST_HEIGHT + 0.1, 0.12), timber)
	HouseKit.box(self, "Bracket", Vector3(0.0, POST_HEIGHT, 0.14), Vector3(0.05, 0.05, 0.3), iron)
	_bell = Node3D.new()
	_bell.name = "Swing"
	_bell.position = Vector3(0.0, POST_HEIGHT - 0.02, 0.26)
	add_child(_bell)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.11
	cone.height = 0.18
	body.mesh = cone
	body.material_override = bronze
	body.position = Vector3(0.0, -0.11, 0.0)
	_bell.add_child(body)
	HouseKit.box(_bell, "Rope", Vector3(0.0, -0.32, 0.0), Vector3(0.012, 0.24, 0.012), HouseKit.paint(Color("8a3a2c"), 0.9))


func _physics_process(_delta: float) -> void:
	if answered and Game.player and Game.player.global_position.distance_to(global_position) > VISIT_RADIUS:
		answered = false


func interact_label() -> String:
	return "Ring the bell"


func interact_point() -> Vector3:
	return _bell.global_position


func aim_box() -> Array:
	return [_bell.global_transform, AABB(Vector3(-0.14, -0.46, -0.14), Vector3(0.28, 0.48, 0.28))]


func interact() -> bool:
	if ErrandKit.player() == null and Game.player != null:
		return false
	ring()
	return true


func ring() -> void:
	if _swing and _swing.is_running():
		_swing.kill()
	_swing = create_tween()
	for swing: float in [0.5, -0.38, 0.24, -0.12, 0.0]:
		_swing.tween_property(_bell, "rotation:x", swing, 0.32).set_trans(Tween.TRANS_SINE)
	ErrandKit.play(self, "bell", Loudness.BELL, true)
	if not answered and randf() < Tune.BELL_ECHO_CHANCE:
		answered = true
		get_tree().create_timer(Tune.BELL_ECHO_DELAY, false).timeout.connect(_answer)


func _answer() -> void:
	if is_inside_tree() and Game.voice and Game.voice.has_method("answer_bell"):
		Game.voice.answer_bell()
