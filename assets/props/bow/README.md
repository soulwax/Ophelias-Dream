# Found Styloo bow

Extracted from the owner's `thecompanycharactersStyloo/glb/elf.glb`, by Styloo. The pack's CC0 record is retained in `LICENSE.txt`; the rest of the elf stays in its prepared, weapon-free model. The bow has its original geometry/material, recentered with its long axis upright. Editable source is in `source/bow.blend` (Godot-ignored).

Rebuild with Blender: `blender --background --python-exit-code 1 --python tools/extract_elf_bow.py -- <original-elf.glb>`. The script selects only vertices weighted to `DEF-bow*`, excluding arrows and character geometry. Originals in the asset bank are unchanged.

`BowPickup` places one bow beside the trail 12 metres beyond its start. Approach, stop and use the regular interact action. `BowHoist` is a C# procedural skeleton animation: reach (0–12%), lift (12–43%), over the shoulder (43–60%), seat (60–80%), release/recover (80–100%) over 2.8 seconds. The right arm uses a two-bone solve against the real discovered grip. The bow stays in the world until grasped, follows the palm through the lift, then follows a chest-bone attachment diagonally across the backpack. Physics owns player movement; she can walk at the careful-walk pace during the upper-body action. Sprint, jump, slide and other interactions wait for recovery; look stays available. Journal and paused phases freeze animation progress. FootLock, Grace and Leap retain their order, with BowHoist evaluated afterward.

Tuning is in `scripts/tune.gd`. Normal new runs start without equipment; lookout checkpoints retain bow ownership and restore one carried instance. This adds carrying only; it does not add arrows or firing controls.

Validation: `dotnet build OpheliasDream.csproj`, Godot Mono import for new classes/assets, then `tools/bow_probe.tscn`. Run the probe with a window for the eight-frame hoist sequence under ignored `build/animation/bow/`.
