# Mathilda: the other side of the afternoon

## Hideout and motive

Mathilda waits at the tent beyond the pines, about 98 metres down the trail. It is a windbreak, not a secret lair. She took the pack after the argument, stopped where the house light is still a point of reference, and kept two cups because leaving was never the same as wanting Ophelia gone. She wants to be chosen, heard and allowed to return without being made small again.

Her chapter is subjective: it does not prove that there are two physical women. It gives the apparent other woman agency, a distinct voice, anger, tenderness and a choice. The contradictory prints, engine and changing note remain contradictions. Ophelia hears only her own projections in the original chapter; Mathilda speaks directly only in this POV.

## Brief playable chapter

Select MATHILDA in the main menu. Begin on the path beside the tent. Examine the cups, gloves and note with E (or the rebound interact action), and do two small chores first: feed the fire and mend the windward guy-line the storm worked loose. All five are required; none of them is a puzzle, just a walk to the right spot and a press of E. Once she has done all five, the pack yields one more thing she hadn't noticed — a photograph, found automatically, no extra prompt. Walk toward the road or back toward the cabin for location lines throughout. Ophelia is out there too, on her own afternoon: on the porch, at the woodpile, sometimes halfway down the path toward the tent before she turns back. If their paths happen to cross (rarely, at most three times) the two of them stop, start a sentence, and do not finish it (see *When they pass each other* in docs/MATHILDA_STORY.md). With everything done, use the hideout prompt to choose Return or Wait. Wait ends on the card *With the light*. Return sends her back to the cabin, where Ophelia waits at the doorstep; speaking to her opens the meeting (`docs/MATHILDA_MEETING.md`), which ends on *Walk beside me* or *On the step*. Each card returns to the main menu. Esc returns to the menu at any time. This chapter uses a first-person camera and the existing movement and winter world; it does not share Ophelia's journal progress or endings.

## Voice direction

Distinct feminine voice, warmer and more direct than Ophelia. Hurt does not erase her wit or decisiveness. First local performance uses Kokoro af_bella at speed 0.94, separated from Ophelia's clip namespace; mood tags remain editorial direction for future per-mood performances. These are authored lines, not live-generated dialogue.

## Spoken script

### arrival

- [hushed] The tent is still here. Good. One thing that stayed where I left it.
- [bitter] Go, then. She said it so quietly I almost thought she was asking me to stay.
- [resolve] I'm not hiding from her. I am waiting where she has to choose to come.

### cups

- [warm] Two cups. I packed two before we argued.
- [shaken] They fit inside each other. They always have.
- [resolve] I'm keeping hers. She can be angry and still be thirsty.

### gloves

- [warm] She knitted these too small. I said they were perfect.
- [bitter] If I put them on, she'll know I needed something from her.
- [resolve] My hands are freezing. That is a stupid reason not to wear gloves.

### note

- [hushed] I wrote don't turn around. I meant don't come after me just because you're afraid.
- [shaken] No. That's not what the page says now.
- [resolve] I want her to come because she wants me. Not because she cannot bear an empty room.

### fire

Feeding the fire, before she can decide anything.

- [resolve] The fire's gone low. I didn't walk all this way to freeze for spite.
- [warm] There. That'll hold till dark, at least.
- [bitter] Funny. I can keep a fire alive out here easier than I kept anything at home.

### mend

The windward guy-line has worked loose. Also required.

- [shaken] Wind's worked this knot loose. One more gust and the whole side comes down.
- [steady] There. Tight enough to hold. Everything should be this simple to fix.
- [wry] I can mend a tent. I could never mend an argument.

### photograph

Found in the pack, once she has done everything else there is to do at camp. Not required to continue; it plays once, automatically.

- [shaken] There's something else in here. Under the map.
- [warm] A photograph. The two of us, before either of us knew how to be unkind.
- [breaking] I didn't know I'd packed this. Or I did, and I didn't want to know I had.
- [hushed] Funny. I don't remember who held the camera.

### lantern

- [warm] There's the window. She left the lantern burning.
- [bitter] A light is not an apology. I know. I'm watching it anyway.
- [pleading] Ophelia. You can leave the house. It won't fall down without you.

### road

- [hushed] The engine was running when I got here. Nobody was in the seat.
- [shaken] I don't remember starting it. I remember the key in my hand.
- [resolve] I could leave. That is different from wanting to.

### house

- [hushed] The door is unlatched. She never leaves it like that.
- [warm] I know which board complains. I know how to come home quietly.
- [resolve] I won't make her guess what I need this time.

### snow

- [shaken] My prints stop before I do. I'm still walking.
- [hushed] Something called her name with my mouth closed.
- [resolve] If the trees answer, let them. They don't get to choose for me.

### idle

- [bitter] She thinks brave means not being frightened. It means going out frightened.
- [warm] She cuts the crusts off when she thinks I'm not looking.
- [hushed] I can hear the house from here. Or I know it too well.
- [shaken] Same afternoon. I have been waiting through the same afternoon.
- [resolve] I left the pack where she could find it. I did not leave it for the trees.
- [pleading] Don't call me back just to put me away again.
- [warm] Two chairs. Two cups. She remembers in objects before she remembers in words.
- [resolve] I can go back without taking back everything I said.
- [wry] My scarf's coming apart. I keep finding red wool on everything.

### passing

When she and Ophelia cross paths (docs/MATHILDA_STORY.md, *When they pass each other*). The `m_` lines are hers when she is played; the `w_` lines are hers when Ophelia is played and she is the one met on the trail. Keyed, so `Encounters` can pick them by id; nothing plays this group as a whole.

- **m_name:** [hushed] Ophelia.
- **m_hi:** [warm] Hi.
- **m_watching:** [shaken] You've been watching it.
- **m_how:** [shaken] Then how...
- **m_mine:** [wry] That's my line.
- **m_im:** [breaking] I'm...
- **m_after:** [hushed] No prints. Not hers, not anyone's.
- **m_after2:** [shaken] She was right here. The snow doesn't believe it.
- **m_half1:** [hushed] I...
- **m_half2:** [shaken] Do you want...
- **m_half3:** [pleading] Wait.
- **w_up:** [hushed] You're up.
- **w_does:** [numb] It does that.
- **w_stove_lit:** [hushed] You lit the stove.
- **w_stove_cold:** [hushed] You didn't light the stove.
- **w_thread:** [shaken] You found my thread.
- **w_cold:** [hushed] It's cold. You should go back in.
- **w_go:** [bitter] Go, then.
- **w_know:** [hushed] I know.
- **w_didnt:** [breaking] I didn't...
- **w_first:** [wry] You first.
- **w_hm:** [hushed] Hm?

### cold

- [hushed] The canvas keeps the wind off. Not the cold.
- [shaken] I thought anger would keep me warm longer than this.

### ending

- [resolve] I'm coming back. You will have to hear me this time.
- [hushed] I will wait a little longer. But I am not disappearing for her.


## Rebuild and verify

`build/voice/venv/Scripts/python.exe tools/bake_mathilda.py` renders missing clips from this script. `python tools/bake_mathilda.py --check` checks script consistency. Run `godot --headless --path . tools/mathilda_probe.tscn` for the chapter flow. `RUN_MATHILDA=1` selects the chapter for startup or screenshot capture.
