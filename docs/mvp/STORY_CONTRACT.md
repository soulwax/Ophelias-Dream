# MVP story contract (W02)

Drafted **2026-10-15** for [MASTERPLAN.md](../../MASTERPLAN.md) package W02. The scripts of record stay where they are ([MATHILDA_STORY.md](../MATHILDA_STORY.md), [MATHILDA_POV.md](../MATHILDA_POV.md), [MATHILDA_MEETING.md](../MATHILDA_MEETING.md), [LAKE_MEETING.md](../LAKE_MEETING.md)). This file records what the code actually requires, where the story and the simulation disagree, and what the owner has to decide before W07–W11 write or wire anything. **Nothing here changes a line of the script.** Items marked *proposal* are the agent's recommendation, not an approved decision.

## 1. Story bible

| Authorial fact | What a character believes or says | Evidence the player can see | Left open on purpose |
| --- | --- | --- | --- |
| Ophelia and Mathilda argued; Ophelia said *go, then*; Mathilda left with the pack | Ophelia: it was her fault. Mathilda: she was waiting to be stopped (lake m10) | Intro card; the bedside page; the lake and doorway talks | Whether Mathilda is a separate person, a shadow, dead or alive |
| Both are Aunes; the photograph holds one or two of them depending on who looks | Each remembers being in it, neither taking it | The hall photograph; Mathilda's copy in her pack | What they are to each other |
| The lights at the lookout are two lanterns on a rail; there is no car and no road | Mathilda's pages promise an engine and a road (m02: *I didn't know what else would get you this far*) | The lookout up close; posts lead on to the lake | — |
| The old hole in the lake ice is where *one held still and one pulled* | Ophelia: *You did. I pulled you out.* Mathilda: *That's how you tell it.* | Prints to the hole; the lake talk | Which of them went through |
| Under the cellar sheet is a coat, buttoned to the throat | The clerk records a body, *exposure*, one cup | Intake form; the morgue | — (m16 says so; the game never shows it) |
| Ophelia's day moves: 14:30 to 14:30 next day over 40 real minutes | Mathilda's page: *the light has not moved… same afternoon* | Sun, dusk, night and dawn in her chapter | Whether time out there is the same for both (see section 2) |
| Mathilda was raped by a lumberjack before either chapter (author's canon) | She has trouble finding words and apologises for that, never for what was done to her | Only the dream's closing warning that he is still nearby | Never staged, named outside the dream, described or explained |
| Mathilda's choice is her own: return or wait | Ophelia offers tasks; Mathilda stops her (doorway) | Return/Wait at the tent; *Ask me properly* on the ice | Whether returning is healing or another kind of staying |

Boundaries that every package must keep: consent before comfort (no embrace or absolution before the shopping-list admission; *Ask me properly*), silence is a valid answer, the lumberjack belongs to the dream only (the errands spec already forbids staging it), and the trees answer only in Ophelia's voice.

## 2. The two clocks (D02, D03)

**D02, Ophelia: no real contradiction.** The script of record already says her afternoon *starts to move* (MATHILDA_STORY *The story*, para. 6), and the code agrees (`game.gd:536` `start_day()`, `Tune.OPHELIA_START` 14.5, `DAY_MINUTES` 40, day-out at `game.gd:558`). The only frozen-afternoon text in her chapter is the *On the post* page, which Mathilda wrote: a character's belief, and it reads as intended dramatic irony against a moving sky. Stale copies of the old claim survive only in historical files (`assets/audio/voice/manifest.json` *The light hasn't moved. She was right.*, not in current `lines.json`; `docs/MATHILDA_PLAN.md`, the 2026-10-06 story plan and spec). **Resolution:** keep the moving clock; label those historical files in W17. Nothing to rewrite.

**D03, Mathilda: a real contradiction.** Her chapter starts the clock at `Tune.MATHILDA_DUSK` (17.3) and runs it (`mathilda_pov.gd:58`), so dusk visibly deepens while she works the camp, yet:

- she says *Same afternoon. I have been waiting through the same afternoon.* (MATHILDA_POV, shaken);
- both doorway endings say *Outside, for the first time since you left, the light moves.* (`mathilda_pov.gd:5-6`, MATHILDA_MEETING *Endings*);
- the Wait ending says *It is still the same afternoon.*

The doorway framing names this exact change as the closure (*What changes is the frozen afternoon*), so it is the design and the clock is the accident.

*Proposal (D03-A, recommended):* hold Mathilda's light still at her dusk hour for the whole chapter (`Atmosphere` already has `clock_running`; set the hour without running it), and start the clock only when a doorway ending begins, so the end card's *the light moves* is literally true on screen. Wait keeps it held. This touches one call in `mathilda_pov.gd` and leaves Ophelia's chapter untouched.
*Alternative (D03-B):* keep the moving dusk and reword three lines to subjective imagery (e.g. *for the first time since you left, it feels like evening*). Costs script, generator and voice changes for Mathilda's identity-critical lines.

## 3. Endings and what they require

Exact conditions from the code. *Base route* means pages, places and the walk; no optional content.

| Ending | Mode | Requires | Where | Reachable on the base route |
| --- | --- | --- | --- | --- |
| `road` (card *The lake*) | Ophelia | At the hole, not `meeting_waiting`, `journal.size() >= 3`, never turned around | `game.gd:165-170` | Yes |
| `prints` (*One set of prints*) | Ophelia | As `road`, after turning around (glance-back held `TURN_HOLD` 1 s outdoors after the last page) | `game.gd:170`, `turn_around()` `:522` | Yes |
| `gone` (*Mathilda is gone*) | Ophelia | 24 h of her day (40 real minutes awake, outside dialogue) without an attempt | `game.gd:558-575` | Yes; also fires while Mathilda waits on the ice |
| `together` / `shore` | Ophelia | `meeting_ready()`: all five trail pages read, the last page's smudges solved (keys: lights visited, *On the post* read), never turned around; then the lake talk's last exchange | `game.gd:580`, `lake.gd:64`, `assets/dialogue/lake.json` | Yes; no errand involved |
| `home` (*Walk beside me*) / `step` (*On the step*) | Mathilda | All five camp objects done (cups, gloves, note, fire, mend) → Return → doorway talk to line 24 / a11 | `mathilda_pov.gd:258`, `assets/dialogue/meeting.json` | Yes |
| `wait` (*With the light*) | Mathilda | All five camp objects done → Wait | `mathilda_pov.gd:252-267` | Yes |
| complete / unresolved / ruptured wake | Dream | `assets/dialogue/dream.json` `ending`, `unresolved`, `ruptured`, with `repair` | `dream_experience.gd` | Walk to waking verified by `dream_flow_probe` (walk, sprint); each outcome class still needs its own check (W05) |

Turning around after Mathilda appears on the ice removes her (`lake.gd:108`), so `together`/`shore` become `prints`.

## 4. Invariants optional content must keep

1. **No optional action gates an ending.** The meeting's last-page keys are base-route events; W08 must not move a mandatory smudge onto `event:cups` (the errands spec says *for the smudges that ask for it*; none does today).
2. **The lake minimum counts story pages only.** *Finding:* it counts the raw journal (`game.gd:169`), and `add_to_journal()` (`:434`) adds every read entry, including the four house documents (bedside note, grate note, photograph, intake; `NoteCatalog.everything()`, `counts = false`) and records. Today **three house documents and no trail page already pass the minimum**, and the errands' *The thread* keepsake, designed with `counts = false` *so it never counts toward LAKE_PAGES*, would count too. *Proposal (D10-A):* count entries with `counts == true` (that is `notes_found`, already tracked and checkpointed), so the minimum means three trail pages. *Owner question:* should the bedside note, which is in Mathilda's hand, count as one of the three? If yes, mark it `counts = true` deliberately rather than relying on the raw count.
3. **Mathilda's camp chores are not optional.** Return and Wait both need all five objects, including *feed the fire* and *fix the guy-line*. That is consistent with the MVP (they are the chapter's activities, not errands), but W11 should keep them short and impossible to miss.
4. **The dream cannot lock a chapter.** Its memory reaches the chapters only as one reflection line and visual landmarks (`main.gd:268`, `dream_reflection.gd`, `dream_memory_architecture.gd`); no dialogue condition reads it. W12 lead: `run_save.gd:365` stores `dream_memory`/`dream_completed` inside the rolling run snapshot, so loading an older run may roll back the in-memory dream state.
5. **Passings only add topics.** `passed` opens lake o20/m23 and doorway a16/a17; zero passings leaves every ending reachable.
6. **Errands live only in Ophelia's chapter**, are let go (not failed) when she turns around or the day ends, and never call `catch_player`.

## 5. Optional content → conversation

| Source | Flag / key | Opens | State |
| --- | --- | --- | --- |
| Trail and house pages read | `pack`, `post`, `torn`, `handwriting`, `intake`, `bed` (`lake.gd:96`) | Lake side topics o06–o13, o19 | Present |
| A passing happened | `passed` | Lake o20/m23; doorway a16/a17 | Present |
| Mathilda's camp objects | `gloves`, `note` (+ `cups`, `fire`, `mend` set but unused) | Doorway topics | Present |
| `two_cups` done | `event:cups` known; `cups` lake flag | Lake cups topic | **Missing**: topic, lines, and the runtime flag (`Lake` must set it; JSON alone is not enough) |
| `red_thread` done | keepsake *The thread* | Journal only; glove at the camp | Missing |
| Bell rung | — | Echo *Here.* from the trees, Ophelia's voice | Missing |

## 6. Accidental contradictions and bounded fixes

| ID | Contradiction | Fix | Owner |
| --- | --- | --- | --- |
| C1 | Mathilda's moving dusk vs *the light moves for the first time* / *same afternoon* | D03-A or D03-B (section 2) | Owner decides; W11 implements |
| C2 | Lake minimum counts house documents and future keepsakes | D10-A (section 4) | Owner decides; W12 implements, W09 depends |
| C3 | Page labels (`page`/`note`/`record`) show through walls (`field_note.gd`, `no_depth_test`), against *no markers* in DIRECTION and the errands spec | *Proposal:* keep the label but depth-test it and show it only within reading reach | Owner decides (BASELINE D-14); W14 implements |
| C4 | Mathilda's chapter shows controls on screen (*Esc: return to menu . E: feed the fire*) against *controls are not shown on screen*; Esc there returns to the title instead of the Esc menu | *Proposal:* use the interact prompt like Ophelia's chapter and give Mathilda the normal Esc menu | W13/W14 |
| C5 | Historical docs still describe the frozen afternoon, Mara, the hunter, the road escape | Label as history and link here (MASTERPLAN W17) | W17 |

Intentional and kept: Mathilda's *same afternoon* page in Ophelia's chapter (belief vs. a moving sky); *the trees answer in her own voice*; prints that differ by whether she turned; the photograph that holds one or two.

## 7. Writing W07–W11 will need

Approve IDs, moods and flags before any generator runs (MASTERPLAN W02). Counts are slots, not drafts.

| Package | Slot | Script home | Proposed IDs / moods |
| --- | --- | --- | --- |
| W06/W11 | Bell echo *Here.* (spec text, Ophelia's voice) | MATHILDA_STORY `### The trees answer` | `answers/bell`, steady |
| W07 | Stove: *no wood in the box*; first armful; stove lit | MATHILDA_STORY `### Errands` (new) | 3 lines, existing moods |
| W08 | Cupboard: one cup missing; cup found on the porch; both on the table; kettle | same | 4 lines |
| W08 | Lake cups topic (one Ophelia line, one Mathilda line) | LAKE_MEETING *Lines*, `lake.json` (`requires: ["cups"]`), `bake_lake.py` | `o21` warm / `m24` hushed |
| W09 | Thread: first snag; winding; the birch and the glove; *The thread* keepsake page | MATHILDA_STORY `### Errands`; keepsake prose in `errands.json` | 3 lines + 1 page |
| W10 | Oil found; lamp lit; lamp low; lamp out | MATHILDA_STORY `### Errands` | 4 lines |
| W11 | *Let go* journal prose for each errand | `errands.json` | 4 prose lines, no voice |

**W08 approved by the owner on 2026-10-15:** the following six lines, IDs,
moods and the optional completed-`two_cups` flag `cups`. Other writing slots
in the table above remain pending.

| Group | ID | Mood | Approved text |
| --- | --- | --- | --- |
| Ophelia errands | cups_missing | steady | One cup. Where’s the other? |
| Ophelia errands | cups_found | warm | You left it out here. |
| Ophelia errands | cups_set | warm | Both cups, this time. |
| Ophelia errands | cups_kettle | warm | The kettle’s on. |
| Lake Ophelia | o21 | warm | Both cups are on the table. The kettle’s on. |
| Lake Mathilda | m24 | hushed | Both. You never set out both at once. |

This keeps m06 (*you only ever set out one for yourself*) true. The pair stays
on the table after completion so the lake exchange remains true. New recordings
are W16 debt; approved text can play as subtitles until those clips exist.

## 8. Decisions

Answered by the owner on 2026-10-15:

| # | Question | Decision | Consequence |
| --- | --- | --- | --- |
| 1 | D03 Mathilda's light | **Keep the moving dusk; reword** | Draft rewordings for the three lines (section 9) for approval; the voiced *Same afternoon* line becomes voice debt once approved (W16) |
| 2 | D10 lake minimum | **Any journal entry counts** (today's code) | House documents keep counting. W09 must keep *The thread* keepsake out of the count explicitly (it is designed not to count), and W12/W13 test the minimum with and without it |
| 3 | C3 page labels | **Depth-test plus reach** | Implemented in W02 (`field_note.gd`) |
| 4 | D01 `docs/THREATS.md` | **Drop the references** | Removed from CLAUDE.md, AGENTS.md and MASTERPLAN in W02 |

Still open: approval of the W06/W07/W09–W11 writing slots and IDs in section 7,
and the D03 rewordings in section 9. W08's six lines and completed-cups flag
are approved above. None of these remaining decisions blocks W08 mechanics.

## 9. D03 rewordings (draft, not approved)

The light keeps moving, so the lines claiming it never did become subjective. The relationship beat stays: *the light* is what changes for her, not the sky.

| Where | Now | Draft |
| --- | --- | --- |
| MATHILDA_POV (shaken), voiced, final clip | *Same afternoon. I have been waiting through the same afternoon.* | *It's getting dark. I've been waiting so long it all feels like one afternoon.* |
| Doorway endings *Walk beside me* and *On the step* (card text) | *Outside, for the first time since you left, the light moves.* | *Outside, the dark comes down, and for the first time since you left it doesn't matter.* |
| Wait ending *With the light* (card text) | *It is still the same afternoon.* | *It gets dark around the window, and it is still the same afternoon.* |

Synchronise on approval: MATHILDA_POV, MATHILDA_MEETING *Endings* and its *Closure* paragraph, `mathilda_pov.gd` `ENDINGS`, `assets/audio/voice/mathilda/lines.json` via `tools/bake_mathilda.py`, then the clip (W16).
