# Run Away

A short third-person winter horror. You are on a ridge trail at night. Something follows the same path. The only way out is the road at the end, and the notes along the way get less safe to read.

## Approach

Ship a single tense run, not a sandbox. The packs cover the valley (alpine pines, snow, rocks, cabin, lookout) and the pages. They do not include a run cycle, so the runner and the thing chasing them share a CC0 humanoid (Quaternius, via the Godot rig pack) with idle, jog, and sprint. The hunter is that rig with the costume stripped to a silhouette and two lights for eyes. Fog, moonlight, and snowfall do more for the mood than extra geometry.

The modern house interior is a different art style and a much larger import. The alpine cabin is the shelter you already stayed in too long.

## Fantasy

You woke in a cabin you do not remember entering. Previous people left field notes. The first ones are practical. Later ones were written by someone whose hands were wrong, and the last one exists to make you stand still. The road's headlights are real. Stopping is how it catches you.

## Player loop

- Look with the mouse. Move with WASD. Shift sprints until your breath gives out.
- The hunter walks the trail at a constant pace, always forward, starting well behind you.
- A careful mix of sprint and walk reaches the road. Pure walking does not.
- Notes are optional and dangerous. Opening one freezes you. The typewriter keeps going, and so does the hunter. Later notes corrupt as they appear. You can close them early.
- Reach the headlights to escape. Let the gap close to nothing and it takes you.

## Systems

Each system is its own script and talks through the `Game` autoload, signals, and groups.

| Piece | Responsibility |
| --- | --- |
| `Tune` | Speeds, distances, timings. Balance lives here. |
| `Game` | Phase (intro, playing, reading, paused, caught, escaped) and restart. |
| `Player` | Body, camera spring, stamina, lantern, locomotion clips. |
| `Hunter` | Offset along the trail, reveal, catch. No navigation mesh. |
| `Trail` | Curve, ground, scatter, landmarks, notes, exit. |
| `PropFactory` | Loads each mesh once, assigns a winter material. |
| `FieldNote` / `NoteCatalog` | World pickups and the text, data separate from the mesh. |
| `Atmosphere` / `Snowfall` | Moon, fog, grade, snow that follows the camera. |
| `Hud` / `NoteReader` / `EndCard` | Vignette, breath, prompts, the page, the ending. |
| `Soundscape` | Wind, drone, heartbeat, footsteps. Generated tones, not licensed music. |

The trail is a `Curve3D`. Both the player and the hunter are measured by distance along it. The player can weave a few meters off the center. The hunter never pathfinds, so trees cannot trap it and the threat stays readable.

## Assets used

- Alpine mountain: pines, dead pines, snow mounds, rocks, cliff, cabin, tent, campfire, lookout, distant trees, mountains, snow textures.
- Papers, lantern, and torch from the same Synty packs.
- Quaternius CC0 rig for both bodies (locomotion the packs did not include).

## Controls

WASD move, mouse look, Shift sprint, E read or close a note, Esc pause, R restart after the ending.

## Tone targets

Night blue fog, a warm lantern, red eyes only when it is near, and no map. The UI never shows a distance number. It says when to run.
