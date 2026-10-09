# Character studio

The reusable personal skill is `$run-away-character-customization`, installed in `~/.codex/skills/run-away-character-customization/`. Its references cover the inspected base model, eye masks, outfit modeling, skin-weight normalization, texture ownership, UVs, normal baking, and export integration.

## Browse the collection

```powershell
godot --path . scenes/character_presentation.tscn
```

The collection selector filters by source pack; the counter shows the filtered position and full gallery size. Left/right arrows or Previous/Next buttons cycle through the visible characters and wrap around. Up/down arrows or the motion selector cycle through the selected model's embedded clips or the elf's baked and feminine libraries, starting in Idle whenever a character is selected. Preview clips loop and crossfade. On rigs with the Styloo arm bones, X or the T pose button toggles a T pose and resumes the selected animation when pressed again; up/down also exits the T pose. Drag with the left mouse button to turn, use the wheel to zoom, Home to reset to idle and reset the view, and Escape to close.

The tracked catalog contains project-owned and redistributable characters. If a local, licensed character bank is installed under `assets/characters/asset_bank/`, the showcase also reads its optional `presentation_catalog.local.json` overlay. Keep that directory local; it is ignored by Git, so the overlay and imported models are not included in project pushes. Some entries are static models or authoring base meshes and therefore do not offer motion clips.

The studio opens on the original costume with four hairstyles and independent hair, eye, cloth and trim colour controls. The earlier seven appearance/hair studies remain in the collection. The three generated alternative outfits have been scrapped. New garments follow the source-based [tailoring workflow](GARMENT_WORKFLOW.md), beginning with one garment and real deformation review.

Use the right-hand panel to combine parts, name the character, randomize or reset the design. **Save character** writes a local configuration under Godot's `user://characters/` and adds it to the collection. Saved characters are loaded on the next launch. Save files retain component IDs and colours; the game still uses its existing player model. Generator/source details are in `assets/characters/creator/README.md`.

The outfit selector currently contains only the original costume. Saved designs using retired outfit IDs display that costume while retaining their names, hair and colours; files are unchanged until you explicitly save another design.

Each catalog entry has:

| Field | Meaning |
| --- | --- |
| `name` | Display name |
| `scene` | `res://` GLB or `.tscn` with a Node3D root |
| `description` | Appearance/outfit notes |
| `scale` | Additional display scale, default 1; base GLB uses 0.8 |
| `yaw_degrees` | Additional facing correction, default 0 |
| `preview_height`, `preview_width` | Optional authored bounds for skinned GLTFs whose runtime mesh bounds collapse |
| `configuration` | Creator component IDs, name and hex colours; replaces the scene field for assembled characters |

Use a wrapper `.tscn` when a variant needs external material overrides or additional clothing nodes. Include them in that scene so the presentation displays the completed character. The gallery previews raw clips on the elf skeleton, without gameplay's blend tree or procedural posture/contact layers; inspect transitions, movement and winter lighting in gameplay separately.

For a deterministic screenshot, set `RUN_PRESENTATION_SHOT` to an absolute PNG path in `build/character/`, optionally set `RUN_PRESENTATION_INDEX` to a zero-based catalog index, launch the presentation scene, and restore the environment variables afterward. The scene captures after twelve frames and exits.
