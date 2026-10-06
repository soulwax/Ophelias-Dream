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
this system; Ophelia waits at the door after Return (see Conversations below).

Run `godot --headless --path . tools/dialogue_probe.tscn` for lifecycle checks.
Set `DIALOGUE_SHOT` to an absolute PNG path and run the same scene with a window
for a rendered preview.

# Conversations (Skyrim-style)

A conversation with someone in the world runs a `DialogueTree` through a
`Conversation` and draws it with `ConversationMenu`. The other person's name
sits over the line being spoken on a dark band to the right of the view, with
her topics under it. The bubble above remains for one-off choices.

- **Tree** (`scripts/dialogue/dialogue_tree.gd`, JSON such as
  `assets/dialogue/meeting.json`): `lines` points at a line table (`id`,
  `speaker`, `mood`, `text`, `pause`). Each node `say`s lines, may `sets`
  flags, and offers `choices`. A choice `say`s one of her lines and may get a
  `reply`. It then `goto`es a node, `end`s the conversation, or (with neither)
  comes back to the same topics. `once` topics disappear after use, topics
  already taken stay but are dimmed, and `requires` hides a topic until its
  flags are set. `leave` is always the last topic, and `resume` greets her when
  she comes back. `problems()` lists missing lines and nodes, dead ends and
  unreachable nodes.
- **Runner** (`scripts/dialogue/conversation.gd`): `Conversation.make(path,
  speaker)` then `begin()` from play. It enters `Game.Phase.DIALOGUE`, which
  locks movement and look while the world keeps going.
  - Lines play one at a time, each from its speaker (`head()` on the NPC, her
    own head), followed by the authored pause from `timing.json`. An authored
    overlap cuts in. A missing clip shows the subtitle for a reading time.
  - E, Enter or a click skips a line but leaves a short beat.
  - The view turns to the NPC (`Player.look_toward`), she turns toward Mathilda
    (`face()`), and Ambience and Dread duck to 35% until it ends.
  - Esc leaves at once and the leave topic leaves with words. Either way
    control comes back, and the next `begin()` picks up at the same node.
  - Signals: `line_started(line)`, `ended(ending)`, `left`.
- **Clips**: `<clips>/<sha256(text|mood)>.wav`, then `<clips>/draft/`, then the
  subtitle alone.

The first conversation is the doorway meeting in Mathilda's chapter
(`docs/MATHILDA_MEETING.md`, pipeline in `docs/MEETING_VOICE.md`). After she
chooses Return at the tent, Ophelia (`OpheliaNpc`) waits at the doorstep. E
within 3.2 m speaks to her, and the meeting ends on one of the chapter's end
cards. `RUN_MEETING=1` starts the chapter at the door and `RUN_MEETING=open`
also opens the meeting. Use either with `RUN_MATHILDA=1`, and with
`RUN_CAPTURE` for a shot.

Run `godot --headless --path . tools/meeting_probe.tscn` to play the spine to
"home" and the chapter's meeting with every side topic, a walk-away and a
resume to "step", printing both transcripts.
