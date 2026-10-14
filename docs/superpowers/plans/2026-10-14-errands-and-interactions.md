# Errands and Environment Interactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task by task (superpowers:executing-plans if subagents are unavailable). Steps use checkbox (`- [ ]`) syntax for tracking. Read **Running this plan with subagents** before dispatching anything.

**Goal:** Ophelia's chapter gets four errands (quests that live in her journal, never on the HUD) and seven new ways to touch the world: carry, place, hold to do, open and look inside, knock snow down, warm her hands, ring the bell.

**Architecture:**
- Two small generic frameworks extend the existing interactable contract (`interact_label/interact_point/interact/aim_box`, group `interactables`, picked by `Player.aim`): *hold to do* (an optional `interact_hold_seconds()`) and *carry* (`Carryable`, `CarrySocket`, `Player.carrying`, the `drop` action, and a C# `CarryHold` skeleton modifier for the arms).
- An `Errands` node (GDScript, event driven) owns errand state from data in `assets/errands/errands.json`, listens to `Game` signals, writes the journal's *Undone* list, and saves through `RunSave` and `Game.checkpoint`.
- `main.gd` adds `Errands` after `Lake`. It builds its world pieces deferred, after the editable-level snapshot is applied, under its own root, never as children of `House` or `Trail`, so saved snapshots still line up.
- Props come from the owner's asset bank through `tools/curate_errand_assets.py`, into `build/vendor/requested_errands/` (git-ignored and `.gdignore`-d, so never imported), loaded at runtime by `VendorLoader` (T5b), with built fallbacks.

**Tech stack:** Godot 4.7.2 mono (`godot-mono`), GDScript, C# (.NET 8) for the per-frame arm pose, Python 3 + Pillow for curation, ffmpeg for the sounds.

**Spec:** `docs/superpowers/specs/2026-10-14-errands-and-interactions-design.md`

---

## Running this plan with subagents

The controller (the session that holds this plan) never writes feature code. For each task it dispatches a fresh implementer, has a fresh reviewer check the result, runs the task's verification itself, and only then ticks the boxes.

### The loop, per task

1. **Dispatch the implementer** (general-purpose agent, foreground) with the prompt template below, filled in with the task's full text. Subagents do not see this conversation, the controller's memory, or the other tasks. Everything they need goes in the prompt.
2. **The implementer** reads `CLAUDE.md` and the files listed under the task, implements it, runs the task's *Verify* commands, and reports: files changed, verification output (last 30 lines of each command), and anything it could not do. It does not start the next task.
3. **Dispatch the reviewer** (a fresh general-purpose agent) with the task text, the spec, and `git diff` of the task. It checks two things in order:
   - *Spec compliance*: every step done, interfaces exactly as named (later tasks depend on the names), nothing extra.
   - *Code quality*: the review checklist below.
   It returns findings ranked by severity, or "clean".
4. **Fix loop:** for any finding marked must-fix, send it back to a new implementer with the reviewer's text; at most two rounds, then stop and ask the user.
5. **The controller runs the task's Verify commands** itself (one Godot process at a time), reads the output, and ticks the boxes. A task is done only when its probe prints its final `PASS` line and exits 0.

### Hard rules for every subagent (paste into each prompt)

- Read `CLAUDE.md` first; where docs and code disagree, trust the code.
- **One Godot process at a time.** Never run Godot in parallel with another agent: the `.godot/` import cache is shared, and this ThinkPad (Iris Xe) hard-freezes under load. Run headless unless the task says *needs a window*; only the controller runs windowed captures.
- After adding a `class_name` script, run `godot-mono --headless --path . --import` before any headless run. After changing C#, run `dotnet build OpheliasDream.csproj` first.
- **Assets come from the owner's bank first**: `C:\Users\soulwax\OneDrive - Biz\Desktop\Assets`, through `tools/curate_errand_assets.py` only. Never copy bank files by hand, never commit bank assets, and keep proprietary ones in `build/vendor/requested_errands/` (load them with `VendorLoader`, never `load("res://build/...")`: `build/` is not imported), and never scan the whole bank recursively (OneDrive is slow); use the exact paths in Task 1.
- Do not rebuild the editable level (`scenes/editable_level.scn`, `scenes/generated/`), change voice-bake thresholds, bake voices on this machine, or commit. Stop and report if a step seems to need one of these.
- Balance values go in `Tune` under the task's prefix. Input actions go in `Game._bind()` and `Settings.ACTIONS`. New sounds get an SPL constant in `Loudness`.
- Match the surrounding code: tabs, static typing, `class_name` on every new script (the dream's preloaded scripts are an exception, not a pattern), comment density like the file you are in.

### Implementer prompt template

```
You are implementing Task <N> of docs/superpowers/plans/2026-10-14-errands-and-interactions.md
in the Godot project at C:\Users\soulwax\Workspace\Godot\run. The design is
docs/superpowers/specs/2026-10-14-errands-and-interactions-design.md.

Hard rules: <paste "Hard rules for every subagent">

Interfaces you may rely on (already built by earlier tasks): <paste the
"Produces" lines of every earlier task this one consumes>

Your task, verbatim: <paste the whole task section>

When done, reply with: files created/modified; the last 30 lines of each
Verify command's output; any step you skipped and why. Do not start any
other task. Do not commit.
```

### Reviewer checklist (code quality)

- The interactable contract is kept: anything that can be aimed at returns `aim_box()` as `[global transform, local AABB]` and leaves the `interactables` group when it has nothing left to offer.
- Errands, carry and the verbs are gated with `not Game.dream_mode and not Game.mathilda_pov` wherever they could leak into another mode.
- No HUD objective, marker, count or distance anywhere. *Undone* prose never contains a number.
- Nothing new is added as a child of `House` or `Trail` (it would shift the editable level's child order).
- Every state that changes in play is saved (`RunSave._capture_game`/`_apply_game` or an `Errands.capture/restore`), and checkpoint-kept where the spec says so.
- Per-frame work stays out of GDScript hot paths: the arm pose is C# (`CarryHold`); `Errands` reacts to signals and never polls every frame.
- Sounds are positional `AudioStreamPlayer3D`s on a named bus with `Loudness.sound(...)`, never a hand-set `volume_db`.
- Missing vendor assets fall back to built shapes without errors or warnings.

### Order and parallelism

```
T0 baseline
T1 assets (Python only) ─────────────┐
T2 tune + drop action ──┐            │
T3 hold-to-do ──────────┤            │
T4 carry (+ C#) ────────┼─ T5 errands core ─ T5b loader ─ T6 verbs ─┬─ T7 warm_house ─ T8 two_cups
                        │                              ├─ T9 red_thread
                        │                              └─ T10 light_for_dark
T11 voice lines (docs + Python) ── after T5 ─────────────────────────────────┐
                                                                    T12 integration
```

- **Parallel-safe** (no Godot runs, separate files): T1 and T11's writing step may run beside any one Godot task. Run T1 in the background while T2–T4 go one by one.
- Everything else runs **in order, one at a time**, in the main checkout.
- **No worktrees.** The ignored `assets/vendor/requested_*` folders and the `.godot/` cache are not in a fresh worktree, so imports and fallbacks would behave differently from the real checkout.

### When to stop and ask the user

- A task would need an editable-level rebuild, a change to an existing ending, or a HUD element showing progress.
- An asset named in Task 1 is missing from the bank or looks wrong in the contact sheet (T12): ask before substituting a different pack.
- Voice: the new lines need baking on the RTX desktop (T11 records them as owed; it does not bake).
- Any commit. The user commits, or asks for one in a single plain sentence.

---

## Global constraints

- Godot 4.7.2 mono; GDScript with tabs and static typing; one `[GlobalClass] partial class` per C# file.
- Errands and verbs exist only in Ophelia's chapter (`not Game.mathilda_pov and not Game.dream_mode`). Bell, snow branches and brushing can stay in Mathilda's chapter only if trivially safe; otherwise they are gated too.
- Nothing is required: the lake ending (`LAKE_PAGES`), the meeting on the ice (`Game.meeting_ready()`), turning around and the day limit behave exactly as before. `tools/ending_probe.tscn`, `tools/checkpoint_probe.tscn` and `tools/journal_probe.tscn` must still pass unchanged after every task.
- `Tune` prefixes: `CARRY_*`, `HOLD_*`, `ERRAND_*`, `LAMP_*`, `WARM_*`, `SNOW_BRANCH_*`, `BELL_*`.
- Dev hook: `RUN_ERRAND=<id>[:<step>]` starts an errand already known (or at a step) for captures and probes.
- **Probes need `RUN_PLAY=1`.** Since the title menu, `main.gd` returns early (menu only) unless a story is chosen, so the older probes hang or fail without it (found in T0). Run every existing probe as `$env:RUN_PLAY="1"; godot-mono --headless --path . tools/<probe>.tscn` (Git Bash: `RUN_PLAY=1 godot-mono ...`). New probes call `OS.set_environment("RUN_PLAY", "1")` in `_ready()` before instancing `main.tscn`, so they work either way.
- Probes copy `tools/checkpoint_probe.gd`: `_check(ok, what)` prints `PASS`/`FAIL`, a final `<NAME> PASS|FAIL (n)` line, and `get_tree().quit(0 if _failures == 0 else 1)`. Never bare `assert()`. Each new probe gets a `.tscn` with only the root `Node` and the script.

## Review focus (pinned risks)

1. **Editable level drift.** Adding children under `House`/`Trail` would misalign saved snapshots. Pinned in T5: `errand_probe` checks `House` and `Trail` child counts are unchanged from a run without `Errands`.
2. **Carry vs. other hand states.** Bow drawn, reading, journal, slide, leap, ladder-free stairs, door assist. Pinned in T4: `carry_probe` cases `_bow_blocks_carry`, `_read_keeps_item`, `_heavy_no_sprint`, `_light_runs`.
3. **Save round trip.** A carried item, a socketed item, a half-done hold, a brushed sign and an errand step survive `RunSave.save_now()` → reload, and the checkpoint. Pinned in T12: `errand_save_probe`.
4. **No counters.** The *Undone* text never contains a digit. Pinned in T5.
5. **Mode leaks.** Nothing errand-related is built in the dream or Mathilda's chapter. Pinned in T5 and T12 with `Game.dream_mode`/`mathilda_pov` runs.
6. **Endings untouched.** T12 reruns `ending_probe`, `checkpoint_probe`, `meeting_probe`, `journal_probe`, `voice_probe`.

---

### Task 0: Baseline (controller, no subagent)

- [ ] `dotnet build OpheliasDream.csproj` and `godot-mono --headless --path . --import`.
- [ ] Run and save the output of: `journal_probe`, `voice_probe`, `ending_probe`, `checkpoint_probe`, `meeting_probe`, `house_space_probe`, `note_access_probe`, `bow_probe` (all `tools/<name>.tscn`, headless) into `build/errands/baseline/<probe>.txt`. Any probe already failing is noted in the plan's checklist as *pre-existing* and is not a regression.
- [ ] Confirm the bank is reachable: `Test-Path "C:\Users\soulwax\OneDrive - Biz\Desktop\Assets\CarpentersWorkshopForward"`.

---

### Task 1: Curate the errand assets (parallel-safe, Python only)

**Files:**
- Create: `tools/curate_errand_assets.py`, `docs/errands/requested_errands_manifest.json` (written by the script), `docs/errands/README.md`
- Create: `tools/make_errand_sounds.py`, `assets/audio/errands/*.wav` (committed, CC0)
- Modify: `.gitignore` (add `/build/vendor/requested_errands/`), `assets/audio/provenance.json`

**Produces:**
- `build/vendor/requested_errands/leartes/<SM_Name>.gltf|.bin|_{B,N,ORM}.png` for: `SM_Crate`, `SM_Chest_01`, `SM_Firewood`, `SM_Cup`, `SM_Jar`, `SM_Bucket`, `SM_Tin_03`, `SM_Bottle`, `SM_Sign`, `SM_Bench`, `SM_Hook`, `SM_Rope_02`, `SM_Rope_03`, `SM_Cuboard_Small`.
- `build/vendor/requested_errands/ww2_lamp/SM_WW2_Lamp_c1_LOD0.fbx` + `T_WW2_Lamp_2048_{B,N,ORM}.png`.
- `assets/vendor/polyhaven/wooden_lantern_01/` (CC0, committed, provenance added).
- `assets/audio/errands/{bell,wood_drop_*,wood_stack_*,tin_*,cup_*,cupboard_open_*,cupboard_close_*,latch,kettle,cloth_*,snow_dump_*}.wav`.

**Bank paths** (root `C:\Users\soulwax\OneDrive - Biz\Desktop\Assets`):
- Leartes: `CarpentersWorkshopForward/Carpenters_Workshop_Forward/Assets/LeartesStudios/CarpentersWorkshop/Art/{Meshes,Textures}` (same as `tools/curate_camp_assets.py`'s `LEARTES`).
- WW2 lamp: `WW2_Lamp_f0243220/WW2_Lamp/Unity/Rocket/WW2_Lamp/HDRP/SM_WW2_Lamp_c1_LOD0.fbx` and `.../WW2_Lamp/Textures/T_WW2_Lamp_2048_{B,OpenGL_N,AO,MS}.png`.
- Poly Haven: `wooden_lantern_01_2k.gltf.zip`.
- Kenney audio (CC0, `License.txt` beside each): `Kenney Game Assets All-in-1 3.7.0/Audio/Impact Sounds/Audio/` (`impactBell_heavy_*`, `impactWood_*`, `impactPlank_medium_*`, `impactTin_medium_*`, `impactGlass_light_*`, `impactSoft_*`) and `.../Audio/RPG Audio/Audio/` (`chop*`, `cloth*`, `creak*`, `doorOpen_*`, `doorClose_*`, `metalLatch*`, `metalPot*`).

- [ ] **Step 1:** Write `curate_errand_assets.py` by copying the structure of `tools/curate_camp_assets.py` (same `BANK` default and argv override, sha256 manifest with `source`, `sha256`, `to`; TGA→PNG via Pillow; the WW2 ORM packing from its `SCANS` branch: R = AO, G = 1 − smoothness from `MS` alpha, B = metal). Missing files print `missing <name>` and are skipped, never fatal. The docstring says why the folder is ignored (no verified redistribution right).
- [ ] **Step 2:** Unzip `wooden_lantern_01_2k.gltf.zip` into `assets/vendor/polyhaven/wooden_lantern_01/` (CC0) and add its entry to `assets/vendor/polyhaven/provenance.json` in that file's existing shape.
- [ ] **Step 3:** `make_errand_sounds.py`: read the Kenney OGGs with ffmpeg, trim silence, level impacts to −12 dBFS peak and the kettle loop to −20 dBFS RMS (as `make_soundscape.py` does), write mono 44.1 kHz WAVs, and append credits to `assets/audio/provenance.json` (source pack, file, licence CC0, `kenney.nl`).
- [ ] **Step 4:** `docs/errands/README.md`: what each asset is for, and the commands below.

**Verify:**
```powershell
python tools/curate_errand_assets.py
python tools/make_errand_sounds.py
python -c "import json;d=json.load(open('docs/errands/requested_errands_manifest.json'));print(len(d['sources']) if isinstance(d,dict) else len(d))"
git status --short assets/vendor   # must show nothing under requested_errands
```
**Done when:** every listed mesh has a gltf+bin and its textures, or a `missing` line the controller has accepted; the WAVs exist; nothing under `requested_errands` is tracked. The `--import` runs in T2, not here (no Godot in a parallel-safe task).

---

### Task 2: Tuning and the `drop` action

**Files:** Modify `scripts/tune.gd`, `scripts/game/game.gd`, `scripts/game/settings.gd`, `scripts/audio/loudness.gd`.

**Produces:**
- `Tune`: `CARRY_HEAVY_SPEED := 2.6`, `CARRY_LIGHT_SPEED_SCALE := 0.92`, `CARRY_DROP_AHEAD := 0.55`, `CARRY_PICK_SECONDS := 0.45`, `HOLD_DEFAULT := 1.2`, `HOLD_FORGET := 3.0`, `ERRAND_WOOD_ARMFULS := 3`, `ERRAND_THREAD_SNAGS := 5`, `LAMP_HOURS := 9.0`, `LAMP_RANGE := 7.0`, `LAMP_ENERGY := 1.6`, `WARM_SECONDS := 2.5`, `WARM_QUIET := 240.0`, `SNOW_BRANCH_REFILL := 600.0`, `BELL_ECHO_DELAY := 1.4`, `BELL_ECHO_CHANCE := 1.0`.
- Input action `drop`: `KEY_Z` and pad `JOY_BUTTON_DPAD_DOWN`, in `Game._bind()`/`_bind_pad()`, and `["drop", "Set down what you carry"]` in `Settings.ACTIONS`.
- `Loudness`: `BELL`, `WOOD_DROP`, `TIN`, `CUP`, `CUPBOARD`, `LATCH`, `KETTLE`, `CLOTH`, `SNOW_DUMP` SPL constants (dB at 1 m, chosen against the existing `CAMPFIRE`/door values).

- [ ] **Step 1:** Add the constants with one comment line per group, in the file's style.
- [ ] **Step 2:** Bind `drop` (key + pad), add it to `Settings.ACTIONS` so it shows on the Keys page and can be rebound.
- [ ] **Step 3:** Add the SPL constants.

**Verify:** `godot-mono --headless --path . --import`, then `journal_probe` and `voice_probe` (unchanged), then `$env:RUN_MENU="keys"; $env:RUN_CAPTURE="1"; $env:RUN_SHOT="$PWD\build\errands\keys.png"; godot-mono --path .` (controller only, needs a window) and look for the new row. Clear the env vars afterwards.

---

### Task 3: Hold to do

**Files:** Modify `scripts/player/player.gd` (`_try_interact` and its caller), `scripts/player/aim.gd` (only if the target must expose hold), `scripts/ui/hud.gd` (`_refresh_reticle`). Create `tools/hold_probe.gd` + `.tscn`.

**Produces:**
- Optional interactable methods: `interact_hold_seconds() -> float` (absent or `0` = instant, as now) and `interact_hold_progress(fraction: float) -> void` (for effects while holding).
- `Player.hold_target: Node3D`, `Player.hold_progress: float` (0..1). Progress is kept per target for `Tune.HOLD_FORGET` seconds after release, then forgotten.
- HUD: a thin ring around the reticle filling with `hold_progress`, bone colour, no number.

- [ ] **Step 1:** In `Player`, when `interact` is pressed on `aim.target` whose `interact_hold_seconds() > 0`, start holding; each physics tick while held and the same target is aimed and in reach, add `delta / seconds`; at 1, call `interact()` once and clear. Moving out of reach, aiming away or releasing pauses it. The interact buffer (`INTERACT_BUFFER`) still applies to instant interactions only.
- [ ] **Step 2:** HUD ring in `_refresh_reticle`.
- [ ] **Step 3:** `hold_probe`: build `main.tscn`, spawn a test interactable in front of her with `interact_hold_seconds() == 1.0`, inject `interact` presses with `Input.action_press`/`action_release`, and check: `_instant_unchanged` (a door still opens on a tap), `_hold_completes` (held 1.1 s → `interact()` called once), `_release_pauses` (0.5 s, release, 1 s wait, 0.6 s more → completes), `_forget` (0.5 s, release, wait `HOLD_FORGET + 0.5` → progress 0), `_reading_blocks` (no progress while `READING`).

**Verify:** `--import`; `godot-mono --headless --path . tools/hold_probe.tscn` → `HOLD PASS`; `note_access_probe` and `house_space_probe` unchanged.

---

### Task 4: Carry and place

**Files:**
- Create: `scripts/player/carryable.gd` (`class_name Carryable`), `scripts/player/carry_socket.gd` (`class_name CarrySocket`), `scripts/player/CarryHold.cs` (`[GlobalClass] public partial class CarryHold : SkeletonModifier3D`), `tools/carry_probe.gd` + `.tscn`.
- Modify: `scripts/player/player.gd`, `scripts/player/stride.gd` (only if the arm pose needs a blend), `scripts/game/run_save.gd` (carried item).

**Produces:**
- `Carryable extends Node3D`: `@export var kind: String` (e.g. `"firewood"`, `"cup"`, `"oil"`, `"lamp"`), `@export var heavy: bool`, `@export var item_id: String` (unique, for saving), `visual: Node3D`, signals `picked`, `placed(socket: CarrySocket)`, `dropped`. It is an interactable ("Pick up the <noun>") while on the ground or in a socket that allows taking.
- `CarrySocket extends Node3D`: `@export var accepts: PackedStringArray`, `@export var capacity: int = 1`, `@export var socket_id: String`, `@export var allow_take := true`, `held: Array[Carryable]`, signal `filled(item: Carryable)`. Interactable only while she carries an accepted kind and it has room ("Put the <noun> here").
- `Player.carrying: Carryable` (null when empty), `Player.pick_up(item) -> bool`, `Player.place(socket) -> bool`, `Player.drop_carried() -> bool`. Heavy: no sprint, leap or slide, speed capped at `CARRY_HEAVY_SPEED`. Light: `CARRY_LIGHT_SPEED_SCALE`. Cannot pick up while the bow is drawn; drawing the bow while carrying first sets the item down.
- `CarryHold` (C#, added after `BowHoist` in the modifier chain, same technique: local rotations conjugated through parents, as `GraceMotion`/`BowHoist` do): two poses, `armful` (both forearms forward and in, elbows bent) and `hand` (right hand low and forward for the lamp, cup or tin). It reads `Player.carrying` through a property the Player sets (`Pose`, `Weight` 0..1), eases in over `CARRY_PICK_SECONDS`, and exposes the hand socket transform so the item's visual follows the hand every frame. The item visual is reparented under the player's model, not a `BoneAttachment3D` (those miss modifier output; see CLAUDE.md *Player model*).
- Saved: `RunSave` stores `carrying_item_id`; Errands (T5) restores the node.

- [ ] **Step 1:** `Carryable`/`CarrySocket` with the contract above and `aim_box()`.
- [ ] **Step 2:** `Player` carry state, movement limits in the existing speed/steer code (`_steer`, the sprint gate, the leap/slide gates), and the `drop` action: set the item on the ground `CARRY_DROP_AHEAD` in front of her via `trail.on_ground()`, or on the floor when `Game.indoors()`. Pad d-pad down fires both `drop` and Godot's `ui_down`, which `Conversation`, `DialogueBubble` and `DreamExperience` use to move their choice cursor (found in T2), so `drop` only acts when `Game.phase == PLAYING` and `not Game.locks_movement()`.
- [ ] **Step 3:** `CarryHold.cs`, built like `BowHoist.cs` (read it first); `dotnet build OpheliasDream.csproj`.
- [ ] **Step 4:** `carry_probe`: `_pick_and_drop`, `_socket_accepts_kind` (a cup is refused by a woodbox), `_socket_capacity`, `_heavy_no_sprint` (sprint held for 2 s at most `CARRY_HEAVY_SPEED + 0.05`), `_heavy_no_leap`, `_light_runs` (lamp: sprint allowed), `_bow_blocks_carry`, `_read_keeps_item` (open and close a page: still carrying), `_indoors_drop_on_floor`, `_hand_follows` (with `CarryHold` on, the item's global position is within 0.15 m of the right hand bone after 30 frames of walking).

**Verify:** `dotnet build OpheliasDream.csproj`; `--import`; `carry_probe` → `CARRY PASS`; `leap_probe`, `bow_probe`, `traversal_probe` unchanged.

---

### Task 5: The errands core

**Files:**
- Create: `scripts/errands/errands.gd` (`class_name Errands`), `scripts/errands/errand.gd` (`class_name Errand`, RefCounted), `assets/errands/errands.json`, `tools/errand_probe.gd` + `.tscn`.
- Modify: `scripts/main.gd` (add `Errands` after `Lake`), `scripts/game/game.gd` (`var errands: Errands`, signal `errand_changed(id: String)`, `reset()` clears), `scripts/ui/journal.gd` (*Undone* list), `scripts/game/run_save.gd`, `Game.reach_checkpoint()`/`resume_checkpoint()`.

**Produces:**
- `errands.json`: `{"version": 1, "errands": [{"id", "steps": [{"id", "undone": "<prose>"}], "done": "<prose>", "let_go": "<prose>", "requires": [<errand ids>]}]}`. Prose has no digits.
- `Errand`: `id`, `state` (`UNKNOWN`, `KNOWN`, `DONE`, `LET_GO`), `step: int`, `flags: Dictionary`, `undone_text() -> String`.
- `Errands extends Node3D`: registers `Game.errands = self` in `_ready()`, builds nothing if `Game.dream_mode or Game.mathilda_pov` (and frees itself). API: `learn(id)`, `advance(id, step_id)`, `finish(id)`, `let_go(id)`, `state_of(id)`, `is_done(id)`, `world_root() -> Node3D` (its own child `World`, built deferred: `call_deferred` after `main.gd`'s snapshot apply, as `Camp` does), `capture() -> Dictionary`, `restore(data)`. Emits `Game.errand_changed`. On `Game.turned` or `mathilda_gone`, every known errand is let go.
- Journal: an *Undone* section after the pages, listing known errands' `undone_text()`, done ones struck through with their `done` prose; nothing for unknown ones. If none are known, the section is absent.
- Saving: `RunSave` gets `"errands": Game.errands.capture()`; `_apply` calls `restore`; checkpoint keeps the same dictionary.
- Dev hook `RUN_ERRAND=<id>[:<step>]`.

- [ ] **Step 1:** Data and classes; seed `errands.json` with the four errands from the spec (prose drafted from the spec's table, in Ophelia's voice, short).
- [ ] **Step 2:** `main.gd` wiring (after `add_child(Lake.new())`), `Game` field and signal, reset.
- [ ] **Step 3:** Journal section (copy the journal's existing entry styling; read `journal.gd` first).
- [ ] **Step 4:** Save and checkpoint.
- [ ] **Step 5:** `errand_probe`: `_learn_advance_finish`, `_requires` (`two_cups` cannot finish before `warm_house`), `_let_go_on_turn`, `_no_digits` (every prose string in the JSON and every `undone_text()`), `_journal_lists_known_only`, `_dream_builds_nothing` (`Game.dream_mode = true` → no `Errands` node, `House`/`Trail` child counts equal to a plain run), `_mathilda_builds_nothing`, `_child_counts_unchanged` (a normal run: `House` and `Trail` child counts equal to a run with `Errands` removed), `_checkpoint_keeps`.

**Verify:** `--import`; `errand_probe` → `ERRAND PASS`; `journal_probe`, `checkpoint_probe`, `ending_probe` unchanged; `RUN_JOURNAL` capture with `RUN_ERRAND=red_thread` (controller, window) to see the section.

---

### Task 5b: VendorLoader (runtime loading of proprietary assets)

Added 2026-10-15: the owner keeps proprietary assets in the git-ignored `build/` folder, which has a `.gdignore`, so Godot never imports them.

**Files:** Create `scripts/world/vendor_loader.gd` (`class_name VendorLoader`, static), `tools/vendor_loader_probe.gd` + `.tscn`. Move the curated files from `assets/vendor/requested_errands/` to `build/vendor/requested_errands/` (re-run `python tools/curate_errand_assets.py`, which now writes there), then delete `assets/vendor/requested_errands/` and its `.import` files.

**Produces:**
- `VendorLoader.ROOT := "res://build/vendor"`, resolved with `ProjectSettings.globalize_path` (and, in an exported game, a `vendor/` folder beside the executable: `OS.get_executable_path().get_base_dir()`).
- `VendorLoader.scene(rel: String) -> Node3D`: loads `.gltf`/`.glb` through `GLTFDocument.append_from_file` + `generate_scene`, `.fbx` through `FBXDocument` (cm → m: scale 0.01 when the FBX's unit scale says centimetres; check how `Camp._bank_scan` treats the WW2 note). Hides `_LOD1..3` and `_ConvexHulls` meshes (Leartes). Returns null when the file is missing, without an error (one `print` line under `RUN_BLACKBOX` at most). Caches the generated scene per path (keep the root as a template and return `duplicate()`), so each mesh is parsed once per run.
- `VendorLoader.texture(rel: String, srgb := true) -> Texture2D`: `Image.load_from_file` → `ImageTexture` (mipmaps generated), cached; null when missing.
- `VendorLoader.leartes(name: String, area := "requested_errands") -> Node3D`: the LOD0 mesh with an override `StandardMaterial3D` per surface built from the set's `_B`/`_N`/`_ORM` PNGs (ORM: R occlusion, G roughness, B metal), as `Camp._orm_from` does. `SM_Jar` and `SM_Bottle` carry a material without textures: give it a glass-ish fallback.
- `VendorLoader.available(rel) -> bool`.

- [ ] **Step 1:** Write the loader; read `scripts/world/camp.gd`'s Leartes and scan loading first and mirror its materials.
- [ ] **Step 2:** Move the files (script re-run), delete the old folder, `--import` so Godot drops the stale imports.
- [ ] **Step 3:** Probe: `_loads_gltf` (`SM_Crate` returns a Node3D with one visible mesh and a non-empty AABB), `_loads_fbx_lamp` (height between 0.2 and 0.6 m), `_textures`, `_cache` (second call is fast and a distinct instance), `_missing_is_null` (no error), `_not_imported` (`ResourceLoader.exists("res://build/vendor/requested_errands/leartes/SM_Crate.gltf")` is false). If `build/vendor/requested_errands/` is absent the probe prints SKIP for the asset cases and still passes `_missing_is_null`.

**Verify:** `--import`; `vendor_loader_probe` → `VENDOR PASS`; `git status` shows nothing under `build/` or `assets/vendor/requested_errands/`.

---

### Task 6: The verbs

**Files:** Create `scripts/errands/house_drawer.gd` (`HouseDrawer`), `snow_branch.gd` (`SnowBranch`), `brushable.gd` (`Brushable`), `warm_spot.gd` (`WarmSpot`), `bell.gd` (`Bell`), `tools/verbs_probe.gd` + `.tscn`. Modify `scripts/errands/errands.gd` (builds them under `world_root()`), `scripts/audio/wildlife.gd` (add a public `flump(at: Vector3)` that wraps its existing `_shot("flump", at, Loudness.SNOW_FLUMP, ...)`, and register `Game.wildlife = self` in `_ready()` with a `var wildlife: Wildlife` on `Game`).

**Produces:**
- `HouseDrawer`: hinge or slide, `open`/`close` tweened, sounds `cupboard_open/close`, optional `contents: Carryable` revealed when open. Interactable label "Open the cupboard" / "Close the cupboard".
- `Brushable`: hold to do (`HOLD_DEFAULT`), swaps a snow-capped material/decal for the clean one, then `Game.visit(place_key)` or `Game.heard(event_key)` from its export. Stays brushed (saved by id).
- `SnowBranch`: low branch dressing at a pine from `Flora.nearest_indices`; interact or `receive_arrow(at, velocity)` drops a `SnowKick`-style puff and calls `Game.wildlife.flump(at)` (so it does not need the new `SNOW_DUMP` sound unless the flump set is missing); refills after `SNOW_BRANCH_REFILL`; can carry a thread snag (T9).
- `WarmSpot`: at the lit stove and the camp fire; hold `WARM_SECONDS` → `Crouch_Idle` pose through `Stride`'s slide layer or a OneShot (whichever `Stride` exposes; read it first), quiets `Voice` cold lines for `WARM_QUIET` seconds (`Voice` gets `warm_until: float`), and slows `Breath`.
- `Bell`: on the lookout rail near `Lake`'s lanterns; rings (`BELL` SPL, long tail, heard far), and after `BELL_ECHO_DELAY` an answer in her voice from the farthest tree in the bell's facing (same path as `Voice` answers; line id `bell_here`, T11). Once per visit to the lookout.
- Placement: every verb is built by `Errands` in world coordinates derived from `Game.trail` (`house.transform`, `exit_point`, `on_ground`), never as a House/Trail child. House-interior pieces use `trail.house.to_global(local)`.

- [ ] **Step 1–5:** one step per verb, each with its fallback mesh when its vendor asset is missing.
- [ ] **Step 6:** `verbs_probe`: one case per verb (state change, sound player created on the right bus, saved by id), plus `_arrow_knocks_snow` (instance `res://scripts/world/arrow_projectile.gd`, which has no `class_name`, aimed at a `SnowBranch`) and `_bell_answers_once`.

**Verify:** `--import`; `verbs_probe` → `VERBS PASS`; `house_space_probe`, `house_sound_probe`, `note_access_probe` unchanged (new cupboards must not block page reach or walkways).

---

### Task 7: `warm_house`

**Files:** Modify `scripts/house/domestic.gd` (the stove chore checks `Game.errands` before lighting), `scripts/errands/errands.gd` (woodpile, woodbox socket, armful carryables). Create `tools/warm_house_probe.gd` + `.tscn`.

- [ ] **Step 1:** Stove chore: when `Game.errands` exists and `warm_house` is not done, interacting with an empty woodbox's stove says "No wood in the box" (`interaction_feedback`, false) and `learn("warm_house")`. With `Game.errands` absent (Mathilda, dream), the chore works as today.
- [ ] **Step 2:** Woodpile under the eaves (Leartes `SM_Firewood` stack; outside the house walls, on the house pad), a heavy `Carryable` armful that respawns from the pile while the box needs more, a `CarrySocket` woodbox by the stove (`SM_Crate`), capacity `ERRAND_WOOD_ARMFULS`, each arrival stacking a visible log mesh and a `wood_stack` sound.
- [ ] **Step 3:** Full box → the stove chore lights as today → `finish("warm_house")`. Effects: `Haunting.tension` drains `x1.6` faster in the ground-floor rooms (`House.room_at`), the stove glow is visible through the living-room window from outside (an `OmniLight3D` already exists; give the window glass an emission pulse, no new light).
- [ ] **Step 4:** Probe: `_stove_refuses_cold`, `_three_armfuls`, `_lights_and_finishes`, `_mathilda_stove_unchanged` (`mathilda_pov` run: chore lights at once).

**Verify:** `warm_house_probe` → `WARM_HOUSE PASS`; `house_space_probe`, `mathilda_probe` unchanged.

---

### Task 8: `two_cups`

**Files:** Modify `errands.gd`, `scripts/notes/note_catalog.gd` (a smudge reading keyed on `cups`, only if a page already has a cups-shaped smudge; otherwise add the key to an existing smudge's readings), `assets/dialogue/lake.json` (one topic gated on flag `cups`, written through Story Studio's format; run `python tools/bake_lake.py --check`). Create `tools/two_cups_probe.gd` + `.tscn`.

- [ ] **Step 1:** Kitchen cupboard (`HouseDrawer`) holding one `SM_Cup`; opening it `learn("two_cups")`.
- [ ] **Step 2:** Mathilda's cup, half under snow on the porch rail (a light `Carryable`), a `CarrySocket` on the table for two cups, a kettle socket on the hob that only accepts once `warm_house` is done (`kettle` loop sound for a while).
- [ ] **Step 3:** Both cups on the table and the kettle warmed → `finish`, `Game.heard("cups")`, so `Game.known("event:cups")` is true (keys are `page:`/`place:`/`event:` prefixed).
- [ ] **Step 4:** Lake meeting: one Ophelia line and one Mathilda reply behind `cups`, added to `docs/LAKE_MEETING.md` and `lake.json` (Mathilda's line baked later with Kokoro by `tools/bake_lake.py`; owed until then).
- [ ] **Step 5:** Probe: `_cupboard_teaches`, `_kettle_needs_stove`, `_finish_knows_event_cups`, `_meeting_offers_topic` (load `lake.json` through `DialogueTree`, check the topic appears only with the flag).

**Verify:** `two_cups_probe` → `TWO_CUPS PASS`; `python tools/bake_lake.py --check`; `meeting_probe`, `journal_probe` unchanged.

---

### Task 9: `red_thread`

**Files:** Modify `errands.gd`, `scripts/house/domestic.gd` (the `window_thread` chore also calls `Game.errands.learn("red_thread")` when present), `scripts/notes/note_catalog.gd` (keepsake entry *The thread*, `counts = false`), `scripts/world/camp.gd` (show the glove at `spots` if `red_thread` is done, via `place_story_prop("gloves")`). Create `tools/red_thread_probe.gd` + `.tscn`.

- [ ] **Step 1:** Five snags (`ERRAND_THREAD_SNAGS`): red wool (`SM_Rope_02/03` with a red wool material, or a thin curved `CSGPolygon`/mesh fallback) on a branch (a `SnowBranch` that reveals it when knocked), a post, a fence wire stub, a stump, a low bush, placed 6–25 m off the route between trail pages 1 and 3 with `trail.on_ground()`, outside `FOREST_CLEAR` and the house pad, each visible from the previous one (raycast check in the probe). Each is a hold-to-do "Wind the thread".
- [ ] **Step 2:** The birch: one existing tree near the last snag (from `Flora.nearest_indices`) gets a bark decal with "M.A." and "O.A."; a glove (`Carryable`, light) in the snow beside it.
- [ ] **Step 3:** Picking up the glove → journal entry *The thread* (short, her hand, no smudges), `finish("red_thread")`.
- [ ] **Step 4:** Probe: `_window_teaches`, `_each_snag_seen_from_previous`, `_snags_off_route_and_clear`, `_keepsake_does_not_count` (`LAKE_PAGES` logic unchanged with the keepsake in the journal), `_camp_glove`.

**Verify:** `red_thread_probe` → `RED_THREAD PASS`; `ending_probe`, `journal_probe`, `flora_probe` unchanged.

---

### Task 10: `light_for_dark`

**Files:** Modify `errands.gd`, `scripts/player/player.gd` (a carried lamp light). Create `scripts/errands/storm_lamp.gd` (`class_name StormLamp extends Carryable`), `tools/lamp_probe.gd` + `.tscn`.

- [ ] **Step 1:** The janitor-room oil cupboard (`HouseDrawer`, Leartes `SM_Cuboard_Small`) with an oil tin (`SM_Tin_03`, light `Carryable`). Opening it, or `Game` reaching the `dusk` day moment, `learn("light_for_dark")`.
- [ ] **Step 2:** The storm lamp (WW2 lamp, or the Poly Haven wooden lantern if the WW2 import fails) on a porch hook (`CarrySocket`, `SM_Hook`). Filling it is hold-to-do with the tin in hand ("Fill the lamp"), which consumes the tin.
- [ ] **Step 3:** `StormLamp`: an `OmniLight3D` (`LAMP_RANGE`, `LAMP_ENERGY`, warm, shadow off on lean, its `shadow_caster_mask` excluding `Tune.FOREST_RENDER_LAYER` like `Camp`'s fire), a gentle flicker, fuel in hours of her day (`LAMP_HOURS`), dimming over its last hour. Carried in the `hand` pose; set down, it keeps burning. Her camera light dims a little while she carries it, so the lamp reads as the light.
- [ ] **Step 4:** `finish("light_for_dark")` when she first carries the lit lamp past the house pad.
- [ ] **Step 5:** Probe: `_oil_teaches`, `_dusk_teaches`, `_fill_lights`, `_fuel_burns` (advance `Game.day_seconds` by `LAMP_HOURS` worth → energy 0), `_set_down_keeps_burning`, `_lean_no_shadow` (`Game.lean_graphics = true`).

**Verify:** `lamp_probe` → `LAMP PASS`; `performance_probe` unchanged; controller capture at night: `RUN_HOUR=22`, `RUN_ERRAND=light_for_dark:carry`, `RUN_CAPTURE=1` → `build/errands/lamp_night.png`.

---

### Task 11: Her lines (writing parallel-safe; the probe is not)

**Files:** Modify `docs/MATHILDA_STORY.md` (new `### Errands` under *Spoken script*), `scripts/player/voice.gd` (`errand(id)` like `chore(id)`, `bell_here` as an answer), `assets/audio/voice/lines.json` (regenerated).

- [ ] **Step 1:** About 24 lines in existing moods, keyed `e_<errand>_<beat>` (learn, progress, finish, let go for each errand) plus `bell_here`, `warm_hands` and `lamp_low`. Short, in Ophelia's voice, matching the *Chores* block's style. No line explains the story.
- [ ] **Step 2:** `python tools/script_to_lines.py`, then `python tools/script_to_lines.py --check`.
- [ ] **Step 3:** `Voice.errand(id)`, called from `Errands` on learn, finish and let go, and from the verbs where a line exists.
- [ ] **Step 4:** Record the bake as owed: `python tools/voice_status.py --owed desktop:chatterbox` lists the new ids. Do not bake. Until then they play as subtitles (`Voice` already does this for a line without a clip).

**Verify:** `script_to_lines.py --check`; `python tools/studio/test_writers.py`; `voice_probe` passes without `PROBE_CLIPS` (with `PROBE_CLIPS=1` it is expected to list exactly the new ids as missing; note that in the checklist).

---

### Task 12: Integration, shots and docs (controller + one implementer)

**Files:** Create `tools/errand_save_probe.gd` + `.tscn`, `tools/errand_view.gd` + `.tscn` (shots into `build/errands/`, needs a window). Modify `CLAUDE.md`, `AGENTS.md` (an *Errands and interactions* paragraph under Architecture, the new probes in Commands, `RUN_ERRAND`, the `drop` key), `README.md` (the `drop` row in the input table), `CHANGELOG.md` (unreleased section).

- [ ] **Step 1:** `errand_save_probe`: mid-errand state for all four (an armful in her arms, two logs in the box, a cup on the table, three snags wound, the lamp lit and set down, the sign brushed), `RunSave.save_now()`, rebuild the scene through the pending-load path `main.gd` uses, and check every piece; then the same through the checkpoint. Also `_dream_round_trip_clean` (a dream save has no errands key effects).
- [ ] **Step 2:** `errand_view`: day and night shots of the woodpile, the kitchen table with two cups, each thread snag from the one before, the birch, the lamp on the hook and in her hand, the bell. Plus a contact sheet of every curated prop next to its fallback (`build/errands/props.png`) for the user to judge the assets.
- [ ] **Step 3:** Rerun the whole baseline set from T0 plus every new probe, and `performance_probe`. Compare with `build/errands/baseline/`.
- [ ] **Step 4:** Lean smoke shot: `RUN_GRAPHICS=lean`, `RUN_CAPTURE=1`, `RUN_PLAY=1`.
- [ ] **Step 5:** Docs. Remove nothing else from CLAUDE.md; keep AGENTS.md consistent.
- [ ] **Step 6:** The controller writes a short validation record at the end of the spec (what passed, what is owed: voice bakes, Mathilda's lake line, any missing bank asset), and asks the user whether to commit.

**Verify:** every probe exits 0; the shots exist and have been looked at; `git status` shows no files under `build/vendor/requested_errands/`.

---

### Task 13: Move the older proprietary folders into `build/` (approved by the owner 2026-10-15)

The owner wants every proprietary bank asset in the git-ignored `build/` folder. The folders that predate the rule: `assets/vendor/requested_house/` (144 MB), `assets/derived/requested_house/` (24 MB, `.scn` scenes built by `tools/curate_house_assets.gd` from imported resources), `assets/vendor/requested_camp/` (170 MB), `assets/vendor/requested_dream/` (23 MB), `assets/vendor/requested_paper/` (25 MB). They are referenced from `scripts/house/domestic.gd`, `scripts/house/loft_room.gd`, `scripts/notes/field_note.gd`, `scripts/world/camp.gd`, `scripts/world/lake.gd` and the tools that curate or probe them (31 references). Out of scope: `assets/characters/asset_bank/` (already ignored, per machine) and the tracked Sketchfab split meshes (a separate licence decision).

Runs after T12, one folder per subagent, each in this order:

- [ ] **Investigate first (read-only):** for the folder, list every `res://` reference and how it is loaded (imported glTF/FBX `PackedScene`, imported textures, or a derived `.scn` that embeds or points at imported resources). Report which can switch to `VendorLoader.scene/texture/leartes` directly and which need their curation tool changed (the derived house `.scn` files must be rebuilt at runtime from the raw meshes, or saved with their materials built from `VendorLoader` textures). Stop and report before changing code.
- [ ] **Move:** point the curation tool at `build/vendor/requested_<area>/`, re-run it, switch the runtime code to `VendorLoader`, keep every existing fallback, delete the old folder and its `.import` files, `--import`.
- [ ] **Verify:** the area's probes (`house_space_probe`, `house_domestic_probe`, `house_loft_probe`, `requested_house_probe`, `house_replacement_probe`; camp: `tools/camp_view.tscn` shots before and after, compared by the controller; lake: `ending_probe`, `tools/lake_view.tscn`; dream: `dream_flow_probe`, `dream_view.tscn`; paper: `journal_probe`, `note_access_probe`), plus a startup time check (`RUN_BLACKBOX`) before and after: runtime parsing must not add more than about a second to the load on this machine. If it does, cache the generated scenes as `.scn` under `user://vendor_cache/` keyed by source sha256, like the terrain cache.
- [ ] **Release:** `tools/export_release.ps1` copies `build/vendor/` to `vendor/` beside the exe (VendorLoader looks there in an exported game). Ask the owner before changing the release script.
- [ ] Remove the old `.gitignore` lines once the folders are gone, and update CLAUDE.md's *Mathilda's camp* and *House* asset notes.
