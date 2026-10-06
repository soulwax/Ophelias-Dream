# At the unlatched door: meeting choreography

## Dramatic chain

Mathilda returns from the tent after examining the cups, gloves and note. Ophelia waits outside the cabin. Relief makes Ophelia offer a task (the kettle), which Mathilda stops. Fear gives way to defensiveness, then a precise memory: Ophelia answered a confession with a shopping list. Only after admitting that action does Ophelia offer a different one: sit and listen. Mathilda hands back the cup. No embrace, instant absolution, lore explanation or threat interrupts the exchange.

The encounter belongs to Mathilda’s subjective chapter and does not rewrite Ophelia’s existing endings. Mathilda may still choose Wait at the tent. Return lets the player walk back to the cabin, where Ophelia now waits at the doorstep; speaking to her opens this scene. Movement locks during speech; the world continues. Escape or "I need a minute." leaves, and the meeting picks up where it stopped when she speaks to Ophelia again.

**Closure.** The relationship resolves; the dream's metaphysics do not. Nobody explains the prints, the engine or the sheet. What changes is the frozen afternoon: in both meeting endings, for the first time since Mathilda left, *the light moves*. Wait at the tent is the open ending: *It is still the same afternoon.*

## Staging and sound

Ophelia stands by the door, angled rather than squarely blocking it. She looks toward Mathilda, then lowers her gaze after the shopping-list admission. Mathilda remains in first person. An offered cup appears only after the admission; no physical gesture implies forgiveness before consent. After “Walk beside me”, Ophelia steps aside. Turns never overlap: wait for clip completion plus the authored reaction pause. Dialogue ducks weather and effects while retaining the Voice bus. Cancellation restores all mix values.

Voice chain: existing Qwen-designed Ophelia mood references -> Chatterbox performance; separate Kokoro af_bella Mathilda reference -> Chatterbox performance. Keep speaker conditioning separate. Render a draft sequence first, then candidates, verify words with Whisper and inspect durations/levels. Use only supported controls; extra conversion stages are rejected if they weaken identity or intelligibility. No model ships in the game. Performances and provenance are recorded separately from the exploration clips.

## Spoken exchange

### 01 | ophelia | pleading | 0.30

Action / reaction: relief; reach for a familiar task.

> You're here. Come in. I'll put the kettle on.

### 02 | mathilda | hushed | 0.80

Action / reaction: stop her before welcome becomes avoidance.

> Not yet.

### 03 | ophelia | shaken | 0.35

Action / reaction: fear replaces relief.

> Are you hurt?

### 04 | mathilda | bitter | 0.70

Action / reaction: name the feeling rather than accuse.

> I'm cold. I'm angry. Those are different things.

### 05 | ophelia | breaking | 0.45

Action / reaction: first attempt to undo the action.

> I didn't mean for you to go.

### 06 | mathilda | resolve | 0.95

Action / reaction: answer the actual claim.

> You said go. I needed you to notice that I could.

### 07 | ophelia | hushed | 0.55

Action / reaction: a concrete confession.

> I noticed. I watched the door all night.

### 08 | mathilda | bitter | 1.25

Action / reaction: hurt asks a precise question.

> Then why didn't you open it?

### 09 | ophelia | shaken | 0.90

Action / reaction: give up the excuse.

> Because if you came back angry, I would have to hear you.

### 10 | mathilda | hushed | 1.10

Action / reaction: recognition; not forgiveness.

> Yes.

### 11 | ophelia | breaking | 0.60

Action / reaction: recognize her pattern.

> I kept thinking of what to say. I never thought of what to ask.

### 12 | mathilda | resolve | 0.90

Action / reaction: offer a chance without rescuing her.

> Ask me now.

### 13 | ophelia | hushed | 0.55

Action / reaction: a real question.

> What did you need from me?

### 14 | mathilda | shaken | 1.10

Action / reaction: the specific grievance.

> To let me finish. I said I was unhappy, and you handed me a list.

### 15 | ophelia | hushed | 0.30

Action / reaction: remember the small action.

> The shopping list.

### 16 | mathilda | bitter | 1.25

Action / reaction: explain the wound, not a new mystery.

> You asked if we needed milk. I was trying to tell you I needed you.

### 17 | ophelia | breaking | 1.00

Action / reaction: take responsibility.

> I heard you. I made it smaller because I knew how to fix milk.

### 18 | mathilda | hushed | 0.85

Action / reaction: set a possible boundary.

> You don't have to fix this before you sit beside me.

### 19 | ophelia | resolve | 0.75

Action / reaction: specific promise.

> Then I'll sit. And I'll listen until you're finished.

### 20 | mathilda | warm | 0.55

Action / reaction: show that anger and care can coexist.

> I brought your cup back.

### 21 | ophelia | warm | 0.35

Action / reaction: surprised tenderness.

> You kept it?

### 22 | mathilda | warm | 1.00

Action / reaction: name the distinction.

> I was angry with you. I didn't want you gone.

### 23 | ophelia | hushed | 0.60

Action / reaction: ask instead of reaching.

> May I take it?

### 24 | mathilda | resolve | 1.20

Action / reaction: consent and a small shared action.

> Yes. Walk beside me.


## Branches

The spine above is the conversation's main path: each Mathilda line is the first topic offered at her turn. The lines below are optional topics, the alternative last answer, and leaving. They obey the same rules: no embrace, no instant absolution, no lore, no threat. The tree that joins them is `assets/dialogue/meeting.json` (see `docs/DIALOGUE.md`).

### a01 | mathilda | warm | 0.60

Action / reaction: topic at 01, once; the light she watched from the tent.

> You left the lantern burning.

### a02 | ophelia | hushed | 0.50

Action / reaction: a plain truth, not a plea.

> I didn't know what else to keep lit.

### a03 | mathilda | wry | 0.60

Action / reaction: topic at 03 after examining the gloves, once; deflect with a joke.

> Only my hands. You knitted the gloves too small.

### a04 | ophelia | warm | 0.50

Action / reaction: she remembers the kindness.

> You said they were perfect.

### a05 | mathilda | bitter | 0.70

Action / reaction: topic at 05, once; refuse the easy retraction.

> You said it like you meant it.

### a06 | ophelia | breaking | 0.80

Action / reaction: honesty instead of denial.

> I did. For as long as it took to say it.

### a07 | mathilda | hushed | 0.70

Action / reaction: topic at 07 after examining the note, once.

> I left you a note. It says something different every time I read it.

### a08 | ophelia | shaken | 0.80

Action / reaction: the same unease, unexplained.

> I read it in your voice. Then in mine. So I stopped reading.

### a09 | mathilda | hushed | 0.70

Action / reaction: topic at 13, once; she is allowed not to know yet.

> I'm not sure I know any more.

### a10 | ophelia | hushed | 0.80

Action / reaction: she waits instead of filling the silence.

> Then I'll wait while you find it.

### a11 | mathilda | hushed | 0.80

Action / reaction: the other answer to 23; consent deferred, not refused.

> Not yet. Sit with me out here first.

### a12 | ophelia | warm | 1.00

Action / reaction: she accepts without reaching.

> Out here. All right.

### a13 | mathilda | hushed | 0.50

Action / reaction: leaving the conversation (any turn).

> I need a minute.

### a14 | ophelia | hushed | 0.50

Action / reaction: she does not follow and does not close the door.

> I'll be here. I'm not going in without you.

### a15 | ophelia | hushed | 0.50

Action / reaction: greeting when Mathilda comes back to the conversation.

> Still here. Go on.

## Endings

Shown on the end card after the last exchange.

- **Walk beside me** (24): *Ophelia steps aside, and you go in together. She sits, and she listens until you have finished, and then a while longer. Two cups on the table, one fitted inside the other. Outside, for the first time since you left, the light moves.*
- **On the step** (a11): *You keep the cup a little longer. Ophelia sits down on the step beside you, in the snow, with the door open behind her and nothing to fix. Neither of you goes in yet. Outside, for the first time since you left, the light moves.*
- **With the light** (Wait, at the tent): *You stay at the tent with both cups and watch the window. The lantern stays lit. It is still the same afternoon.*
