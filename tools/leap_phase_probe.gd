extends SceneTree

# Where each foot meets and leaves the ground in her running clips, for the
# leap's flight (Stride.JOG_PHASES / SPRINT_PHASES). Prints paste-ready
# constants. Exits 1 if a clip lacks a contact or toe-off for either foot.
#   godot-mono --headless --path . -s tools/leap_phase_probe.gd

const CLIPS := {"JOG_PHASES": "Jog_Fwd", "SPRINT_PHASES": "Sprint"}
const SAMPLES := 240
# Metres above its lowest in the cycle that a foot still counts as down.
const DOWN := 0.035
# Samples (of SAMPLES) a foot may lift within one stance as it rolls.
const MERGE := 8


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
	var failed := 0
	for constant: String in CLIPS:
		var clip: String = CLIPS[constant]
		var anim := player.get_animation(clip)
		player.play(clip)
		var lifts := {}
		for side in ["L", "R"]:
			var ankle := PackedFloat32Array()
			var ball := PackedFloat32Array()
			for i in SAMPLES:
				player.seek(anim.length * float(i) / float(SAMPLES), true)
				ankle.append(skeleton.get_bone_global_pose(skeleton.find_bone("DEF-foot." + side)).origin.y)
				ball.append(skeleton.get_bone_global_pose(skeleton.find_bone("DEF-toe." + side)).origin.y)
			var lift := PackedFloat32Array()
			var ankle_low := _lowest(ankle)
			var ball_low := _lowest(ball)
			for i in SAMPLES:
				# Down while either the heel or the ball is at its lowest.
				lift.append(minf(ankle[i] - ankle_low, ball[i] - ball_low))
			lifts[side] = lift
		var phases := {"length": anim.length}
		for side in ["L", "R"]:
			var stance := _longest_stance(lifts[side])
			print("%s %s down: %s" % [clip, side, stance.all])
			if stance.best.size() == 2:
				phases[side + "_contact"] = anim.length * float(stance.best[0]) / float(SAMPLES)
				phases[side + "_off"] = anim.length * float(stance.best[1]) / float(SAMPLES)
		for key in ["L_contact", "L_off", "R_contact", "R_off"]:
			if not phases.has(key):
				print("FAIL %s: no %s found" % [clip, key])
				failed += 1
		# A running foot is down for a sixth to a half of the cycle; anything
		# else is jitter mistaken for a step.
		for side in ["L", "R"]:
			if phases.has(side + "_contact") and phases.has(side + "_off"):
				var stance := fposmod(float(phases[side + "_off"]) - float(phases[side + "_contact"]), anim.length) / anim.length
				if stance < 0.15 or stance > 0.6:
					print("FAIL %s: %s foot down for %.0f%% of the cycle" % [clip, side, stance * 100.0])
					failed += 1
		if phases.size() == 5:
			for lead in ["L", "R"]:
				var push := "R" if lead == "L" else "L"
				var mid := _wrap_mid(phases[push + "_off"], phases[lead + "_contact"], anim.length)
				var at := int(mid / anim.length * SAMPLES) % SAMPLES
				var flying: bool = (lifts["L"] as PackedFloat32Array)[at] > DOWN and (lifts["R"] as PackedFloat32Array)[at] > DOWN
				print("%s lead %s: flight %.3f -> %.3f s, both feet up mid-flight: %s" % [clip, lead, phases[push + "_off"], phases[lead + "_contact"], flying])
			print("const %s := {\"length\": %.4f, \"L_contact\": %.4f, \"L_off\": %.4f, \"R_contact\": %.4f, \"R_off\": %.4f}" % [
				constant, phases.length, phases.L_contact, phases.L_off, phases.R_contact, phases.R_off])
	print("Leap phase probe: %s" % ("PASS" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed > 0 else 0)


# Every stretch of the loop a foot spends down, as [touchdown, lift-off]
# sample indices; the longest is its stance. Short dips near the bottom of a
# swing are jitter, not steps.
func _longest_stance(lift: PackedFloat32Array) -> Dictionary:
	var all: Array = []
	for i in SAMPLES:
		var was := lift[(i - 1 + SAMPLES) % SAMPLES] <= DOWN
		if lift[i] <= DOWN and not was:
			var j := i
			while lift[(j + 1) % SAMPLES] <= DOWN and j - i < SAMPLES:
				j += 1
			all.append([i, (j + 1) % SAMPLES, j + 1 - i])
	# A foot rolling from heel to ball lifts a hair mid-stance: rejoin pieces
	# separated by a gap of MERGE samples or less, around the loop.
	var merged := true
	while merged and all.size() > 1:
		merged = false
		for k in all.size():
			var here: Array = all[k]
			var next: Array = all[(k + 1) % all.size()]
			var gap := posmod(int(next[0]) - int(here[1]), SAMPLES)
			if gap <= MERGE:
				var joined := [here[0], next[1], int(here[2]) + gap + int(next[2])]
				all[k] = joined
				all.remove_at((k + 1) % all.size())
				merged = true
				break
	var best: Array = []
	var longest := 0
	for span: Array in all:
		if span[2] > longest:
			longest = span[2]
			best = [span[0], span[1]]
	return {"best": best, "all": all}


func _lowest(values: PackedFloat32Array) -> float:
	var low := values[0]
	for v in values:
		low = minf(low, v)
	return low


func _wrap_mid(from: float, to: float, length: float) -> float:
	if to < from:
		to += length
	return fmod((from + to) * 0.5, length)
