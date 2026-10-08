extends SceneTree

# The leap's pure math: airtime against a step-by-step copy of Player's jump,
# flight progress (including a long drop), the landing spring, the knee fold
# and the shape of her line. Exits 1 on any failure.
#   godot-mono --headless --path . -s tools/leap_math_probe.gd

var _failed := 0


func _initialize() -> void:
	for rise in [Tune.JUMP_VELOCITY, Tune.JUMP_VELOCITY * Tune.LEAP_LIFT]:
		var predicted := Leap.airtime(rise)
		var simulated := _simulated_airtime(rise)
		_check(absf(predicted - simulated) < 0.035, "airtime at %.2f m/s: %.3f predicted, %.3f simulated" % [rise, predicted, simulated])

	var t := Leap.airtime(Tune.JUMP_VELOCITY)
	_check(is_equal_approx(Leap.flight_progress(t * 0.5, t, 3.0), 0.5), "progress follows time before the hold")
	_check(Leap.flight_progress(t * 2.0, t, 3.0) <= Tune.LEAP_REACH_HOLD + 0.0001, "off a ledge the reach holds while the ground is far")
	_check(is_equal_approx(Leap.flight_progress(t * 0.95, t, 0.0), 1.0), "the ground arriving finishes the flight")
	var mid := Leap.flight_progress(t * 0.95, t, Tune.LEAP_REACH_HEIGHT * 0.5)
	_check(mid > Tune.LEAP_REACH_HOLD and mid < 1.0, "half the reach height is part way through the reach (%.3f)" % mid)
	_check(Leap.flight_progress(-0.1, t, 3.0) >= 0.0, "progress never goes below 0")

	for depth in [Tune.LEAP_DIP_DEPTH, Tune.LEAP_DIP_DROP]:
		var x := 0.0
		var v := Leap.dip_kick(depth)
		var deepest := 0.0
		var highest := 0.0
		var elapsed := 0.0
		var settled_at := -1.0
		while elapsed < 1.0:
			var next := Leap.spring(x, v, 1.0 / 60.0)
			x = next.x
			v = next.y
			elapsed += 1.0 / 60.0
			deepest = maxf(deepest, x)
			highest = minf(highest, x)
			if settled_at < 0.0 and elapsed > 0.1 and absf(x) < depth * 0.05 and absf(v) < 0.05:
				settled_at = elapsed
		_check(absf(deepest - depth) < depth * 0.1, "dip of %.2f m reaches %.3f m" % [depth, deepest])
		_check(-highest < depth * 0.15, "dip of %.2f m springs back only a little (%.3f m)" % [depth, -highest])
		_check(settled_at > 0.0 and settled_at < 0.45, "dip of %.2f m settles in %.2f s" % [depth, settled_at])

	var a := 0.42
	var b := 0.40
	var span := 0.75
	var fold := Leap.knee_fold(a, b, span, 0.1)
	var before := acos((a * a + b * b - span * span) / (2.0 * a * b))
	var after := before - fold
	var shorter := sqrt(a * a + b * b - 2.0 * a * b * cos(after))
	_check(fold > 0.0, "a lower hip folds the knee")
	_check(absf(shorter - (span - 0.1)) < 0.001, "the folded leg is 0.1 m shorter (%.4f)" % shorter)
	_check(is_zero_approx(Leap.knee_fold(a, b, span, 0.0)), "no drop, no fold")

	var peak := Leap.line(0.4, 1.0)
	_check(is_equal_approx(peak.split, Tune.LEAP_SPLIT), "the split peaks at 40% of the flight")
	_check(is_zero_approx(Leap.line(0.0, 1.0).split) and is_zero_approx(Leap.line(0.9, 1.0).split), "no extra split at takeoff or the reach")
	_check(is_equal_approx(Leap.line(1.0, 1.0).point_lead, Tune.LEAP_POINT * 0.25), "the lead foot lands ball first, mostly unpointed")
	_check(is_zero_approx(Leap.line(0.4, 0.0).arms), "no amount, no line")

	var phases := {"length": 1.0, "L_contact": 0.1, "L_off": 0.35, "R_contact": 0.6, "R_off": 0.85}
	_check(is_equal_approx(Stride.flight_time(phases, true, 0.0), 0.85), "a left-lead leap starts at the right toe-off")
	_check(is_equal_approx(Stride.flight_time(phases, true, 1.0), 0.1), "and ends on the left contact, across the loop")
	_check(is_equal_approx(Stride.flight_time(phases, true, 0.5), 0.975), "half way is half way, before the wrap")
	_check(is_equal_approx(Stride.flight_time(phases, false, 0.5), 0.475), "a right-lead leap runs left toe-off to right contact")
	_check(Stride.SPRINT_PHASES.has("L_contact") and Stride.JOG_PHASES.has("R_off"), "Stride carries the measured phases")

	print("Leap math probe: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


# Player's own integration with jump held: apex hang inside APEX_SPEED,
# heavier falling, one tick at a time.
func _simulated_airtime(rise: float) -> float:
	var vy := rise
	var y := 0.0
	var t := 0.0
	var dt := 1.0 / 60.0
	while t < 5.0:
		var weight := Tune.FALL_GRAVITY if vy < 0.0 else 1.0
		if absf(vy) < Tune.APEX_SPEED:
			weight = Tune.APEX_HANG
		vy -= Tune.GRAVITY * dt * weight
		y += vy * dt
		t += dt
		if y <= 0.0:
			break
	return t


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failed += 1
