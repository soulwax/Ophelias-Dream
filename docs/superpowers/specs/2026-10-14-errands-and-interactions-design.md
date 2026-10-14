# Errands and environment interactions: design

Date: 2026-10-14. Plan: `docs/superpowers/plans/2026-10-14-errands-and-interactions.md`.

## Goal

Give Ophelia's chapter quests and more to do with her hands, without breaking what the game already promises: no objective on the HUD, no markers, no counters, no distances. The quests are **errands**: small things the house and the field ask of her, which she notices herself and keeps in her journal in her own words. Each one is tied to a motif the story already has (the cold stove, the cups, the red thread, the light that runs out), and each pays off in something she can feel in play, not in points.

## Rules that do not change

- The HUD shows no objective, marker, count or distance. Errands live in the journal's new *Undone* list, as prose that changes when she makes progress ("A thread on the window frame." becomes "Red wool, the birches, the stump. It goes on.").
- Nothing is required. The lake ending, the meeting on the ice and the day limit work exactly as now. An errand can make the walk easier or add a reading, never gate an ending.
- Errands exist only in Ophelia's chapter. They are off in Mathilda's chapter and in the dream (`not Game.dream_mode`, `not Game.mathilda_pov`).
- No threat is added. Errands may raise or ease `Haunting.tension`, but never call `catch_player`.
- The lumberjack canon belongs to the dream and stays there; no errand stages, names or points to it.

## The four errands

| id | Starts when | What she does | What it gives back |
| --- | --- | --- | --- |
| `warm_house` | She tries the stove chore and the woodbox is empty ("Light the stove" now says "No wood in the box"). | Carry firewood from the woodpile under the eaves to the woodbox (three armfuls), then light the stove. | The living room stays lit and warm: `Haunting` tension drains faster in the ground-floor rooms, the cold lines (`cold`) wait longer after she comes in, and the stove's glow shows through the window on her way back. |
| `two_cups` | She opens the kitchen cupboard and sees one cup missing from the pair. | Find Mathilda's cup (on the porch rail, half under snow), bring it in, set both cups on the table, warm the kettle on the lit stove. Needs `warm_house`. | Unlocks the `{cups}` reading (`Game.known("event:cups")`) for the smudges that ask for it, and a line at the meeting on the ice (topic gated on the `cups` flag). |
| `red_thread` | The existing `window_thread` chore. | Follow red wool snagged on branches, a fence wire and a stump off the route (five snags), winding it as she goes. It ends at a birch with both initials cut into it and a glove in the snow. | A keepsake journal entry *The thread* (`NoteEntry.counts = false`, so it never counts toward `LAKE_PAGES`), and the glove shown at the camp if she reaches it. |
| `light_for_dark` | Dusk (`Tune.DAY_MOMENTS`), or earlier if she opens the cellar oil cupboard. | Take the oil tin from the janitor room, fill the storm lamp on the porch hook, and carry it. | A held lamp: a warm, short-range light that keeps the trail readable through her night. It can be set down and picked up again. It burns `Tune.LAMP_HOURS` of her day. |

Each errand has states `unknown → known → (steps) → done`, and can be *let go* (she turns around, or the day runs out), which crosses it out in her own words rather than failing it.

## Ways to touch the world

These are verbs, not errands, though some errands use them.

1. **Carry** (`Carryable`): one thing in her arms at a time (an armful of wood, a cup, the oil tin, the lamp). Heavy carries (`CARRY_HEAVY`) stop sprint, leap and slide. Interact on a socket puts it there; the new rebindable `drop` action (Z / pad d-pad down; G and pad B are taken by `shoot_arrow` and `slide`) sets it down at her feet. The lamp is light and can be carried at a run. If she reads a page or opens the journal, the item stays held.
2. **Place** (`CarrySocket`): a spot that takes one kind of item (the woodbox, the table, the stove hob, the lamp hook).
3. **Hold to do** (`interact_hold_seconds()` on any interactable): brushing snow off the house sign, a post or the bench, winding the thread, filling the lamp. The reticle shows a thin ring filling; letting go keeps the progress for a few seconds.
4. **Open and look inside** (`HouseDrawer`): cupboards, drawers and the cellar oil cupboard open on a slide or a hinge, with sounds, and may hold an item.
5. **Knock the snow down** (`SnowBranch`): low pine branches loaded with snow. Brushing them with interact, or hitting them with an arrow (`receive_arrow`, which already exists), drops a puff of snow and plays `Wildlife`'s existing snow *flump*. Some hide a thread snag.
6. **Warm her hands** (`WarmSpot`): at the lit stove or Mathilda's campfire, holding interact crouches her (`Crouch_Idle`) and quiets the `cold` lines for a while. Her breath slows.
7. **Ring the lookout bell** (`Bell`): one bell on the lookout rail. Ringing it rolls out over the field, and from the far trees an echo answers a heartbeat late, in her own voice ("Here."), like the trees that already answer.

## Assets

Everything comes from the owner's bank (`C:\Users\soulwax\OneDrive - Biz\Desktop\Assets`) through a new `tools/curate_errand_assets.py` into `build/vendor/requested_errands/` (git-ignored, and not imported by Godot because `build/` has a `.gdignore`; the game loads them at runtime through `VendorLoader`), with the manifest at `docs/errands/requested_errands_manifest.json`. Without them the game builds stand-ins from `HouseKit` boxes and cylinders, as the camp does.

| Use | Source in the bank | Licence handling |
| --- | --- | --- |
| Woodbox, crate | Leartes Carpenter's Workshop `SM_Crate` (also in the camp), `SM_Chest_01` | `build/vendor`, runtime load, fallback |
| Firewood armful | Leartes `SM_Firewood` (also in the camp; reuse `requested_camp` if present) | `build/vendor`, runtime load, fallback |
| Cups, kettle stand-in | Leartes `SM_Cup`, `SM_Jar`, `SM_Bucket` | `build/vendor`, runtime load, fallback |
| Oil tin, bottle | Leartes `SM_Tin_01`..`SM_Tin_10` (pick one), `SM_Bottle` | `build/vendor`, runtime load, fallback |
| House sign, bench, lamp hook | Leartes `SM_Sign`, `SM_Bench`, `SM_Hook` | `build/vendor`, runtime load, fallback |
| Thread snags | Leartes `SM_Rope_02`/`SM_Rope_03` with a red wool material | `build/vendor`, runtime load, fallback |
| Storm lamp | `WW2_Lamp_f0243220/WW2_Lamp/Unity/Rocket/WW2_Lamp/HDRP/SM_WW2_Lamp_c1_LOD0.fbx` photoscan with `../Textures/T_WW2_Lamp_2048_{B,OpenGL_N,AO,MS}.png`, packed to ORM as `curate_camp_assets.py` does for the note | `build/vendor`, runtime load, fallback |
| Hand lantern (alternative) | `wooden_lantern_01_2k.gltf.zip` (Poly Haven, CC0) | May be committed under `assets/vendor/polyhaven/` with provenance |
| Cupboard | `painted_wooden_cabinet_2k` is already in the house; the cellar oil cupboard uses Leartes `SM_Cuboard_Small` | `build/vendor`, runtime load, fallback |
| Sounds: bell, glass, wood | Kenney *Impact Sounds* (`impactBell_heavy_*` bell, `impactWood_*` and `impactPlank_medium_*` firewood, `impactTin_medium_*` oil tin, `impactGlass_light_*` cups, CC0) and *RPG Audio* (`chop`, `cloth`, `creak`, `doorOpen_`/`doorClose_` for cupboards, `metalLatch`, `metalPot` for the kettle, CC0) | Cut into `assets/audio/errands/` by `tools/make_soundscape.py`-style levelling, credited in `assets/audio/provenance.json`, committed |

Not used, on purpose: Synty POLYGON and Kenney 3D models (low-poly, they clash with the scanned house), and the Unity-only VFX packs (`NS1_*`, `POLYGON_Particle_FX`), which Godot can't import. Snow puffs and lamp light are built in code like `SnowKick` and the camp fire.

## Voice and writing

New spoken lines go into `docs/MATHILDA_STORY.md` under a new `### Errands` heading (about 24 lines, existing moods), and `python tools/script_to_lines.py` regenerates `lines.json`. Until they are baked on the desktop GPU they play as subtitles only, which `Voice` already does for a line without a clip. The *Undone* prose and the keepsake page are data in a new `assets/errands/errands.json`, not code.

## Saving

`Errands` state (each errand's step and flags, which items sit in which socket, what she is carrying, the lamp's fuel, which snow is brushed) goes into `RunSave` and `Game.checkpoint`. A carried item after a load is back in her arms.

## Editable level

The new world pieces are built by an `Errands` node that `main.gd` adds after `Lake`, deferred until the snapshot is applied, like `Camp` and `Lake`. Nothing is added as a child of `House` or `Trail`, so saved snapshots still line up child for child and no rebuild is needed.

## Decisions to confirm

1. *Quests as errands in the journal, with no HUD objective.* This keeps the rule from `docs/DIRECTION.md`. The alternative is a small objective line, which the game removed on purpose.
2. *Ophelia's chapter only.* Mathilda's chapter could get its own errands (the camp, the cups) in a later pass.
3. *The bell's answer is her own voice.* This fits the trees that answer. It costs one new line to bake.
