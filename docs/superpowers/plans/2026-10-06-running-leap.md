# Running Leap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** From a sprint, a jump becomes a long stride leap with a feminine line in the air and a catlike landing on the lead foot that keeps her speed.

**Architecture:**
- `Player` decides at takeoff whether a jump is a leap, and changes its arc, carry, air drag and one-footed takeoff and landing.
- `Stride` gets a leap layer that plays the airborne stretch of her own jog and sprint clips, slowed to fill the flight, and re-cues the gait to the lead foot's contact on landing.
- A new `Leap` skeleton modifier after `Grace` adds the split, pointed toes, arms and chest, plus a spring-driven dip. Its pure math is static and testable headlessly.

**Tech Stack:** Godot 4.7.2 (binary `godot-mono` on this machine), GDScript, AnimationTree built in code, SkeletonModifier3D.

**Spec:** `docs/superpowers/specs/2026-10-06-running-leap-design.md`

## Global Constraints

- GDScript with tabs, static typing (`:=`, typed returns), and `class_name` on every script; refer to classes by name, not preload.
- All balance values live in `Tune` (`scripts/tune.gd`) under `LEAP_*`.
- Build everything in code; no editor-authored scenes except the probe `.tscn` harnesses in `tools/`.
- After adding a new `class_name` script, run `godot-mono --headless --path . --import` before any headless run.
- Scripts that use the `Game` autoload are tested with a `tools/*_probe.tscn` scene probe. Pure math is tested with a `-s` SceneTree probe. Every probe counts failures and calls `quit(1)` on failure; never bare `assert()`.
- Standing hop (`Jump_Start`/`Jump_Land`), slide jump (×1.1 rise) and stumble behaviour stay unchanged.
- Leap threshold `LEAP_FROM` = 3.2 m/s. Full leap at `SPRINT_SPEED` = 6.85 m/s.
- Commit only if the user asks. Commit messages are one plain descriptive sentence.

## Review Focus

1. **Echo plants.** As the gait resumes after a leap landing, `FootLock` can plant the lead foot again, giving a double footstep. Expect one landing sound. Pinned in Task 3: `echoes == 0`.
2. **Walking jump.** At 1.83 m/s a jump must stay the two-footed hop at full `JUMP_VELOCITY`. Pinned in Task 3: `_walking_hop`.
3. **Slide jump.** It must keep its ×1.1 spring and not become a leap. Pinned in Task 3: `_slide_jump`.
4. **Chained leaps.** Jumping again on each landing must never ratchet speed past `LEAP_MAX_SPEED`. Pinned in Task 3: `_chained_leaps`.
5. **Long drops.** Off a ledge the flight must hold the reach (progress ≤ `LEAP_REACH_HOLD`) until the ground is near, never finish mid-air or exceed 1. Pinned in Task 2: `flight_progress` cases.

---

### Task 1: Measure the running clips' foot events

**Files:**
- Create: `tools/leap_phase_probe.gd`

**Interfaces:**
- Produces: printed constant lines `const JOG_PHASES := {...}` and `const SPRINT_PHASES := {...}` with keys `"length"`, `"L_contact"`, `"L_off"`, `"R_contact"`, `"R_off"` (seconds, floats). Task 4 pastes them into `Stride`.

- [ ] **Step 1: Write the probe**

```gdscript
extends SceneTree

# Where each foot meets and leaves the ground in her running clips, for the
# leap's flight (Stride.JOG_PHASES / SPRINT_PHASES). Prints paste-ready
# constants. Exits 1 if a clip lacks a contact or toe-off for either foot.
#   godot-mono --headless --path . -s tools/leap_phase_probe.gd

const CLIPS := {"JOG_PHASES": "Jog_Fwd", "SPRINT_PHASES": "Sprint"}
const SAMPLES := 240
# Metres above its lowest in the cycle that a foot still counts as down.
const DOWN := 0.025


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
			var lift: PackedFloat32Array = lifts[side]
			for i in SAMPLES:
				var was := lift[(i - 1 + SAMPLES) % SAMPLES] <= DOWN
				var now := lift[i] <= DOWN
				var t := anim.length * float(i) / float(SAMPLES)
				if now and not was and not phases.has(side + "_contact"):
					phases[side + "_contact"] = t
				if was and not now and not phases.has(side + "_off"):
					phases[side + "_off"] = t
		for key in ["L_contact", "L_off", "R_contact", "R_off"]:
			if not phases.has(key):
				print("FAIL %s: no %s found" % [clip, key])
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


func _lowest(values: PackedFloat32Array) -> float:
	var low := values[0]
	for v in values:
		low = minf(low, v)
	return low


func _wrap_mid(from: float, to: float, length: float) -> float:
	if to < from:
		to += length
	return fmod((from + to) * 0.5, length)
```

- [ ] **Step 2: Run it**

Run: `godot-mono --headless --path . -s tools/leap_phase_probe.gd`
Expected: exit 0, ending with `Leap phase probe: PASS`, two `const ..._PHASES := {...}` lines, and four `flight` lines. "both feet up mid-flight: true" is expected for Sprint. For Jog_Fwd it may be false (some jogs have no float); that is acceptable and only means a jog leap's base pose comes from the stride's crossover. If any key is missing, raise `DOWN` to 0.035 and rerun; report the values used.

- [ ] **Step 3: Save the output** for Task 4 (copy the two `const` lines verbatim).

---

### Task 2: Leap math and tuning

**Files:**
- Create: `scripts/player/leap.gd`
- Modify: `scripts/tune.gd` (add the `LEAP_*` block after the `AIR_DRAG` line)
- Create: `tools/leap_math_probe.gd`

**Interfaces:**
- Produces (static, on `class_name Leap extends SkeletonModifier3D`):
  - `static func airtime(rise: float) -> float`: seconds of flight on flat ground with jump held.
  - `static func flight_progress(air_time: float, airtime: float, drop: float) -> float`: 0..1.
  - `static func spring(x: float, v: float, dt: float) -> Vector2`: next (crouch, speed).
  - `static func dip_kick(depth: float) -> float`: initial spring speed for a dip of about `depth`.
  - `static func knee_fold(a: float, b: float, span: float, drop: float) -> float`: extra knee fold in radians.
  - `static func line(progress: float, amount: float) -> Dictionary`: keys `split`, `straighten`, `point_trail`, `point_lead`, `arms`, `chest` (radians, except `straighten` 0..1).
- Produces (Tune): `LEAP_FROM`, `LEAP_LIFT`, `LEAP_CARRY`, `LEAP_MAX_SPEED`, `LEAP_DRAG_CUT`, `LEAP_LINE_JOG`, `LEAP_REACH_HOLD`, `LEAP_REACH_HEIGHT`, `LEAP_SPLIT`, `LEAP_POINT`, `LEAP_ARMS`, `LEAP_CHEST`, `LEAP_DIP_DEPTH`, `LEAP_DIP_DROP`, `LEAP_DIP_FREQ`, `LEAP_DIP_ZETA`, `LEAP_DIP_LEAN`, `LEAP_FOV`, `LEAP_BOOM`.

- [ ] **Step 1: Write the failing math probe**

```gdscript
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
```

- [ ] **Step 2: Run it to see it fail**

Run: `godot-mono --headless --path . -s tools/leap_math_probe.gd`
Expected: a parse error that the identifier `Leap` (or `Tune.LEAP_LIFT`) is not declared, and a non-zero exit.

- [ ] **Step 3: Add the tuning block to `scripts/tune.gd`** directly after `const AIR_DRAG := 0.6`:

```gdscript
# The running leap. A jump taken at LEAP_FROM or faster is one long stride,
# off the foot she last planted onto the other. leap (0..1 from LEAP_FROM to
# SPRINT_SPEED at takeoff) lowers the arc to LEAP_LIFT of a hop and adds
# LEAP_CARRY of forward speed, never past LEAP_MAX_SPEED; the air takes
# LEAP_DRAG_CUT less of her speed. A jog leap shows LEAP_LINE_JOG of the line.
const LEAP_FROM := 3.2
const LEAP_LIFT := 0.88
const LEAP_CARRY := 0.06
const LEAP_MAX_SPEED := 7.3
const LEAP_DRAG_CUT := 0.9
const LEAP_LINE_JOG := 0.6
# Flight: time leads to LEAP_REACH_HOLD of the way, then only the ground
# coming within LEAP_REACH_HEIGHT metres finishes her reach for it.
const LEAP_REACH_HOLD := 0.85
const LEAP_REACH_HEIGHT := 0.35
# Her line in the air, in radians at a full leap: the split at its widest,
# pointed toes, arms opening, chest lifted.
const LEAP_SPLIT := 0.35
const LEAP_POINT := 0.5
const LEAP_ARMS := 0.45
const LEAP_CHEST := 0.08
# The catlike dip: metres on an ordinary leap and on a hard drop, the
# spring's frequency (rad/s) and damping ratio, and the chest's forward lean
# per metre of dip.
const LEAP_DIP_DEPTH := 0.03
const LEAP_DIP_DROP := 0.15
const LEAP_DIP_FREQ := 20.0
const LEAP_DIP_ZETA := 0.6
const LEAP_DIP_LEAN := 0.8
# The camera at a full leap: degrees of field of view and metres of boom.
const LEAP_FOV := 3.0
const LEAP_BOOM := 0.25
```

- [ ] **Step 4: Create `scripts/player/leap.gd`** with the static math (the modifier body comes in Task 5):

```gdscript
class_name Leap
extends SkeletonModifier3D

# Her running leap's carriage, layered after Grace: the split, pointed toes,
# opening arms and a lifted chest in the air, and a catlike dip on the lead
# leg when she lands. The math is static so it can be checked headlessly
# (tools/leap_math_probe.gd).


# Seconds from takeoff to landing on flat ground for a jump leaving at rise
# m/s with jump held: Player's gravity, its apex hang within APEX_SPEED and
# its heavier fall.
static func airtime(rise: float) -> float:
	var g := Tune.GRAVITY
	var band := minf(Tune.APEX_SPEED, rise)
	var up := (rise - band) / g
	var hang := band / (g * Tune.APEX_HANG)
	# Down through the hang band again, then the rest at fall gravity.
	var left := (rise * rise - band * band) / (2.0 * g)
	var fall_g := g * Tune.FALL_GRAVITY
	var down := (-band + sqrt(band * band + 2.0 * fall_g * left)) / fall_g
	return up + hang * 2.0 + down


# 0..1 through the flight. Time leads until LEAP_REACH_HOLD; from there only
# the ground coming up (drop, metres below her feet) finishes the reach, so
# off a ledge she holds it.
static func flight_progress(air_time: float, airtime: float, drop: float) -> float:
	var by_time := maxf(air_time / maxf(airtime, 0.1), 0.0)
	if by_time < Tune.LEAP_REACH_HOLD:
		return by_time
	var near := 1.0 - clampf(drop / Tune.LEAP_REACH_HEIGHT, 0.0, 1.0)
	return lerpf(Tune.LEAP_REACH_HOLD, 1.0, near)


# One step of her landing spring: crouch x (metres, positive is lower) and its
# speed v, slightly under-damped so she sinks, springs back and settles.
static func spring(x: float, v: float, dt: float) -> Vector2:
	var w := Tune.LEAP_DIP_FREQ
	var z := Tune.LEAP_DIP_ZETA
	var steps := maxi(1, ceili(dt * 240.0))
	var h := dt / float(steps)
	for i in steps:
		v += (-w * w * x - 2.0 * z * w * v) * h
		x += v * h
	return Vector2(x, v)


# The speed a landing gives the spring so its deepest point is about depth
# (at damping 0.6 the peak is half of kick / frequency).
static func dip_kick(depth: float) -> float:
	return 2.0 * depth * Tune.LEAP_DIP_FREQ


# How much further the knee must fold (radians) for a leg of thigh a and
# shin b, hip-to-ankle span now, to come drop shorter.
static func knee_fold(a: float, b: float, span: float, drop: float) -> float:
	var lo := absf(a - b) + 0.001
	var hi := a + b - 0.001
	var now := acos(clampf((a * a + b * b - pow(clampf(span, lo, hi), 2.0)) / (2.0 * a * b), -1.0, 1.0))
	var then := acos(clampf((a * a + b * b - pow(clampf(span - drop, lo, hi), 2.0)) / (2.0 * a * b), -1.0, 1.0))
	return now - then


# Her line at this point of the flight. The split swells to its widest at 40%
# and is gone by the reach; the lead foot unpoints for a ball-first landing.
static func line(progress: float, amount: float) -> Dictionary:
	var p := clampf(progress, 0.0, 1.0)
	var swell := amount * sin(PI * clampf(p / 0.8, 0.0, 1.0))
	return {
		"split": Tune.LEAP_SPLIT * swell,
		"straighten": 0.7 * swell,
		"point_trail": Tune.LEAP_POINT * amount,
		"point_lead": Tune.LEAP_POINT * amount * lerpf(1.0, 0.25, smoothstep(0.75, 1.0, p)),
		"arms": Tune.LEAP_ARMS * swell,
		"chest": Tune.LEAP_CHEST * amount * (1.0 - smoothstep(0.8, 1.0, p)),
	}
```

- [ ] **Step 5: Register the class and run the probe**

Run: `godot-mono --headless --path . --import` then `godot-mono --headless --path . -s tools/leap_math_probe.gd`
Expected: every line `ok`, ending `Leap math probe: PASS`, exit 0. If the airtime check fails by more than 0.035, compare against the simulation; do not loosen the tolerance without saying so.

---

### Task 3: Leap physics in Player

**Files:**
- Modify: `scripts/player/player.gd` (signal; vars after `_air_weight`; `_jump`; `_track_air`; `_land`; new `_land_leap`, `_foot_spot`; `_both_feet`; `_on_planted`; `_footfall`; `_steer`)
- Create: `tools/leap_probe.gd`, `tools/leap_probe.tscn`

**Interfaces:**
- Consumes: `Leap.airtime(rise)` (Task 2), `Tune.LEAP_*` (Task 2).
- Produces on `Player`:
  - `signal stepped(left: bool)`, emitted for every sounded footfall.
  - `var leaping: bool`, `var leap: float`, `var leap_lead_left: bool`.
  - `func _foot_spot(left: bool) -> Vector3`.
  - `var _leap_airtime: float`, `var _landed_msec: int`.
  - `func _land_leap(power: float) -> void`.

- [ ] **Step 1: Write the failing scene probe** `tools/leap_probe.gd`:

```gdscript
extends Node

# Drives the real player through jumps on the saved trail and checks the
# running leap: flatter and carried from a sprint, one foot down at each end,
# speed kept on landing, chained leaps capped, and the walking hop and the
# slide jump unchanged. Exits 1 on any failure.
#   godot-mono --headless --path . tools/leap_probe.tscn

var _player: Player
var _trail: Trail
var _failed := 0
# [msec, left] for every footfall she sounds.
var _steps: Array = []


func _ready() -> void:
	process_priority = -100
	process_physics_priority = -100
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	_player = Game.player
	_trail = Game.trail
	if _player == null or _trail == null:
		_check(false, "the scene built the player and the trail")
		_finish()
		return
	_player.stepped.connect(_on_stepped)
	_player.global_position = _trail.on_ground(_trail.position_at(_trail.player_start_offset)) + Vector3.UP * 0.3
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	Game.set_phase(Game.Phase.PLAYING)
	await _ticks(30)
	await _walking_hop()
	await _sprint_leap()
	await _chained_leaps()
	await _slide_jump()
	_finish()


# Keeps her on the route, a few metres ahead.
func _physics_process(_delta: float) -> void:
	if _player == null or _trail == null:
		return
	var ahead := _trail.position_at(minf(_trail.offset_of(_player.global_position) + 5.0, _trail.exit_offset))
	var direction := ahead - _player.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.04:
		_player._yaw = atan2(-direction.x, -direction.z)


func _walking_hop() -> void:
	Input.action_release("sprint")
	Input.action_press("move_forward")
	await _seconds(1.2)
	var took := await _jump()
	_check(not _player.leaping, "a walking jump is a hop, not a leap")
	_check(absf(took.rise - Tune.JUMP_VELOCITY) < 0.01, "the hop rises at JUMP_VELOCITY (%.2f)" % took.rise)
	_check(took.takeoff_steps == 2, "the hop leaves on both feet (%d steps)" % took.takeoff_steps)
	await _land()


func _sprint_leap() -> void:
	_player.stamina = Tune.STAMINA_MAX
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(2.0)
	var took := await _jump()
	_check(_player.leaping, "a sprinting jump is a leap")
	_check(_player.leap > 0.9, "a full sprint gives leap near 1 (%.2f)" % _player.leap)
	var rise := Tune.JUMP_VELOCITY * lerpf(1.0, Tune.LEAP_LIFT, _player.leap)
	_check(absf(took.rise - rise) < 0.01, "the leap rises at %.2f m/s (got %.2f)" % [rise, took.rise])
	var carried := minf(took.speed_before * (1.0 + Tune.LEAP_CARRY * _player.leap), maxf(took.speed_before, Tune.LEAP_MAX_SPEED))
	_check(took.speed >= carried * 0.98, "the push-off carries her to %.2f m/s (got %.2f)" % [carried, took.speed])
	_check(took.takeoff_steps == 1, "the leap pushes off one foot (%d steps)" % took.takeoff_steps)
	if took.takeoff_steps == 1:
		_check(took.push_left != _player.leap_lead_left, "the push-off foot is not the lead foot")
	var down := await _land()
	_check(down.landing.size() == 1, "the leap lands on one foot (%d steps)" % down.landing.size())
	if down.landing.size() == 1:
		_check(down.landing[0][1] == _player.leap_lead_left, "it lands on the lead foot")
	_check(down.after >= down.before * 0.995, "landing keeps her speed (%.2f -> %.2f)" % [down.before, down.after])
	_check(down.echoes == 0, "the rig does not plant the lead foot a second time (%d)" % down.echoes)


func _chained_leaps() -> void:
	_player.stamina = Tune.STAMINA_MAX
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(1.5)
	var top := 0.0
	for i in 3:
		await _jump()
		var down := await _land()
		top = maxf(top, down.top)
	_check(top <= Tune.LEAP_MAX_SPEED + 0.05, "chained leaps stay within LEAP_MAX_SPEED (top %.2f)" % top)


func _slide_jump() -> void:
	_player.stamina = Tune.STAMINA_MAX
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(1.5)
	Input.action_press("slide")
	await _seconds(0.2)
	_check(_player.sliding, "she is sliding before the slide jump")
	var took := await _jump()
	Input.action_release("slide")
	_check(not _player.leaping, "a slide jump is not a leap")
	_check(absf(took.rise - Tune.JUMP_VELOCITY * 1.1) < 0.01, "a slide jump keeps its 1.1x spring (%.2f)" % took.rise)
	await _land()
	Input.action_release("sprint")


# Presses jump until she leaves the ground; returns what she left with.
func _jump() -> Dictionary:
	var before := _player._ground_speed()
	var count := _steps.size()
	Input.action_press("jump")
	for i in 30:
		await get_tree().physics_frame
		if _player._jumped:
			break
		before = _player._ground_speed()
		count = _steps.size()
	var added: Array = _steps.slice(count)
	return {
		"rise": _player.velocity.y,
		"speed_before": before,
		"speed": _player._ground_speed(),
		"takeoff_steps": added.size(),
		"push_left": added[-1][1] if not added.is_empty() else null,
	}


# Waits for touchdown; returns her speed either side of it, the steps sounded
# on landing, and any second plant of the lead foot just after.
func _land() -> Dictionary:
	var before := _player._ground_speed()
	var count := _steps.size()
	var top := before
	for i in 300:
		await get_tree().physics_frame
		if not _player._airborne:
			break
		before = _player._ground_speed()
		count = _steps.size()
		top = maxf(top, before)
	Input.action_release("jump")
	var landing: Array = _steps.slice(count)
	var after := _player._ground_speed()
	var landed := Time.get_ticks_msec()
	await _seconds(0.25)
	var echoes := 0
	for step: Array in _steps.slice(count + landing.size()):
		if step[1] == _player.leap_lead_left and step[0] - landed < 150:
			echoes += 1
	return {"before": before, "after": after, "top": top, "landing": landing, "echoes": echoes}


func _on_stepped(left: bool) -> void:
	_steps.append([Time.get_ticks_msec(), left])


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failed += 1


func _finish() -> void:
	for action in ["move_forward", "sprint", "jump", "slide"]:
		Input.action_release(action)
	print("Leap probe: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	get_tree().quit(1 if _failed > 0 else 0)
```

And `tools/leap_probe.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/leap_probe.gd" id="1"]

[node name="LeapProbe" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Run it to see it fail**

Run: `godot-mono --headless --path . tools/leap_probe.tscn`
Expected: a script error about `stepped` (or `leaping`) not existing on `Player`, and a non-zero exit (or a hang; stop it after 60 s).

- [ ] **Step 3: Add the signal and state to `Player`**

Below `extends CharacterBody3D` (line 2), add:

```gdscript

# Every footfall she sounds, takeoffs and landings included; probes count them.
signal stepped(left: bool)
```

After `var _air_weight := 0.0`, add:

```gdscript
# A jump at a jog or faster is a leap: leap 0..1 sets how flat and carried it
# is, off the foot she last planted and onto the other one.
var leaping := false
var leap := 0.0
var leap_lead_left := true
var _leap_airtime := 0.5
var _landed_msec := 0
```

And with the other constants at the top of the file:

```gdscript
# How long after a leap lands it still counts as one (the pose blends out and
# the rig's own plant of the lead foot is ignored).
const LEAP_SETTLE_MSEC := 250
```

- [ ] **Step 4: Replace `_jump()`**

```gdscript
func _jump() -> void:
	var from_slide := sliding
	if sliding:
		_end_slide()
	var speed := _ground_speed()
	# From a jog or faster it is one long stride: lower, carried further, off
	# the foot she last planted and onto the other. Out of a slide she keeps
	# the slide's speed and springs a little higher, as before.
	leaping = not from_slide and speed >= Tune.LEAP_FROM
	leap = clampf((speed - Tune.LEAP_FROM) / (Tune.SPRINT_SPEED - Tune.LEAP_FROM), 0.0, 1.0) if leaping else 0.0
	velocity.y = Tune.JUMP_VELOCITY * (1.1 if from_slide else lerpf(1.0, Tune.LEAP_LIFT, leap))
	_coyote = 0.0
	_jump_buffer = 0.0
	_airborne = true
	_jumped = true
	_air_time = 0.0
	stamina = maxf(stamina - Tune.JUMP_STAMINA, 0.0)
	strain = maxf(strain, 0.4)
	_jolt -= 0.03
	if not leaping:
		_both_feet(0.6)
		return
	var carried := minf(speed * (1.0 + Tune.LEAP_CARRY * leap), maxf(speed, Tune.LEAP_MAX_SPEED))
	_glide = Vector3(_glide.x, 0.0, _glide.z) / speed * carried
	leap_lead_left = not _left_foot
	_leap_airtime = Leap.airtime(velocity.y)
	_footfall(_left_foot, _foot_spot(_left_foot), _ground_speed())
```

- [ ] **Step 5: End stale leaps in `_track_air`.** Replace its on-floor branch:

```gdscript
	if is_on_floor():
		if _airborne and (_jumped or _air_time > 0.15):
			_land(_fall_speed)
		elif leaping and Time.get_ticks_msec() - _landed_msec > LEAP_SETTLE_MSEC:
			leaping = false
		_airborne = false
		_jumped = false
		_air_time = 0.0
		_fall_speed = 0.0
		return
```

- [ ] **Step 6: Land a leap on one foot.** At the top of `_land()`, after `var power := ...`, insert:

```gdscript
	_landed_msec = Time.get_ticks_msec()
	if leaping:
		_land_leap(power)
		return
```

and add below `_land`:

```gdscript
# A leap comes down on the lead foot alone and runs on: only a real drop
# costs speed, and half what a hop's landing would.
func _land_leap(power: float) -> void:
	_glide *= lerpf(1.0, 0.85, power)
	_since_plant = 0.0
	_last_plant_msec = _landed_msec
	_footfall(leap_lead_left, _foot_spot(leap_lead_left), _ground_speed())
	_jolt -= lerpf(0.02, 0.1, power)
	Game.rumble(0.08 + 0.3 * power, 0.5 * power, 0.08 + 0.12 * power)
```

- [ ] **Step 7: Share the foot spot and announce steps.** Add above `_both_feet`:

```gdscript
# Beside her, where a boot meets the ground for steps the rig does not plant.
func _foot_spot(left: bool) -> Vector3:
	var forward := Vector3(_glide.x, 0.0, _glide.z)
	forward = forward.normalized() if forward.length() > 0.1 else -global_transform.basis.z
	var side := Vector3(forward.z, 0.0, -forward.x)
	return global_position + side * (0.12 if left else -0.12)
```

In `_both_feet`, replace `var at := global_position + side * (0.12 if left else -0.12)` with `var at := _foot_spot(left)`, and add `stepped.emit(left)` directly after it. Delete the now-unused `side` local; keep `forward`, which the prints still use.

In `_footfall`, add `stepped.emit(left)` directly after `_left_foot = left`.

- [ ] **Step 8: Ignore the rig's echo of the landing.** In `_on_planted`, after the first `return` guard, insert:

```gdscript
	# Just down from a leap, the rig's own plant of the lead foot is the
	# landing she already made.
	if leaping and left == leap_lead_left and Time.get_ticks_msec() - _landed_msec < 150:
		return
```

- [ ] **Step 9: Let the air keep a leap's speed.** In `_steer`, replace the not-asked air branch:

```gdscript
		if not asked:
			var drag := Tune.AIR_DRAG * (1.0 - leap * Tune.LEAP_DRAG_CUT) if leaping else Tune.AIR_DRAG
			_glide = flat.move_toward(Vector3.ZERO, drag * delta)
			return
```

- [ ] **Step 10: Run the probe to see it pass**

Run: `godot-mono --headless --path . tools/leap_probe.tscn`
Expected: every line `ok`, `Leap probe: PASS`, exit 0. If a check fails, fix the code, not the expectation. If a scenario cannot run on this route (for example the slide never starts), report the setup problem.

- [ ] **Step 11: Re-run Task 2's math probe** to confirm nothing regressed: `godot-mono --headless --path . -s tools/leap_math_probe.gd` → PASS.

---

### Task 4: Stride's leap layer and landing cue

**Files:**
- Modify: `scripts/player/stride.gd` (phase constants, `_points`, blend points with seeks, `sync_mode`, leap nodes, `leap_pose`, `leap_land`, `flight_time`)
- Modify: `scripts/player/player.gd` (`_animate`, new `_leap_progress`, `_drop_below`, and in `_land_leap` the cue)
- Modify: `tools/leap_math_probe.gd` (flight_time checks), `tools/leap_probe.gd` (animation checks)

**Interfaces:**
- Consumes: `Leap.flight_progress` (Task 2); the `JOG_PHASES` / `SPRINT_PHASES` lines from Task 1; `Player.leaping`, `leap`, `leap_lead_left`, `_leap_airtime` (Task 3).
- Produces on `Stride`:
  - `const JOG_PHASES: Dictionary`, `const SPRINT_PHASES: Dictionary`.
  - `func leap_pose(amount: float, progress: float, lead_left: bool, leap: float) -> void`.
  - `func leap_land(lead_left: bool) -> void`.
  - `static func flight_time(phases: Dictionary, lead_left: bool, progress: float) -> float`.
  - Blend point names `"%s_%d" % [clip, index]` with parameter paths `parameters/locomotion/<name>/seek/seek_request` (verified on 4.7.2).
- Produces on `Player`: `func _leap_progress() -> float`, `func _drop_below() -> float`.

- [ ] **Step 1: Write the failing checks.** In `tools/leap_math_probe.gd`, before the final `print`, add:

```gdscript
	var phases := {"length": 1.0, "L_contact": 0.1, "L_off": 0.35, "R_contact": 0.6, "R_off": 0.85}
	_check(is_equal_approx(Stride.flight_time(phases, true, 0.0), 0.85), "a left-lead leap starts at the right toe-off")
	_check(is_equal_approx(Stride.flight_time(phases, true, 1.0), 0.1), "and ends on the left contact, across the loop")
	_check(is_equal_approx(Stride.flight_time(phases, true, 0.5), 0.975), "half way is half way, before the wrap")
	_check(is_equal_approx(Stride.flight_time(phases, false, 0.5), 0.475), "a right-lead leap runs left toe-off to right contact")
	_check(Stride.SPRINT_PHASES.has("L_contact") and Stride.JOG_PHASES.has("R_off"), "Stride carries the measured phases")
```

In `tools/leap_probe.gd`, inside `_sprint_leap()` replace `var down := await _land()` with:

```gdscript
	await _seconds(_player._leap_airtime * 0.5)
	var tree := _player.stride.tree
	_check(float(tree.get("parameters/leap/blend_amount")) > 0.9, "mid-flight shows the leap pose")
	_check(is_zero_approx(float(tree.get("parameters/air/blend_amount"))), "mid-flight hides the standing jump pose")
	var down := await _land()
	var contact: float = Stride.SPRINT_PHASES["L_contact" if _player.leap_lead_left else "R_contact"]
	_check(absf(down.cued - contact) < 0.08, "the sprint picks up at the lead foot's contact (%.3f vs %.3f)" % [down.cued, contact])
```

And in `_land()`, record the cue one rendered frame after touchdown, before the 0.25 s wait: replace `var landed := Time.get_ticks_msec()` with

```gdscript
	var landed := Time.get_ticks_msec()
	await get_tree().process_frame
	var cued := float(_player.stride.tree.get("parameters/locomotion/Sprint_6/seek/current_position"))
```

and add `"cued": cued` to its returned dictionary.

And at the start of `_sprint_leap()`, after `await _seconds(2.0)`, add:

```gdscript
	var tree0 := _player.stride.tree
	var first := float(tree0.get("parameters/locomotion/Sprint_6/seek/current_position"))
	await _ticks(3)
	var later := float(tree0.get("parameters/locomotion/Sprint_6/seek/current_position"))
	_check(not is_equal_approx(first, later), "the sprint still runs through its seek node")
```

- [ ] **Step 2: Run both probes to see them fail**

Run: `godot-mono --headless --path . -s tools/leap_math_probe.gd`. Expected: parse error, `flight_time` / `SPRINT_PHASES` not found, non-zero exit.

- [ ] **Step 3: Rebuild the blend space with cue points.** In `stride.gd`:

Add below the `AIR_*` constants, pasting Task 1's printed values in place of the two lines:

```gdscript
# Where each foot meets and leaves the ground in the running clips (seconds),
# measured by tools/leap_phase_probe.gd. A leap plays from the push-off
# foot's toe-off to the lead foot's contact, slowed to fill the flight.
const JOG_PHASES := {"length": 0.9333, "L_contact": 0.0, "L_off": 0.0, "R_contact": 0.0, "R_off": 0.0}  # replace with Task 1 output
const SPRINT_PHASES := {"length": 0.6667, "L_contact": 0.0, "L_off": 0.0, "R_contact": 0.0, "R_off": 0.0}  # replace with Task 1 output
```

(Replace both lines with the probe's exact output and delete the trailing comments. The Step 1 checks only confirm the keys exist, so compare the values by eye against the probe output.)

Add `var _points: Array = []` after `var _gaits: Array = []`, with the comment `# [blend point name, clip] for each running point, for landing cues.`

Replace the blend-space loop:

```gdscript
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = Tune.SPRINT_SPEED + 1.0
	space.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_INDEPENDENT
	for index in stride._gaits.size():
		var gait: Array = stride._gaits[index]
		var clip := _resolve(player, gait[0])
		if clip == "":
			continue
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		# Each point can be cued on its own: a leap lands on a contact frame.
		var point := AnimationNodeBlendTree.new()
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		point.add_node("clip", node)
		point.add_node("seek", AnimationNodeTimeSeek.new())
		point.connect_node("seek", 0, "clip")
		point.connect_node("output", 0, "seek")
		var point_name := "%s_%d" % [gait[0], index]
		space.add_blend_point(point, gait[1], -1, point_name)
		stride._points.append([point_name, gait[0]])
```

- [ ] **Step 4: Add the leap layer to the tree.** Change the chain comment to `# locomotion -> pace -> air -> leap -> slide -> land -> stumble -> output`. After the `air` Blend2 is connected, add:

```gdscript
	# A running leap: her own jog and sprint from toe-off to the next contact,
	# slowed to fill the flight and blended by her speed at takeoff.
	root.add_node("leap_jog", _clip_node(player, JOG))
	root.add_node("leap_jog_seek", AnimationNodeTimeSeek.new())
	root.connect_node("leap_jog_seek", 0, "leap_jog")
	root.add_node("leap_sprint", _clip_node(player, SPRINT))
	root.add_node("leap_sprint_seek", AnimationNodeTimeSeek.new())
	root.connect_node("leap_sprint_seek", 0, "leap_sprint")
	root.add_node("leap_gait", AnimationNodeBlend2.new())
	root.connect_node("leap_gait", 0, "leap_jog_seek")
	root.connect_node("leap_gait", 1, "leap_sprint_seek")
	root.add_node("leap", AnimationNodeBlend2.new())
	root.connect_node("leap", 0, "air")
	root.connect_node("leap", 1, "leap_gait")
```

and change `root.connect_node("slide", 0, "air")` to `root.connect_node("slide", 0, "leap")`.

- [ ] **Step 5: Add the Stride functions** after `land()`:

```gdscript
# amount 0..1 of the leap pose; progress 0..1 through the flight; leap 0..1
# from a jog to a full sprint at takeoff, which picks the clip.
func leap_pose(amount: float, progress: float, lead_left: bool, leap: float) -> void:
	if tree == null:
		return
	tree.set("parameters/leap/blend_amount", amount)
	if amount <= 0.0:
		return
	tree.set("parameters/leap_gait/blend_amount", leap)
	tree.set("parameters/leap_jog_seek/seek_request", flight_time(JOG_PHASES, lead_left, progress))
	tree.set("parameters/leap_sprint_seek/seek_request", flight_time(SPRINT_PHASES, lead_left, progress))


# Down from a leap: every running clip picks up at the lead foot's contact,
# so her stride carries on from the step she landed on.
func leap_land(lead_left: bool) -> void:
	if tree == null:
		return
	var key := "L_contact" if lead_left else "R_contact"
	for point: Array in _points:
		var phases: Dictionary = JOG_PHASES if point[1] == JOG else SPRINT_PHASES if point[1] == SPRINT else {}
		if phases.is_empty():
			continue
		tree.set("parameters/locomotion/%s/seek/seek_request" % point[0], phases[key])


# Seconds into a running clip at this point of a leap's flight: from the
# push-off foot's toe-off to the lead foot's contact, across the loop if needed.
static func flight_time(phases: Dictionary, lead_left: bool, progress: float) -> float:
	var from: float = phases["R_off" if lead_left else "L_off"]
	var to: float = phases["L_contact" if lead_left else "R_contact"]
	var length: float = phases["length"]
	if to < from:
		to += length
	return fmod(lerpf(from, to, clampf(progress, 0.0, 1.0)), length)
```

- [ ] **Step 6: Drive it from Player.** Replace the `if stride:` block in `_animate` with:

```gdscript
	var flight := _leap_progress()
	if stride:
		stride.update(_ground_speed())
		stride.posture(0.0 if leaping else _air_weight, velocity.y / Tune.JUMP_VELOCITY, _slide_weight)
		stride.leap_pose(_air_weight if leaping else 0.0, flight, leap_lead_left, leap)
```

Add after `_animate`:

```gdscript
# 0..1 through a leap's flight: by time at first, then by the ground coming
# up, so off a ledge she holds her reach. Down again, it is the landing.
func _leap_progress() -> float:
	if not leaping:
		return 0.0
	if not _airborne:
		return 1.0
	var reaching := _air_time / maxf(_leap_airtime, 0.1) >= Tune.LEAP_REACH_HOLD
	return Leap.flight_progress(_air_time, _leap_airtime, _drop_below() if reaching else 3.0)


# Metres of air under her boots, up to 3.
func _drop_below() -> float:
	var from := global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.1, Tune.LAYER_WORLD)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return 3.0 if hit.is_empty() else maxf(global_position.y - (hit.position as Vector3).y, 0.0)
```

In `_land_leap`, add as its first line:

```gdscript
	if stride:
		stride.leap_land(leap_lead_left)
```

- [ ] **Step 7: Run both probes to see them pass**

Run: `godot-mono --headless --path . -s tools/leap_math_probe.gd` → `PASS`, then `godot-mono --headless --path . tools/leap_probe.tscn` → `PASS`.

- [ ] **Step 8: Smoke-test the gait still runs**

Run in PowerShell:
`$env:RUN_CAPTURE="1"; $env:RUN_AUTOPILOT="sprint"; $env:RUN_SHOT="$PWD\build\leap\sprint.png"; godot-mono --path .; Remove-Item Env:RUN_CAPTURE, Env:RUN_AUTOPILOT, Env:RUN_SHOT`
(Create `build/leap/` first.) Expected: the shot shows her mid-sprint, legs in a normal stride. Look at it.

---

### Task 5: The Leap modifier (line and dip)

**Files:**
- Modify: `scripts/player/leap.gd` (modifier members and body)
- Modify: `scripts/player/player.gd` (`leap_layer` var, `Leap.fit` in `_build_model`, `_animate`, `_land_leap`)
- Create: `tools/leap_sheet.gd` (windowed contact sheet)

**Interfaces:**
- Consumes: `Leap.line`, `Leap.spring`, `Leap.dip_kick`, `Leap.knee_fold` (Task 2); `Stride.leap_pose` (Task 4).
- Produces:
  - `static func Leap.fit(skeleton: Skeleton3D) -> Leap`.
  - Properties `amount: float`, `progress: float`, `lead_left: bool`.
  - `func dip(power: float, left: bool) -> void`.
  - `Player.leap_layer: Leap`.

- [ ] **Step 1: Write the contact sheet (the visual test)** `tools/leap_sheet.gd`:

```gdscript
extends SceneTree

# A sprint leap from her left side, eight points through the flight: the clip
# alone (top row), with Leap's line (middle), and the landing dip after a hard
# drop (bottom, about 0.04 s apart). Needs a window.
#   godot-mono --path . -s tools/leap_sheet.gd
# The sheet lands in build/leap/leap_sheet.png.

const OUT := "res://build/leap/"
const CELL := Vector2i(200, 260)
const COLUMNS := 8

var _stride: Stride
var _leap: Leap


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_root().size = Vector2i(600, 780)
	var world := Node3D.new()
	get_root().add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.72, 0.76, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.82, 0.86)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(30.0), 0.0)
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(6, 6)
	world.add_child(floor_mesh)
	var model := (load("res://assets/characters/styloo_elf/elf.glb") as PackedScene).instantiate()
	model.scale = Vector3.ONE * Tune.PLAYER_MODEL_SCALE
	world.add_child(model)
	var camera := Camera3D.new()
	camera.fov = 30.0
	world.add_child(camera)
	camera.look_at_from_position(Vector3(4.6, 0.95, 0.0), Vector3(0, 0.8, 0.0))
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := AnimationPlayer.new()
	skeleton.get_parent().add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", load("res://assets/characters/styloo_elf/elf_animations.res") as AnimationLibrary)
	_stride = Stride.build(player, skeleton.get_parent())
	_leap = Leap.fit(skeleton)
	_leap.lead_left = true
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * 3, false, Image.FORMAT_RGB8)
	for row in 2:
		for column in COLUMNS:
			var progress := float(column) / float(COLUMNS - 1)
			_stride.leap_pose(1.0, progress, true, 1.0)
			_leap.amount = float(row)
			_leap.progress = progress
			await _frames(3)
			_blit(sheet, column, row)
	_leap.amount = 0.0
	_stride.leap_pose(1.0, 1.0, true, 1.0)
	await _frames(3)
	_leap.dip(1.0, true)
	for column in COLUMNS:
		await _frames(2)
		_blit(sheet, column, 2)
	sheet.save_png(ProjectSettings.globalize_path(OUT + "leap_sheet.png"))
	print("saved ", OUT + "leap_sheet.png")
	quit()


func _blit(sheet: Image, column: int, row: int) -> void:
	var shot := get_root().get_texture().get_image()
	shot.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * column, CELL.y * row))


func _frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw
```

- [ ] **Step 2: Run it to see it fail**

Run: `godot-mono --path . -s tools/leap_sheet.gd`
Expected: an error that `Leap.fit` / `amount` does not exist.

- [ ] **Step 3: Add the modifier to `scripts/player/leap.gd`.** Insert after the class comment, before `airtime`:

```gdscript
const BONES := ["DEF-spine", "DEF-spine.004", "DEF-spine.006",
	"DEF-upper_arm.L", "DEF-forearm.L", "DEF-upper_arm.R", "DEF-forearm.R",
	"DEF-thigh.L", "DEF-shin.L", "DEF-foot.L",
	"DEF-thigh.R", "DEF-shin.R", "DEF-foot.R"]

# Set by the player each tick: how much of the line shows (0 on the ground),
# how far through the flight she is, and which leg leads.
var amount := 0.0
var progress := 0.0
var lead_left := true
var _dip := 0.0
var _dip_speed := 0.0
var _dip_left := true
var _bones := {}
var _last_msec := 0
# This frame's pose before Leap: each bone's own and its parent's, in
# skeleton space. Global poses go stale once a parent is written (see Grace).
var _pose := {}
var _parent := {}


static func fit(skeleton: Skeleton3D) -> Leap:
	var leap := Leap.new()
	leap.name = "Leap"
	for name in BONES:
		var bone := skeleton.find_bone(name)
		if bone < 0:
			push_warning("Leap: missing bone " + name)
			return leap
		leap._bones[name] = bone
	skeleton.add_child(leap)
	return leap


# She has landed: the spring sinks her on the lead leg, deeper for a harder
# drop (power 0..1), then lets her rise.
func dip(power: float, left: bool) -> void:
	_dip_left = left
	_dip_speed = dip_kick(lerpf(Tune.LEAP_DIP_DEPTH, Tune.LEAP_DIP_DROP, power))


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _bones.size() < BONES.size():
		return
	var now := Time.get_ticks_msec()
	var delta := clampf(float(now - _last_msec) / 1000.0, 0.001, 0.1)
	_last_msec = now
	var next := spring(_dip, _dip_speed, delta)
	_dip = next.x
	_dip_speed = next.y
	var crouch := maxf(_dip, 0.0)
	if amount <= 0.001 and crouch <= 0.0005:
		return
	for name in BONES:
		var bone: int = _bones[name]
		_pose[name] = skeleton.get_bone_global_pose(bone)
		var up := skeleton.get_bone_parent(bone)
		_parent[name] = skeleton.get_bone_global_pose(up) if up >= 0 else Transform3D()
	if amount > 0.001:
		_hold_line(skeleton)
	if crouch > 0.0005:
		_crouch(skeleton, crouch)


# In skeleton space +Z is forward and +X her left; turning a hanging limb by
# +X swings it back, and turning a foot by +X tips its toes down.
func _hold_line(skeleton: Skeleton3D) -> void:
	var shape := line(progress, amount)
	var lead := "L" if lead_left else "R"
	var trail := "R" if lead_left else "L"
	# The lead thigh reaches, the trailing one extends behind, and the
	# trailing knee all but straightens.
	_turn(skeleton, "DEF-thigh." + lead, Quaternion(Vector3.RIGHT, -shape.split))
	_turn(skeleton, "DEF-thigh." + trail, Quaternion(Vector3.RIGHT, shape.split))
	var thigh := (_pose["DEF-thigh." + trail] as Transform3D).basis.y.normalized()
	var shin := (_pose["DEF-shin." + trail] as Transform3D).basis.y.normalized()
	if thigh.dot(shin) < 0.9999:
		_turn(skeleton, "DEF-shin." + trail, Quaternion.IDENTITY.slerp(Quaternion(shin, thigh), shape.straighten))
	_turn(skeleton, "DEF-foot." + trail, Quaternion(Vector3.RIGHT, shape.point_trail))
	_turn(skeleton, "DEF-foot." + lead, Quaternion(Vector3.RIGHT, shape.point_lead))
	# The arm opposite the lead leg comes forward and a little open; the
	# other sweeps back and out. Elbows stay soft.
	for side in ["L", "R"]:
		var sign := 1.0 if side == "L" else -1.0
		var forward := side == trail
		var swing: float = -shape.arms if forward else shape.arms * 0.8
		var open: float = sign * shape.arms * (0.25 if forward else 0.45)
		_turn(skeleton, "DEF-upper_arm." + side, Quaternion(Vector3.BACK, open) * Quaternion(Vector3.RIGHT, swing))
		_turn(skeleton, "DEF-forearm." + side, Quaternion(Vector3.RIGHT, -deg_to_rad(18.0 if forward else 6.0) * amount))
	# Chest lifted; the head keeps level.
	var lift := Quaternion(Vector3.RIGHT, -shape.chest)
	_turn(skeleton, "DEF-spine.004", lift)
	_turn(skeleton, "DEF-spine.006", lift.inverse())


# Hips down by depth metres. The planted leg folds half at the hip and half
# at the ankle around its knee, so the foot stays where it landed; the chest
# tips forward a touch and the head stays level.
func _crouch(skeleton: Skeleton3D, depth: float) -> void:
	var drop := depth / Tune.PLAYER_MODEL_SCALE
	var hips: int = _bones["DEF-spine"]
	var moved := (_parent["DEF-spine"] as Transform3D).basis.inverse() * Vector3(0.0, -drop, 0.0)
	skeleton.set_bone_pose_position(hips, skeleton.get_bone_pose_position(hips) + moved)
	var side := "L" if _dip_left else "R"
	var hip := (_pose["DEF-thigh." + side] as Transform3D).origin
	var knee := (_pose["DEF-shin." + side] as Transform3D).origin
	var ankle := (_pose["DEF-foot." + side] as Transform3D).origin
	var fold := knee_fold(hip.distance_to(knee), knee.distance_to(ankle), hip.distance_to(ankle), drop)
	_turn(skeleton, "DEF-thigh." + side, Quaternion(Vector3.RIGHT, -fold * 0.5))
	_turn(skeleton, "DEF-shin." + side, Quaternion(Vector3.RIGHT, fold))
	_turn(skeleton, "DEF-foot." + side, Quaternion(Vector3.RIGHT, -fold * 0.5))
	var tip := Quaternion(Vector3.RIGHT, Tune.LEAP_DIP_LEAN * depth)
	_turn(skeleton, "DEF-spine.004", tip)
	_turn(skeleton, "DEF-spine.006", tip.inverse())


# Rotates a bone by a skeleton-space rotation about its head, written into its
# local pose through the parent's pose as Leap found it (Grace's method).
func _turn(skeleton: Skeleton3D, name: String, rotation: Quaternion) -> void:
	if rotation.is_equal_approx(Quaternion.IDENTITY):
		return
	var bone: int = _bones[name]
	var frame := (_parent[name] as Transform3D).basis.orthonormalized().get_rotation_quaternion()
	var local := frame.inverse() * rotation * frame
	skeleton.set_bone_pose_rotation(bone, (local * skeleton.get_bone_pose_rotation(bone)).normalized())
```

- [ ] **Step 4: Wire it into Player.**
  - Add `var leap_layer: Leap` after `var grace: Grace`.
  - In `_build_model`, after `grace = Grace.fit(skeleton)`, add `leap_layer = Leap.fit(skeleton)`.
  - In `_animate`, after the `if stride:` block, add:

```gdscript
	if leap_layer:
		leap_layer.amount = _air_weight * lerpf(Tune.LEAP_LINE_JOG, 1.0, leap) if leaping else 0.0
		leap_layer.progress = flight
		leap_layer.lead_left = leap_lead_left
```

  - In `_land_leap`, after the stride cue, add:

```gdscript
	if leap_layer:
		leap_layer.dip(power, leap_lead_left)
```

- [ ] **Step 5: Import, run the sheet, and look at it**

Run: `godot-mono --headless --path . --import`, then `godot-mono --path . -s tools/leap_sheet.gd`. Read `build/leap/leap_sheet.png` and check each row:
- **Top (clip only):** a sprint stride from toe-off to contact, slowed.
- **Middle (with Leap):** a visibly wider split peaking around columns 3–4, a straighter trailing knee, pointed toes, the right arm forward and the left back (lead left), a lifted chest and a level head.
- **Bottom:** the hips sink and rise back over the row, with the left foot not visibly sliding.

If an axis is mirrored (for example the lead thigh swings back), flip that sign in `_hold_line` and rerun. Write down any sign you changed.

- [ ] **Step 6: Re-run both probes**: math probe → PASS; `tools/leap_probe.tscn` → PASS.

- [ ] **Step 7: Show the user the sheet** and ask whether the line reads as feminine and elegant. Tune `LEAP_SPLIT`, `LEAP_POINT`, `LEAP_ARMS`, `LEAP_CHEST` and the dip values in `Tune` from their notes, rerunning the sheet each time.

---

### Task 6: Camera, breath, and the leap autopilot

**Files:**
- Modify: `scripts/player/player.gd` (`_rise_lag` var, `_move_camera`, `_apply_look`, `_jump`, `_land_leap`, autopilot block, `_sprint_wanted`, autopilot comment)
- Modify: `tools/leap_probe.gd` (FOV check)

**Interfaces:**
- Consumes: `Tune.LEAP_FOV`, `Tune.LEAP_BOOM` (Task 2); `leaping`, `leap`, `_air_weight` (Task 3).
- Produces: `RUN_AUTOPILOT=leap`.

- [ ] **Step 1: Write the failing check.** In `tools/leap_probe.gd` `_sprint_leap()`, record the field of view before the jump and check it at mid-flight. Add `var fov_before := _player.camera.fov` directly before `var took := await _jump()`. After the mid-flight `blend_amount` checks, add:

```gdscript
	if Game.settings.speed_fov:
		_check(_player.camera.fov > fov_before + 1.0, "the view opens on a leap (%.1f -> %.1f)" % [fov_before, _player.camera.fov])
```

- [ ] **Step 2: Run the probe to see it fail.** Run `godot-mono --headless --path . tools/leap_probe.tscn`. Expected: `FAIL the view opens on a leap`.

- [ ] **Step 3: Camera.**
  - Add `var _rise_lag := 0.0` after `var _trail_offset := Vector3.ZERO`.
  - In `_move_camera`, after `var pace := ...`, add `var leap_air := _air_weight * leap if leaping else 0.0`.
  - Change the `widen` line to:

```gdscript
	var widen := (9.0 * pace + 5.0 * _slide_weight + Tune.LEAP_FOV * leap_air) if Game.settings.speed_fov else 0.0
```

  - Change `outdoors_boom` to:

```gdscript
	var outdoors_boom := BOOM_LENGTH * Game.settings.camera_distance + 0.5 * pace + Tune.LEAP_BOOM * leap_air * Game.settings.camera_shake
```

  - At the end of `_move_camera`, add:

```gdscript
	# On a leap the camera trails her rise and fall by a hair.
	var lag := clampf(velocity.y * 0.012, -0.05, 0.05) * leap_air * Game.settings.camera_shake
	_rise_lag = lerpf(_rise_lag, lag, 1.0 - exp(-delta * 6.0))
```

  - In `_apply_look`, change the `mount` line to:

```gdscript
	var mount := Vector3(_shoulder, 1.5 - 0.4 * _slide_weight + _jolt * Game.settings.camera_shake - _rise_lag, 0.0)
```

- [ ] **Step 4: Breath and landing roll.**
  - In `_jump`, at the end of the leaping path (after `_footfall(...)`), add:

```gdscript
	if breath and not holding_breath:
		breath.gasp(0.0)
```

  - In `_land_leap`, after the `_jolt` line, add:

```gdscript
	_roll_kick += (1.0 if leap_lead_left else -1.0) * lerpf(0.008, 0.02, power)
```

- [ ] **Step 5: Autopilot.**
  - In the autopilot block in `_physics_process`, after the `jump` case, add:

```gdscript
		if _autopilot == "leap" and _autopilot_clock > 2.4 and _ground_speed() > Tune.SPRINT_SPEED * 0.9:
			_autopilot_clock = 0.0
			jump_pressed = true
```

  - Add `"leap"` to the list in `_sprint_wanted`.
  - Update the comment above `var _autopilot` to `# Dev hook: RUN_AUTOPILOT=walk, jog, sprint, jump, slide, glance or leap holds forward (most sprint; leap leaps every few seconds at full speed), so RUN_CAPTURE can photograph her mid-stride.`

- [ ] **Step 6: Run the probe to see it pass.** `godot-mono --headless --path . tools/leap_probe.tscn` → PASS.

- [ ] **Step 7: Capture mid-flight and look at it.** In PowerShell, try `RUN_SHOT_FRAME` values until one is mid-air (the leap happens about 2.4 s after she reaches sprint speed; start near 300):
`$env:RUN_CAPTURE="1"; $env:RUN_AUTOPILOT="leap"; $env:RUN_SHOT_FRAME="300"; $env:RUN_SHOT="$PWD\build\leap\leap.png"; godot-mono --path .; Remove-Item Env:RUN_CAPTURE, Env:RUN_AUTOPILOT, Env:RUN_SHOT_FRAME, Env:RUN_SHOT`
Read the image. Expected: her in the air in the split, from behind, in the snow.

---

### Task 7: Docs and the full check

**Files:**
- Modify: `CLAUDE.md`, `AGENTS.md` (commands only)

- [ ] **Step 1: Update CLAUDE.md**
  - **Project paragraph:** note that on this machine the binary is `godot-mono` (4.7.2 mono build) and that every `godot` command works with it.
  - **Commands:** add:

```powershell
# Running leap: pure math, physics/animation on the real player, and the contact sheet
godot-mono --headless --path . -s tools/leap_math_probe.gd
godot-mono --headless --path . tools/leap_probe.tscn
godot-mono --path . -s tools/leap_sheet.gd        # needs a window; build/leap/leap_sheet.png
godot-mono --headless --path . -s tools/leap_phase_probe.gd   # re-measure Stride.*_PHASES after changing a running clip
```

  - **Locomotion:** replace the claim that walk and jog are the Bandai feminine takes with: since commit `c9fb491` she plays the Quaternius `Walk_Formal` and `Jog_Fwd`; `feminine/elf_feminine.res` is still built by `tools/retarget_bvh.gd` but not loaded. Add a **Running leap** bullet:
    - A jump at `LEAP_FROM` or faster is a leap (`Player.leaping`, `leap`, `leap_lead_left`).
    - Physics: lower arc, carry, one-footed takeoff and landing, speed kept.
    - `Stride`'s leap layer plays the jog or sprint from the push-off toe-off to the lead contact (`*_PHASES`), and `leap_land` re-cues each blend point via `parameters/locomotion/<point>/seek/seek_request`.
    - `Leap` (a `SkeletonModifier3D` after `Grace`) adds the line and the spring dip; its math is static.
    - Tuning is in `Tune.LEAP_*`.
    - Add `leap` to the `RUN_AUTOPILOT` list.
- [ ] **Step 2: Update AGENTS.md** with the probe commands only.
- [ ] **Step 3: Full check.** Run in order and record results:
  - `godot-mono --headless --path . --import`
  - math probe → PASS
  - phase probe → PASS
  - leap probe → PASS
  - `godot-mono --headless --path . tools/traversal_probe.tscn`, which must reach the same result as before the change (escaped or timed out the same way; compare against a run on the unchanged code if unsure)
  - a lean smoke capture `$env:RUN_CAPTURE="1"; $env:RUN_GRAPHICS="lean"; godot-mono --path .`; look at it.
- [ ] **Step 4: Hand the play checklist to the user** (spec, Verification): jog leap, sprint leap, a leap off a ledge, an uphill leap, a slide jump, a leap while glancing back, landing into a stop versus running on, indoors on wood, lean graphics. Report what the probes cover and what only play can judge.
- [ ] **Step 5: Commit only if the user asks**, with a message such as `Give her a long running leap that lands catlike on the lead foot and runs on.`
