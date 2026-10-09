extends SceneTree

# One-time bake of the existing locomotion clips onto Styloo's elf skeleton.
# The hunter rig provides the shared movement clips. Only the baked library
# is used by the player at runtime.
const SOURCE := "res://addons/quaternius_ik_rigged/Models_with_rigging/Master_Rigged.tscn"
const TARGET := "res://assets/characters/styloo_elf/elf.glb"
const OUTPUT := "res://assets/characters/styloo_elf/elf_animations.res"
const CLIPS := ["Idle", "Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Jump_Start", "Jump_Land", "Crouch_Idle", "Hit_Chest"]
const BONES := {
	"Hips": "DEF-spine",
	"Spine": "DEF-spine.001",
	"Chest": "DEF-spine.003",
	"UpperChest": "DEF-spine.004",
	"Neck": "DEF-spine.005",
	"Head": "DEF-spine.006",
	"LeftShoulder": "DEF-shoulder.L",
	"LeftUpperArm": "DEF-upper_arm.L",
	"LeftLowerArm": "DEF-forearm.L",
	"LeftHand": "DEF-hand.L",
	"RightShoulder": "DEF-shoulder.R",
	"RightUpperArm": "DEF-upper_arm.R",
	"RightLowerArm": "DEF-forearm.R",
	"RightHand": "DEF-hand.R",
	"LeftUpperLeg": "DEF-thigh.L",
	"LeftLowerLeg": "DEF-shin.L",
	"LeftFoot": "DEF-foot.L",
	"LeftToes": "DEF-toe.L",
	"RightUpperLeg": "DEF-thigh.R",
	"RightLowerLeg": "DEF-shin.R",
	"RightFoot": "DEF-foot.R",
	"RightToes": "DEF-toe.R",
}
const DIRECTION_CHILD := {
	"LeftShoulder": "LeftUpperArm", "LeftUpperArm": "LeftLowerArm", "LeftLowerArm": "LeftHand",
	"RightShoulder": "RightUpperArm", "RightUpperArm": "RightLowerArm", "RightLowerArm": "RightHand",
	"LeftUpperLeg": "LeftLowerLeg", "LeftLowerLeg": "LeftFoot", "LeftFoot": "LeftToes",
	"RightUpperLeg": "RightLowerLeg", "RightLowerLeg": "RightFoot", "RightFoot": "RightToes",
}

func _initialize() -> void:
	call_deferred("_bake")

func _bake() -> void:
	var source := (load(SOURCE) as PackedScene).instantiate()
	var target := (load(TARGET) as PackedScene).instantiate()
	get_root().add_child(source)
	get_root().add_child(target)
	var source_skeleton := source.find_child("GeneralSkeleton", true, false) as Skeleton3D
	var target_skeleton := target.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var output := AnimationLibrary.new()
	var mappings: Array[Dictionary] = []
	for source_name in BONES:
		var target_name: String = BONES[source_name]
		var source_bone := source_skeleton.find_bone(source_name)
		var target_bone := target_skeleton.find_bone(target_name)
		if source_bone < 0 or target_bone < 0:
			push_error("Missing bone %s -> %s" % [source_name, target_name])
			quit(1)
			return
		mappings.append({"source": source_bone, "target": target_bone, "source_name": source_name, "name": target_name})
	mappings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.target < b.target)
	for name in CLIPS:
		var full_name := Stride._resolve(player, name)
		var clip := player.get_animation(full_name) if full_name != "" else null
		if clip == null:
			push_error("Missing animation " + name)
			quit(1)
			return
		var baked := Animation.new()
		baked.length = clip.length
		baked.loop_mode = clip.loop_mode
		var tracks: Array[Dictionary] = []
		for mapping in mappings:
			var rot := baked.add_track(Animation.TYPE_ROTATION_3D)
			baked.track_set_path(rot, NodePath("Skeleton3D:%s" % mapping.name))
			var pos := -1
			if mapping.name == "DEF-spine":
				pos = baked.add_track(Animation.TYPE_POSITION_3D)
				baked.track_set_path(pos, NodePath("Skeleton3D:%s" % mapping.name))
			tracks.append({"rot": rot, "pos": pos})
		player.play(full_name)
		var frames := ceili(clip.length * 30.0)
		for frame in frames + 1:
			var time := minf(float(frame) / 30.0, clip.length)
			player.seek(time, true)
			target_skeleton.reset_bone_poses()
			for index in mappings.size():
				var m := mappings[index]
				var src: int = m.source
				var dst: int = m.target
				var source_rest := source_skeleton.get_bone_global_rest(src)
				var source_pose := source_skeleton.get_bone_global_pose(src)
				var target_rest := target_skeleton.get_bone_global_rest(dst)
				var delta := source_pose.basis * source_rest.basis.inverse()
				var target_basis := delta * target_rest.basis
				if DIRECTION_CHILD.has(m.source_name):
					var child_name: String = DIRECTION_CHILD[m.source_name]
					var source_child := source_skeleton.find_bone(child_name)
					var target_child := target_skeleton.find_bone(BONES[child_name])
					var source_dir := source_skeleton.get_bone_global_pose(source_child).origin - source_pose.origin
					var target_dir := target_skeleton.get_bone_global_rest(target_child).origin - target_rest.origin
					if source_dir.length() > 0.001 and target_dir.length() > 0.001:
						target_basis = Basis(Quaternion(target_dir.normalized(), source_dir.normalized())) * target_rest.basis
				# Preserve the current joint position after its parent has moved.
				var target_pose := Transform3D(target_basis, target_skeleton.get_bone_global_pose(dst).origin)
				if m.name == "DEF-spine":
					target_pose.origin += (source_pose.origin - source_rest.origin) * 1.25
				target_pose.origin.x = clampf(target_pose.origin.x, -0.2, 0.2)
				target_pose.origin.z = clampf(target_pose.origin.z, -0.2, 0.2)
				target_skeleton.set_bone_global_pose(dst, target_pose)
				baked.rotation_track_insert_key(tracks[index].rot, time, target_skeleton.get_bone_pose_rotation(dst))
				if tracks[index].pos >= 0:
					baked.position_track_insert_key(tracks[index].pos, time, target_skeleton.get_bone_pose_position(dst))
		output.add_animation(name, baked)
		print("Baked ", name, ": ", frames + 1, " frames, ", baked.get_track_count(), " tracks")
	var result := ResourceSaver.save(output, OUTPUT)
	print("Saved ", OUTPUT, " error ", result)
	quit(0 if result == OK else 1)
