# Legacy Bandai walk and jog clips

`elf_feminine.res` holds the legacy walk, jog, light run and backward walk clips, adapted from the **Bandai Namco Research Motion Dataset 1** by Bandai Namco Research Inc. ([source](https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset)), licensed under [Creative Commons Attribution-NonCommercial 4.0](https://creativecommons.org/licenses/by-nc/4.0/). The full licence text is in `LICENSE.txt`. These clips are retained with their provenance and are no longer loaded by gameplay or Character Studio.

**Ophelia's Dream must stay non-commercial while these clips are in it.**

| Clip | Take |
| --- | --- |
| `Walk` | `dataset-1_walk_feminine_001` |
| `Jog` | `dataset-1_run_feminine_001` |
| `Run` | `dataset-1_dash_feminine_001` |
| `Walk_Back` | `dataset-1_walk-back_feminine_001` |

Changes made: each take was retargeted from the dataset's skeleton onto the Styloo elf. One steady gait cycle was cut from it, turned to face forward, made to loop in place, and set on the ground. The torso is posed relative to its average over the cycle, and the neck and head follow the chest.

Normal gameplay walking uses the neutral Quaternius `Walk` clip baked into `../elf_animations.res`; that library retains Quaternius jog, sprint and leap sampling too. The Bandai walk's source frames were 129–169 (40 frames at 30 fps, 1.333 s), with measured natural speed 0.986 m/s at model scale 0.8. Its provenance and this measurement are kept here for reference. Gameplay movement remains in-place; physics owns movement.

Grace keeps the authored hip and arm motion, adding only 20% of its former arm/elbow correction and 25% of its shoulder counter-turn. Its idle-to-walk carriage envelope enters over 0.18 s and settles over 0.24 s, using smoothstep endpoints. Stops/restarts retarget the current envelope without restarting the clip or locking input. Airborne, slide and exhaustion weights gate the layer immediately. FootLock still evaluates before Grace; walk edits do not change jog/sprint leap phase tables.

Rebuild:

```powershell
python tools/fetch_motion.py
godot --headless --path . -s tools/retarget_bvh.gd
```

The first command downloads the takes into `build/bandai/`, which is not committed.
