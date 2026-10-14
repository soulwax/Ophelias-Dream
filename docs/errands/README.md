# Errand assets

Props and sounds for Ophelia's errands and the new ways to touch the world (`docs/superpowers/specs/2026-10-14-errands-and-interactions-design.md`). Every prop has a built fallback, so the game runs without the ignored folder.

## Commands

```powershell
python tools/curate_errand_assets.py ["<bank root>"]   # props into build/vendor/requested_errands/, the CC0 lantern into assets/vendor/polyhaven/
python tools/make_errand_sounds.py ["<bank root>"]     # sounds into assets/audio/errands/, credits into assets/audio/provenance.json
godot-mono --headless --path . --import                # then import them
```

The bank root defaults to `C:\Users\soulwax\OneDrive - Biz\Desktop\Assets`. Both scripts read only the exact paths they name (never a recursive scan of the bank) and can be re-run: they overwrite their outputs and replace, not duplicate, their provenance entries. A missing source prints `missing <name>` and is skipped.

## Licences

- **Leartes Studios Carpenter's Workshop** and the **WW2 lamp scan** are commercial downloads from the owner's bank with no verified redistribution right. They land in the ignored `build/vendor/requested_errands/`, and `requested_errands_manifest.json` here records each source path and SHA-256 (it holds no licensed data). They are never imported by Godot (`build/` has a `.gdignore`); `VendorLoader` reads them at runtime, so a release must ship them beside the exe or go without them (stand-ins).
- **Poly Haven `wooden_lantern_01`** is CC0. It is unzipped into the tracked `assets/vendor/polyhaven/wooden_lantern_01/` and credited in `assets/vendor/polyhaven/provenance.json`.
- **Kenney Impact Sounds and RPG Audio** are CC0 (`License.txt` beside each pack, checked by the script). The cut WAVs in `assets/audio/errands/` are tracked and credited in `assets/audio/provenance.json` under `errands/`. Note that `tools/make_soundscape.py` rewrites that file from scratch: run `make_errand_sounds.py` again after it.

## Props (`build/vendor/requested_errands/`)

| File | For |
| --- | --- |
| `leartes/SM_Crate` | the woodbox by the stove (`warm_house`) |
| `leartes/SM_Chest_01` | alternative woodbox, or a chest to open |
| `leartes/SM_Firewood` | one armful of firewood; the woodpile under the eaves |
| `leartes/SM_Cup` | the two cups (`two_cups`) |
| `leartes/SM_Jar`, `leartes/SM_Bucket` | kettle stand-in on the stove hob |
| `leartes/SM_Tin_03` | the oil tin from the janitor room (`light_for_dark`) |
| `leartes/SM_Bottle` | oil bottle, a second thing in the oil cupboard |
| `leartes/SM_Sign` | the house sign she can brush the snow off |
| `leartes/SM_Bench` | the porch bench, brushable |
| `leartes/SM_Hook` | the porch lamp hook (a lamp socket) |
| `leartes/SM_Rope_02`, `leartes/SM_Rope_03` | thread snags (`red_thread`), with a red wool material |
| `leartes/SM_Cuboard_Small` | the cellar oil cupboard (`HouseDrawer`) |
| `ww2_lamp/SM_WW2_Lamp_c1_LOD0.fbx` | the storm lamp she fills and carries |
| `polyhaven/wooden_lantern_01/` (tracked) | hand lantern, an alternative to the storm lamp |

Leartes textures are shared by several meshes and are named by set, not by mesh (`T_Woodprops_01_{B,N,ORM}.png`, `T_Wooden_*`, `T_Tools_*`, `T_GlassProps_*`, `T_ShelfandBench_*`, `T_Metal_*`, `T_Rope_*`). Each glTF references its `_B` and `_N` PNGs by those names; the `_ORM` PNG (R occlusion, G roughness, B metal) is not referenced and has to be wired in on the Godot side, as `Camp._orm_from` does. Each glTF holds `_LOD0`..`_LOD3` meshes and a `_ConvexHulls` mesh; use LOD0.

The lamp's textures are `T_WW2_Lamp_2048_{B,N,ORM}.png` (`N` is the OpenGL normal; `ORM` is packed from the scan's AO and Unity metal/smoothness map). The FBX names no textures, so the material is built in code.

## Sounds (`assets/audio/errands/`)

Mono 44.1 kHz 16-bit WAVs, levelled as `make_soundscape.py` levels one-shots: the loudest 50 ms at a -12 dBFS impact RMS, never over -1 dBFS peak. Give each an SPL in `scripts/audio/loudness.gd`.

| Files | Source (Kenney) | For |
| --- | --- | --- |
| `bell.wav` | `impactBell_heavy_001` (the longest), tail kept | the bell |
| `wood_drop_00..03` | `impactWood_heavy_000..002`, `impactWood_medium_000` | an armful set down or dropped |
| `wood_stack_00..02` | `impactPlank_medium_000..002` | wood laid into the woodbox |
| `tin_00..02` | `impactTin_medium_000..002` | the oil tin set down, the lamp filled |
| `cup_00..02` | `impactGlass_light_000..002` | a cup set down |
| `cupboard_open_00..01` | `doorOpen_1..2` | `HouseDrawer` opening |
| `cupboard_close_00..02` | `doorClose_1..3` | `HouseDrawer` closing |
| `latch.wav` | `metalLatch` | the lamp hook, the oil cupboard latch |
| `kettle.wav` | `metalPot1` | the kettle set on the hob. A one-shot clank, not a loop: the packs have no simmer, so any boiling bed has to come from elsewhere |
| `cloth_00..03` | `cloth1..4` | brushing snow, winding the thread, warming her hands |
| `snow_dump_00..03` | `impactSoft_heavy_000..002`, `impactSoft_medium_000` | snow knocked off a branch or a sign |
