# Run Away: finish the run

> The figure and the Listener were removed on 2026-10-05. The steps and the validation record below that rely on them wait for replacements from [THREATS.md](THREATS.md).

Build a short, authored daylight winter horror game. The player leaves a record
with her boots that disagrees with the pages and the mortuary file. Survival
should be understandable; the identities should remain unresolved.

## The playable sequence

1. Wake and explore the existing house. Establish the lantern, the bed page,
   and the cellar before asking the player to understand their contradictions.
2. Leave for the early trail. The Listener teaches that exertion exposes her;
   the house offers a real refuge. Returning remains a choice, not a locked gate.
3. On a return, the mat and the snow disagree with the page. Keep the unusual
   marks long enough to discover them. Never show a clue counter or spawn a body
   to explain the tracks.
4. Past the early trail, the figure takes over. Crossing into the latter route
   starts pursuit even if the player skipped every page. Three pages can start
   it sooner. Reading therefore changes risk without being required to activate
   the game. Only one lethal rule speaks at a time.
5. Reach real headlights, or die by one of the two established rules. Preserve
   the last-page variations and the unresolved identity.

## Implementation pass

- Centralize the hunt transition in Game; advance its clock only during play
  and reading. Use route progress as the fallback trigger, with balance in Tune.
- Make all systems use that hunt state, including the Listener, house and HUD.
- Preserve one wrong outdoor track and the doorway sole through an exploration
  return. Protect those pooled patches from subsequent footsteps. Place the
  doorway mark out of sight and respect the authored house orientation.
- Keep ordinary prints short lived. Freeze print ageing under pause and endings.
- Add an integration probe covering route escalation, optional reading,
  pause/reset, threat handoff, house return, print retention and ending variants.
- Run a clean import, the probe, and a lean rendered smoke capture. Inspect the
  capture; record limitations honestly.

## Scope and completion

One existing house, one existing route, five trail pages, two threats. No new
assets, movement features, explanatory dialogue, or scene regeneration. Preserve
hand-authored scene edits. Update the old task list to point here.

This pass is complete when the listed checks pass and skipping notes no longer
skips pursuit. A first-time human playthrough must still judge whether the return
is tempting and the altered snow is noticed. Measure a first-time run before
setting a duration target; do not stretch the trail simply to meet a number.

## Validation record

Implemented the hunt transition, active-play clock, HUD/house/Listener handoff,
protected evidence patches and unseen doorway placement. Returning from at least
22 m along the early trail now turns the mat; a quick step outside does not. The
wrong track appears after 30 m on a stretch the player can retrace before the
hunt. The doorway sole is larger and darker. The route marker received a targeted
edit in `scenes/editable_level.scn`; the scene and vendor assets were not
regenerated.

Run `godot --headless --path . tools/run_sequence_probe.tscn` for integration
checks. The saved route spans 243.2 m from its start to the exit; the no-page
hunt starts at 85 m. A lean rendered startup capture and headless startup both
completed without runtime errors on Godot 4.7.2. Evidence stays for four
minutes; ordinary tracks retain their original lifetime.

All 27 sequence checks passed, including both hunt triggers, the no-page exit
trigger, hunter catch after Listener handoff while breath is held, early-trail
wrong track, the excursion gate on house return, unseen doorway placement, pool
retention, ending variants, and restart. Local logs and inspected captures are
in `build/validation/` and are excluded from commits. With `RUN_GRAPHICS=lean`,
run `godot --path . tools/return_evidence_probe.tscn` to recapture
the doorway clue from staged close and third-person viewpoints. The darker sole
is visible beside the player at the step, though it remains a small detail
against bright snow. The capture does not prove a new player will notice it.

Initial import restored missing cached textures. The vendor log-pile and bench
FBX files still report unavailable embedded texture paths during import; their
runtime scene wrappers supply existing materials. Those source-asset warnings
remain outside this gameplay pass. Human pacing/discoverability review remains
necessary; the probe validates transitions rather than a player's experience.
