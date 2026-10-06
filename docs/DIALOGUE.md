# Dialogue bubbles

`Game.dialogue` renders a transparent UI texture on a camera-facing 3D plane.
During play it displays the current spoken line. Journal, reader and ending
subtitles keep their existing screen placement. Response turns keep the world
running while locking movement and look; Escape cancels and restores play.

Open a turn with a speaker, line, up to five response dictionaries, an optional
world target, and an optional callback receiving the chosen response ID:

```gdscript
Game.dialogue.open("Mathilda", "What do you keep now?", [
	{"id": "return", "text": "Return to Ophelia"},
	{"id": "wait", "text": "Wait with the light"},
], null, _on_response)
```

Responses can include `disabled: true`. IDs should be unique per turn. The
callback may open another turn. `response_selected` and `cancelled` signals
allow other systems to observe the result. An optional Node3D target positions
the bubble near that character or object while keeping it within the view.

Mouse hover/click, up/down or W/S, controller navigation, Enter and the
rebindable interaction action select responses. Mathilda's camp decision uses
this system.

Run `godot --headless --path . tools/dialogue_probe.tscn` for lifecycle checks.
Set `DIALOGUE_SHOT` to an absolute PNG path and run the same scene with a window
for a rendered preview.
