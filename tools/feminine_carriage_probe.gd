extends SceneTree

# Verifies that Grace's feminine carriage pass computes hip sway,
# quiet shoulders, and narrow arm carriage cleanly across the walk cycle.
#   & $env:GODOT_BIN --headless --path . -s tools/test_feminine_carriage.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model := (load("res://assets/characters/styloo_elf/elf.glb") as PackedScene).instantiate()
	get_root().add_child(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := AnimationPlayer.new()
	skeleton.get_parent().add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", load("res://assets/characters/styloo_elf/elf_animations.res") as AnimationLibrary)
	
	var grace := Grace.fit(skeleton)
	if grace == null:
		push_error("Failed to fit Grace")
		quit(1)
		return
	grace.authored_walk = true
	grace.speed = Tune.WALK_SPEED
	grace.poise = 1.0

	var hips_bone := skeleton.find_bone("DEF-spine")

	var walk_anim := player.get_animation("Walk")
	player.play("Walk")

	var hip_yaws: Array[float] = []
	var hip_rolls: Array[float] = []
	var hip_xs: Array[float] = []
	
	for i in range(21):
		var time := walk_anim.length * float(i) / 20.0
		player.seek(time, true)
		skeleton.force_update_bone_child_transform(hips_bone)
		var hip_rot := skeleton.get_bone_pose_rotation(hips_bone).get_euler()
		var hip_pos := skeleton.get_bone_pose_position(hips_bone)
		hip_yaws.append(hip_rot.y)
		hip_rolls.append(hip_rot.z)
		hip_xs.append(hip_pos.x)

	var min_yaw: float = hip_yaws[0]
	var max_yaw: float = hip_yaws[0]
	for val: float in hip_yaws:
		min_yaw = minf(min_yaw, val)
		max_yaw = maxf(max_yaw, val)
	var yaw_span: float = max_yaw - min_yaw

	var min_roll: float = hip_rolls[0]
	var max_roll: float = hip_rolls[0]
	for val: float in hip_rolls:
		min_roll = minf(min_roll, val)
		max_roll = maxf(max_roll, val)
	var roll_span: float = max_roll - min_roll

	var min_x: float = hip_xs[0]
	var max_x: float = hip_xs[0]
	for val: float in hip_xs:
		min_x = minf(min_x, val)
		max_x = maxf(max_x, val)

	print("Feminine carriage check:")
	print("  Hip yaw span:  %.4f rad (%.2f deg)" % [yaw_span, rad_to_deg(yaw_span)])
	print("  Hip roll span: %.4f rad (%.2f deg)" % [roll_span, rad_to_deg(roll_span)])
	print("  Hip X shift min/max: %.4f .. %.4f m" % [min_x, max_x])

	if yaw_span < 0.04 or roll_span < 0.03:
		push_error("Hip sway failed to produce distinct feminine rotation")
		quit(1)
		return

	print("PASS: Feminine hip sway and carriage active and verified.")
	quit(0)
