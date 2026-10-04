# Run Away

A short third-person winter horror game in Godot 4.7. You wake in a house,
follow a snowbound ridge toward distant headlights, and decide how long to stop
for pages that disagree with what the snow shows you.

## Play

Open the project in Godot 4.7 and run `scenes/main.tscn`, or start from the
repository root:

```powershell
godot --path .
```

Use WASD to move, the mouse to look, Shift to sprint, E to read and interact,
F or right mouse to hold your breath, Space to jump, and Ctrl or C to slide.
Esc opens controls and settings. When the run ends, R restarts it. The notes
are optional; the road is the way out.

The game uses Forward+ and Jolt physics. On constrained GPUs, set
`RUN_GRAPHICS=lean` before launching. Allow Godot to import the project on its
first run.

## Development

Gameplay systems live in `scripts/`. The entry scene is `scenes/main.tscn`;
its authored level is stored in `scenes/editable_level.scn`. See
[level editing](docs/EDITOR.md) before changing or regenerating saved scenes.
Balance values are in `scripts/tune.gd`.

The current direction and validation record are in [DIRECTION.md](docs/DIRECTION.md),
with outstanding work in [TODO.md](TODO.md). Run the sequence check with:

```powershell
godot --headless --path . tools/run_sequence_probe.tscn
```

Asset licenses and source details are kept beside the assets, including
[the elf](assets/characters/styloo_elf/README.md),
[environment assets](assets/environment/premium/README.md), and provenance
records under `assets/vendor/` and `assets/audio/`.
