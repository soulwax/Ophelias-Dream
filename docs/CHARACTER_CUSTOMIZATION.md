# Character customization and presentation

The reusable personal skill is `$run-away-character-customization`, installed in `~/.codex/skills/run-away-character-customization/`. Its references cover the inspected base model, eye masks, outfit modeling, skin-weight normalization, texture ownership, UVs, normal baking, and export integration.

## Browse the collection

```powershell
godot --path . scenes/character_presentation.tscn
```

Left/right arrows or Previous/Next buttons cycle through characters and wrap around. Up/down arrows cycle through the baked and feminine animation libraries, starting in Idle whenever a character is selected. Preview clips loop and crossfade. X toggles a T pose and resumes the selected animation when pressed again; up/down also exits the T pose. Drag with the left mouse button to turn, use the wheel to zoom, Home to reset to idle and reset the view, and Escape to close.

The catalog contains seven characters: the base, Snowlight, Ember, Midnight, Frost Bob, Ember Crown, and Midnight Braids. The last three change hair geometry, with fuller scalp volume, gathered locks, and tapered braids. Add completed edits to `assets/characters/presentation_catalog.json` to retain earlier variants. Generators, editable Blender sources and provenance are described in `assets/characters/variants/README.md` and `assets/characters/hairstyles/README.md`.

Each catalog entry has:

| Field | Meaning |
| --- | --- |
| `name` | Display name |
| `scene` | `res://` GLB or `.tscn` with a Node3D root |
| `description` | Appearance/outfit notes |
| `scale` | Additional display scale, default 1; base GLB uses 0.8 |
| `yaw_degrees` | Additional facing correction, default 0 |

Use a wrapper `.tscn` when a variant needs external material overrides or additional clothing nodes. Include them in that scene so the presentation displays the completed character. The gallery previews raw clips on the elf skeleton, without gameplay's blend tree or procedural posture/contact layers; inspect transitions, movement and winter lighting in gameplay separately.

For a deterministic screenshot, set `RUN_PRESENTATION_SHOT` to an absolute PNG path in `build/character/`, optionally set `RUN_PRESENTATION_INDEX` to a zero-based catalog index, launch the presentation scene, and restore the environment variables afterward. The scene captures after twelve frames and exits.
