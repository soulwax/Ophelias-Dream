# Changelog

## 0.2.2.1 — 2026-10-08

- Give Ophelia and Mathilda independent voice-performance archetypes for conversation auditions, with editable profiles and saved selections.
- Keep character voice identity steady while exploring guardedness, tenderness, resolve, humor, confession, unease and reassurance.
- Give the optional dream its own branching script in Story Studio, so its path, answers and waking echoes can be written without entering the voiced-line catalogue.

## 0.2.2.0 — 2026-10-08

### A borrowed curve

- The spine lends a curve; the left palm inherits it.
- Three sealed sheaves, eight notches: flight subtracts, earth may answer.
- Two hands keep the pause. The stride continues underneath.

## 0.2.1.11 — 2026-10-08

**Revised build, same version.** The zip on the 0.2.1.11 release was rebuilt later the same day with:

- Holding your breath removed: it did nothing, and right mouse, F and the right trigger are free again.
- For writing the game, not playing it: Story Studio (`python tools/studio/server.py`, docs/STORY_STUDIO.md), a browser workbench for every spoken line. It shows which lines are final, drafts, missing or waiting for the desktop; tries readings with Kokoro; edits a line's words or mood straight into its script, with undo; bakes a single line; reviews new clips against what they replace; and launches the game at a line's scene (`RUN_PLAY=1`).

0.2.1.10 was tagged but never built: its export had no solution file and no .NET templates, so the C# in it could not run. This release is the same game, exported properly.

- The game now ships as a zip: the executable and the `data_OpheliasDream_windows_x86_64` folder beside it, which holds the C# side. Keep them together.

## 0.2.1.10 — 2026-10-08

- Whoever you play, the other one is out there on her own afternoon. Mathilda walks the trail, warms herself at her fire, stands at the posts; Ophelia comes out onto the porch and gets halfway down the path to the tent before she turns back. They notice you, look away, crouch to fix a boot, and leave no prints.
- Now and then (rarely, three times at most) the two of you pass each other, and it goes wrong in the ordinary way. The first time it's small talk about the door or the wood. The second time she knows something she couldn't know. The third time she says your own words back. Both start to apologise at once, and nobody finishes. Pressing to speak gets half a word out. The meetings at the lake and at the door remember it.
- A new page in the hall, "the photograph": the winter the ice sang, two of you on the lake, and only one of you in it. Mathilda finds the same photograph in her pack, with both of them in it, and doesn't remember who held the camera.
- The eye in the main menu now has a cornea: a small, curved reflection of the cabin window with the lantern lit sits over the pupil, with snow going past it, and now and then someone standing in it. It moves at its own depth, between the iris and the catchlight.
- The main menu doesn't take sides any more: OPHELIA and MATHILDA sit side by side, and it opens on either one at random.
- Fixed the janitor's door in the cellar, which jammed against its own wall and never opened far enough to get through.
- Performance-critical code is now written in C#, starting with how she walks, sees and is seen.

## 0.2.1.9 — 2026-10-07

- Ophelia has things to do before she sets out. The front door is swollen shut and takes two shoves. She can light the cold stove, and latch the living-room window, where she finds a thread of red wool caught in the frame. A new page, "the grate", lies on the kitchen table.
- Mathilda works her camp before she decides: she feeds the fire, which flares up, and re-pegs the guy-line the wind pulled loose, which pulls the sagging tent corner taut again. Once she has done everything, she finds a photograph in her pack. She can only choose Return or Wait after all of it.
- Sixteen new lines. Mathilda's nine are voiced. Ophelia's seven (five for the chores, two for the new page) are subtitled for now.
- The eye in the main menu: the iris has finer, more varied fibres that react to the light, it trembles slightly, the reflection stays in one place, and it looks a little teary.

## 0.2.1.8 — 2026-10-07

- The lights at the lookout were a false lead: only two lanterns on its rail, no car, no road. It's now a checkpoint instead of the ending; posts with red rags lead on to a frozen lake from her memory, where the run actually ends.
- Give her one day: from the afternoon she wakes into through dusk, a night in the storm and a grey dawn, back to the hour she let Mathilda go. She needs at least three pages in her journal before she'll step onto the ice; if the day runs out first, the run ends on "Mathilda is gone".
- Add a real meeting: read every trail page, decipher the last one and never turn around, and Mathilda is waiting on the ice by the old hole for a full, voiced, branching conversation, ending "Together" or "On the shore".
- Eleven new monologue lines about the lake, the hours passing, and sighting her, on top of the new meeting's 41 lines.
- Cache generated terrain and woods to disk so a matching run skips straight to a cached rebuild (terrain 3.7s to 0.5s, flora 2.2s to 0.15s on this machine), add occlusion culling with house wall/ceiling/floor occluders, put the forest on its own render layer so lights can exclude it cheaply, and bake the ground shader's noise as a texture.

## 0.2.1.7 — 2026-10-07

- Rebuild Mathilda's camp to look real: a weathered canvas tent with snow settled on it and guy lines pegged out, a stone-ringed campfire with a split-log tepee, glowing coals, sparks and drifting wood smoke, a woodpile with an axe, a stool, a crate table and a hurricane lantern on a stump.
- The fire's flames are drawn by a shader, it lights the camp with a flickering, shadow-casting glow, it crackles, and the snow round it slowly melts back to wet earth.
- Her chapter now begins at early dusk, and the light keeps moving: a whole day passes in 40 minutes, through sunset and blue hour into a moonlit night.
- Her cups, gloves and note are real objects on the crate, the stool and under the lantern.
- Glints in the snow are now fine grains of ice instead of square flecks, and lamplight no longer sets them sparkling.

## 0.2.1.6 — 2026-10-07

0.2.1.5 was prepared but never published; its changes are part of this release.

- Grow woods across a larger world from a hand-made Sketchfab fir-forest pack: spruces and great pines in the snow, green firs, bushes and grass beyond, a few lone giants near the route, and rock faces on the cliffs. Trees keep clear of the route and of steep slopes, and their trunks block her.
- Build that world as chunked terrain around the story, with mountains and a ground shader that blends snow, thaw, grass and rock, and keep it in step with older saved levels.
- Her steps sound like grass on green ground and softer on thawing snow, prints and powder stay on the snow, and the snowfall thins out over green land.
- Lean graphics plant about half the trees and undergrowth, and forest textures use compressed GPU formats.

## 0.2.1.4 — 2026-10-06

- Ophelia now speaks fifteen of her twenty lines in the meeting at the door in her own voice, the one she has in the field. Five lines and all of Mathilda's still use draft performances; Mathilda's match her chapter.
- Clean up how voice assets are managed and let meeting takes be re-baked from a chosen seed.

## 0.2.1.3 — 2026-10-06

- Voice the whole meeting at the door with draft performances for both women, cleaned, levelled and timed so no turn overlaps another. Ophelia's draft voice there is not yet her own; her final performances come in a later release.
- A mouse cursor resting over the conversation's topic list no longer picks the first topic by itself.

## 0.2.1.1 — 2026-10-06

- Add Mathilda's chapter, chosen from the main menu: a first-person afternoon at the tent beyond the pines, with her own voice, three things to examine and a choice to wait or return.
- Returning leads to a fully voiced meeting with Ophelia at the unlatched door, answered through 3D dialogue bubbles with mouse, keys or pad, and ending with the light moving for the first time.
- Clean and time the meeting's speech so turns never overlap, and duck the weather while they talk.
- Steady the painted menu's gaze and refine the eye shader.

## 0.1.1.0 � 2026-10-06

- Rebrand the game as Ophelia's Dream, with updated Windows metadata and documentation.
- Introduce a painted main menu with subtle mouse-following gaze, creeping shadows, horizontal selection bars and Christian Kling credits.
- Connect the search for Mathilda to pages, deciphering, memories, echoes and distinct spoken endings across 137 voice lines.
- Play Danse Macabre in the main menu, with recording attribution and a fade into gameplay.
- Include the current character customization and house improvements.


## 0.0.16 — 2026-10-06

- Expand the upstairs to 12.6 × 9.8 metres, with higher ceilings, wider doors and clear circulation around human-sized furniture.
- Add an upholstered reading chair, tea table and woven cushions, with warm lamps, rugs and linen curtains.
- Refresh the editable house and bedside spawn while preserving the authored route and cellar connection.
- Verify door passage, spawn clearance, note access and physical stair traversal.

## 0.0.15.0 — 2026-10-05

- Give her 26 specific page reactions, room observations, and idle mutters, with baked local speech included in the Windows game.
- Keep speech and subtitles in sync, avoid repeated lines within a run, and let page reactions interrupt a mutter.
- Restore the shared walk and jog clips and simplify the procedural pose adjustments.
- Add voice verification and a repeatable Windows release export tool.
