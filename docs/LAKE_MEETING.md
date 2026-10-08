# On the ice: Ophelia meets Mathilda

The script of record for the meeting at the end of Ophelia's chapter. The lines
table is `assets/audio/voice/lake/lines.json` and the tree is
`assets/dialogue/lake.json`; keep both in step with this file. The runtime is
`Conversation` (docs/DIALOGUE.md); `Lake` stages it.

## When it happens

Mathilda is waiting on the lake ice, by the old hole, only if all of these hold
when Ophelia comes within sight of the lake:

- every trail page has been read (by the post, the pack, the torn page, the
  handwriting, *don't turn around*),
- the last page's smudge has been deciphered in the journal,
- she never turned around.

If she turns around after Mathilda has appeared, Mathilda is simply not there
any more. Without the meeting, the lake ends the run as before ("The lake" or
"One set of prints"), and it needs at least three pages in the journal: with
fewer, Ophelia stops at the shore and will not go out.

The whole chapter now runs on a day clock (14:30 to 14:30 the next day, 40 real
minutes). If the day ends before she has reached the lake with three pages,
the run ends on **Mathilda is gone**.

## Shape

The spine runs: *you didn't turn around* → the lake and who went through → *go,
then* → sorry → what Mathilda is → the ask. Side topics open with what Ophelia
has read (`requires` flags: `pack`, `post`, `torn`, `handwriting`, `intake`,
`bed`), and `passed` if the two of them passed each other on the way (docs/MATHILDA_STORY.md,
*When they pass each other*). Two endings, chosen in the last exchange: **Together** (she asks
properly, and they walk back side by side) and **On the shore** (she lets
Mathilda stay out there, and keeps the lantern lit).

Mathilda's voice is her chapter's (Kokoro `af_bella` at 0.94, `tools/bake_lake.py`).
Ophelia's lines have no clips until the Chatterbox bake on the desktop; they
show as subtitles.

## Lines

| id | speaker | mood | text |
|---|---|---|---|
| m01 | mathilda | hushed | You didn't turn around. |
| o01 | ophelia | shaken | I wanted to. Every step. |
| o02 | ophelia | bitter | You lied about the car. |
| m02 | mathilda | wry | I didn't know what else would get you this far. You only ever walk toward a way out. |
| m03 | mathilda | steady | This is where it happened. Do you remember which of us went through? |
| o03 | ophelia | steady | You did. I pulled you out. |
| m04 | mathilda | wry | That's how you tell it. |
| o04 | ophelia | breaking | I don't. I've never known. |
| m05 | mathilda | warm | One of us held very still, and one of us pulled. And after that you never let me go anywhere again. |
| o05 | ophelia | breaking | I was scared you'd go through again. |
| o06 | ophelia | hushed | The card in the cellar said one cup. |
| m06 | mathilda | hushed | You only ever set out one for yourself. Mine you set out for me. |
| o07 | ophelia | warm | I found your pack. Two cups. |
| m07 | mathilda | warm | I packed for both of us. I always do. You just never came. |
| o08 | ophelia | shaken | You wrote on the post that it used my name. |
| m08 | mathilda | shaken | It did. And I answered. That's how I knew it wasn't lying. |
| m09 | mathilda | bitter | So you said go, then. |
| o09 | ophelia | breaking | I'm sorry. I'm so sorry I said it. |
| o10 | ophelia | bitter | You were already going. |
| m10 | mathilda | steady | I was standing at the door, waiting for you to stop me. |
| m11 | mathilda | hushed | I know. I heard you. Every time you called, I heard you. |
| o11 | ophelia | pleading | Then why didn't you answer? |
| m12 | mathilda | wry | I did. You kept hearing yourself. |
| o12 | ophelia | hushed | It's my handwriting on your pages. |
| m13 | mathilda | steady | Then you've been writing to yourself the whole time. Read it back sometime. Out loud. |
| o13 | ophelia | shaken | The torn page said the prints just stop. |
| m14 | mathilda | numb | They stop where you stopped looking. |
| m15 | mathilda | steady | I'm not the one who went out into the storm, Ophelia. I'm the part of you that wanted to. |
| o14 | ophelia | shaken | Then what's under the sheet? |
| m16 | mathilda | numb | A coat, buttoned to the throat. Nobody was ever in it. |
| o15 | ophelia | resolve | I don't care what you are. Come home. |
| m17 | mathilda | warm | Ask me properly. Not "come home." Ask. |
| o16 | ophelia | pleading | Walk back with me. Beside me. Not behind. |
| m18 | mathilda | warm | Okay. |
| o17 | ophelia | resolve | Stay out here if you need to. I'll keep the lantern lit. |
| m19 | mathilda | hushed | Then I'll always know where you are. |
| o18 | ophelia | hushed | I need a minute. |
| m20 | mathilda | steady | The ice will hold. Take it. |
| m21 | mathilda | hushed | Still here. Still holding still. |
| o19 | ophelia | warm | You left the door open for me. The page by the bed. |
| m22 | mathilda | wry | For one of us. I never could decide which one needed rescuing. |
| o20 | ophelia | hushed | I saw you on the trail. You didn't say anything. |
| m23 | mathilda | wry | Neither did you. |

## Endings

**Together**
> You walk back across the ice side by side. The prints you leave are two sets, close together, all the way to the shore, and neither of you looks back, because nobody is behind you.

**On the shore**
> You sit on the shore with the lantern lit. Out on the ice she holds very still, and for the first time it does not frighten you. When the light comes up, she is walking in.

**Mathilda is gone** (the day ran out)
> A whole day, and you never went to her. The posts are still standing; the wind has taken the rags. Out on the lake the prints have filled in. Wherever she was waiting, she has stopped.

- if fewer than three pages: *You never read enough of her to follow.*
- Spoken over the card (breaking): **"Mathilda? ...Mathilda!"**
