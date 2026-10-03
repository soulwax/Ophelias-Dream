extends SceneTree

# Samples the elf's baked clips in skeleton space: how far her arms hang out,
# how much they swing, how bent the elbows are, and where the feet are.
#   godot --headless --path . -s tools/elf_motion_probe.gd

const CLIPS := ["Idle", "Walk_Formal", "Jog_Fwd", "Sprint"]


func _initialize() -> void:
	call_deferred("_probe")


func _probe() -> void:
	var model := (load("res://assets/characters/styloo_elf/elf.glb") as PackedScene).instantiate()
	get_root().add_child(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := AnimationPlayer.new()
	skeleton.get_parent().add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", load("res://assets/characters/styloo_elf/elf_animations.res") as AnimationLibrary)
	var bones := {}
	for name in ["DEF-spine", "DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L", "DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R", "DEF-thigh.L", "DEF-thigh.R", "DEF-foot.L", "DEF-foot.R", "DEF-toe.L", "DEF-spine.006"]:
		bones[name] = skeleton.find_bone(name)
	print("REST hips ", skeleton.get_bone_global_rest(bones["DEF-spine"]).origin, " head ", skeleton.get_bone_global_rest(bones["DEF-spine.006"]).origin)
	print("REST shoulderL ", skeleton.get_bone_global_rest(bones["DEF-upper_arm.L"]).origin, " handL ", skeleton.get_bone_global_rest(bones["DEF-hand.L"]).origin)
	print("REST footL ", skeleton.get_bone_global_rest(bones["DEF-foot.L"]).origin, " toeL ", skeleton.get_bone_global_rest(bones["DEF-toe.L"]).origin)
	print("PARENT upper_arm.L ", skeleton.get_bone_name(skeleton.get_bone_parent(bones["DEF-upper_arm.L"])))
	print("PARENT foot.L ", skeleton.get_bone_name(skeleton.get_bone_parent(bones["DEF-foot.L"])), " thigh.L parent ", skeleton.get_bone_name(skeleton.get_bone_parent(bones["DEF-thigh.L"])))
	for clip in CLIPS:
		var anim := player.get_animation(clip)
		player.play(clip)
		var swing_lo := 99.0
		var swing_hi := -99.0
		var out_lo := 99.0
		var out_hi := -99.0
		var bend_lo := 999.0
		var bend_hi := -999.0
		var hips_lo := 99.0
		var hips_hi := -99.0
		var samples := 24
		for i in samples + 1:
			player.seek(anim.length * float(i) / float(samples), true)
			var s := skeleton.get_bone_global_pose(bones["DEF-upper_arm.L"]).origin
			var e := skeleton.get_bone_global_pose(bones["DEF-forearm.L"]).origin
			var h := skeleton.get_bone_global_pose(bones["DEF-hand.L"]).origin
			var arm := (h - s)
			swing_lo = minf(swing_lo, arm.z)
			swing_hi = maxf(swing_hi, arm.z)
			out_lo = minf(out_lo, absf(arm.x))
			out_hi = maxf(out_hi, absf(arm.x))
			var bend := rad_to_deg((e - s).angle_to(h - e))
			bend_lo = minf(bend_lo, bend)
			bend_hi = maxf(bend_hi, bend)
			var hy := skeleton.get_bone_global_pose(bones["DEF-spine"]).origin.y
			hips_lo = minf(hips_lo, hy)
			hips_hi = maxf(hips_hi, hy)
			if i % 6 == 0:
				var fl := skeleton.get_bone_global_pose(bones["DEF-foot.L"]).origin
				var tl := skeleton.get_bone_global_pose(bones["DEF-toe.L"]).origin
				var tz := skeleton.get_bone_global_pose(bones["DEF-thigh.L"]).basis.y
				print("  %s t%.2f handL-shoulder %s elbow %.0f  footL %s toeL %s thighL_dir %s" % [clip, float(i) / float(samples), arm, bend, fl, tl, tz])
		print("CLIP %s len %.2f  swing z %.3f..%.3f  out x %.3f..%.3f  elbow %.0f..%.0f deg  hips %.3f..%.3f" % [clip, anim.length, swing_lo, swing_hi, out_lo, out_hi, bend_lo, bend_hi, hips_lo, hips_hi])
	quit()
