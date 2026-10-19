# Dream playability and release pass

The dream is one playable walk, not a sequence of menus or separate flashback levels. This pass closes the gap between crossing a cue, hearing Mathilda, seeing its landmark, replying, and waking. The route remains freely walkable between conversations, with unlimited sprint.

## Player rhythm

| Passage | Player understands | Required handoff |
| --- | --- | --- |
| Threshold | Follow the trail and listen; J opens the separate dream journal. | First line and figure appear before later cues can overtake them. |
| Sisters and thread | The recurring images are clues, not objectives. | Each cue waits for its own subtitle, landmark and optional reply. Dark patches leave a breath between scenes. |
| Warm window | Distance and permission matter; the window is a clue. | The window becomes visible with the warning line, then the second talk station can be answered or passed. |
| Clearing | Mathilda needs an answer, then the dream ends. | Pending lines and stations drain in order; arrival, optional small talk, final answer and closing line never overlap. |
| Wake and replay | The chosen memory affects later chapters. | Save only after an answer; waking marks completion; replay and pause keep the game usable. |

## Work slices and gates

1. **Trace a full route.** Use a deterministic playthrough on the real dream scene at walking and sprint pace. Record cue, line, station, choice, journal, apparition, wake and phase changes. Find stalls, skips, duplicate dialogue and unreadable camera views.
2. **Repair flow.** Fix the smallest owning functions in `dream_experience.gd`, `dream_route.gd` or the story data. Keep one speaker at a time. A queued cue must not reveal a distant landmark before its line, and reaching the clearing must not discard dialogue. Pausing and journaling must preserve the same place in the sequence.
3. **Visual and audio pass.** Review player camera captures at threshold, lighthouse, window, clearing and warning. Remove construction fragments, hard shader edges, overlapping text and abrupt sound changes. Check the same route in full and lean graphics.
4. **Release gate.** Import and compile with Godot Mono, run the story and flow probes, exercise complete, unresolved, strained and ruptured outcomes, inspect rendered captures, and export Windows with the matching .NET template. Synchronize project and export versions, write short cryptic release notes, sign and push the commit and tag, upload the executable, and confirm the published asset.

Do not release if the route can strand a player, skip a required exchange, lose a chosen memory, display a cue over the wrong place, or produce a broken export. Keep generated captures and build outputs out of Git.

## Execution record

The sprint pace trace preserved all seven cues in order, reached both station exchanges with their own reply sets, kept the journal and pause usable during a subtitle, and made complete, unresolved and ruptured endings reachable. Story cues now drain one at a time with a breath between exchanges. The final warning uses the forest stump asset and a readable axe silhouette.

The shared `SignalGlass` overlay applies a restrained CRT pass to every screen, with occasional brief signal breaks, Japanese record marks and a computer feed label. The Screen Effects setting controls its intensity; the existing paper page remains a paper object.

The follow-up UI pass adds finer phosphor grain, a slow sync roll, corner registration marks and compact compute/record readouts. Japanese status text follows the current phase. The standalone waking handoff now saves completion and consumes the final input before replacing the scene.

Godot 4.7.2 Mono import, the dream flow probe, the story data check, and the C# build passed. The station composition was captured with lean graphics; the warning composition was captured with lean and full graphics. The generated editable level still reports two node type warnings during scene assembly; those did not interrupt the route probe or captures.
