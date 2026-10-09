# Dream atmosphere without staged memory scenes

Direction updated 2026-10-09. The dream does not instantiate flashback scenes or scene-specific assets. There are no memory doors, lighthouse/cabin vignettes, or reflected rooms beneath the ice. Story moments are cued along the existing winter route through subtitle dialogue and journal entries.

## Current design

- Keep the playable forest route, Mathilda's shadow figure, free running, the existing journal, and all three ending outcomes.
- Let trail progress cue three authored story events: the sisters, the red thread, and the warm-window warning. These cues deliver dialogue and journal material without changing the world into a separate scene.
- The first two small-talk rounds can follow the thread and warm-window dialogue. If the player runs past a cue, queued subtitles stay sequential and the closing conversation offers any round that was not heard.
- Preserve the folded snow path and sparse ground shadows as dream-native distortions. They are part of the continuous route, not memory scenes.
- `DreamRoute.cue_requested` is the extension point for future authored visuals or other events. No listener currently spawns scene assets. A cue may be connected later without restoring automatic scene changes.

## Story and event rules

1. Ordinary winter details lead into each subtitle event.
2. Mathilda speaks alone; each line and player choice resolves before the next turn.
3. Movement cues stay small: a measured step, a look toward the trees, or a held pause. Dialogue remains readable if the player is moving quickly.
4. Each story cue records its journal entry once. The warning requires the warm-window clue and one other event; pressure can still lead to the ruptured outcome.
5. Future visual cues are optional, localized, and must not obstruct the linear route or replace the subtitle/journal clue.

## Implementation slices

| Slice | Status | Notes |
| --- | --- | --- |
| Remove staged scenes and assets | Implemented | Route builders, door props, under-ice scene shader, memory sound clips, and scene capture references are removed. |
| Trail event cues | Implemented | `dream.json` stores three route offsets and authored lines. Runtime emits `DreamRoute.cue_requested` for future optional listeners. |
| Dialogue distribution | Implemented | Thread/window rounds are event-driven, remain sequential, and are skipped at the close only after they were actually completed. |
| Visual and route review | In progress | The folded path remains; verify the normal player camera, reduced effects, journal/pause, and all wakeup outcomes in a complete run. |

## Review gates

- Confirm no dream event instantiates a memory scene or asset.
- Walk slowly, run through all three cue offsets, and backtrack. Subtitles must queue in order and never overlap.
- Open and close the journal during a cue and during a choice; verify the current event and the next response remain available.
- Try the warm-window clue with and without one other cue, plus the ruptured conversation. Confirm each ending and journal note remain legible.
- Capture the route with normal and reduced visual effects. The folded path should read as impossible only through perspective and movement, while the playable ground remains clear.
