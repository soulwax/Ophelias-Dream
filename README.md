# Ophelia's Dream

Ophelia's Dream is a third-person winter horror game made with Godot 4.7.2
Mono, Forward+ rendering, and Jolt physics. Its three playable perspectives
are **Dream**, **Ophelia**, and **Mathilda**. Ophelia follows Mathilda's trail
from the house to the frozen lake; Mathilda has her own afternoon and a return
to the house. The standalone dream tells a quieter, branching encounter.
There are no field threats before the MVP. The journal, places, domestic
actions, and the women's meetings carry the story.

The [MVP masterplan](MASTERPLAN.md) tracks scope, dependencies, open decisions,
and acceptance gates. It is a work plan, not a claim that the current build is
release-ready. The [story and spoken script](docs/MATHILDA_STORY.md) and
[story contract](docs/mvp/STORY_CONTRACT.md) govern narrative changes.

## Run the game

Use Godot **4.7.2 Mono** and the .NET 8 SDK. On this Windows workstation,
PowerShell's `GODOT_BIN` points to the console executable; set it explicitly if
your shell does not have it:

```powershell
$env:GODOT_BIN = 'C:\Users\soulwax\scoop\apps\godot-mono\current\godot-mono.console.exe'
dotnet build OpheliasDream.csproj
& $env:GODOT_BIN --headless --path . --import
& $env:GODOT_BIN --path .
```

Run commands from the repository root. The main scene is
[scenes/main.tscn](scenes/main.tscn); [scripts/main.gd](scripts/main.gd)
assembles most gameplay systems. The title screen offers the three modes and
Continue. The Esc menu has settings, save/load, and return to title. The game
also autosaves an active run. Saves live in Godot's `user://` location.

For a constrained GPU, set `$env:RUN_GRAPHICS = 'lean'` before launching and
remove it afterward with `Remove-Item Env:RUN_GRAPHICS`.

| Input | Action |
| --- | --- |
| WASD / left stick | Move |
| Mouse / right stick | Look |
| Shift; Alt | Sprint; walk slowly |
| Space | Jump or running leap |
| Ctrl or C | Slide while sprinting |
| E / pad X | Read or interact |
| Q or middle mouse | Look behind |
| J, Tab, or pad Y | Open the journal |
| Esc | Pause and open settings |

The journal binding can be changed in settings. Opening the journal stops
player movement while the world continues. The journal has no objective list:
its pages, smudges, and Undone entries help the player make sense of events.

## Internal tools

Start with the [internal tools guide](docs/INTERNAL_TOOLS.md) for exact commands,
inputs, output locations, and cautions. The main entry points are:

| Task | Entry point |
| --- | --- |
| Edit lines, audition voices, review clips, replace SFX, edit dream subtitles | `python tools/studio/server.py` — [Story Studio](docs/STORY_STUDIO.md) |
| Check the current voice inventory | `python tools/voice_status.py` |
| Edit level nodes and generated snapshots | Godot editor — [level editing guide](docs/EDITOR.md) |
| Audition character animations | `& $env:GODOT_BIN --path . tools/animation_workbench.tscn` — [workbench guide](docs/ANIMATION_WORKBENCH.md) |
| Inspect terrain, camp, lake, or dream | `tools/*_view.tscn` — captures under `build/` |
| Verify a feature | Focused `tools/*_probe.tscn` scene — [probe map](docs/INTERNAL_TOOLS.md#probes-and-captures) |
| Produce a Windows candidate | `./tools/export_release.ps1` — [release workflow](docs/INTERNAL_TOOLS.md#release-candidate) |

Story Studio runs locally in a browser. Its voice experiments render to ignored
scratch files; generating a take does not replace a game clip. Qwen and
Chatterbox auditions require their own downloaded weights, CUDA runtimes, and
approved character references. The [voice guide](docs/VOICE.md) covers setup
and the production bake. Do not run `tools/bake_voice.py`; it uses an obsolete
format.

## Working in this repository

| Path | Responsibility |
| --- | --- |
| [scripts/game/](scripts/game/) | Run state, settings, save/load, phases, and input |
| [scripts/player/](scripts/player/) | Movement, camera, interaction, and voice playback |
| [scripts/world/](scripts/world/) | Terrain, trail, lake, camp, dream, and weather-facing world systems |
| [scripts/house/](scripts/house/) and [scripts/errands/](scripts/errands/) | House spaces, chores, and optional domestic activities |
| [scripts/notes/](scripts/notes/) and [scripts/ui/](scripts/ui/) | Page catalogue, journal, menus, and HUD |
| [assets/dialogue/](assets/dialogue/) and [assets/audio/voice/](assets/audio/voice/) | Runtime dialogue and reviewed voice data |
| [tools/](tools/) and [docs/](docs/) | Authoring, diagnostics, plans, and contracts |

Most gameplay nodes are built in code. The editable scene snapshots under
`scenes/generated/` can contain hand changes; read the
[level editing guide](docs/EDITOR.md) before rebuilding them. Story text is
spread across several scripts of record: use [Story Studio](docs/STORY_STUDIO.md)
or the [internal tools guide](docs/INTERNAL_TOOLS.md#story-and-audio-authoring)
to find the right source before editing generated JSON or audio.

## Assets and distribution

The owner's asset bank supplies optional realistic environment props. Local
proprietary packs belong in ignored `build/vendor/`; the game has fallbacks when
they are absent. Asset manifests in `docs/` record provenance. Do not commit
`.godot/`, `build/`, local model weights, `godot.gdkey`, or scratch captures.

The MVP distribution target remains **non-commercial** while active animation
and third-party asset rights are audited ([masterplan decision D04](MASTERPLAN.md#decisions-and-contradictions-to-close-at-g0)). A code licence or a newly
created animation does not establish rights for every bundled asset. Check
each asset's provenance before packaging or redistributing it.
