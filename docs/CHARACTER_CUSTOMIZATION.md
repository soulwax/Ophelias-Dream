# Character customization and presentation

The reusable personal skill is `$run-away-character-customization`, installed in `~/.codex/skills/run-away-character-customization/`. Its references cover the inspected base model, eye masks, outfit modeling, skin-weight normalization, texture ownership, UVs, normal baking, and export integration.

## Browse the collection

```powershell
godot --path . scenes/character_presentation.tscn
```

Left/right arrows or Previous/Next buttons cycle through characters and wrap around. Drag with the left mouse button to turn, use the wheel to zoom, Home to reset the view, and Escape to close. Each character is framed from its mesh bounds and placed on a lit presentation platform. The scene is independent of the game's entry scene.

The catalog contains the base character plus Snowlight, Ember, and Midnight appearance studies. Add every completed edit to `assets/characters/presentation_catalog.json` so the collection retains earlier variants. Their reproducible Blender generator and provenance are described in `assets/characters/variants/README.md`.

Each catalog entry has:

| Field | Meaning |
| --- | --- |
| `name` | Display name |
| `scene` | `res://` GLB or `.tscn` with a Node3D root |
| `description` | Appearance/outfit notes |
| `scale` | Additional display scale, default 1; base GLB uses 0.8 |
| `yaw_degrees` | Additional facing correction, default 0 |

Use a wrapper `.tscn` when a variant needs external material overrides or additional clothing nodes. Include them in that scene so the presentation displays the completed character. The gallery shows static geometry; inspect movement and winter lighting in gameplay separately.

For a deterministic screenshot, set `RUN_PRESENTATION_SHOT` to an absolute PNG path in `build/character/`, optionally set `RUN_PRESENTATION_INDEX` to a zero-based catalog index, launch the presentation scene, and restore the environment variables afterward. The scene captures after twelve frames and exits.
