# Her movement

How to make her controls more satisfying and precise, and her animation clearly feminine, without making her a caricature or a second person.

## Where it stands

A lot already works, and none of it should be redone.

- **Steering.** `Player._steer` moves speed and heading separately. Turning at a walk is quick, at a sprint it sweeps, and hard corners bleed speed. A reversal at speed brakes first, and letting go skids.
- **Jumping.** Coyote time, a jump buffer, variable height, a heavier fall, and air control are in.
- **Sliding.** Slides use snow friction and gravity along the slope.
- **Steps.** `_step_surge` checks her speed as a foot lands and surges as it pushes off.
- **Her body.** `CharacterBody3D` already snaps to the floor (`floor_snap_length`), keeps a constant speed on slopes, and has physics interpolation on.
- **Locomotion clips.** `Stride` blends Idle, `Walk_Formal`, `Jog_Fwd`, and `Sprint` by her ground speed, at a playback rate that keeps the feet from skating. Air, slide, landing, and stumble layers ride on top.
- **Foot contact.** `FootLock` finds real foot contacts and drives steps, prints, and powder. It can hold feet with IK, but nothing on the elf uses that yet.
- **Carriage.** `Grace` adds arm counter-swing, soft elbows, a lifted chest, a level head, and a recurring rise onto her toes.
- **Camera.** It widens with speed, jolts on each footfall, rolls slightly into turns, and leans with her acceleration.

What is missing is where the remaining feel lives.

- **No gamepad support at all.** Every bind in `Game._bind` is a key or a mouse button.
- **No leg IK on the elf.** `FootLock.fit` looks for `L_LegIK3D` and `L_foot_target` nodes, which the elf rig does not have, so her feet are wherever the clip puts them. On slopes, the porch, and the stair, one foot floats or sinks.
- **Her hands sit in their rest pose.** The retarget in `tools/retarget_elf.gd` maps no finger bones, so the fingers keep the shape they had in the bind pose.
- **Her hair, dress, and face are not driven.** The skeleton has 216 bones, including the hair chains (`DEF-hairfront`, `DEF-hairside.L/R`, three segments each), the dress chains (`DEF-dressA`, `DEF-dressF.L/R`, `DEF-dressB.L/R`), eyelids, brows, jaw, lips, eyes, and twist bones in the arms and legs. Nothing animates any of them. `CLAUDE.md` says the model has no face or cloth to simulate; the bones say otherwise.
- **Turns in place, starts, and stops are just rotations and speed changes.** Nothing in her body anticipates them or settles after them.
- **Every clip comes from one male performance.** All the clips are baked from the Quaternius library. `Walk_Formal` is a stiff, formal walk that `Grace` has to work against.

## Principles

1. **Precision first.** A press shows in her within one physics tick, and what she does is predictable. Every assist below is something the player would only notice if it were missing.
2. **Feminine through dynamics, and grounded.** In point-light gait studies (Murray, Kory and Sepic 1970; Mather and Murdoch 1994; Troje 2002), women's walks read through lateral hip sway more than shoulder sway, elbows held close to the body, and a body that takes up less room. Men's read through shoulder sway and elbows held out. Those cues are motion, not mesh, so they can be layered over any clip. Aim for a real woman walking, not a catwalk. She is also cold and frightened, and her carriage should show both.
3. **Source the clips and layer the rest.** Every clip has its provenance recorded. The procedural layers make any clip read as hers.
4. **Every step ends in a measurement or a capture.** There is no test suite, so each phase names its probe.
5. **The narrative rules still hold.** No wave and no writing pose, because either would decide the pages. The figure and the Listener keep their rig and their clips. `docs/NARRATIVE_INTENT.md` said her clips would not change. This plan is where they change, and only hers.

## Phase 0: Measure the starting point

1. Extend `tools/elf_motion_probe.gd` into a gait probe. For each clip it should measure step width, lateral hip sway, pelvic tilt and turn, lateral shoulder sway, how far the elbows are from the torso, and how far a planted foot drifts. It writes `build/gait/baseline.txt`, and every later phase reruns it against that file.
2. Render `tools/grace_probe.gd` side, front, and back views at idle, walk, jog, and sprint, so later views can be compared against them.
3. Measure input latency. From a key press, count the physics ticks until `_glide` changes. It should be one tick.
4. Note that on this machine `godot` no longer resolves in a fresh shell. Only `godot-mono` 4.7.2 is installed (`C:\Users\soulwax\scoop\apps\godot-mono\4.7.2\godot-mono.console.exe`). Either restore the plain shim or point the commands in `CLAUDE.md` at it.

## Phase 1: Controls

These do not depend on any animation work.

1. **Gamepad.** Add joypad slots to `Settings.ACTIONS` and bind them in `Game._bind`: left stick to move, right stick to look, triggers for sprint and holding breath, face buttons for jump, slide, and interact. Give the left stick a radial dead zone (start at 0.18) and a response curve (start at power 1.6). Give the right stick acceleration that ramps in over 0.25 s, so small corrections stay fine and a full push turns quickly. Look sensitivity for the stick goes on the Camera page.
2. **Analog speed.** A partly pushed stick walks slower, down to about 0.6 m/s, and `Stride` already slows the clip to match. On keyboard, add a rebindable "walk slowly" action that is held, in `Settings.ACTIONS`.
3. **Start burst.** From standing, the first tick of input gives her up to 0.55 m/s at once, then the existing acceleration takes over. That makes the start feel immediate. Phase 7 gives it a pose.
4. **Fine heading.** At a walk, a heading change under 20° applies at once instead of through the turn rate, so she can line up with a door or a page.
5. **Input buffers.** Keep an interact press for 0.15 s, so E pressed just before she is in reach still opens the door. When she is moving too fast to read, keep the read request for 0.4 s while she slows. Right now `nearby_note()` refuses and the press is lost.
6. **Door-frame assist.** Indoors, when she hits a vertical edge while pushing mostly forward, use `test_move` to try sideways nudges from 0.06 to 0.15 m. If one is clear, slide her through. With a 0.34 m capsule and 0.92 m doorways, she snags on frames today.
7. **Apex hang.** While the jump is held and her vertical speed is under 1.2 m/s, gravity is 0.65 of normal. The top of the jump floats a little, and the existing heavier fall makes the drop crisp.
8. **Glance back.** Add a held, rebindable action (R3 on a pad). The camera swings round to look behind her over about 0.18 s. Her movement stays relative to where the camera faced before the glance, so she keeps running forward. Her head and shoulders turn back (Phase 6). On release the camera swings back. This is the horror game's own camera move: the figure leaves when it is watched, and the wrong print lies behind her.
9. **Camera arm.** When the spring arm hits something it pulls in at once, but it should extend back out over about 0.4 s instead of popping. At speed, shift the pivot 0.25 m toward where she is going. Smooth the camera's height separately for small vertical steps like the porch and the stair. For gamepad only, an optional setting eases the camera behind her after 1.5 s without right-stick input. It stays off for the mouse.

How to check: run `RUN_AUTOPILOT=walk` and `sprint` with a pad and with the keyboard. Walk through every doorway in the house from different angles. Jump on the spot and while sprinting. Hold the glance while sprinting on the trail.

## Phase 2: Feet on the ground

Leg IK comes first, because the narrow base, slopes, the stair, and the dress collisions all depend on it.

1. **Leg IK.** Add one `TwoBoneIK3D` per leg on the elf: root `DEF-thigh`, middle `DEF-shin`, end `DEF-foot`. Put a pole node ahead of each knee. Name the targets `L_foot_target` and `R_foot_target` under the rig root, and the IK nodes `L_LegIK3D` and `R_LegIK3D`, which is what `FootLock.fit` already looks for. Godot 4.6 added these solvers.
2. **Modifier order.** `FootLock` judges contacts on the clip's pose, then `Grace` adds her carriage and moves the pelvis, then the IK solves the legs. Today `Grace` is added after `FootLock`, and `FootLock` moves itself ahead of any IK it finds. Keep that order explicit when the IK nodes are added.
3. **Pelvis adjustment.** Lower the hips by however far the lower foot falls short of its ground, smoothed, so both feet reach on slopes, the porch, and the stair.
4. **Foot to the ground.** Pitch and roll a planted foot to the terrain normal, sampled from `Ground.height_at` or from the floor ray indoors.
5. **Twist bones.** Add a `BoneTwistDisperser3D` for the `.001` twist bones in the upper arms, forearms, and thighs, so wrists and thighs do not twist like a sweet wrapper when the arms swing or the hips turn.

How to check: in the gait probe, a planted foot drifts less than 2 cm and the knee never locks straight. In captures on the stair and a slope, both feet are on the surface.

## Phase 3: Sourcing clips

1. **Quaternius Universal Animation Library 2.** It is [CC0](https://quaternius.com/packs/universalanimationlibrary2.html), released January 2026, now at v2.1, with more than 130 clips, new idles, and walks in eight directions. It is built on the same universal rig as the first library, so the bone map in `tools/retarget_elf.gd` already fits. Download the standard glTF export without root motion into `assets/vendor/quaternius_ual2/`, with a `provenance.json` like the Poly Haven one. Audition the clips in the [animation viewer](https://quaternius.com/animviewer.html) first. Look for a lighter walk than `Walk_Formal`, a less bouncy jog, an athletic run, idles that shift weight, turns in place, and the eight-direction walk.
2. **A general retarget.** Change `tools/retarget_elf.gd` to read a list of (source scene, source clip, role name). Map the finger bones too if the source has them. Bake the clips into `elf_animations.res` under role names (`Walk`, `Jog`, `Run`, `Idle_Calm`, `Idle_Cold`, `Step_L`, …), so `Stride` stops hard-coding Quaternius clip names.
3. **Natural speeds.** Re-measure `Tune.STRIDE_*` for each new clip with the gait probe, so the playback rate still keeps her feet from skating.
4. **Bandai Namco motion dataset.** [Dataset 1](https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset) has walk, run, dash, and walking back, left, and right performed in a *feminine* style, as BVH at 30 fps. Her walk, jog, and sprint come from it. The licence is CC BY-NC 4.0: Run Away must stay non-commercial while these clips are in it, and the credit travels with the game. `tools/retarget_bvh.gd` reads the BVH directly (Godot does not import BVH), cuts one looping cycle, and bakes it onto the elf.
5. **Not used.**
   - [100STYLE](https://ianxmason.github.io/100style/) is CC BY 4.0, but all of it is one 182 cm male performer. A cautious or tiptoe style might help. None of it is feminine.
   - Mixamo is under Adobe's terms, not CC0, and does not fit the provenance rule.
   - CMU is free, but the quality is uneven.

How to check: every new clip plays on the elf in `tools/grace_probe.gd` views, and a walk in the game shows no skating.

## Phase 4: Her carriage

This is the feminine layer itself, in `Grace`. It reads the gait phase from the thighs, as `Grace` already does, so it stays in step with any clip.

1. **Hip sway.**
   - The pelvis shifts toward the standing leg (start at ±2 cm at a walk).
   - The hip on the swinging side drops (±4°).
   - The pelvis turns forward with the reaching leg (±5°).
   - Full strength at a walk, about 40% at a jog, about 10% at a sprint. A sprint is athletic, not swaying.
2. **Quiet shoulders.** Cut the shoulder counter-turn to the least that keeps her head level. No sideways shoulder sway. The head stays steady, as it does now.
3. **Narrow base.** During each swing, pull the IK foot target toward her line of travel, so each step lands about 4 cm closer to the centre line than the clip puts it. Feet never cross the line; crossing over is the catwalk.
4. **Arms close.**
   - The upper arms come in about 6 to 8° toward the body, turned slightly inward.
   - The forearms stay softly bent, 12 to 20°.
   - The arms swing mostly forward and back, as they already do. At a jog or a sprint they swing a little across the body.
5. **Hands.**
   - A relaxed curl per finger: the index finger least, the little finger most, the thumb soft.
   - Outside, in the cold, the hands close toward a half fist. At a sprint, a loose fist.
   - This step matters most, because flat hands are the most mechanical thing about her today.
6. **A light step.** At the same speed she takes shorter steps at a higher cadence: move the walking plateau in `Stride` so the walk clip plays faster. She lands softer on the heel, and her body bobs up and down less.
7. **Tuning constants.** Add them to `Tune`: `GRACE_HIP_SHIFT`, `GRACE_HIP_DROP`, `GRACE_HIP_TURN`, `GRACE_STEP_NARROW`, `GRACE_ELBOW_TUCK`, `GRACE_FOREARM_SOFT`, `GRACE_HAND_CURL`, `GRACE_HAND_COLD`.

How to check:
- The gait probe shows hip sway well above shoulder sway, the elbows closer to the torso than the baseline, and a narrower step width.
- In side and front captures the walk reads as hers.
- The caricature check: her feet never cross, and her hip turn at a walk stays at or under 6°.

## Phase 5: Hair and dress

1. **Springs.** Add a `SpringBoneSimulator3D` for the hair chains (`DEF-hairfront`, `DEF-hairside.L`, `DEF-hairside.R`) and the dress chains (`DEF-dressA`, `DEF-dressF.L/R`, `DEF-dressB.L/R`). Each chain is stiffer at the root than at the tip, with moderate drag and gravity pulling down.
2. **Collisions.** Add `SpringBoneCollision3D` capsules on the thighs and shins, and a sphere at the hips for the dress and one at the head for the hair. Without them the hem passes through her legs in a sprint or a slide.
3. **Wind.** Outside, push the springs with `Game.weather.wind` and the gust. Her hair streams downwind and the hem flutters in a gust. Indoors that force is zero, so the cabin is also where her hair is still. That carries the warm room against the storm into her body.
4. **Ears.** A very stiff spring, so they lag only slightly.
5. **Breasts.** Leave `DEF-breast.L/R` out of the simulation. Movement there would read as caricature.
6. **Order.** The springs run after the leg IK, so the dress follows the solved legs. On lean graphics, update them at half rate if the frame time needs it.

How to check: capture a sprint, a slide, and standing in a gust outside, then the same standing inside. The hem should never pass through her legs.

## Phase 6: Gaze and face

1. **Looking.** Add a `LookAtModifier3D` to the neck and head (about 40/60 between them) and to `DEF-eye.L/R`, with angle limits so her head never turns too far. Targets, in priority order:
   1. The figure, while it is shown. She looks at it, and the player sees her see it.
   2. A sound, for 1.5 s: a knock, the whisper, a branch snapping.
   3. A page or door she is near.
   4. When she is standing or walking slowly, where the camera is looking.
2. **Blinking.** Using the `DEF-lid` bones, blink every 2.5 to 6 s, sometimes twice. She blinks faster under threat and narrows her eyes into a gust.
3. **Brows.** The `DEF-brow` bones draw together as `Game.threat()` rises and lift on a sting.
4. **Mouth and breath.** The jaw and lips part with `Breath.strain` while she pants, press shut while she holds her breath, and open on the gasp. Her face then shows the same thing the plume shows, which is exactly the Listener's rule.
5. **Shiver.** A small tremor through the shoulders in a strong gust outside.

How to check: a capture with the figure in view, a knock heard indoors, holding her breath beside the Listener, and the gasp.

## Phase 7: Starts, stops, and turns

Godot's AnimationTree crossfades between clips, but it has no inertial blending. These transitions therefore live in `Grace` and decay their own offsets.

1. **Starts.** A brief lean of about 80 ms, with her weight onto the standing foot, then a quicker first step. This is the pose for the start burst in Phase 1.
2. **Stops.** Predict where she will stop from her speed and the stopping rate (v²/2a). Time the last foot contact so her feet finish together. Her torso carries on slightly and settles. The arm swing dies away like a damped spring instead of cutting off.
3. **Turns in place.** When standing and the input swings more than 70°, her head turns first, then her shoulders and hips about 80 ms later, then her feet in two short pivot steps. `FootLock` registers those as steps, so they sound. Use a clip from the second library if one fits, or do it procedurally.
4. **Reversing at speed.** She plants, leans back, throws snow forward, and pivots over the outside foot, with a scuff sound.
5. **Indoors.** At walking speed indoors she keeps facing the camera and steps in eight directions, using a 2D blend space over the eight-direction walk. That is precise in the narrow rooms. Outdoors she turns to face where she is going, as she does now.
6. **In the air.** Her arms lift a little for balance. On landing, `Jump_Land` still plays, and the leg IK puts her knees over uneven ground.

How to check: turn in place to every side, stop from a walk and from a sprint, reverse during a sprint, and walk through the hall in every direction.

## Phase 8: Idles and weather

1. **Weight on one leg.** Standing, her weight rests on one leg and the opposite hip drops. Every 6 to 10 s she shifts to the other leg with a small step.
2. **Cold outside.**
   - Her shoulders rise and her arms draw in.
   - In strong wind her hands tuck or rub her upper arms.
   - She turns her face away from the gust.
3. **Warm inside.** Her shoulders drop and her hands hang loose. The rise onto her toes happens only indoors; in the snow it looks wrong.
4. **Listening.** Her head turns toward sounds, from Phase 6.
5. **A stretch goal.** After a gust has blown hair across her face, she sometimes brushes it back. That needs arm IK to her temple (Phase 9). It only happens outside and it is rare.

How to check: stand for a minute outside in a gust, then inside by the lamp. The two should look clearly different.

## Phase 9: Her hands on things

1. **Doors and switches.** Add a `TwoBoneIK3D` on each arm. When she presses E at a door, her hand reaches the handle (`interact_point`) over about 0.25 s, the leaf swings while her hand is on it, and then she lets go. On a switch, her fingers press it.
2. **Reading.** Her head bows toward the page on the ground through the gaze in Phase 6. Her hands stay still, so there is no writing pose.

How to check: open every door in the house. Her hand should meet each handle without passing through the leaf.

## Phase 10: Sound and touch

1. **Cloth sound.** A cloth rustle in time with her arm swing and her dress. Source it CC0 through `tools/fetch_sounds.py` from BigSoundBank or Freesound, cut and level it with `tools/make_soundscape.py`, and give it an SPL constant in `Loudness`.
2. **Breathing in step.** At a jog or a sprint her breathing locks to her steps: two steps in, two out.
3. **Scuffs.** A scuff on hard turns and stops. Snow sprays forward when she reverses.
4. **Rumble on a pad.**
   - On landing, scaled by how hard she came down.
   - On a stumble.
   - A low, slow pulse while the figure waits at the door.
   - A short pulse on the sting.

## What not to do

- No crossing steps, no exaggerated hip swing, no primping or posing idles, and no breast physics.
- No wave and no writing pose.
- No new body and no constructed meshes. Everything above drives the elf she already is.
- Do not change how the figure or the Listener move.

## Order

Phase 1 and Phase 2 go first and do not depend on each other. Phase 4 needs the IK from Phase 2 for the narrow base. Phase 5 is better after Phase 2, so the collisions follow the solved legs. Phase 6 depends on nothing and can go whenever the face is wanted. Phase 3 only gates the clip swaps in Phases 7 and 8; the procedural versions of those can come first.

After each phase, update the bullets about the player model in `CLAUDE.md` (no leg IK, no face, no cloth), the controls table in `docs/GDD.md` once a gamepad is in, and the animation section of `docs/NARRATIVE_INTENT.md`, which says her clips will not change.

## Decided

1. Her walk, jog, and sprint use the Bandai Namco feminine-style clips. They are CC BY-NC 4.0, so the game stays non-commercial and credits Bandai Namco Research Inc.
2. The keyboard gets a held, rebindable "walk slowly" key.
3. Indoors at walking speed she faces the camera and steps in eight directions. Outside she turns to where she goes.

## Sources

- Troje, "Decomposing biological motion" (Journal of Vision, 2002): [paper](https://jov.arvojournals.org/article.aspx?articleid=2192503). Women's walkers: more hip sway than shoulder sway, elbows held close.
- Mather and Murdoch (1994), via the same paper: lateral sway decides how the gender of a walker is read, even against body shape.
- Godot: [IK in 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/), [TwoBoneIK3D](https://docs.godotengine.org/en/stable/classes/class_twoboneik3d.html), [SpringBoneSimulator3D](https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html), [state machine transitions](https://docs.godotengine.org/en/stable/classes/class_animationnodestatemachinetransition.html) (crossfades, no inertial blending).
- Clips: [Quaternius Universal Animation Library 2](https://quaternius.com/packs/universalanimationlibrary2.html) (CC0), [Bandai Namco Research Motion Dataset](https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset) (CC BY-NC 4.0), [100STYLE](https://ianxmason.github.io/100style/) (CC BY 4.0).
