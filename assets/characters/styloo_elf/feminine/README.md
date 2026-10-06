# Her walk and jog

`elf_feminine.res` holds her walk, jog, light run and backward walk. They are adapted from the **Bandai Namco Research Motion Dataset 1** by Bandai Namco Research Inc. ([source](https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset)), licensed under [Creative Commons Attribution-NonCommercial 4.0](https://creativecommons.org/licenses/by-nc/4.0/). The full licence text is in `LICENSE.txt`.

**Ophelias Dream must stay non-commercial while these clips are in it.**

| Clip | Take |
| --- | --- |
| `Walk` | `dataset-1_walk_feminine_001` |
| `Jog` | `dataset-1_run_feminine_001` |
| `Run` | `dataset-1_dash_feminine_001` |
| `Walk_Back` | `dataset-1_walk-back_feminine_001` |

Changes made: each take was retargeted from the dataset's skeleton onto the Styloo elf. One steady gait cycle was cut from it, turned to face forward, made to loop in place, and set on the ground. The torso is posed relative to its average over the cycle, and the neck and head follow the chest.

Rebuild:

```powershell
python tools/fetch_motion.py
godot --headless --path . -s tools/retarget_bvh.gd
```

The first command downloads the takes into `build/bandai/`, which is not committed.
