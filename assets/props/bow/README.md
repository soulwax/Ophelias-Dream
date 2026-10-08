# Found Styloo bow

Extracted from the owner's `thecompanycharactersStyloo/glb/elf.glb`, by Styloo. The pack's CC0 record is retained in `LICENSE.txt`; the rest of the elf stays in its prepared, weapon-free model. The bow has its original geometry/material, recentered with its long axis upright. Editable source is in `source/bow.blend` (Godot-ignored).

Rebuild with Blender: `blender --background --python-exit-code 1 --python tools/extract_elf_bow.py -- <original-elf.glb>`. The script selects only vertices weighted to `DEF-bow*`, excluding arrows and character geometry. Originals in the asset bank are unchanged.

`BowPickup` places one bow beside the trail 12 metres beyond its start. Approach, stop and use the regular interact action. `BowHoist` is a C# procedural skeleton animation: reach (0–12%), lift (12–43%), over the shoulder (43–60%), seat (60–80%), release/recover (80–100%) over 2.8 seconds. The right arm uses a two-bone solve against the real discovered grip. The bow stays in the world until grasped, follows the palm through the lift, then follows a chest-bone attachment diagonally across the backpack. Physics owns player movement; she can walk at the careful-walk pace during the upper-body action. Sprint, jump, slide and other interactions wait for recovery; look stays available. Journal and paused phases freeze animation progress. FootLock, Grace and Leap retain their order, with BowHoist evaluated afterward.

Tuning is in `scripts/tune.gd`. Normal new runs start without equipment; lookout checkpoints retain bow ownership and restore one carried instance. The bow sits 0.22 skeleton metres behind the body, 0.26 closer than the original placement.

After finding it, use the rebindable `draw_bow` action (F / right shoulder button) to reach behind, lift the bow over the shoulder and lower it into the left hand. Draw takes 1.8 seconds and ends in a persistent left-palm-following hold pose. Use the same action again to hoist it onto the back and release the arm. Legs keep walking; sprint/jump/slide remain unavailable during either gesture. Draw requests while sprinting, airborne or already animating are refused. Repeated input does not queue or restart gestures. Journal/menu phases freeze progress.

Three finite arrow bundles lie along the trail (four arrows each); the quiver holds eight. Use `aim_bow` (X / right mouse / left shoulder) to raise the bow and nock an arrow, then `shoot_arrow` (G / left mouse / right trigger) to draw and release the string. A shaft that strikes the world remains recoverable. Arrows and collected bundles persist at the lookout checkpoint. The bow lowers during a run while keeping both hands in the combat pose; running remains available at reduced speed.

Validation: `dotnet build OpheliasDream.csproj`, then `tools/bow_probe.tscn` for hoist, draw, aim, run, collection, release and recovery.
