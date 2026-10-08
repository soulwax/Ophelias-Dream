# Running leap: design

Date: 2026-10-06. Status: approved in conversation, awaiting review of this document.

## Goal

From a jog or a sprint, a jump becomes a long stride leap: a feminine line in the air and a catlike landing on the ball of the lead foot that keeps her speed and runs straight on. It should feel powerful to do and look elegant.

## Agreed choices

- **Leap style:** a long stride leap. The lead leg reaches, the trailing leg extends behind, the toes point, and the arms open in counter-swing. Not a dancer's jeté, not a light bound.
- **Landing:** flow on with a dip scaled to the fall. She never stops. An ordinary leap gives a light knee dip; a real drop gives a deeper crouch that springs back. No roll.
- **Trajectory:** longer and flatter from a sprint, with speed carried through. Jump costs and timings stay as they are.
- **Animation source:** stretch the airborne part of her own jog and sprint clips, with a procedural `Leap` layer on top. No new clip, mocap or licence.

## Why

Today every jump plays the standing Quaternius `Jump_Start`, held at a frame chosen from her vertical speed, and every landing fires `Jump_Land` and fires both feet (`Player._both_feet`). A sprinting leap reads as a standing hop that comes to a halt, and landings always cost 3–30 % of her speed. Neither motion source has a running jump: the Bandai Namco dataset has no jump takes at all, and Quaternius only has standing `Jump`, `Jump_Start`, `Jump_Land` and `Roll`.

## Scope

In: jumps that take off at jog speed or faster. Out: the standing hop (unchanged), slide jumps (keep their own carry and pose), rolls, vaults, climbing, and leg IK beyond the landing dip.

## 1. Physics and feel (`Player`, `Tune`)

**Leap factor.** At takeoff, `leap` = 0..1 ramps from a new `LEAP_FROM` (3.2 m/s, the jog clip's natural speed `STRIDE_JOG`) to `SPRINT_SPEED` (6.85 m/s). Below `LEAP_FROM` the jump is the standing hop and nothing in this document applies. `leap` is fixed for the whole jump.

**Takeoff.**
- Vertical speed: `JUMP_VELOCITY × lerp(1, LEAP_LIFT, leap)`, with `LEAP_LIFT` about 0.88.
- Horizontal carry: speed × `(1 + LEAP_CARRY × leap)`, `LEAP_CARRY` about 0.06, capped at `LEAP_MAX_SPEED`, a little above sprint speed.
- Unchanged: stamina cost, coyote time, jump buffer, variable height (`JUMP_CUT`), apex hang, fall gravity.
- A leap takes off from one foot. Instead of `_both_feet`, the push-off foot plays a step (sound at a higher force, print, powder).

**In the air.** Air drag scales toward zero with `leap` (`AIR_DRAG × (1 − leap × LEAP_DRAG_CUT)`), so a sprint leap keeps nearly all its speed. Air control (`AIR_ACCEL`) is unchanged.

**Predicted airtime.** Computed at takeoff for flat ground from the takeoff vertical speed, `GRAVITY`, `FALL_GRAVITY` and an allowance for apex hang. It drives the animation (section 2); it does not change the physics.

**Landing.**
- A leap lands on the lead foot only: one step with print and powder, not `_both_feet`.
- Speed is kept on an ordinary leap landing. Only a real drop (`power > 0`, fall speed above 6 m/s, as today) costs speed, at roughly half the current rate (`_glide *= lerp(1.0, 0.85, power)`).
- Whether she runs on or stops depends only on whether movement is still held, as with any step.

## 2. Animation (`Stride`, new `Leap` modifier)

**Lead foot.** `Player` already receives `FootLock.planted(left, at)`. The last planted foot at takeoff is the push-off foot; the other leg leads. No input delay waits for a better foot.

**Phase constants.** A headless probe (extending `tools/elf_motion_probe.gd` or alongside it) measures, for the clips `Stride` actually plays (`Jog_Fwd` and `Sprint`, both Quaternius, from `elf_animations.res`): each foot's toe-off time and the other foot's next contact time. They become constants in `Stride`, in the same style as `AIR_FROM` / `AIR_TUCK` / `AIR_TO`.

**Flight playback.**
- A new leap layer in the `Stride` tree: a TimeSeek for each of jog and sprint, blended by `leap`, behind a Blend2 on the existing chain (ordered beside `air`, before `slide`).
- `Stride.leap_pose(amount, progress, lead_left)` seeks each clip to `lerp(toe_off, contact, progress)` for the chosen foot.
- **Progress** = elapsed air time / predicted airtime. A downward ray from `Player` (reusing its surface ray) holds progress at most `LEAP_REACH_HOLD` (≈ 0.85) while the ground is still further away than a short reach distance. Progress completes only as the ground arrives. If she lands earlier than predicted (uphill), the landing cue's short crossfade covers the gap.

**The line (`Leap`, a `SkeletonModifier3D` after `Grace`).** It uses the same technique as `Grace`: local rotations conjugated through each parent's clip pose. Its weight is `leap × air`, shaped over `progress`:
- Split: the lead thigh flexes forward; the trailing hip extends with the knee near straight. Peaks around progress 0.4 (`LEAP_SPLIT`).
- Pointed toes on both feet through the flight (`LEAP_POINT`). Near the end, the lead foot eases out of the point so the ball of the foot lands first.
- Arms: the opposite arm forward and slightly up, the other sweeping back and slightly out; soft wrists (`LEAP_ARMS`). Grace's own arm swing is already off in the air (`poise` 0).
- Chest lifted, head level (`LEAP_CHEST`).
- Reach: from progress ≈ 0.75 the lead leg extends under her centre of mass.

**Landing cue.** On touchdown after a leap, jog and sprint are each re-cued to the lead foot's contact frame, so the gait carries on from where she landed. Each clip gets its own cue because their lengths differ. Check the Godot 4.7 `AnimationNodeBlendSpace1D.sync_mode` change while doing this. The `Jump_Land` one-shot does not fire for leaps.

**Catlike dip.**
- A slightly under-damped spring (`LEAP_DIP_*`: stiffness, damping, depth) drives a crouch value 0..1 after touchdown, settling in about 0.25 s while she keeps running.
- Depth is about 3 cm on an ordinary leap, rising with `power` to about 15 cm.
- The crouch lowers the hips, bends the knees, tips the chest forward slightly, then rebounds.
- The planted leg folds at hip, knee and ankle by a two-bone angle calculation (law of cosines on its thigh and shin lengths), so the foot stays on its spot while the hips lower. No IK node is added: `FootLock` already reserves an unused `L_LegIK3D`/`R_LegIK3D` hook, and a second IK path would fight it.

**Unchanged.** The standing hop keeps `Jump_Start` (seeked by vertical speed) and `Jump_Land`. `FootLock.suspended` behaves as today.

## 3. Camera, sound, feedback

**Camera.**
- Takeoff: the boom stretches slightly and the FOV opens by `LEAP_FOV` (≈ 3°), both easing back on landing.
- The rig lags her rise slightly.
- Landing: a small jolt (existing `_jolt`) plus a light roll toward the lead foot's side.
- Everything scales with the leap factor. The FOV kick follows the existing speed-FOV setting (`Game.settings.speed_fov`), like the sprint widening. The boom stretch, the rise lag and the roll follow `Game.settings.camera_shake`.

**Sound and touch.**
- Push-off: a footstep at a higher force, a short breath puff (`Breath`), and `SnowKick` powder from the push-off foot.
- Landing: one soft step and powder; on a drop, a heavier crunch and `Game.rumble` scaled by `power` as today.
- Indoor surfaces use the existing `_surface_at`, so wood and stone work unchanged.

## Tuning

All new values live in `Tune` under `LEAP_*`: `LEAP_FROM`, `LEAP_LIFT`, `LEAP_CARRY`, `LEAP_MAX_SPEED`, `LEAP_DRAG_CUT`, `LEAP_REACH_HOLD`, `LEAP_SPLIT`, `LEAP_POINT`, `LEAP_ARMS`, `LEAP_CHEST`, `LEAP_DIP_DEPTH`, `LEAP_DIP_STIFFNESS`, `LEAP_DIP_DAMPING`, `LEAP_FOV`.

## Verification

- **Phase probe:** prints toe-off and contact times per foot for jog and sprint. These are the constants in section 2.
- **Autopilot:** `RUN_AUTOPILOT=leap` sprints and leaps on a timer, for capture runs and hands-off checks.
- **Contact sheet:** a windowed tool like `tools/gait_sheet.gd` renders a side-on leap, frame by frame, into `build/leap/`, with and without `Leap`, for reviewing the line with the user.
- **Play checklist:**
  - standing hop unchanged
  - jog leap
  - sprint leap
  - leap off a ledge (held reach, deeper dip)
  - uphill leap (early landing)
  - slide jump unchanged
  - a leap while glancing back
  - landing into a stop versus running on
  - indoors on wood
  - lean graphics on
- A `RUN_CAPTURE` shot with `RUN_AUTOPILOT=leap` and `RUN_SHOT_FRAME` set mid-flight.

## Risks

- **Re-cueing the gait on landing.** Seeking a blend space whose clips have different lengths needs a cue per clip. If that proves awkward in the tree, the fallback is to retime the jog and sprint so their foot events share phase.
- **Quaternius base clips.** Commit `c9fb491` unwired the Bandai `feminine` library, so the game currently plays the Quaternius `Jog_Fwd` and `Sprint` for both gaits (CLAUDE.md still says otherwise). Every leap therefore starts from a masculine clip, and the `Leap` layer carries the feminine line throughout. Judge it on the contact sheet. Re-wiring the Bandai clips is out of scope here; if it happens later, only the phase constants need re-measuring.
- **The dip's bend.** It assumes the planted leg is roughly vertical at contact and splits the fold half at the hip and half at the ankle. If the contact sheet shows the foot sliding, the split can be weighted by the leg's actual angle.
- **In practice a leap means a sprint.** She has two input speeds, walk (1.83 m/s) and sprint (6.85 m/s), so she only passes `LEAP_FROM` while sprinting or speeding up to a sprint. A walking jump stays a hop.
