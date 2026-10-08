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
Answers: none
Intensity: 0.35

> You're here. Come in. I'll put the kettle on.

### 02 | mathilda | hushed | 0.80

Action / reaction: stop her before welcome becomes avoidance.
Answers: 01 "I'll put the kettle on."
Intensity: 0.30

> Not yet.

### 03 | ophelia | shaken | 0.35

Action / reaction: fear replaces relief.
Answers: 02 "Not yet."
Intensity: 0.45

> Are you hurt?

### 04 | mathilda | bitter | 0.70

Action / reaction: name the feeling rather than accuse.
Answers: 03 "Are you hurt?"
Intensity: 0.60

> I'm cold. I'm angry. Those are different things.

### 05 | ophelia | breaking | 0.45

Action / reaction: first attempt to undo the action.
Answers: 04 "I'm angry."
Intensity: 0.70

> I didn't mean for you to go.

### 06 | mathilda | resolve | 0.95

Action / reaction: answer the actual claim.
Answers: 05 "I didn't mean for you to go."
Intensity: 0.65

> You said go. I needed you to notice that I could.

### 07 | ophelia | hushed | 0.55

Action / reaction: a concrete confession.
Answers: 06 "I needed you to notice that I could."
Intensity: 0.45

> I noticed. I watched the door all night.

### 08 | mathilda | bitter | 1.25

Action / reaction: hurt asks a precise question.
Answers: 07 "I watched the door all night."
Intensity: 0.80

> Then why didn't you open it?

### 09 | ophelia | shaken | 0.90

Action / reaction: give up the excuse.
Answers: 08 "why didn't you open it?"
Intensity: 0.75

> Because if you came back angry, I would have to hear you.

### 10 | mathilda | hushed | 1.10

Action / reaction: recognition; not forgiveness.
Answers: 09 "I would have to hear you."
Intensity: 0.35
Break: yes

> Yes.

### 11 | ophelia | breaking | 0.60

Action / reaction: recognize her pattern.
Answers: 10 "Yes."
Intensity: 0.60

> I kept thinking of what to say. I never thought of what to ask.

### 12 | mathilda | resolve | 0.90

Action / reaction: offer a chance without rescuing her.
Answers: 11 "I never thought of what to ask."
Intensity: 0.50

> Ask me now.

### 13 | ophelia | hushed | 0.55

Action / reaction: a real question.
Answers: 12 "Ask me now."
Intensity: 0.40

> What did you need from me?

### 14 | mathilda | shaken | 1.10

Action / reaction: the specific grievance.
Answers: 13 "What did you need from me?"
Intensity: 0.65

> To let me finish. I said I was unhappy, and you handed me a list.

### 15 | ophelia | hushed | 0.30

Action / reaction: remember the small action.
Answers: 14 "you handed me a list."
Intensity: 0.40

> The shopping list.

### 16 | mathilda | bitter | 1.25

Action / reaction: explain the wound, not a new mystery.
Answers: 15 "The shopping list."
Intensity: 0.85
Break: yes

> You asked if we needed milk. I was trying to tell you I needed you.

### 17 | ophelia | breaking | 1.00

Action / reaction: take responsibility.
Answers: 16 "I needed you."
Intensity: 0.80

> I heard you. I made it smaller because I knew how to fix milk.

### 18 | mathilda | hushed | 0.85

Action / reaction: set a possible boundary.
Answers: 17 "I knew how to fix milk."
Intensity: 0.45

> You don't have to fix this before you sit beside me.

### 19 | ophelia | resolve | 0.75

Action / reaction: specific promise.
Answers: 18 "sit beside me."
Intensity: 0.45

> Then I'll sit. And I'll listen until you're finished.

### 20 | mathilda | warm | 0.55

Action / reaction: show that anger and care can coexist.
Answers: 19 "I'll listen until you're finished."
Intensity: 0.35

> I brought your cup back.

### 21 | ophelia | warm | 0.35

Action / reaction: surprised tenderness.
Answers: 20 "I brought your cup back."
Intensity: 0.40

> You kept it?

### 22 | mathilda | warm | 1.00

Action / reaction: name the distinction.
Answers: 21 "You kept it?"
Intensity: 0.45

> I was angry with you. I didn't want you gone.

### 23 | ophelia | hushed | 0.60

Action / reaction: ask instead of reaching.
Answers: 22 "I didn't want you gone."
Intensity: 0.35

> May I take it?

### 24 | mathilda | resolve | 1.20

Action / reaction: consent and a small shared action.
Answers: 23 "May I take it?"
Intensity: 0.45

> Yes. Walk beside me.


## Branches

The spine above is the conversation's main path: each Mathilda line is the first topic offered at her turn. The lines below are optional topics, the alternative last answer, and leaving. They obey the same rules: no embrace, no instant absolution, no lore, no threat. The tree that joins them is `assets/dialogue/meeting.json` (see `docs/DIALOGUE.md`).

### a01 | mathilda | warm | 0.60

Action / reaction: topic at 01, once; the light she watched from the tent.
Answers: 01 "I'll put the kettle on."
Intensity: 0.30

> You left the lantern burning.

### a02 | ophelia | hushed | 0.50

Action / reaction: a plain truth, not a plea.
Answers: a01 "lantern burning."
Intensity: 0.30

> I didn't know what else to keep lit.

### a03 | mathilda | wry | 0.60

Action / reaction: topic at 03 after examining the gloves, once; deflect with a joke.
Answers: 03 "Are you hurt?"
Intensity: 0.40

> Only my hands. You knitted the gloves too small.

### a04 | ophelia | warm | 0.50

Action / reaction: she remembers the kindness.
Answers: a03 "You knitted the gloves too small."
Intensity: 0.35

> You said they were perfect.

### a05 | mathilda | bitter | 0.70

Action / reaction: topic at 05, once; refuse the easy retraction.
Answers: 05 "I didn't mean for you to go."
Intensity: 0.70

> You said it like you meant it.

### a06 | ophelia | breaking | 0.80

Action / reaction: honesty instead of denial.
Answers: a05 "like you meant it."
Intensity: 0.75

> I did. For as long as it took to say it.

### a07 | mathilda | hushed | 0.70

Action / reaction: topic at 07 after examining the note, once.
Answers: 07 "I watched the door all night."
Intensity: 0.45

> I left you a note. It says something different every time I read it.

### a08 | ophelia | shaken | 0.80

Action / reaction: the same unease, unexplained; hands back to the door so 08 still lands.
Answers: a07 "It says something different every time I read it."
Intensity: 0.50

> I read it in your voice. Then in mine. So I stopped reading, and watched the door.

### a16 | mathilda | hushed | 0.70

Action / reaction: topic at 07 if they passed each other before she decided, once; she saw her stop.
Answers: 07 "I watched the door all night."
Intensity: 0.50

> Not all night. I saw you on the path. Halfway.

### a17 | ophelia | hushed | 0.80

Action / reaction: the truth, small; hands back to the door so 08 still lands.
Answers: a16 "Halfway."
Intensity: 0.55

> Halfway is as far as I ever get.

### a09 | mathilda | hushed | 0.70

Action / reaction: topic at 13, once; she is allowed not to know yet.
Answers: 13 "What did you need from me?"
Intensity: 0.35

> I'm not sure I know any more.

### a10 | ophelia | hushed | 0.80

Action / reaction: she waits instead of filling the silence.
Answers: a09 "I'm not sure I know any more."
Intensity: 0.30

> Then I'll wait while you find it.

### a11 | mathilda | hushed | 0.80

Action / reaction: the other answer to 23; consent deferred, not refused.
Answers: 23 "May I take it?"
Intensity: 0.35

> Not yet. Sit with me out here first.

### a12 | ophelia | warm | 1.00

Action / reaction: she accepts without reaching.
Answers: a11 "Sit with me out here first."
Intensity: 0.35

> Out here. All right.

### a13 | mathilda | hushed | 0.50

Action / reaction: leaving the conversation (any turn).
Answers: any
Intensity: 0.30
Break: yes

> I need a minute.

### a14 | ophelia | hushed | 0.50

Action / reaction: she does not follow and does not close the door.
Answers: a13 "I need a minute."
Intensity: 0.30

> I'll be here. I'm not going in without you.

### a15 | ophelia | hushed | 0.50

Action / reaction: greeting when Mathilda comes back to the conversation.
Answers: any
Intensity: 0.30

> Still here. Go on.

## Endings

Shown on the end card after the last exchange.

- **Walk beside me** (24): *Ophelia steps aside, and you go in together. She sits, and she listens until you have finished, and then a while longer. Two cups on the table, one fitted inside the other. Outside, for the first time since you left, the light moves.*
- **On the step** (a11): *You keep the cup a little longer. Ophelia sits down on the step beside you, in the snow, with the door open behind her and nothing to fix. Neither of you goes in yet. Outside, for the first time since you left, the light moves.*
- **With the light** (Wait, at the tent): *You stay at the tent with both cups and watch the window. The lantern stays lit. It is still the same afternoon.*
