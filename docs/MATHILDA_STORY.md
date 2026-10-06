# Looking for Mathilda — complete story and voice script

This is the story draft for review **before the remaining voice clips are generated**. It records the exact text currently in the game: the opening, all seven written pages, their deciphered readings and hidden sentences, the road ending, and every spoken line. Page text comes from `scripts/notes/note_catalog.gd`; spoken text and moods come from `assets/audio/voice/lines.json`. If this draft changes, those source files must change with it before baking.

## The story as played

An unnamed woman wakes in a winter cabin. Mathilda has gone out into the storm. The lantern is burning beside a note in Mathilda's hand, and the door was left unlatched. The protagonist goes looking for her. Her first certainty is simple: Mathilda is cold, close by, and in need of help.

The search runs through the cabin, its cellar, and the snowfield toward the lights at the road. Mathilda's pack contains a map marked at the lookout and a list for two people. A note on a post says she heard the protagonist's voice call from the trees. Near the pines, a torn page describes footprints that stop without turning back. Mathilda stood in them and found that they fit. Later pages say the cabin has appeared twice without Mathilda returning to it, and her handwriting is becoming the protagonist's. Her final instruction is to reach the lights without turning around.

The cellar offers another possible account. An intake record describes a person brought in from the step during the storm, under a sheet, with a strap marked **M. Aune** and one cup. Mathilda and the protagonist share the surname Aune; the record does not identify which woman it describes. The protagonist does not lift the sheet. Nor does the game say what the two women are to one another. Mathilda speaks only through the pages; the voice heard aloud is the protagonist's.

The protagonist can piece together each damaged page in her journal. A smudge is written below as `{the intended reading}`; in play it is initially obscured. The alternative readings are listed after the pages. Deciphering both smudges on a page reveals its *between-the-lines* sentence. The pages can be discovered and solved out of order, so the account a player forms may change as they explore.

At the road, an engine is running, the driver's door is open, and the seat is still warm. Reading the last page adds the fact that she did not turn around. Deciphering every page reveals a second warm cup beside the first on the dashboard. The story ends there. It does not identify who kept the engine running, whose body is under the sheet, or whether Mathilda is behind her, at the road, or absent.

## The seven pages

The bed and intake pages are in the house. The other five form the trail. Their order here follows the likely first journey, with the intake after the trail; a player can find the house pages at another time.

### By the bed

> I lit the lantern so you would see it from the field. Leave it burning.
>
> If you are reading this, you came back and {I} did not. Stay in. I mean it this time. Do not do what you always do, which is come after me.
>
> Put your coat on before you argue with me.
>
> — {M.}

*Between the lines:* I left the door unlatched so you could get back in. Or so I could.

### From the pack

> Packed for {two}: two cups, one candle (we share), the map. Lookout circled. That is where the road comes up. If the storm closes, go there. Someone always comes up the road.
>
> Left the pack here. Too heavy to run with. You will know it is mine. Follow the {posts}, not the prints. The prints lie in this wind.

*Between the lines:* If you find this pack with one cup in it, do not count them again.

### On the post

> It is the same afternoon it was. The light has not moved since I left the cabin.
>
> I called your name until I could not hear it over the wind. Then I heard it again, from the trees, in {your} voice.
>
> I did not answer it. If you hear me from the trees, do not {answer} either.

*Between the lines:* It called me by your name.

### Torn page

> —your prints from the step. I followed them as far as the pines. They do not go on and they do not come back. They stop, both feet {together}, as if you stood there and the snow decided you had never been here.
>
> i stood in them. they {fit} me.
>
> I am going on to the lights. If you are behind me, you will find this. If I am behind you, I already did.

*Between the lines:* The prints were smaller than mine. Then they were not.

### The handwriting changes

> I keep writing to you because writing is the only thing that stays where I put it. The snow does not. The prints do not. the cabin does not. i have passed it twice and it was lit both times and i never went back in.
>
> my letters are going wrong. they lean the way {yours} lean. i know your hand better than mine. i read every list you ever left me. this is your hand now and i am still writing.
>
> if you are reading this, which of us is holding the {pen}.

*Between the lines:* hold this next to the page by the bed. same hand. it was always the same hand.

### Don't turn around

> stop looking for me.
>
> go to the lights. the engine has been running since before the snow. someone kept it warm for {one} of us. i will be there or i will not, but you will.
>
> i am right {behind} you. i always was. do not turn around until you reach the road.
>
> — m

*Between the lines:* the sheet in the cellar is not me. say it back to me. the sheet is not me.

### Intake

> Brought in from the step during the storm. Length under the sheet: 1.6 m. Strap stamped M. Aune. Given name, as copied: {M—}. Personal effects: one cup. Next of kin: {out searching}. Not yet notified.

*Between the lines:* Scratched inside the rim of the cup: M.

## Smudge readings

The first reading is the intended one; the other two are choices the protagonist can reject. A clue becomes available after the named page, place, or event is known. Hearing a call or echo has a fallback when voice playback is disabled, so the story remains solvable without audio.

| Page | Smudge | Readings, intended first | Clue |
| --- | --- | --- | --- |
| By the bed | `{I}` | I / you / we | Torn page read |
| By the bed | `{M.}` | M. / Mum / Me | From the pack read |
| From the pack | `{two}` | two / one / three | Living room visited |
| From the pack | `{posts}` | posts / lights / trees | On the post read |
| On the post | `{your}` | your / my / her | A call heard; snow visited if voice is off |
| On the post | `{answer}` | answer / follow / listen | An echo heard; last page read if no echo |
| Torn page | `{together}` | together / bare / apart | Snow visited |
| Torn page | `{fit}` | fit / followed / knew | The handwriting changes read |
| The handwriting changes | `{yours}` | yours / mine / hers | By the bed read |
| The handwriting changes | `{pen}` | pen / lantern / sheet | Intake read |
| Don't turn around | `{one}` | one / both / neither | Lights visited |
| Don't turn around | `{behind}` | behind / beside / ahead of | On the post read |
| Intake | `{M—}` | M— / Mathilda / nobody | From the pack read |
| Intake | `{out searching}` | out searching / notified / none | By the bed read |

## Frame and ending text

Opening card: **RUN AWAY** — “Mathilda went out into the storm.” The HUD gives no written objective. Finding a page shows “Added to the journal.”

Road ending: **The road** — “The engine is running. The driver's door is open, the seat still warm.” If the last page was read: “You didn't turn around.” If all seven pages were deciphered: “Beside the cup on the dash, a second one. Still warm.”

The generic caught ending remains “It caught you” / “You stopped. The snow closed over the place you were.” A specific threat can replace it later; this story pass adds no field threat or Mathilda apparition.

## Spoken script

The following lines are all spoken by the unnamed protagonist, never by Mathilda. The mood in brackets is the direction used for baking. Page and deciphered reactions play when their event occurs; place and revisit lines depend on where the player goes. Idle thoughts and calls are grouped by story stage: **hope** with zero or one trail page, **doubt** with two or three, and **resolve** with four or more or the last page. This is the complete set of 62 lines in `lines.json`; a given playthrough will not necessarily hear all of them.

<!-- The exact line list below is generated from assets/audio/voice/lines.json for audit. -->

### Page reactions

- **by the bed:** [shaken] "Stay in." She's the one out there, and she's telling me to stay in.
- **from the pack:** [breaking] Two cups. She packed for both of us. She knew I'd come.
- **on the post:** [hushed] Then I heard it again, from the trees. Okay. I won't answer. I won't.
- **torn page:** [shaken] Prints that just stop. She's describing mine. I haven't been to the pines yet. Have I?
- **the handwriting changes:** [hushed] That's my handwriting. That's how I make my M's.
- **don't turn around:** [resolve] Don't turn around. Fine. I won't. Just be at the lights.
- **intake:** [breaking] One cup. Just one. I'm not lifting that sheet. I'm not.

### Deciphered-page reactions

- **by the bed:** [warm] She left the door open for me. Or for herself. She never could decide which of us needed rescuing.
- **from the pack:** [breaking] One cup. The intake said one cup. I'm not counting again. I'm not.
- **on the post:** [shaken] It knew my name. It used my name on her.
- **torn page:** [hushed] Smaller than mine. Then not. Like the prints were growing into me.
- **the handwriting changes:** [hushed] Same hand, both pages. I'd know it anywhere. That's what scares me.
- **don't turn around:** [resolve] The sheet is not her. The sheet is not her. I'll say it all the way to the road.
- **intake:** [breaking] Just an M. It could be either of us. It could be both.

### First visits

- **bedroom:** [warm] Her side of the bed is still warm. She can't be far.
- **hall:** [shaken] Her boots are gone. The door isn't even latched.
- **living:** [hushed] Two chairs pulled out. She sat up with that candle until it went out.
- **backhall:** [hushed] Mathilda? She wouldn't go down there. She hates the cellar.
- **stair:** [hushed] If she's down here, she's been quiet a long time.
- **landing:** [hushed] No wind down here. Just my heart, and I wish it would slow down.
- **corridor:** [hushed] Why does a cabin need a hallway this long under the ground?
- **janitor:** [shaken] Someone keeps this place clean. Someone expects to use it.
- **morgue:** [breaking] No. She wouldn't be here. She's out in the snow. She has to be.
- **snow:** [resolve] Her prints are already filling in. I have to be faster than the snow.
- **lights:** [breaking] Headlights. Someone's waiting. Please let it be her.

### Revisits

- **bedroom:** [shaken] The lantern's still lit. Nobody's been here. Or I have, and I don't remember.
- **hall:** [shaken] I latched it behind me. I know I did.
- **living:** [hushed] Still two chairs. I keep thinking one of them will be pushed in.
- **morgue:** [breaking] I said I wouldn't come back down here. I keep coming back down here.
- **snow:** [hushed] Every set of prints out here could be mine.

### Idle thoughts

**Hope**

- [steady] She knows this field better than I do. She'll have found shelter.
- [shaken] Ten minutes, she said. Ten minutes, and then the snow came in sideways.
- [warm] When I find her I'm going to be so angry. And then I'm not letting go.
- [steady] She always leaves something behind so I can find her. Always.
- [hushed] Every white shape is her coat, until it isn't.
- [warm] She'll be cold. She never wears the hat. I should've made her wear the hat.

**Doubt**

- [shaken] Her prints stop. Mine don't. What does that make me?
- [hushed] I've said her name so many times it's just a sound now.
- [shaken] What if she's back at the cabin, by the lantern, writing to me?
- [breaking] I can't remember which of us said we'd stay.
- [breaking] I keep turning to tell her something. There's nobody to tell.
- [hushed] The light hasn't moved. She was right. It's the same afternoon.

**Resolve**

- [resolve] Don't turn around. I can do that. I can do that much.
- [breaking] If she's behind me, she can see me. That has to be enough.
- [hushed] The engine's running. Someone kept it warm for one of us.
- [resolve] Whatever's at the lights, I'm walking up to it. I'm not stopping now.
- [breaking] I'll find you. Or you'll find me. One of us gets to go home.
- [hushed] I'm not cold any more. That's bad, isn't it. Keep walking.


### Calls into the storm

**Hope**

- [calling] Mathilda!
- [calling] Mathilda! Can you hear me?
- [calling] Mathilda! Over here!

**Doubt**

- [calling] Mathilda! Answer me!
- [breaking] Mathilda... where are you?
- [calling] Mathilda! Say something!

**Resolve**

- [calling] Mathilda! I'm coming!
- [breaking] Mathilda... please.
- [calling] I'm going to the lights, Mathilda! Meet me there!

### Rejected readings

- [hushed] No. That's not it.
- [steady] That doesn't fit.
- [shaken] She'd never write that.
- [hushed] Wrong. Look again.
- [breaking] I want it to say that. It doesn't.

**Total: 62 spoken lines.**
