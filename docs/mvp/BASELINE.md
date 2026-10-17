# MVP baseline (W01)

Recorded **2026-10-15** for [MASTERPLAN.md](../../MASTERPLAN.md) package W01. This records what was run and what it showed. Raw logs are in ignored `build/mvp/g0/W01/` (`data_checks.log`, `import.log`, `probes/`, `probes_isolated/`, `probes_fixed/`, `probes_plain/`).

## Environment

| Item | Value |
| --- | --- |
| Commit | `6d4f43a` plus uncommitted work (below) |
| Engine | Godot 4.7.2.stable.mono.official.ed1daf0bf (`$env:GODOT_BIN` = scoop `godot-mono.console.exe`) |
| .NET | SDK 10.0.402; `OpheliasDream.csproj` builds with 0 warnings, 0 errors |
| Machine | ThinkPad, Intel Iris Xe (driver 32.0.101.7092); lean graphics auto-selected in every headless run |
| Other load | An orphaned headless Godot test from another project (`tests/north_star_climate_test.gd`, started 10:30) used ~40 % of a core throughout. **All timings below are contaminated by it.** |

Uncommitted work at the start, owned by other sessions and not touched by W01: `README.md`, `TODO.md`, `docs/DIRECTION.md`, `docs/NARRATIVE_PRESENTATION_ATMOSPHERE_PLAN.md`, bow (`BowHoist.cs`, `player.gd`, `tools/bow_probe.gd`, `assets/props/bow/README.md`), nature (`flora.gd`, `premium_flora.gd`, `vendor_loader.gd`, `tune.gd`, `curate_nature_assets.py`, nature manifest). The index was unstaged during the session, so another session was active.

## How probes must be run

1. **Isolate user data.** Probes that instantiate `main.tscn` autosave through `RunSave` and write `settings.cfg` into the real user folder. The first W01 batch overwrote the owner's `run_save.cfg`, `.bak` and `settings.cfg`; they were restored from a SHA-256-verified backup. Run probes with a temporary root `override.cfg`:

   ```ini
   [application]
   config/use_custom_user_dir=true
   config/custom_user_dir_name="DreamFlowPlayabilityAudit"
   ```

   Delete it afterwards (it is not git-ignored). `dream_flow_probe` refuses to finish without this folder name. The sandbox is `%APPDATA%\DreamFlowPlayabilityAudit` (not under `Godot\app_userdata`); keeping it keeps a warm terrain/flora cache for later runs.
2. `dream_flow_probe` requires `RUN_DREAM_PACE=walk|sprint`; it has no default.
3. Use a timeout and read the log, not just the exit code. A GDScript assertion or parse error in a probe does not quit the process: it hangs until the timeout. `dialogue_probe`, `dream_story_probe` and `mathilda_probe` always quit 0, and before W01 `biome_snapshot_probe` printed PASS while all five fixtures had errored.
4. One Godot process at a time. Stopping a background runner from the harness did not stop its bash loop on this machine; kill bash/timeout/godot by PID and re-check the saves.

## Results

Data checks (all exit 0): Ophelia 182 lines, Mathilda 69, lake 43, doorway 41 (82 transitions, 160 paths), doorway timing matches. Voice inventory unchanged from MASTERPLAN section 3: **68 missing clips, 26 drafts**, 3 archive candidates. Headless import: exit 0, no errors, 69 s.

Probe results (isolated user data; final column is after the W01 fixture repairs, run with the documented command alone):

| Probe | First isolated run | After W01 repairs |
| --- | --- | --- |
| journal / voice | PASS (159 / 287 checks) | not rerun |
| dialogue / dream_story | PASS | not rerun |
| dream_flow walk / sprint | PASS | PASS (walk) |
| hold / carry / errand | PASS (27 / 1 / 72); historical hold failure **not reproduced** | not rerun |
| mathilda | PASS only with `RUN_MATHILDA=1` | PASS |
| meeting | **FAIL** "she starts within reach" (also hung) | PASS (after D-4 and D-11) |
| encounter (Ophelia / Mathilda) | PASS only with start-up env | PASS (both chapters) |
| ending / checkpoint | PASS (16 / 11) only with `RUN_PLAY=1` | PASS (16 / 11) |
| bow | PASS only with `RUN_PLAY=1` | not changed (file owned by bow work) |
| note_access / house_space / house_domestic / house_loft | PASS only with `RUN_PLAY=1` | PASS |
| house_sound | parse error, hung | PASS (after D-10) |
| traversal / performance / leap / leap_math / terrain / biome_effects | PASS only with `RUN_PLAY=1` | PASS (traversal reaches the lake) |
| biome / ground_material | hung (null `EditableLevel`) | PASS; ground 1368 ms with a warm cache |
| biome_snapshot | false PASS (5 fixture errors) | PASS, fixtures run (63 s) |
| flora | **FAIL** budget: 2758 ms > 2500 ms | **FAIL** budget: 2606 ms > 2500 ms (warm cache) |
| spawn (new) | n/a | PASS: Ophelia in the bedroom; Mathilda 4.5 m from her camp; doorway within reach |

Every world probe logs 13 errors from the nature vendor pack (see D-5). They are not counted as failures.

## Defects

Severity: **B** blocker, **M** major, **m** minor, **F** fixture/tooling.

| ID | Sev | Finding | Evidence / repro | Owner / package | State |
| --- | --- | --- | --- | --- | --- |
| D-1 | B | Exported builds lose the lake's line table: `export_presets.cfg` `include_filter` had no `assets/audio/voice/lake/*.json`, while `assets/dialogue/lake.json` reads `res://assets/audio/voice/lake/lines.json` | read the preset; verify in a packaged build | W17 | **fixed and verified**: a release export's `RUN_SELFCHECK` loads all nine runtime data files, the lake's included (2026-10-15, W04) |
| D-2 | M | Vendor packs can never load in an export: `VendorLoader` resolves `globalize_path("res://build/vendor/…")` and `flora.gd` checks `res://build/vendor/…`; neither exists beside an exe. Falls back silently, no crash | read `vendor_loader.gd`, `flora.gd:435,471` | W04 | **fixed** (W04): `VendorLoader.root()` is `build/vendor/` developing and `vendor/` beside the exe exported (`RUN_VENDOR=off` forces fallbacks); `flora.gd` asks the loader once per kind. A release export loads the pack from `vendor/` and falls back cleanly without it |
| D-3 | M | At W01 no errands were built: `Errands.ensure_built()` only made an empty `World` | W01 read of `errands.gd:89` | W06–W10 | **verbs, warm-house, cups and red thread done (W06–W09)**; W09 verified 2026-10-17; W10 builder remains |
| D-4 | m | `RUN_MEETING` dev hook placed Ophelia 2.37 m above the doorstep. It ran inside `MathildaPov._start()` during `main.gd`'s loading awaits, when the hidden editable snapshot's collision was still live, so `OpheliaNpc.settle()` landed on snapshot geometry. Normal play is unaffected (the return happens after loading; restores run after `apply_pending`) | `spawn_probe` with `PROBE_CHAPTER=mathilda RUN_MEETING=1`: 2.20 m across, 2.44 m below her; the same ray after loading hits ground at the doorstep height | W01 | **fixed**: the hook waits for the snapshot to be freed (`mathilda_pov.gd`) |
| D-5 | m | Nature pack log noise: `SM_MVV_Flowers_01_B_c1_LOD0.fbx` and the grass FBX reference `Flowers_Normal.png`, `Flowers_Opacity.png`, `build/vendor/Textures/T_GrassSet_B.tga`, which the curated pack lacks; FBXDocument logs errors before the loader replaces materials | any world probe log | nature work owner / W04 | open |
| D-6 | m | Probes write to the real user save (see *How probes must be run*) | first batch changed all three files | W12 / tooling | mitigated by procedure; an automatic guard is still needed |
| D-7 | M | Build-time budgets, remeasured 2026-10-15 with the orphan process stopped: ground **5.2 s cold** / 0.9 s warm (budget 3.5, documented ~3.7 fresh); flora **3.9 s cold** / 1.7 s warm (budget 2.5, documented ~2.2 fresh, ~0.15 cached). Warm passes; cold misses both. The vendor FBX parse adds ~0.26 s per launch outside the flora cache | `build/mvp/g1/W04/budget_*` | W14 | **accepted by the owner 2026-10-15** ("performance is fine"): no work planned; the cold-build budget lines in `biome_probe`/`flora_probe` may fail on a fresh cache and are not treated as regressions |
| D-8 | F | ~19 probes predate the title gate (`9b7a3fd`, 2026-10-08) and stopped at the title menu without `RUN_PLAY`/`RUN_MATHILDA`, then hung on a null `Game.trail`/`player` | first batch | W01 | **fixed**: each sets its own start-up env |
| D-9 | F | `biome`, `ground_material`, `biome_snapshot` expected `EditableLevel` inside `main.tscn`; `main.gd` loads it at runtime since `9b7a3fd` | null `set_meta`/`get_node` | W01 | **fixed**: `_editable()` helper mirrors `main.gd` |
| D-10 | F | `house_sound_probe` called `StormAudio._place_door_leak()` with 4 of 5 arguments (parse error), and opened the front door once although it is swollen shut since the chore system (`f6c236e`) | parse error; door angle 0.0° | W01 | **fixed**: passes `quiet_db` 0, clears `jam_shoves`; door swings to −96°, leak −10 dB |
| D-11 | F | `meeting_probe` waited a fixed 12 frames, shorter than loading | assertion on `_going_home` | W01 | **fixed**: waits for the doorway to be staged |
| D-12 | m | `docs/THREATS.md` is referenced by CLAUDE.md and the masterplan but does not exist (D01) | `ls` | coordinator / W17 | open |
| D-13 | M | The Esc menu drew **under** dream overlays: `PauseMenu` lived in the HUD's canvas layer 20, below `DreamInterface` 21, the speech bubble 22, dream reflection 26, `DreamJournalLayer` 28 and conversations 30. Pausing during a dream reply left the reply rows over the menu (owner-reported, seen in `build/dream/answer.png`) | `tools/dream_pause_probe.tscn` (new; `PROBE_SHOT=<png>` with a window) | W01 | **fixed**: `hud.gd` puts the menu on its own `PauseLayer` (60); probe and windowed shot pass. The reported vertical stretch of the rows did not reproduce once the layering was fixed; the rows hold 540×46 while paused |
| D-14 | m | Page pickups carry billboard labels (`page`/`note`/`record`) with `no_depth_test`, so they show through walls and doors, e.g. two labels visible from the bedroom spawn. This conflicts with the MVP's *no objective marker* boundary | `build/mvp/g0/W01/shots/ophelia.png`; `field_note.gd:51-63` | W02 | **fixed** (owner chose depth-test plus reach): labels are depth-tested and shown only within `READ_DISTANCE` in line of sight (`Aim._update_marks`, `field_note.gd`); `note_access_probe` checks wall, reach and distance |
| D-15 | m | Mathilda's opening view: green-wood card trees near the camp read as jagged shards in the dusk fog; spark particles render as squares; the top line shows controls (`Esc: return to menu . E: feed the fire`) with a stray period, against *controls are not shown on screen* | `build/mvp/g0/W01/shots/mathilda.png` | W14 | open |
| D-16 | M | Without the vendor pack (every public build) each `flowers` placement fell back to PropFactory's 0.6 x 1.2 x 0.6 m box in the green clearings; flora also asked the disk for the pack once per undergrowth candidate, and its cache did not key on the pack's presence | `tools/vendor_probe.tscn` with `RUN_VENDOR=off` | W04 | **fixed**: flowers fall back to the forest pack's grass card; availability is asked once per kind and joins the flora cache fingerprint; the probe checks no box fallback either way |
| D-17 | B | A release export with the vendor pack crashed on quit (exit 139, 2 of 2 runs): `VendorLoader`'s static caches were released after the rendering server shut down | `RUN_PLAY=1 RUN_SELFCHECK=1 OpheliasDream.exe --headless` | W04 | **fixed**: `VendorLoader.clear()` from `Game._exit_tree()`; 3 of 3 clean exits after re-export |
| D-18 | m | The release export is 1.3 GB (exe with embedded pack) plus 77 MB of .NET data | export of 2026-10-15 | W17 | open: audit what the pack carries |
| D-19 | M | No chore's `done` state was saved: after loading, a lit stove was cold, a latched window loose, a shoved front door jammed again (`RunSave` kept only the chores' voice lines) | read `run_save.gd`; `warm_house_probe` reload | W07 / W12 | **fixed 2026-10-17**: W07 saves the stove; W12 saves the window and every house door's jam and hinge state in the run and lookout checkpoint. `warm_house_probe` passed two real save/load cycles, including the latch, first shove and open door; `checkpoint_probe` passed a rebuilt lookout restart with the latch and remaining shove. Both ran with isolated user data and `RUN_VENDOR=off`. |
| D-20 | m | The woodpile (W07) and the lookout bell (W06) are hard to pick out in the fog from the path, dark against dark | `build/mvp/g2/W07/outside.png`, `build/mvp/g2/W06/lookout.png` | W14 | open (both are placed and reachable; probes check reach and position) |

## Inventories

- **Endings:** Ophelia `road` (shown as *The lake*), `prints`, `gone`, `together`, `shore` (`game.gd`); Mathilda `home`, `step`, `wait` (`mathilda_pov.gd`).
- **Dream:** branches `name`, `waiting`, `remember`, `silence`, `walk_beside`, `present_need`; outcome sections `ending`, `unresolved`, `ruptured`, plus `repair` (`assets/dialogue/dream.json`).
- **Run save:** snapshot v3 (`run_save.gd`), loads v1 (migrated), v2 and v3. Sections: `atmosphere chapter dialogue dream dream_architecture dream_mode dream_route dream_soundscape errands game house journal_ui mathilda_pov phase player reader_ui voice was_paused weather world_seed`. The `house` section is optional for older v3 saves.
- **Runtime data reads (`res://`):** `assets/dialogue/{dream,lake,meeting}.json`, `assets/errands/errands.json`, `assets/audio/voice/lines.json`, `…/mathilda/lines.json`, `…/meeting/lines.json` (via `meeting.json`), `…/lake/lines.json` (via `lake.json`, **not exported**, D-1), `assets/characters/presentation_catalog.json` (+ local asset-bank catalog). `ground.gd`/`flora.gd` fingerprint their own source with `FileAccess`; in an export with binary-token scripts the `.gd` is absent and is skipped by an existence check.

## Not done in W01

- Only capture shots, no continuous windowed tour: title, Ophelia's and Mathilda's openings (`build/mvp/g0/W01/shots/`) and the dream compositions (`tools/dream_view.tscn` into `build/dream/`) were inspected, giving D-13 to D-15. No startup or cache timings or FPS. The machine has hard-frozen under the game before; do this with `tools/run_blackbox.ps1` on an idle machine.
- No export attempt. D-1 and D-2 come from reading code and config.
- No audio listening.

## Next safe assignments (updated after W09, 2026-10-17)

- G1 foundations and G2 warm-house are complete; the current gate is G3.
- W08 two cups is complete and verified (`W08.md`), including the organic
  placement pass, vendor/fallback runs and three real save/load cycles. W09's
  thread route, keepsake exclusion and glove/camp restoration now pass the
  dedicated `tools/thread_probe.tscn`. Continue with W10 storm lamp and W11
  chapter connections, serializing shared builders and obtaining remaining
  writing approvals.
- W12's window/front-door restoration gap D-19 is fixed and probed. W14 owns D-20
  visual legibility and the remaining performance findings.
- D-1/D-2 have packaged verification from W04 and the 0.2.16.0 release.
  New W08 voice debt is six clips; the total is 74 missing and 26 drafts.
