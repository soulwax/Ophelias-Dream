# Fir forest in the mountains (Sketchfab)

The green biome's trees and undergrowth come from this pack.

| | |
| --- | --- |
| Original title | лес пихты в горах на скетч ("fir forest in the mountains") |
| Source | Sketchfab. **Model page URL: to be filled in** |
| Author | **To be filled in** |
| Licence | Sketchfab Standard licence, free download (<https://sketchfab.com/licenses>) |
| Received | `the-landscape-is-a-forest-in-the-mountains.zip`, 2026-10-06 |

## Licence terms that matter here

- Use in this game, including modified, is allowed, commercial or not.
- No redistribution of the licensed material as stand-alone files. The pieces ship inside the game. The raw diorama and its original textures are therefore kept out of git, in the ignored `build/vendor/sketchfab_forest/` (see below). Earlier commits on `mathilda-story` still contain them.
- Credit the provider where other licensed material is credited. The Esc menu's credits carry a line for this pack.

## What is here

Tracked, and shipped in the game:

- `meshes/`: the ten pieces the game plants, written by `tools/import_forest_pack.gd`.
- `source/forest_pack_*.png` (all but `_9`): the textures Godot extracted from the FBX that those meshes use.

Kept on the machine, not in git (`build/vendor/sketchfab_forest/`; `.gitignore` blocks them under `assets/`):

- `source/forest_pack.fbx`: the original scene (renamed from `лес пихты в горах на скетч.fbx`). A hand-made diorama about 35 × 24 m with 395 meshes and 19.4k triangles.
- `source/forest_pack_9.png`: the extracted ground texture (7.9 MB), which no piece uses.
- `textures/`: the pack's 14 textures, unchanged.

The received zip is the source of all of these. Keep it, or the `build/` copy, on each machine that has to rebuild the meshes.

## Changes made

`tools/import_forest_pack.gd` takes ten meshes out of the scene: five tall spruces (`spruce_a..e`, 4–11 m), two crossed-card trees, two sizes of the small card fir (`card_fir`, `card_bush`) and a grass card. For each it:
- bakes the mesh's place in the scene into its vertices
- moves it so its base sits at the origin
- gives it its own material copies: surfaces with alpha are alpha-cut (0.4) and double-sided, with roughness 0.9 and no metal

The diorama's ground mesh and its baked texture are not used.

Rebuild:

```powershell
Copy-Item build/vendor/sketchfab_forest/source/forest_pack.fbx assets/vendor/sketchfab_forest/source/
godot-mono --headless --path . --import
godot-mono --headless --path . -s tools/import_forest_pack.gd
godot-mono --headless --path . -s tools/forest_pack_probe.gd
```
