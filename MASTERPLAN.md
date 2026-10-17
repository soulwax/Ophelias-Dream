# Ophelia's Dream — masterplan to MVP

Updated **2026-10-17**. Planning baseline: `main` at `6d4f43a`, plus the existing uncommitted bow, player, tuning, flora, nature-curation and vendor-loader work. Revalidate that baseline before implementation. This document reconciles the plans; it does not claim that the game has passed the release gates below.

## 1. The finish line

Ship a dependable, non-commercial Windows x64 MVP of the existing intimate winter horror game. A player can enter **Dream, Ophelia or Mathilda**, understand what they can do, complete that mode, save and resume safely, and return to the title or replay. The three perspectives share objects, memories and human stakes without requiring a prescribed play order.

The production strategy is **finish and connect the existing game**, then stop expanding it. Keep the working dream, house, terrain, movement, journal, conversations and chapter endings. Complete the already-designed domestic interaction layer, repair observed defects, finish required audio, and prove the exported game works away from the editor.

### MVP scope contract

| Area | Required for this MVP | Boundary |
| --- | --- | --- |
| Dream | Current standalone walk, readable landmark/cue order, six existing memory branches, complete/unresolved/ruptured outcomes, repair and privacy paths, journal and waking handoff | No wholesale rewrite or new metaphysical explanation; subtitle driven by design |
| Ophelia | House and cellar opening; existing five trail pages plus house documents; smudge interpretation; optional domestic activity; false lookout; continuation to lake; current endings | No objective marker, required errand checklist, new region or reinstated predator |
| Mathilda | Camp inspections and practical chores; meaningful Wait; Return walk; doorstep conversation and both relationship closures | No new chapter or extensive first-person hand system |
| Errands | Four designed errands: `warm_house`, `two_cups`, `red_thread`, `light_for_dark`; carry/place/hold/open/knock snow/warm hands/ring bell | Optional for the player; none changes the central ending eligibility requirements |
| Shared systems | Existing locomotion, lantern, bow and arrows remain usable; rare passings remain optional; settings/input, pause, save/load, checkpoint and restart work | No combat loop, bow targets progression, new locomotion feature or character roster |
| Presentation | Critical-path geometry, materials, camera, bodies, dialogue, subtitles and sound are coherent in full/lean and reduced effects | Polish the normal player view; showcase tools are supporting tools, not MVP products |
| Release | Matching Godot 4.7.2 Mono export; executable and .NET data folder; complete runtime data; verified distributable assets or fallbacks; local save and credits instructions | Windows first; no installer, encryption project, storefront integration or platform port |

This is the **recommended scope**, not a claim of a previously approved release specification. G0 freezes it. If capacity requires a smaller MVP, cut an entire optional errand and its advertised content at G0 rather than ship a discoverable unfinished task. Preserve the smallest complete domestic action and the existing chapter routes. Do not silently cut a mode or turn an optional action into a mandatory puzzle.

Keep the non-commercial distribution constraint from repository instructions until the actual active animation assets and their licences have been audited. README's newer commercial/MIT claim is not sufficient evidence to remove that constraint. A code licence does not establish third-party asset rights.

### Done means all of these

- Every mode has an understandable start, playable middle, complete ending, and usable exit/replay path.
- Every advertised errand has discovery, action, feedback, payoff, restoration and fallback coverage.
- No blocker or major defect remains in the route/ending/save/input matrix in section 8.
- No required spoken line is silently absent. Dream silence remains intentional; chapter speech has a reviewed clip or an explicit, scoped release decision.
- Full/lean, muted audio, reduced effects and large text retain the information needed to play.
- A clean exported candidate completes all three modes without the source tree or proprietary asset bank.
- Versions, changelog, controls, credits, asset policy and known limitations describe that exact candidate.

## 2. Authority and reconciliation

**This file owns production order, MVP scope, dependencies, assignments and gate status.** Existing story documents remain the script of record. Existing specs retain their detailed contracts unless a conflict is explicitly resolved here or in a recorded decision. Live code establishes what exists, not whether it is good enough to ship. An unchecked historical plan box is not proof of missing implementation; a source file or old PASS log is not proof of current readiness.

| Source family | Disposition in the masterplan |
| --- | --- |
| [Whole-game narrative/presentation roadmap](docs/NARRATIVE_PRESENTATION_ATMOSPHERE_PLAN.md) | Retain its emotional direction, scene specifications, accessibility and reliability gates. Fold slices 1–2 into G0/G1, existing dream slices 3–6 into W05, restoration slice 7 into W12, chapter slices 8–10 into W07–W11, finish slice 11 into W13–W14, release slice 12 into W15–W18. Its twelve slices are not twelve blank implementation jobs. |
| [Errands design](docs/superpowers/specs/2026-10-14-errands-and-interactions-design.md) and [execution plan](docs/superpowers/plans/2026-10-14-errands-and-interactions.md) | Active feature specification. Audit T0–T5 instead of repeating them; complete missing T5b contracts, T6–T12 gameplay and T13 asset migration through W03–W04/W06–W10/W12/W15. Retain its implementer/reviewer/controller workflow. |
| [Dream atmosphere](docs/DREAM_ATMOSPHERE_PLAN.md), [dream playability/release](docs/DREAM_PLAYABILITY_RELEASE_PLAN.md) | Current local design and historical execution evidence. Retain implemented architecture and flow; reproduce defects before changing it. The execution record is not a current release certification. |
| [Dream experience](docs/DREAM_EXPERIENCE_PLAN.md) | Earlier intent and thematic reference. Superseded where branch counts, outcome rules or authoring behavior differ from the live data. |
| [Mathilda story](docs/MATHILDA_STORY.md), [POV](docs/MATHILDA_POV.md), [doorstep](docs/MATHILDA_MEETING.md), [lake](docs/LAKE_MEETING.md), [dialogue](docs/DIALOGUE.md) | Content and relationship contracts. Reconcile factual, symbolic and timing contradictions in W02; synchronize deliberate content changes with JSON and generators. |
| [Mathilda plan](docs/MATHILDA_PLAN.md), [Jungian plan](docs/MATHILDA_JUNGIAN_PLAN.md), October 6 story/Jungian specs and plans | Historical implementation recipes for foundations already present. Retain intent and useful checks; do not recreate journal, turns, voices or endings because the boxes are unchecked. |
| October 6 [running leap](docs/superpowers/plans/2026-10-06-running-leap.md), [natural terrain](docs/superpowers/plans/2026-10-06-natural-terrain.md), [biome world](docs/superpowers/plans/2026-10-06-biome-world.md) plans and matching specs | Implemented foundations needing targeted regression checks under W13/W14. No terrain or animation rebuild just to complete old plans. |
| [House refinement](docs/house/REFINEMENT.md), [next pass](docs/house/NEXT_PASS.md), [loft](docs/house/LOFT_PLAN.md), [identity](docs/house/IDENTITY.md), asset request/replacement records | Preserve the authored house and provenance. Fix visible/traversal defects and loader migration regressions. Additional decoration and replacement shopping are deferred unless a critical scene needs them. |
| [Original plan](docs/PLAN.md), [GDD](docs/GDD.md), [direction](docs/DIRECTION.md), [narrative intent](docs/NARRATIVE_INTENT.md), [TODO](TODO.md) | Historical context where they assume Listener/Hunter, Mara, road escape or old page structure. Their current entry points must link here in W17. Do not restore removed threats as a supposed missing MVP dependency. |
| [Voice](docs/VOICE.md), [meeting voice](docs/MEETING_VOICE.md), [handoff](docs/HANDOFF.md), voice READMEs | Pipeline/reference material requiring correction against current manifests. HANDOFF's `0.2.1.4`, branch and exe-only instructions are historical; do not use its next-version recipe. |
| [Story Studio](docs/STORY_STUDIO.md), [animation workbench](docs/ANIMATION_WORKBENCH.md), character/garment workflows | Retain authoring contracts and existing tools. Only tool work necessary to preserve current game data belongs before MVP. |

### Decisions and contradictions to close at G0

| ID | Conflict or uncertainty | Resolution / decision owner |
| --- | --- | --- |
| D01 | Old plans require two lethal threats and real headlights; live game has none and a false lookout/lake | Keep current threat-free MVP. **Resolved 2026-10-15:** the owner chose to drop the references to the absent threats file; removed from CLAUDE.md, AGENTS.md, GDD and NARRATIVE_INTENT. One pointer remains in `docs/DIRECTION.md`, pending that file's other uncommitted edits. |
| D02 | Repository prose says Ophelia's afternoon never moves; `Game.start_day()` starts the atmosphere clock and `_tick_day()` advances toward the 40-minute timeout | Preserve implemented moving clock pending a dedicated pacing review. Story owner distinguishes a character's statement about the afternoon from literal simulation rules. Do not break the lamp/dusk errand by following stale comments. |
| D03 | Mathilda's moving dusk conflicts with ending language about light moving for the first time / the same afternoon | Story owner labels intentional subjective imagery or revises the wording in its script of record; no accidental factual contradiction. |
| D04 | README claims commercial/MIT eligibility; repository instructions retain CC BY-NC movement restriction | Asset owner traces active clips to source/provenance. Until resolved, non-commercial scope; do not distribute any asset whose applicable permission is unverified. |
| D05 | Voice counts and production stages differ across docs; old handoff says five missing doorway finals | Use current data in section 3, refreshed after writing. Do not bake from old counts or regenerate the whole catalogue. |
| D06 | Studio's `FINAL_ENGINE` policy calls Mathilda meeting drafts Chatterbox debt; historical direction intentionally matches Kokoro chapter voice | Audio owner recommends a consistent, listened-to Mathilda identity across chapter/lake/doorstep for MVP. Engine labels alone do not decide quality; record the accepted policy before baking. No automatic full Mathilda voice replacement. |
| D07 | Errands plan assumes `VendorLoader.scene/texture/leartes/available`; existing nature loader exposes different methods | W04 adapts the existing implementation with compatible wrappers or updated consumers. Preserve current nature callers and units/materials. **Resolved 2026-10-15 (W04):** the API is `root()`, `resolve()`, `available()`, `load_model()`, `load_texture()` (mipmapped), `nature_mesh()`, `spawn_nature_prop()`, `clear()`; errand builders use those names, and any Leartes material helper is added with its first consumer in W06. |
| D08 | Some dream plans say Studio drops unknown metadata; current normalizer validates and returns a deep copy | Verify round-trip preservation and update the stale claim; no unnecessary schema rewrite. **Resolved 2026-10-15:** `dream_story.normalize()` round-trips `dream.json` with 0 differences; `tools/studio/test_dream_story.py` was stale (`event_talk` since `6db75c7`) and is fixed. |
| D09 | Project/export metadata is `0.2.14.0`; changelog begins at `0.2.13.0` | Document the actual pending work, then choose the candidate's version using current repository release rules. No predetermined old patch number. |
| D10 | Adding a keepsake to a journal counted by `journal.size()` may affect lake eligibility | Separate story-progress eligibility from optional keepsakes where needed. Prove three-page minimum and meeting readiness remain unchanged by errands. |

Record unresolved decisions with an owner and affected package. Decisions involving content or rights block their dependent work; independent discovery and verification can continue. This planning pass does not authorize committing, moving assets, baking voices or publishing.

## 3. Grounded baseline: what is actually left

Status vocabulary: **present / verify** = implementation found, release acceptance pending; **partial** = supporting implementation exists with concrete missing pieces; **missing** = specified deliverable not found; **deferred** = outside this MVP. Nothing below is marked release-done from source inspection alone.

| System | Status on 2026-10-15 | Evidence and next action |
| --- | --- | --- |
| Three title doors and construction flow | Present / verify | `scripts/main.gd`, `scripts/ui/dream_menu.gd`, `scripts/game/game.gd`; test independent first entry, return and replay |
| Dream, memory architecture, turns and journal | Present / verify | `scripts/world/dream_experience.gd`, `dream_memory_architecture.gd`, `dream_route.gd`, `dream_story.gd`, `assets/dialogue/dream.json`; flow fixes and prior captures already recorded |
| House/trail/journal/lookout/lake endings | Present / verify | `scripts/house/`, `scripts/notes/`, `scripts/world/trail.gd`, `lake.gd`, `scripts/game/game.gd`; continuous route evidence still needed |
| Mathilda, camp and doorstep | Present / verify | `scripts/player/mathilda_pov.gd`, `scripts/world/camp.gd`, `assets/dialogue/meeting.json`; five camp activities exist, not just the older three inspections |
| Rare passings | Present / verify | `scripts/npc/encounters.gd`, `Wanderer.cs`; validate no-passing path and at-most-three behavior, not more encounter content |
| Save and checkpoint | Present / verify | `scripts/game/run_save.gd` snapshot v3, checksum/temp/backup and dream state; Game checkpoint includes errand state hooks |
| Hold, carry, sockets and Undone journal | Present / verify | `scripts/player/aim.gd`, `carryable.gd`, `carry_socket.gd`, `CarryHold.cs`, `tools/hold_probe.tscn`, `carry_probe.tscn`, `errand_probe.tscn`; prior hold failure logs require fresh triage |
| Errand data/core | Partial | `assets/errands/errands.json`, `scripts/errands/errand.gd`, `errands.gd`; state/registry/save APIs exist, but `ensure_built()` currently creates an empty World and emits built |
| World verbs / four playable errands | Missing | No specified drawer/branch/brush/warm/bell/storm-lamp scripts or actual errand builders/payoffs found; T6–T12 remain substantive feature work |
| Vendor loading | Partial | `scripts/world/vendor_loader.gd` loads runtime models/textures for nature; export-adjacent resolution, planned helper contracts, unit/material verification and migration remain |
| Older proprietary asset relocation | Missing | House/camp/dream/paper references still use old `assets/vendor/requested_*` / derived scene paths; migrate incrementally, preserving fallbacks |
| Movement, bow and nature | Present / verify; active work | Current dirty files include these systems. Establish their intended baseline with their owner before assigning overlapping edits |
| Export | Partial / release blocker risk | `tools/export_release.ps1` and preset exist; engine selection, reproducible candidate, data coverage, Mono folder and distributable package need work |

### Lightweight checks actually run during reconciliation

These are data checks on this working tree, not Godot runtime, audio listening, gameplay or export results:

| Command | Result |
| --- | --- |
| `python tools/script_to_lines.py --check` | PASS; 182 Ophelia lines |
| `python tools/bake_mathilda.py --check` | PASS; 69 chapter lines |
| `python tools/bake_lake.py --check` | PASS; 43 lake lines |
| `python tools/bake_meeting.py --check` | PASS; 41 doorway lines, 82 transitions, 160 paths |
| `python tools/dialogue_post.py --check` | PASS; 41 doorway lines |
| `python tools/voice_status.py` | Inventory below; not an audio quality pass |

| Catalogue | Current inventory | Work implication |
| --- | --- | --- |
| Ophelia chapter | 182 total: 134 final, **48 missing** | Complete selected current-script debt after writing freeze |
| Mathilda chapter | 69 final | Listen and preserve identity; no automatic re-bake |
| Lake | 43 total: 23 Mathilda final, **20 Ophelia missing** | Lake is not audio-complete despite coherent data |
| Doorstep | 41 total: 15 Ophelia final, **6 Ophelia draft**, **20 Mathilda draft** | Review Ophelia's six drafts and settle Mathilda policy |

Total: **68 missing clips and 26 drafts** before new errand lines. The tool labels all 94 as Chatterbox debt; the 20 Mathilda drafts require a policy/listening decision rather than automatic replacement. Errand writing and the new cups topic will increase the inventory. Refresh this table when scripts change.

No engine build, full import, windowed capture or export was run for this documentation task. Historical probe PASS records and a historical meeting assertion/timeout are leads for W01, not current results.

## 4. Subagent operating model

Use **one coordinator plus at most three active workers**. A worker implements one bounded package; a fresh reviewer checks it; the coordinator owns integration and final verification. Parallelize independent reading, writing and disjoint edits. Serialize shared file edits and all Godot processes. More agents do not make shared runtime state independent.

### Ownership and dispatch rules

1. Coordinator records the starting commit, dirty/staged files and active ownership. Preserve existing user work; never reset, unstash, stage or commit it as a shortcut.
2. Give each worker an exclusive file list and consumed/produced interfaces. Discovery may be shared; edits to `main.gd`, `game.gd`, `run_save.gd`, `tune.gd`, `errands.gd`, `player.gd`, `dream_experience.gd`, story JSON or provenance files require one named owner at a time.
3. Integration changes requested by another worker are handed to the current owner. No simultaneous patching of a common file. If a task becomes broad, split it at a stable interface and finish the smaller slice first.
4. **One Godot process at a time**, including import, headless probes and windowed captures. Coordinator schedules the engine slot and performs windowed reviews. Build C# first when changed; import after adding classes/resources. Workers report needed commands if the slot is occupied.
5. Use the Godot navigation/debugging/targeted-verification skills when relevant. The UI/UX skill requires explicit confirmation before file edits; do not invoke it casually for unrelated runtime work. Follow any applied skill's actual requirements. Do not assume the unavailable `superpowers:*` subskill named in old plans is installed; use the concrete workflow here.
6. Workers do not commit, bump versions, publish, regenerate editable scenes, lower voice thresholds or bulk-bake. Any future release automation/script change follows applicable repository instructions and explicit authorization at that time.
7. Retain programmatic node-building patterns, typed GDScript/tabs, C# where already justified, Game-registered input, Tune balance and Loudness sound levels. Preserve authored `scenes/editable_level.scn` and `scenes/generated/`.
8. Assets come from exact known folders in the owner's bank through curation tools and manifests. Proprietary files stay ignored; fallbacks are built and tested. Avoid whole-bank recursive scans.
9. Reviewer first checks the package's acceptance and spec, then regressions/quality. Must-fix findings return to implementation; after two unsuccessful fixes, escalate the concrete issue instead of broadening the change.
10. Coordinator reruns the necessary check, reads output, inspects required images and updates this plan's gate record. A reviewer saying “clean” is not a test result.

### Task prompt contract

```text
Package: Wxx — <title>; starting commit and known dirty work: <snapshot>.
Read: AGENTS.md, MASTERPLAN.md sections <n>, and <specific spec sections>.
Goal / player-visible result: <one bounded outcome>.
Own exclusively: <files>. Other files are read-only; request integration edits.
Dependencies available: <APIs, stable IDs, scene anchors, approved decisions>.
Produce: <API/data/state changes, fallback behavior, companion doc updates>.
Acceptance: <cases from this package, including reset/load/cancellation>.
Verify: <exact focused commands>; request the Godot slot from coordinator.
Do not commit, publish, regenerate authored scenes, or start the next package.
Return: changed files; interface/state additions; commands and exit codes;
evidence paths; unresolved issues and risks; estimated remaining work.
```

Each task report includes asset source/hash/licence changes when relevant and distinguishes **not run**, **failed**, **passed** and **human review pending**. No passing checkbox without evidence. Keep captures/logs under `build/mvp/<gate>/<package>/`; commit only concise validation summaries and necessary source/provenance.

## 5. Dependency order and gates

| Gate | Objective | Packages | Parallel work that is safe | Exit evidence |
| --- | --- | --- | --- | --- |
| **G0 — contract** | One actual baseline, scope and decision register | W01, W02 | Read-only code/data audit, story audit and asset/voice inventory | Current failures reproduced; D01–D10 assigned/resolved as needed; scope frozen |
| **G1 — trustworthy foundations** | Interaction and loader contracts; existing dream remains playable | W03, W04, W05 | Separate interaction, loader and dream owners; coordinator handles shared integrations | Focused probes; small player-view review; no cross-mode leakage |
| **G2 — complete domestic slice** | Real opening action with persistent payoff | W06 then W07 | W06 verbs may be split into disjoint scripts; W02 can prepare later writing | Warm house from discovery to payoff, through save/reload and fallback |
| **G3 — feature complete** | Finish remaining errands and chapter connections | W08, W09, W10, W11 | Errand builder changes serialized; disjoint thread/lamp helper code and writing can overlap | All four errands playable; core endings independent of optional actions; text freeze |
| **G4 — state and content locked** | Restore every mode; finish voice and vendor integration | W12, W15, W16 | Save owner, asset migration owner and audio owner use disjoint files; engine scheduled centrally | Restoration matrix, asset/fallback audit, reviewed audio inventory |
| **G5 — candidate quality** | Whole-run experience, presentation and performance | W13, W14, W17 | QA reports and release-tool preparation can overlap; freeze runtime during evidence capture | Human review, full/lean evidence, known hardware budget, candidate manifest |
| **G6 — MVP accepted** | Exported candidate and handoff | W18 | Independent reviewers inspect the same immutable candidate | Three-mode packaged playthrough, checksums, accurate docs, no unresolved blockers |

Critical path: **W01/W02 → W03/W04 → W06 → W07 → W08/W09/W10 → W11 → W12 → W13/W14 → W18**. W05 starts at G1 and must finish before W12. W15 can investigate early and migrate after feature integration is stable. W16 can inventory early but final baking waits for text freeze. W17 can prepare tooling early; candidate packaging waits for G4/G5 inputs.

Treat every package as roughly **one to three focused agent sessions**, not a calendar promise. W12, W15 and W18 are likely multi-session integration work; split W15 by asset family. Baseline measurements at G0 produce estimates. Do not trade away restoration or exported-build verification to hit an invented date.

## 6. Detailed implementation packages

### W01 — baseline and reproducible defects [P0; coordinator + QA auditor]

**Own:** proposed `docs/mvp/BASELINE.md` and ignored `build/mvp/g0/` evidence; runtime read-only initially. **Depends:** none.

- Record commit, dirty/staged paths, engine/.NET versions, GPU/driver, reference resolution and full/lean settings. Check whether other sessions own the active bow/nature work.
- Run the data checks in section 3, C# build/import, then relevant current probes one at a time. Require an appropriate timeout, exit 0, the expected terminal PASS marker and no unresolved script errors/assertions; an aborted check can otherwise hang or appear successful. Inspect probes that instantiate `main.tscn` for title-only startup; set `RUN_PLAY=1` where required and record it.
- Reproduce the historical hold failure and meeting assertion/timeout; isolate stale fixture expectations versus product failures. Fix neither by removing checks without confirming behavior.
- Take a short normal-camera tour of each mode and list concrete defects: trigger, expected/actual behavior, severity, owner, next verification. Capture startup/cache timings.
- Inventory all endings, stable dream memory IDs, save fields, runtime JSON references and active asset families. Mark evidence missing instead of assuming success.

**Done:** another agent can reproduce each blocker; scope and ownership are reviewable; no old failed run has been relabeled as a new pass.

### W02 — story contract, branch map and writing lock [P0; narrative agent + independent story reviewer]

**Own:** proposed `docs/mvp/STORY_CONTRACT.md`, relevant script-of-record updates by lease; JSON remains read-only until its owner integrates. **Depends:** W01 inventory.

- Write the roadmap's compact four-column bible: authorial fact, character belief, observable evidence, unresolved interpretation. Record intentional contradictions explicitly.
- Resolve D02/D03: both implemented clocks, waiting, frozen-afternoon language, dream memory versus run state. Keep consent, responsibility and valid silence clear even when identity stays uncertain.
- Map Dream → persistent memory → chapter reflection, plus rare passings/errands → optional conversation topics. A private or ruptured dream cannot silently lock a chapter's central ending.
- Audit all existing outcomes for a present action: resolved/unresolved/ruptured wake; lake/prints/gone/together/shore; home/step/wait. Keep Mathilda's independent decision meaningful under symbolic interpretations.
- Draft only missing errand lines, cups topic and corrections exposed by review. Approve IDs/moods/flags before generators run. No compulsory lumberjack confrontation or graphic reenactment.

**Done:** every ending has a route/prerequisites table; accidental contradictions have a bounded fix; writing required for W08–W11 is ready without redoing the whole story.

### W03 — hold/carry foundation verified [P0; interaction agent]

**Own:** `scripts/player/aim.gd`, `carryable.gd`, `carry_socket.gd`, `CarryHold.cs`, hold/carry probes; lease `player.gd`, input/settings and Tune only for necessary integration. **Depends:** W01 and clearance of current player work.

- Verify hold start, progress, release/cancel, moving out of range, target switching, object deletion and phase changes. Completion fires once; pause/journal/endings leave no stuck action or arm layer.
- Verify one carried object, valid/rejected sockets, heavy/light movement, safe drop, no duplicate ownership, no under-terrain loss, and lantern/bow coexistence.
- Confirm stable item/socket IDs and restoration without replaying pickup/placed side effects. Prove dream and Mathilda modes remain unaffected.
- Repair concrete failing cases before building errands on top. Preserve the interactable aim-box convention.

**Done:** hold/carry/errand core probes pass on current code, and actual player input demonstrates pick/place/drop/interrupt. Relevant C# build passes.

### W04 — one vendor loader for development and exports [P0; asset/runtime agent]

**Own:** `scripts/world/vendor_loader.gd`, proposed focused loader probe; coordinate nature consumers. **Depends:** W01, D07 and existing loader ownership.

- Define a single documented relative-path contract: development `build/vendor/`, exported adjacent `vendor/`, fallback when absent. Preserve `load_model/load_texture/spawn_nature_prop` consumers or migrate compatibly.
- Implement only helpers needed by errands/migration: model instancing/cache ownership, textures/mipmaps, explicit scale/units, LOD/collision-hull filtering, material assignment including normal/ORM maps.
- Check missing and malformed assets return a safe fallback, texture/material state is not accidentally shared across instances, and cached objects remain valid after scene replacement.
- Compare a vendor prop against its fallback and expected metre scale. Test exported resolution early with a tiny candidate, rather than waiting for all migrations.

**Done:** loader probe plus with/without-pack smoke pass; current nature rendering is preserved; W06 and W15 can consume a stable API. No redistribution assumption is embedded in loading logic.

### W05 — finish the existing dream [P0 correctness; P1 composition; dream agent]

**Own:** dream runtime/route/architecture, `assets/dialogue/dream.json` by lease, dream probes; request shared UI/save edits from their owners. **Depends:** W01/W02.

- Retain current cue queue, opening domestic baseline, quiet interval, branch IDs, memory doors, acting/camera and waking safeguards. Reproduce known visual risks before altering afterimages or landmarks.
- Walk and sprint the route; stop, backtrack, leave a talk station, open journal, pause and return. Clearing cannot discard earlier required dialogue or strand the final reply.
- Keep one turn and one primary notice readable at once. Align landmark reveal, speaker position, subtitle, response and departure. Review threshold, late step/lighthouse, window, clearing and warning through the player camera.
- Confirm all six memory choices and all three outcome classes remain reachable, including privacy and repair. Persistent completion commits once and the closing input cannot trigger the next screen.
- Verify Studio round-trips current staging metadata; fix destructive behavior if reproduced. Extract helpers only where a necessary change becomes unsafe; no large refactor prerequisite.

**Done:** story/flow probes and selected Studio checks pass; slow/sprint/repair/rupture runs finish; full/lean/reduced-effects captures are inspected. Mid-scene restoration joins W12.

### W06 — complete the seven world verbs [P1; interaction implementer(s)]

**Own:** proposed `scripts/errands/house_drawer.gd`, `snow_branch.gd`, `brushable.gd`, `warm_spot.gd`, `bell.gd`, `tools/verbs_probe.gd/.tscn`; lease `errands.gd` for placement and other shared integrations. **Depends:** W03/W04 and W02 sound/line IDs.

- Carry, place and hold reuse W03. Build cupboard open/close with hidden/revealed contents; brushable persistent snow; arrow/interact branch snow drop/refill; warming; lookout bell and one delayed answer per visit.
- Follow errands T6 for public contracts. Integrate warming with Breath/Voice and an existing pose, using minimal rig changes. Use existing wildlife snow audio where possible and Loudness constants for new sounds.
- Include the minimal approved `bell_here` script ID, generator support and Voice answer dispatch in this package so the delayed answer is testable before W11. Subtitle fallback is acceptable during implementation; W11 reviews the complete writing set and W16 supplies the final clip.
- Place in world coordinates under Errands after snapshot application, deriving positions from house/trail/lake anchors. Never change authored child indices or block pages, doors, stairs or walkways.
- Each verb needs a fallback, idempotent state, cancellation, reset and registered persistence. Wrong-mode invocation is harmless; sound goes through the correct buses and settings.

**Done:** proposed verbs probe covers real state changes, arrow knockdown, warm cooldown and bell once-per-visit; house space/sound/note access checks remain valid; player-view interaction is understandable.

### W07 — warm-house vertical slice [P1; domestic gameplay agent]

**Own:** new warm-house builder/probe; leases for `errands.gd`, `scripts/house/domestic.gd`, `haunting.gd`. **Depends:** W06 and W02.

- Discover the cold stove; receive journal prose without a HUD objective; fetch visible armfuls from under the eaves; fill the woodbox; tend the stove.
- Implement visible stacking, sound, stable spawned-item IDs and finite needed quantities. No infinite orphan carryables or item duplication after load.
- Deliver the specified calmer ground-floor house and readable window warmth using existing lighting before adding new lights. Preserve the original stove behavior when Errands is absent.
- Save at discovery, while carrying, with a partial box, and after completion; resume and finish. Repeat with vendor pack absent. Turning around/day-end lets known unfinished errands go without an objective-failed flow.

**Done:** warm-house probe, relevant house/Mathilda checks and a continuous player-input recording pass. This is G2: finish one whole activity before scattering the other three across the map.

### W08 — two cups with a real conversation payoff [P1; domestic/narrative integration agent]

**Implementation 2026-10-15:** `TwoCups` builds a cupboard, porch cup, two table
slots and a kettle heated by a real hold on the lit stove. Pieces use the
existing Errands/RunSave registry. The owner approved the six lines, IDs,
moods and `cups` flag in STORY_CONTRACT section 7. `event:cups` is an alternate
key for the pack's *two* reading; `place:living` still works. Lake refreshes
the topic flag from completion. **Verified 2026-10-16:** vendor and fallback
runs pass three real save/load cycles, actual kettle hold input and the
once-only lake exchange. Cups, kettle and porch snow have an asymmetric,
stable placement pass. Journal, dialogue and affected regression probes pass.
Six approved voice clips remain W16 debt. See [W08 handoff](docs/mvp/W08.md).

**Own:** cups builder and proposed cups probe; leases for note catalogue, `lake.gd`, `lake.json`, lake script and generators. **Depends:** W07 and W02 approved text.

- Discover kitchen cupboard, find porch cup, carry/place two cups, warm the kettle only after the stove works. Completion produces the `event:cups` evidence.
- Connect one appropriate interpretation without replacing a mandatory smudge key with an errand-only gate. Optional errands must not block the base story's deciphering/meeting route.
- Explicitly carry the completed cups flag into the lake conversation. Updating topic JSON alone is insufficient if the runtime never sets the flag.
- Synchronize lake script, generated line/timing data and voice debt. Respect the sound inventory: kettle clank is not a boiling loop; use a suitable licensed loop only if one exists, otherwise design coherent quiet feedback.

**Done:** cups probe proves prerequisites, completion, correct flag/topic availability with/without cups and preservation of base ending eligibility; journal/dialogue/lake data checks pass.

### W09 — red thread as an optional walk [P1; world/errand agent]

**Own:** thread builder/probe; leases for Errands, Domestic, NoteCatalog and Camp. **Depends:** W06/W07, stable flora baseline and W02 keepsake prose.

- Build the specified five snags and glove discovery using actual terrain/tree anchors. Each next snag is visible from the previous one at ordinary player height, not merely an abstract point raycast.
- Preserve trail clearance, house pad, performance and existing authored route. Brush/branch and hold interactions reveal useful detail without a minimap or objective beam.
- Add the non-counting keepsake and visible camp-glove payoff. Recover a dropped glove, restore partially wound snags and avoid duplicate journal entries.
- Resolve D10: the keepsake cannot satisfy the minimum lake page requirement or accidentally become an additional mandatory page in `meeting_ready()`/`all_deciphered()`.

**Done 2026-10-17:** `tools/thread_probe.tscn` covers five snags, terrain sightlines, snow-branch reveal, brushing the birch, the keepsake's lake exclusion, real save/load cycles (partial walk, carried/dropped glove, camp placement), and recovery without duplicate entries. Six player-height link captures are in ignored `build/mvp/thread/`; the hill that hid the second snag was corrected. Flora, journal and ending probes pass. A continuous on-foot traversal remains a W13 acceptance check. See [W09 handoff](docs/mvp/W09.md).

### W10 — a light for dark [P1; lamp/errand agent]

**Own:** proposed `scripts/errands/storm_lamp.gd`, lamp builder/probe; leases for Errands/player/Tune. **Depends:** W06/W07, W04 and D02 clock contract.

- Learn from the oil cupboard or actual dusk moment; obtain oil; fill the lamp by holding; consume the tin exactly once; carry the light beyond the house pad.
- Add an explicit day-moment event hook through the Game owner if none exists; do not poll the entire errand system every frame to discover dusk.
- Burning persists when placed/dropped. Fuel uses chapter time consistently; pause stops the appropriate clock, and restoration does not refill or double-consume fuel.
- Preserve lantern/bow/carry priority and readable arm/camera behavior. Use bounded light range, forest shadow exclusion and lean shadow-off policy.
- Dev hooks must stage real state/props, not only advance a journal step. Check whether `RUN_HOUR` changes the relevant chapter path before relying on the old plan's night-capture command.

**Done:** lamp probe covers discovery, fuel, darkness, set-down, consumption and restoration; day/night player views are useful with/without vendor packs; performance does not regress beyond the recorded budget.

### W11 — connect chapters and freeze content [P1; narrative integrator]

**Own:** approved story text, generator support and Voice errand dispatch by lease; `scripts/npc/encounters.gd`, `mathilda_pov.gd`/conversation changes only when needed. **Depends:** W02, W05, W07–W10.

- Add the designed short errand reactions, bell answer, warming and lamp-low lines using stable IDs and existing moods. Update `script_to_lines.py` support before regenerating if adding a new group; do not hand-maintain divergent catalogues.
- Verify priority/interrupt behavior: no greeting over an ending, no repeated completion line after load, trees answer in Ophelia's own voice, and no voiced dream conversion.
- Play Mathilda's five existing activities, Wait, Return and both doorstep closures. Fix redundant/broken actions or boundary-erasing wording; avoid adding chores merely to pad duration.
- Test zero and rare passings; keep at most three and remember only committed encounters. Optional motifs may change a topic or composition, not make a previously valid central ending impossible.
- Freeze text, moods, branch IDs and conditions. Refresh voice inventory; hand exact changed IDs to W16.

**Done:** scripts/data agree, no required topic is unreachable, base chapters remain complete without errands or the dream, and additional voice debt has an explicit list.

### W12 — save/load, checkpoint and phase reliability [P0; state agent]

**Own:** `scripts/game/run_save.gd`, relevant `game.gd` state transitions by lease, proposed errand-save and mode-restoration probes. **Depends:** all state-producing feature packages and W05/W11.

- Extend versioned snapshots only for real new state. Preserve v1/v2/v3 support or document a deliberate migration; use stable IDs and data, not callbacks/transient nodes.
- Implement the restoration matrix in section 8 through the actual pending-load path in `main.gd`, not by assigning dictionaries back to the same live objects.
- Recreate dynamic meeting actors/trees and pending turns correctly. `MathildaPov.restore_after_load()` and generic dialogue restoration must agree on what owns the restored meeting. Check the lake actor as well as the doorway.
- Carry item/socket ownership, consumed tins, woodbox count, wound snags, brushed surfaces, cupboard openness, lamp fuel, voice seen-state and errand flags across full load and lookout checkpoint.
- Verify choice consequences commit once; pause/journal/replies restore control and mouse mode; completed-dream memory and rolling run save have separate lifetimes.
- Exercise damaged-primary recovery and failed writes in an isolated test save location. Preserve the user's actual save/backup; never corrupt it for a test.

**Done:** matrix passes with deterministic evidence and no duplicate awards, stuck controls, silent state rollback or cross-mode contamination.

### W13 — continuous runs, traversal and usability [P0; gameplay QA + targeted fixer]

**Own:** defect reports/evidence and narrowly assigned runtime fixes; no broad scene rebuild. **Depends:** W11/W12 and feature freeze.

- Execute the route/ending matrix, including no-page exploration, deliberate reading, return to house, minimum pages, full interpretation, no optional actions, all optional actions, backtracking and sprinting.
- Check reach/aim at every required page, door, cupboard, socket and conversation from normal camera height. Inspect cellar/stairs, slopes, lake shore/ice and world boundaries for trapping/falling.
- Verify walk/jog/leap/slide/landings, foot contact, bow aim/fire/pickup, carry and lantern combinations after the current dirty work is integrated. No new locomotion design.
- Exercise keyboard/mouse, controller, rebound actions, hold cancellation, reply focus, restart, Continue and returning to title. One click/press must not select two consecutive replies.
- Observe at least two fresh players without coaching, covering all three modes across sessions. Record time, navigation stalls and interpretation before suggesting fixes; repeat only scenes affected by changes.

**Done:** no run-ending defects, essential navigation confusion or undiscoverable mandatory interactions remain. Players can describe a human stake and the final action without being taught the mythology.

### W14 — presentation, sound and measured performance [P0 readability; P1 finish; visual/audio/performance owners]

**Own:** assigned shaders/materials/UI/audio/movement polish files; shared runtime files by lease. **Depends:** G3 stable scenes; final acceptance after W12/W13.

- Review player camera plus overview and short motion clips at house, trail, lookout, lake, camp, doorstep and dream landmarks. Fix floating props, visible construction fragments, seams, clipping, text collisions and distracting repetitions.
- Check largest subtitle/UI text, small viewport, 16:9 and ultrawide; full/lean; reduced screen effects/motion; muted audio; controller focus. Colour or sound alone cannot carry a required instruction.
- Keep the lantern/window, cups/thread/prints and ice readable through ordinary lighting and motion. Use existing assets and restrained actor gestures; no general character makeover.
- Mix wind, fire, steps, cloth, bell, ice and speech with scene-specific quiet. Verify priority, distance, reverb, duck/recovery and volume settings. A missing clip must not look like an intentional silent turn.
- Measure named hardware at 1600×900: median and p95 frame time, long stalls, cold/warm startup and memory over a repeated run. Begin with the roadmap's 60 FPS objective (16.7 ms); G0 sets the attainable full and lean acceptance budgets. Record any agreed lower lean target explicitly.
- Probe cache invalidation, missing packs and nature/flora performance. Treat `performance_probe` as policy/cache checks, not measured rendered FPS. Runtime vendor migration should add no more than about one second on the same machine; profile/cache only if measured necessary.

**Lighting pass 2026-10-16:** selected indoor fixtures cast bounded shadows,
the house uses cool sky fill and warm practical lamps, and clean plaster keeps
the scanned normal/roughness detail. Lean rendered views of the kitchen,
bedroom and cellar were inspected. W14 still owns the whole-route visual and
frame-time acceptance.

**Done:** evidence and measured budgets support a smooth, readable critical path; reduced settings preserve meaning; no unbounded quality work remains.

### W15 — asset provenance, migration and fallback parity [P0; asset integration agent; split by family]

**Own:** curation tools/manifests and runtime loaders by family; `.gitignore` and exporter changes via their owners. **Depends:** W04; read-only inventory at G0, migration after G3 stable integration.

- Trace active licences for player/animations, character variants actually shipped, audio/music, forest meshes and all vendor content. Resolve D04 with paths and evidence; keep unverified proprietary rights out of the distributed payload.
- Inventory every old imported/derived asset dependency before moving it. Follow errands T13: investigate/report each family, then implement the approved change. Recreate material/collision/transform behavior rather than treating derived `.scn` files as raw FBX.
- Migrate **paper → camp/lake → dream → house/derived loft** in separate reviewable slices of increasing complexity, using runtime loading and preserving fallbacks. Keep manifests/provenance accurate, including stale manifest notes that still name the old errands folder; ensure generators do not overwrite another area's credits. Check nature's existing ignored runtime pack too.
- Do not recursively move/delete old assets until resolved absolute source/destination paths are checked and replacements verified. Keep rollback copies outside tracked content while validating.
- Reimport and run only affected probes/captures after each family; compare startup and player view before/after. Update curation instructions and remove obsolete references only after proving fallback behavior.
- Default public candidate uses redistributable content and fallbacks. A separate local licensed-pack build may be tested, but possession/ignoring/encryption does not establish permission to ship raw files. Do not blindly copy all of `build/vendor/` beside the exe.

**Done:** manifest for the exact candidate explains every shipped asset, no critical path needs the owner's bank, all fallbacks are playable, and no old proprietary resource reference is needed by the release.

### W16 — close the voice inventory [P0 required speech; audio production agent + listener]

**Own:** approved clip/manifest/timing updates, voice status policy by lease; no gameplay rewrite. **Depends:** W02 identity decision and W11 text freeze; inventory/listening can start earlier.

- Recompute missing/draft/current counts; distinguish required speech from deliberately unvoiced dream text and accepted engine choices. Adopt one Mathilda voice identity consistently across the chapter and conversations.
- Complete the current 48 missing Ophelia chapter and 20 missing lake clips, review the six doorway Ophelia drafts, then complete new errand/cups lines. Counts must be refreshed rather than baked as a fixed quota.
- Bake on the capable CUDA machine with committed references/voice lock and frozen requirements. Do not use obsolete `tools/bake_voice.py`, reset reference identity, lower thresholds or use `--accept-bad` without the required explicit decision.
- Archive superseded clips under `build/voice/archive/`; never delete them as a cleanup step. Preserve `SHA-256(text|mood)` naming and generator/post-processing ownership of metadata.
- Reimport, run data/timing checks and clip-required probes that support them. Inspect catalogues not covered by a probe through manifest/file validation and the real conversation runtime.
- Listen to full coherent chapter/meeting paths for pronunciation, voice identity, short-line artifacts, levels, emotion and pauses. WER/similarity and file presence do not approve acting.
- Reconcile `docs/MEETING_VOICE.md` sign-off with the unbuilt preview stage: `dialogue_post.py` has no `--preview`. Prefer recorded in-game path reviews as an explicitly documented substitute for MVP, or implement a bounded preview if the reviewer needs it; do not claim a nonexistent tool produced approval evidence.

**Done:** no unlisted missing required clip, all accepted draft/engine decisions are explicit, timings match current audio, and the exported candidate contains the reviewed clips.

### W17 — reproducible release tooling and current docs [P0; release agent]

**Own:** `tools/export_release.ps1`, `export_presets.cfg`, release documentation/README/TODO; version and changelog edits only when candidate is ready. **Depends:** W01 export inventory, W15 asset policy; final data inventory after W11/W16.

- Honor `$env:GODOT_BIN` or an explicit matching Mono path before PATH scanning. Validate engine version, Mono/.NET support, `OpheliasDream.csproj` and `OpheliasDream.sln`, templates and required runtime layout.
- Prepare build/import/export with explicit exit-code handling. Export from an immutable clean candidate snapshot/worktree, preserving the active dirty workspace and explicitly provisioning only approved local dependencies.
- Audit `include_filter`/`exclude_filter` against every `FileAccess` runtime read. The preset currently enumerates chapter/Mathilda/meeting voice JSON but omits lake voice JSON; lake dialogue refers to it. Verify all dream/errand/voice/timing data in the exported build, not only in the editor.
- Package the exe **and** `data_OpheliasDream_windows_x86_64` into a versioned ZIP with checksums and run instructions. Verify file presence and launch behavior. Do not publish an exe-only artifact.
- Keep the supported unencrypted Mono route. Remove dependence on unnecessary key generation for that route if changing the script; do not start a custom encryption template project.
- Add concise links to this masterplan from README, TODO and current roadmap/direction entry points; retain old plans as labelled history. Correct PATH commands, current modes/line counts, voice source authority, clocks, licences and release instructions. Keep AGENTS/CLAUDE coherent where updates are warranted, noting they are locally ignored.
- Synchronize `project.godot` config/version and export file/product versions, add a factual changelog entry, and use the applicable release/commit skill when that work is actually requested. No commit/tag/push/publication is part of this planning task.

**Done:** a future release operator can produce the complete candidate without choosing the wrong engine, relying on working-tree residue or forgetting runtime data/assets.

### W18 — exported candidate acceptance and MVP handoff [P0; coordinator + fresh release reviewer]

**Own:** final evidence manifest, proposed `docs/mvp/VALIDATION.md`, candidate ZIP under ignored build output. **Depends:** W01–W17 acceptance, G5 freeze.

- Record exact candidate commit, engine/template, version, asset manifest, settings/hardware and SHA-256 of package. Clear developer overrides and use an isolated fresh user-data location.
- Extract outside the source tree. Launch without editor, source checkout or asset bank access. Complete the three title entries, save/quit/relaunch/Continue, each mode's principal ending and chapter return/replay. Verify remaining ending variants against the same candidate.
- Test vendor-absent/fallback distribution and supported lean settings. Confirm lake voice JSON, timings and new errand data actually load. Check all files needed by C# are inside the package.
- Review all outstanding defects. Block on crashes, softlocks, data loss, unreachable advertised content/endings, missing required assets/data/speech, unreadable required text or unresolved asset eligibility. Minor cosmetic defects may remain only with location, impact and a recorded disposition.
- Prepare release copy and handoff: what the player does, controls, how saves work, supported platform/settings, non-commercial/credits policy and known minor limitations. Keep production internals out of player-facing flow.
- If later authorized to publish: use current signed release rules, check every branch/tag/upload result, and confirm the remote asset is complete. Do not reuse historical hard-coded versions, branch assumptions or identities from HANDOFF.

**Done:** fresh reviewer reproduces the packaged game acceptance, every gate has evidence, and the user receives a complete candidate plus a short truthful validation record. Publication is a separate action unless explicitly included in that later task.

## 7. Scheduling shared work without conflicts

| Shared surface | Exclusive owner while active | Integration rule |
| --- | --- | --- |
| `game.gd`, `run_save.gd`, `main.gd` | Coordinator/state owner | Feature agents provide requested fields/hooks; owner applies and verifies phase/save changes |
| `errands.gd` and errand world placement | Current errand integrator | Complete W07, then serialize W08/W09/W10 builder integration; helpers and probes can be prepared separately |
| `player.gd`, C# modifiers, `stride.gd` | Current interaction/motion owner | Preserve active bow work; no concurrent carry/lamp/acting edits |
| `tune.gd`, settings/input, Loudness | Coordinator or explicitly leased owner | Batch agreed constants/actions without racing edits; preserve existing dirty values |
| Story docs, `dream.json`, meeting/lake JSON | Narrative integrator | Writing review first; one data owner; generated outputs come from the same approved source |
| Voice manifests/timing/generator outputs | Audio production owner | No simultaneous bakes/post-processing/Studio writes to a catalogue |
| Vendor loader, provenance, export preset | Asset owner then release owner by lease | Nature, legacy migration and packaging consume one agreed path contract |
| `.godot/` and windowed GPU work | Coordinator's engine slot | No parallel imports, probes, exports or captures, even across agents |

Example next dispatch after accepting this plan: W01 coordinator establishes baseline; one worker audits W02 story decisions; one inventories W04/W15 loader/assets; one prepares W03 interaction triage. After G0, assign implementers to W03/W04/W05 with shared-file leases. Review each package before starting its dependents. Do not dispatch all eighteen packages at once.

## 8. Verification matrix and commands

### Route and ending coverage

| Surface | Required cases |
| --- | --- |
| Title/session | Fresh Dream, fresh Ophelia, fresh Mathilda; Continue for each; settings; quit; return; replay; no developer environment overrides |
| Dream | Walk and sprint; stop/backtrack/leave station; privacy; repair; explicit rupture; incomplete observations; all six memories; complete/unresolved/ruptured wake; replay with prior completion |
| Ophelia base | House/cellar; leave/return evidence; no pages; below minimum at lake; minimum pages without meeting; all trail pages plus solved final page; turning after final page; lookout checkpoint |
| Ophelia endings | `road` (displayed as The lake), `prints`, `gone`, `together`, `shore`; all-deciphered text variants; none requires optional errands |
| Mathilda | Cups/gloves/note/fire/mend; Wait (`wait`); Return; doorstep `home` and `step`; accepted boundary, refusal/leave and conversation recovery |
| Optional systems | Each errand alone and all together; ignore all; let go; no-passing and up-to-three passings; no inaccessible topic or blocking keepsake |
| Body/interaction | Rebound keys and controller; hold interruption; heavy/light carry; bow/lantern/lamp priority; leap/slide/stairs/slopes; lost/dropped item recovery |

### Restoration coverage

Use pairwise combinations where sensible, but always cover every story commit boundary. Do not multiply every cosmetic setting by every save case.

| Save point | Must survive full scene rebuild + Continue |
| --- | --- |
| Chapter traversal | Seed, mode, transform, movement, time/weather, read/solved pages, lantern/bow/arrows, encounter count |
| Dream | Completed cue; mid-line; reply menu; journal; reveal; figure motion; quiet interval; clearing; before/after final choice; wake |
| Conversations | Lake and doorstep actor present; mid-turn/choice; optional topic used; leave/reenter; committed ending not awarded twice |
| Errands | Carrying armful; partial woodbox; cup placed; kettle progress; three wound snags; glove loose/held; cupboard open; sign brushed; lamp lit/dropped/partly empty; consumed tin |
| Checkpoint | Repeat relevant chapter/errand cases through actual lookout restart; no ghost objects or changed story prerequisites |
| Recovery/reset | Damaged primary → valid backup in test profile; failed write retains last good save; new run resets run-only state; mode change clears carry/errands; completed-dream memory survives appropriately |

### Existing command catalogue

Run from repository root in PowerShell using the matching Mono executable. Check native command exit codes explicitly. Save/restore any prior environment values when scripting checks. These commands are future checks except the lightweight results recorded in section 3.

```powershell
dotnet build OpheliasDream.csproj
& $env:GODOT_BIN --headless --path . --import

python tools/script_to_lines.py --check
python tools/bake_mathilda.py --check
python tools/bake_lake.py --check
python tools/bake_meeting.py --check
python tools/dialogue_post.py --check
python tools/voice_status.py

# Run individually, with the engine slot reserved.
& $env:GODOT_BIN --headless --path . tools/dream_story_probe.tscn
& $env:GODOT_BIN --headless --path . tools/dream_flow_probe.tscn
& $env:GODOT_BIN --headless --path . tools/journal_probe.tscn
& $env:GODOT_BIN --headless --path . tools/voice_probe.tscn
& $env:GODOT_BIN --headless --path . tools/dialogue_probe.tscn
& $env:GODOT_BIN --headless --path . tools/meeting_probe.tscn
& $env:GODOT_BIN --headless --path . tools/mathilda_probe.tscn
& $env:GODOT_BIN --headless --path . tools/encounter_probe.tscn
& $env:GODOT_BIN --headless --path . tools/ending_probe.tscn
& $env:GODOT_BIN --headless --path . tools/checkpoint_probe.tscn
& $env:GODOT_BIN --headless --path . tools/hold_probe.tscn
& $env:GODOT_BIN --headless --path . tools/carry_probe.tscn
& $env:GODOT_BIN --headless --path . tools/errand_probe.tscn
```

When a probe requires a playing world, temporarily use `RUN_PLAY=1`; inspect its setup rather than globally assuming every probe needs it. Use `PROBE_CLIPS=1` for voice/journal checks that implement it once W16 is complete; structural checks passing without clips do not close the audio gate.

Repeat `dream_flow_probe` with `RUN_DREAM_PACE=sprint` in addition to its default walking run. Repeat `encounter_probe` with `PROBE_CHAPTER=mathilda` as well as its default Ophelia chapter. Restore these environment values after each case. Apply W01's timeout/PASS-marker/error-log rules to every probe invocation.

Target additional checks to the changed owner: `note_access`, `house_space`, `house_sound`, `house_domestic`, `house_loft`, `traversal`, `leap`, `biome`, `flora`, `biome_effects`, `performance`, `bow` probes and the standalone leap math script. Review `tools/*_probe` setup before treating a stale fixture as a product failure. No surviving `run_sequence_probe.tscn` was found for the old threat plan; do not call it as a current gate.

**New diagnostics to implement with their features:** loader, verbs, warm-house, cups, thread, lamp, errand-save and mode-restoration cases described above. They are proposed deliverables, not currently runnable commands. Prefer focused additions to existing probes where ownership makes that clearer than another scene.

**Visual tools:** use `tools/dream_view.tscn`, `camp_view.tscn`, `lake_view.tscn`, `terrain_view.tscn` and startup hooks for composition evidence, plus proposed errand views. A staged image does not replace a continuous player-input run. Windowed captures are serialized and inspected, not merely generated.

## 9. Risk register and scope cuts

| Risk | Early signal | Response |
| --- | --- | --- |
| Building on broken hold/carry | Historical HOLD FAIL or current compile/cancellation failure | Stop dependent errands at W03; isolate the foundational bug |
| Errands appear complete because framework exists | Empty `ensure_built()` World or only dev-hook journal progress | Require discovery-to-payoff recordings and real restore, not state-only screenshots |
| Optional content changes ending eligibility | Raw journal count, new NoteCatalog entry or errand-only smudge key | Test with/without each optional item; preserve explicit story-page semantics |
| Restore serializes state but cannot recreate actors | Lake/doorstep dialogue has no target after load | Rebuild actors/tree/controller before applying turn state and presentation |
| Loader migration breaks scale/materials/cold startup | Oversized prop, missing ORM, >~1 s load regression | Compare one family at a time; cache only measured costs; keep fallback/rollback |
| Export passes but runtime JSON is absent | Missing lake voice/timing/data from PCK | Audit runtime FileAccess paths and test packaged scenes; include-filter fix is not sufficient by itself |
| Voice work grows after every writing pass | Repeated text/mood changes after baking | Freeze current content at G3; inventory first, bake only changed/current IDs |
| Visual ambition reopens the whole game | New shaders/terrain/rig/motif framework proposed without a defect | Finish current scenes; defer general redesign; every addition names a visible MVP need |
| Shared-work collisions | Two agents edit Tune/player/Errands or run Godot together | File leases and one engine slot; review baseline after external changes |
| Licence uncertainty delays public distribution | Contradictory README/animation/source rights | Keep non-commercial constraint, resolve active assets, ship verified fallbacks where appropriate |

**Cut order if G0 estimates exceed capacity:** new Studio branch/timeline tools → broad dream-runtime extraction → extra optional scene gestures/landscape dressing → new motif variations → entire nonessential errand packages chosen at G0. Preserve navigation, complete chapter arcs, one domestic slice, saved-state correctness, legible UI, required speech/data, asset eligibility and exported-build proof.

**Explicitly after MVP:** lethal threat replacement and lore restoration; combat/bow progression; larger world/new regions; new chapters/endings beyond fixes; character roster/customization/garment expansion; major animation-system rebuild; procedural narrative; voiced dream; full Studio timeline/branch simulator; commercial relicensing campaign; encryption/custom engine templates; other platforms and storefront systems. Existing tools remain available without becoming launch requirements.

## 10. Live gate record and handoff

Update this section after evidence is reviewed. Keep package details above as the stable contract; record changes to scope/decisions with a date and reason.

| Gate | State at plan creation | Evidence / next action |
| --- | --- | --- |
| G0 contract | Pending; **W01 headless baseline done 2026-10-15** | [docs/mvp/BASELINE.md](docs/mvp/BASELINE.md): every headless probe passes with its documented command except the flora time budget (D-7, remeasure); hold failure not reproduced; meeting assertion was a dev-hook placement bug, fixed. Fixed since: export lake JSON in the preset (D-1), Esc menu under dream overlays (D-13). Open: export vendor paths (D-2), probes writing the real save (D-6), labels through walls (D-14, needs a decision). **W02 contract drafted 2026-10-15:** [docs/mvp/STORY_CONTRACT.md](docs/mvp/STORY_CONTRACT.md) (ending requirements from code, D02 no contradiction, D03 real, D10 already live via house documents). Still to do for G0: the owner's answers to its section 8 |
| G1 foundations | **Reached 2026-10-15** | W03: `tools/interaction_probe.tscn` (real input: pick, place, drop; hold vs pause and freed target; lantern vs carry; slope drop) passes, with carry/hold/errand/bow probes. Fixed: the lantern and a carried thing shared her right hand (`player.gd` `toggle_lantern`/`pick_up`, `carryable.gd` refusal text); `bow_probe` now sets `RUN_PLAY`. **W05 done 2026-10-15:** `tools/dream_branches_probe.tscn` (all six answers kept, a closed question ignores a late answer, repair clears strain, escalation ruptures), `dream_flow` walk/sprint, `dream_story`, `dream_pause` and Studio tests pass. Fixed: dream reply rows stretched over each other at the real font (`PanelContainer` → `Panel`) and the guidance overflowed its box (measured, not estimated) in `dream_experience.gd`; lean and no-screen-effects captures inspected. Full-graphics captures are left for a discrete-GPU machine. **W04 done 2026-10-15:** one vendor path contract (`build/vendor/` developing, `vendor/` beside the exe, `RUN_VENDOR=off`), `tools/vendor_probe.tscn` both ways, and `RUN_SELFCHECK=1` for packaged builds; a release export loads the pack and falls back without it, and all runtime data loads. Fixed: flowers fell back to boxes without the pack (D-16), the export crashed on quit with the pack (D-17). Remeasured D-7 (cold builds over budget, W14). **G1 complete; G2 subsequently reached with W06/W07.** |
| G2 domestic slice | **Reached 2026-10-15** | W06: `scripts/errands/` `HouseDrawer`, `Brushable`, `SnowBranch`, `WarmSpot`, `Bell`, `ErrandKit`; `Errands` places the lookout bell (on its own post in front of the tower, within reach) and warm spots at the stove (once lit) and the campfire; `Player.warming`/`warmth` (crouch on an active hold, cold lines wait, breath slows), `Voice.answer_bell` (subtitle *Here.* until the line is approved and baked), `Wildlife.flump`, `Game.wildlife`. `tools/verbs_probe.tscn` passes (34 checks) with the house, page-reach, ending, checkpoint, journal, voice, errand, carry, hold, interaction, bow, Mathilda and meeting probes. Fixed: `Errands.capture/restore` called freed pieces. Errand assets curated into `build/vendor/requested_errands/`. **W07 done 2026-10-15 — G2 reached:** `scripts/errands/warm_house.gd` (woodpile under the eaves right of the door, one armful at a time; woodbox by the stove takes three and stacks them; the stove refuses "No wood in the box" until full, which teaches the errand; lighting it finishes it; the warm ground floor settles the haunting). `tools/warm_house_probe.tscn` passes as is, with `RUN_VENDOR=off` and in Mathilda's chapter (stove lights at once), through two real `RunSave` save/loads (carrying the third armful with two boxed; after completion). `Chore` gained `gate`/`blocked`/`restore_done`, and the stove's lit state is now saved. `house_space_probe` updated for the gated stove. G3 is active; W08 and W09 are complete |
| G3 feature complete | In progress; **W08/W09 done 2026-10-17** | W08 vendor/fallback, save/load, rendered placement and real lake exchange verified; six clips deferred to W16. W09 route, keepsake exclusion, glove recovery/camp placement and player-height link views verified with `tools/thread_probe.tscn`; three new clips deferred to W16. Next W10/W11; freeze writing and refresh voice debt. |
| G4 state/content lock | Pending; **W12 D-19 closed 2026-10-17** | Window latch and front-door jam/open pose now survive real save/load and lookout restart; `warm_house_probe` and `checkpoint_probe` pass under isolated user data with vendor fallbacks. W12 still owns the rest of the restoration matrix; W15 provenance/migration and W16 required audio remain. |
| G5 candidate quality | Pending | W13 continuous runs, W14 presentation/performance, W17 reproducible packaging/docs |
| G6 accepted MVP | Pending | W18 extracted-package review and final validation record |

G2 is reached and W08/W09 are complete. W09 passes its thread probe;
G3 remains active for W10 storm lamp and W11 chapter connections. Serialize their changes
to Errands and obtain the remaining story approvals before generating those
lines. The W01 foundation audit is already recorded in BASELINE.md. The
window/front-door restore fix from W12 is complete ahead of W09 so the thread's
window entry can survive a rebuilt run. Keep the walk animation unchanged.
