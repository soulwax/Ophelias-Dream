# Ophelia's Dream: storytelling, presentation, and atmosphere roadmap

> [MASTERPLAN.md](../MASTERPLAN.md) reconciles this roadmap with the current
> implementation and the other plans. It owns MVP scope, subagent work packages,
> dependencies, and acceptance gates; this document retains the creative direction.

Written 2026-10-11 against the current Godot 4.7.2 Mono project. This is a game-wide design and production plan, not a record of completed implementation.

## 1. The experience we are building

Ophelia's Dream should become an intimate winter horror game in which caring for someone, fearing their absence, and trying to control the outcome gradually become difficult to distinguish. The player moves through a world that almost holds together. Ordinary domestic details acquire contradictory meanings. Listening changes what a place means before it changes what happens there.

The desired emotional journey is **familiarity → unease → recognition → vulnerable choice → an image that stays**. The supernatural uncertainty should deepen the relationship rather than displace it. By the end, the player may remain unsure what Mathilda is, who went through the ice, or how the house can repeat. They should understand what each woman needed and what their own choices did to the conversation.

The strongest upgrade is to compose the existing pieces into one dramatic language. More terrain, branches, shaders, or monologues are useful when they strengthen that language. Every addition must earn its place through an emotional purpose, a playable action, and a visible consequence.

### Five promises to the player

1. **The world rewards attention.** A cup, a sleeve, a door, or a delayed step can tell a story without a caption explaining it.
2. **The women feel human.** They have habits, irritation, humor, practical needs, and contradictory wants alongside fear and regret.
3. **Unreality has a grammar.** Locally believable places form globally impossible relationships. The player learns enough to notice when the grammar changes.
4. **Choices change an encounter.** Responses affect distance, permission, topics, actions, and remembered details; the effect is legible before an ending judges the exchange.
5. **The game remains dependable.** Movement, readability, pause, saving, and interaction stay clear even when the world becomes unreliable.

## 2. Current foundation and the gaps to close

The project already contains most of the necessary foundations:

| Existing foundation | Current ownership | How this plan develops it |
| --- | --- | --- |
| Subtitle-driven dream with four approach beats, three route events, four small-talk rounds, six final branches, repair, and resolved/unresolved/ruptured wakeups | `assets/dialogue/dream.json`, `scripts/world/dream_story.gd`, `scripts/world/dream_experience.gd` | Give the sequence a stronger emotional progression and make the consequences less dependent on memorizing a route. |
| Cue-controlled lighthouse, warm room, clearing, folded path, and dark intervals | `dream_memory_architecture.gd`, `dream_route.gd` | Finish their composition, make their contradictions readable through movement, and reduce competing effects. |
| Ophelia's house, cellar, trail pages, journal deciphering, false lookout, and lake | `main.gd`, `trail.gd`, `house/`, `note_catalog.gd`, `lake.gd` | Turn searching and interpreting into an escalating relationship story. |
| Mathilda's first-person camp chapter, practical chores, return/wait decision, and doorstep meeting | `mathilda_pov.gd`, `camp.gd`, `docs/MATHILDA_POV.md`, `docs/MATHILDA_MEETING.md` | Give her perspective equal agency and a distinct rhythm. |
| Rare encounters with the other woman and later references to those encounters | `scripts/npc/encounters.gd`, `Wanderer.cs`, conversation data | Make each passing change a later scene without making rare encounters mandatory. |
| Footplant-driven movement, jumps/leaps/slides, camera anticipation, footprints, snow kicks, weather, day progression, and terrain/flora batching | `player/`, `weather/`, `atmosphere.gd`, `ground.gd`, `flora.gd`, `tune.gd` | Improve the physical presence and clarity of movement through composed spaces. |
| CRT presentation, world-associated dialogue, separate dream journal, settings, and title return | `signal_glass.gd`, `dialogue_bubble.gd`, dream UI, `pause_menu.gd` | Establish consistent visual hierarchy and separate dramatic feedback from interface feedback. |
| A rolling run snapshot with temporary write, validation, checksum, backup, and dream state capture | `scripts/game/run_save.gd` | Make new scene states and dramatic handoffs safe to resume. |
| Story Studio, animation workbench, and focused visual/probe tools | `tools/studio/`, `tools/animation_workbench.gd`, existing probes and views | Make timing, consequences, staging, and performance reviewable before release. |

The recent player-view review images under `build/dream/` show useful presentation risks: large repeated body afterimages compete with the scene, a speech panel can appear detached from its speaker, and the lower clue ribbon competes with other interface marks. These are observations of review captures, not a diagnosis of every normal playthrough. Reproduce their conditions before attributing a cause or changing an effect.

The existing dream runtime is approximately 2,200 lines and owns flow, choreography, figure treatment, dialogue, journal, choices, and presentation. That concentration makes each additional feature risky. Later slices should gradually move stable responsibilities into small helpers while preserving the working behavior and save contract.

### Relationship to existing plans

Use [DREAM_ATMOSPHERE_PLAN.md](DREAM_ATMOSPHERE_PLAN.md) for the current overlapping architecture and [DREAM_PLAYABILITY_RELEASE_PLAN.md](DREAM_PLAYABILITY_RELEASE_PLAN.md) for its established playability checks. [DREAM_EXPERIENCE_PLAN.md](DREAM_EXPERIENCE_PLAN.md) contains valuable earlier intent, but some mechanics are historical: the current dream has six branches and three outcomes. This roadmap supplies the whole-game direction; live code and current story data remain authoritative for implemented behavior.

Ophelia's domestic actions and her new ways of touching the world (section 9, slice 8) are specified in [the errands design](superpowers/specs/2026-10-14-errands-and-interactions-design.md) and built task by task, with subagents, from [its plan](superpowers/plans/2026-10-14-errands-and-interactions.md). That plan also carries the move of every proprietary asset into `build/` (section 19).

## 3. Settle the dramatic contract before expanding content

Write a compact story bible with four separate columns: **authorial fact, a character's belief, observable evidence, and unresolved interpretation**. Use it to audit every page, encounter, monologue, and ending.

The authorial facts already established include the argument, the importance of choice and distance, the shared winter and lake imagery, and Mathilda's history of sexual violence by a lumberjack. The assault is never staged or described graphically. Its aftermath affects her, while her character remains larger than it.

The existing story also presents Mathilda as Ophelia's shadow and includes strong claims about that relationship at the lake. Treat the distinction between authorial symbolism and a speaker's interpretation carefully. Mathilda's first-person chapter must remain meaningful even when an ending suggests that she is part of Ophelia. A symbolic reading should not erase the woman's stated boundaries, experiences, or independent choices.

Lock these narrative rules:

- Ambiguity may surround identity, chronology, memory, and supernatural causation. Consent, responsibility for violence, and the validity of silence remain clear.
- Ophelia's guilt about saying “Go, then” and her habit of answering difficult feelings with practical tasks are relationship conflicts. They do not make her responsible for another person's assault.
- Mathilda may be angry, mistaken, funny, evasive, direct, or tired. She need not become a perfectly instructive guide to earn the player's care.
- The lumberjack's presence becomes a specific warning late in the dream. He does not become the main attraction or a compulsory confrontation.
- The relationship may reach a meaningful change without an explanation of the dream's metaphysics.
- Each ending resolves a present action or relationship choice. It does not settle every mystery.

**Deliverable:** a two-to-four-page story bible with a contradiction register. Record intentional contradictions and fix accidental ones. Synchronize the relevant script-of-record documents when content changes; do not let a new planning document silently replace them.

## 4. Give the three modes distinct dramatic jobs

Keep the three existing entry points, and make each satisfying when played first. Offer the dream as a recommended first experience without requiring it. When a player begins with a chapter, introduce that chapter's needs through its own scenes.

| Mode | The question it asks | Main playable verbs | What its ending changes |
| --- | --- | --- | --- |
| Dream | Can I stay with someone without taking their story from them? | Walk, notice, wait, choose distance, listen, reply, repair | The player carries a remembered way of approaching uncertainty into a chapter. |
| Ophelia | Am I searching for her, or for the version of her that makes me feel safe? | Keep a light, search, read, interpret, follow, return, ask | Care becomes an action the other woman can accept or refuse. |
| Mathilda | Can I choose to return without surrendering the right to leave? | Tend, mend, inspect, remember, wait, return, set a boundary | Returning becomes a chosen relationship rather than an obligation. |

Aim initially for a dream that feels complete in roughly eight to twelve minutes at an ordinary reading pace. Treat that as an editorial target, not a timer. Measure the chapters from real first-time play before setting their final duration. Preserve the existing 40-minute day rule until a dedicated timing review determines whether it supports the drama fairly.

The modes should echo one another through objects and actions. A dream choice changes which detail receives emphasis later; it should not make a chapter's central ending inaccessible because the player chose privacy in the prologue.

## 5. Build a motif system with changing meanings

Limit the principal motifs to a small set. Give each an initial mundane use, a disturbing reinterpretation, and a later practical action. Repetition should alter context rather than increase the number of copies.

| Motif | Familiar use | Disturbing reinterpretation | Later human action |
| --- | --- | --- | --- |
| Two cups | Habit, company, making room | Counts and ownership disagree; one nests inside the other | Offer a cup after listening; accept that warmth does not settle an argument. |
| Door and latch | Shelter and an ordinary household task | An open door can be welcome, abandonment, or a remembered threat | Step aside and let someone choose to enter. |
| Coat and gloves | Protection from winter | A coat keeps a shape; borrowed gloves carry dependence and resentment | Put on protection by choice; help without claiming ownership. |
| Lantern and window | A way to find home | The light watches the wrong direction; shelter is visible but unreachable | Keep a light available without treating it as a summons. |
| Prints and delayed steps | Evidence of movement | Another stride stops late; the count changes behind the player | Walk beside someone, matching pace rather than forcing it. |
| Red wool or thread | A scarf, a repair, a marker | The same strand appears where it should not reach | Repair a small thing; follow a detail without demanding its whole history. |
| Ice and the held body | A winter memory | A pause becomes indistinguishable from freezing | Ask before taking a hand or choosing a direction. |

Reserve the axe as a secondary motif of remembered danger. Repeating it everywhere would turn a late recognition into an early certainty. Let ordinary cut wood remain ordinary at first.

**Production rule:** every recurrence receives a scene ID, a reason for returning, and a planned change in meaning. Remove decorative repetitions that cannot answer those questions.

## 6. Recompose the dream into a complete emotional arc

Keep the existing linear walking route, unlimited stamina, subtitle-only speech, and quiet intervals. Build depth through pacing and branching encounters rather than a longer maze of disconnected landmarks.

### Scene A: the threshold — an ordinary reason to stay

The player enters cold air, hears a door settle, and notices the house light. Mathilda appears where she could plausibly have been standing beyond the first trunks. Her arrival has a readable approach, a pause, and a restrained purple outline. She begins with a practical observation or small question.

Give this moment thirty to sixty seconds of stable space before the first strong anomaly. A familiar gesture, dry remark, or concern about cold establishes a person worth staying with. A player who runs should still receive the opening before later lines start queuing over it.

Move controls into a brief separate hint that reflects remapped input. The current opening announces three trail moments and journal instructions inside the story; revise that separation so the first impression is an encounter with a person rather than a briefing about clue collection.

**Playable purpose:** choose whether to approach, keep distance, or wait; every approach permits the scene to continue. **Image:** a small human silhouette between warm shelter and cold open space.

### Scene B: the late step — discover the rule through stopping

Use the existing delayed-footstep language. Mathilda stops, or the player stops; another step arrives late and then ceases. The anomaly is sparse enough to distinguish from an audio bug. Her monologue begins with a concrete detail, drifts into the sisters/Fates image, and returns to a simple present need.

Give the player a response that can offer a choice: moving, waiting, or leaving the subject unfinished. No option earns courage points. The surrounding snow and trunks remain dependable.

**Playable purpose:** learn that pace and attention affect a scene's presentation. **Image:** the path is clear while the sound behind it fails to obey the body.

### Scene C: the lighthouse — a way out that will not stay put

Use the existing thread cue and complete lighthouse. First compose a believable tower, then let its relationship to the cabin become impossible through parallax or a lookback. Its beam crosses the real trees and snow so it belongs to the scene. The contradiction is spatial, even with screen effects disabled.

Mathilda's mythic drift turns the idea of a guide into a question about who laid the path. After the drift, she asks the player to remain where she can see them. That request becomes the conversational stake; the tower remains a witness rather than a destination.

**Playable purpose:** find a stable position in an unstable relationship of landmarks. **Image:** a quiet beam reveals a path whose bearing cannot be reconciled with the house.

### Scene D: the warm window — safety is not an invitation

Retain the warm room and window cue. Finish the building as a deliberately modest, weathered structure: a convincing roof, trim, grounded base, and a single controlled pool of warm light. Its impossible quality should emerge from its relationship to the winter route rather than missing construction.

Make the warm-window clue coincide with the line that gives it meaning. This is where danger becomes specific. Allow Mathilda to choose distance and where she stands. A conversation about being cold can turn into a question about whether coming closer would help; it must not leap straight from small talk to a demand for details.

**Playable purpose:** practice asking before acting. **Image:** shelter is close enough to want and uncertain enough to distrust.

### Scene E: the dark interval — carry a thought without being taught

Protect an interval between the window and clearing. No fresh revelation, mandatory choice, or competing journal toast. Let snow, footsteps, cloth movement, and the last sentence remain with the player. Mathilda's body language carries the tension: she begins to turn back, decides against it, and continues.

The live transition now begins after the window exchange and lasts at least six seconds, continuing until the player reaches the clearing approach at route metre 61. Mathilda briefly stops and looks toward the window, then follows the path forward. Remembered footsteps and room tone recede while the player's movement and weather remain audible. Pause and journal access suspend the interval; the run snapshot preserves its progress. This transition introduces no additional story fields or changes to memory IDs.

**Playable purpose:** choose a pace and absorb what happened. **Image:** two separated figures on one clear line through the dark.

### Scene F: the clearing — decide how to remain present

Drain pending exchanges in order before opening the final answer. Use the six existing memory IDs and preserve their save compatibility. Add variety through the conversation that led here, not through a larger final menu.

The current final question invites a personal answer such as “I said no.” Make that invitation and the reply's speaker explicit, and keep the player's chosen words distinct from Mathilda's disclosure in the journal and later echoes. Uncertainty about the dreamer's identity must not become confusion about whose words the player is selecting.

Keep Mathilda's direct speech above her head. Place player reply choices near the player's side of the composition with a clear handoff. When she rambles, her gaze can drift into the folded path; when she asks a direct question, she returns to the other character. Strong psychedelic treatment recedes while the text and choice are active.

The clearing now reveals a shallow crescent of six low, dark ice fins behind the figure and a small, two-pane echo of the cabin window beyond them. Both follow the existing clearing cue. The amber light breathes almost imperceptibly; the architecture places it ahead on the horizon after the player has walked away from the house. The open center preserves the path, the light and Mathilda's silhouette as separate shapes. At the answer, the ground projection now gathers into two soft pools under the figures joined by a narrower bridge. It makes their positions legible before briefly implying a shared edge; the figures themselves remain separate, and the projection dissolves with the merge cue.

**Playable purpose:** choose a present action, a personal answer, or privacy. **Image:** an impossible side path surrounds a dependable place to stand.

### Scene G: the warning and wake — finish through action

The warning connects the cut trees, the handle near the window, and the direction of the light. Mathilda apologizes briefly for being difficult to follow, then states what she can and what she needs now. The apology should not become a recurring demand that the player soothe her.

Allow a short physical resolution before the wake: stand beside the light, offer to accompany her, keep a chosen distance, or leave space. The memory reflects the conversation. Mathilda's withdrawal, when it occurs, has an intentional exit direction and a cue; it is not a sudden rendering disappearance.

Resolved, unresolved, and ruptured outcomes each receive a distinct final composition and a complete emotional meaning. A private answer can still complete the dream meaningfully. A rupture follows an explicit boundary being ignored; an unresolved warning follows incomplete connection or observation, with a legible route back on replay.

## 7. Make dialogue a relationship, with believable branches

Replace the feeling of selecting the obviously virtuous sentence with choices between plausible intentions. A worried person may offer warmth too quickly, ask a concrete question at the wrong moment, or mistake silence for a request to take charge. Those choices create drama when the other woman responds specifically.

For each branch, author five things:

1. What the player character is trying to do.
2. What the spoken sentence actually asks or assumes.
3. How Mathilda interprets it in this moment.
4. What changes physically or conversationally.
5. Whether and how a repair remains available.

Use a compact set of meaningful state: explicit permissions, a boundary stated, a topic deferred, an observed motif, a repair attempted, and a practical offer accepted. Keep tension/pressure as internal pacing information rather than a displayed moral score. Observation unlocks context; it does not make someone owe an account.

An example choice set might include “I could put the kettle on,” “Would you rather stay out here?” and “You shouldn't be alone out here.” The first can be care or avoidance, the second leaves the location to her, and the third can become control. Her response and the follow-up reveal the difference. Examples in this plan are editorial directions, not replacement canonical lines.

Support four kinds of conversation path: ordinary rapport, a topic that opens, a respectful deferral, and a rupture with a chance to repair. Each path should contain something worth hearing. Do not reserve every interesting line for the single resolved route.

### Writing rhythm

- Begin many exchanges with something concrete: damp gloves, wind at the latch, a badly tied knot, a familiar cup.
- Let Mathilda's rambling combine myth, contradiction, and philosophical unease in original language. A drift should expose an emotional pattern even when its literal argument wanders.
- Follow dense imagery with an ordinary sentence or a physical request. That return to the present creates the impact.
- Give Ophelia distinct habits of speech: practical substitutions, self-correction, incomplete admission, then a simple ask.
- Preserve Mathilda's wit and decisiveness. Include moments when she refuses a premise or changes the subject for her own reasons.
- Remove lines that explain the symbol immediately after presenting it. Read every scene aloud for rhythm even when the dream ships without voice.
- Use apology at an authored turning point. Repeating it after every monologue weakens both her agency and the apology.

### One turn at a time

The presentation sequence is **speaker line → reading/listening time → reaction → replies or a new turn**. One system owns the active speaker. Ambient speech, encounter lines, reflection text, tutorials, and journal notices defer when a dramatic exchange has priority. A button press that finishes a line must not also select the newly opened reply.

Movement stays free between conversations. During an exchange, communicate the temporary hold clearly and restore the exact movement/look state on cancellation, pause, load, or topic exit. Never use hidden player positioning or unannounced camera rotation as a response to dialogue pressure.

## 8. Make the journal change understanding

Keep the dream journal separate from chapter page deciphering. Give them related visual language while preserving their different jobs.

The **dream journal** records observations, remembered wording, unanswered questions, and possible approaches. Its first layer should sound like the player's recollection. Practical guidance belongs in an optional secondary view, with the existing accessibility and prompt settings respected. Replace constant numeric clue messaging with unobtrusive, useful feedback at deliberate moments; players should not have to watch a completion counter while Mathilda speaks.

The **chapter journal** remains physical evidence and interpretation: smudges, alternate readings, unlocked words, and between-the-lines discoveries. Strengthen the relationship between a newly unlocked reading and the place or action that made it possible. A changed interpretation should refer back to a concrete observation rather than appearing as an unexplained vocabulary reward.

Allow a player to revisit an entry without losing the current line, choice, or reveal. Show a concise return context after loading: the last completed observation and the current practical situation. This is orientation, not an objective marker.

**Acceptance:** a player can explain why an interpretation became available and what remains uncertain. The journal helps attention without supplying a universal answer key to another person's feelings.

## 9. Strengthen Ophelia's chapter through domestic action

Compose the cabin as the emotional baseline of the entire game. Its objects should demonstrate a shared life: one badly repaired latch, cups stored in a practiced arrangement, a list with a missing subject, red wool caught on an ordinary surface, gloves that have been moved rather than conspicuously placed as loot.

Give the opening one short, optional practical action whose meaning returns later: tend the stove, set down a cup, or inspect the open latch. The game already knows chores and encounters; reuse those systems rather than creating a new inventory puzzle. Let that action alter a later passing or the doorstep composition in a small, legible way.

Rework the trail's page progression as five changes in understanding. Each page should either contradict an assumption, reveal a human detail, or make an earlier action feel different. Avoid repeating the same “the world is wrong” message at increasing volume. Keep the cellar's institutional language cold and sparse; the contrast with domestic language is its strength.

Make the lookout deception emotionally credible. From the route, its lights resemble a practical way out. At arrival, the expected evidence fails: no car, no road, a wind that does not carry an engine. Let the player discover the mismatch through movement and sound before a caption confirms it. The posts toward the lake should immediately supply a readable continuation.

**In progress (2026-10-15): errands and environment interactions.** The optional practical actions take the form of four *errands*: warm the house, set out two cups, follow the red thread, and carry a light into the dark. They are kept in the journal's *Undone* list in her own words, never on the HUD, and none gates an ending. Seven verbs support them and stand on their own: carry, place, hold to do, open and look inside, knock the snow down, warm her hands, and ring the lookout bell. Carrying is one thing held in her arms, never an inventory. Each errand pays off in play: a calmer house, a `{cups}` reading and a line on the ice, a keepsake page and a glove at the camp, a lamp for her night. Specification: [errands design](superpowers/specs/2026-10-14-errands-and-interactions-design.md); execution and status: [errands plan](superpowers/plans/2026-10-14-errands-and-interactions.md).

At the lake, the conversation should move from accusation or evasion to an actual ask. Keep the existing encounter and journal references, but protect a clear dramatic spine for players who did not discover optional material. Every successful relational ending earns a physical change: walking beside, stepping aside, or keeping a light without calling the other woman back.

## 10. Give Mathilda's chapter equal emotional weight

Make the camp a place Mathilda has chosen and maintained. The cups, gloves, note, fire, and guy-line should form a short arc of practical competence. Her choices reveal taste and humor as well as hurt. Chores are small acts of agency, not busywork that delays a dialogue reward.

Revisit each required inspection: does it reveal a different need, or simply increment progress? If the required sequence feels repetitive, combine redundant interactions or make an order-dependent line respond naturally while preserving the chapter's completion rules.

Use first-person presentation to distinguish Mathilda's body in the cold: hands near a cup, gloves put on, breath settling while the fire improves. Begin with restrained gestures supported by the existing rig and assets. Do not schedule an extensive first-person hand system before the camp scene proves it needs one.

The return walk should be a dramatic scene of its own. The house gradually becomes audible; the door's condition matters; Ophelia's position must leave a way past her. Keep the established doorstep exchange as the model for specificity: the shopping-list admission answers a concrete past failure, then the offered cup follows listening rather than preceding it.

Wait must remain a complete choice with dignity. Return must not imply that Mathilda takes back her anger. The chapter should end with her decision rather than with a diagnosis of what she represents.

## 11. Compose the landscape at three scales

### The walking line

The route is the player's dependable physical thread. Preserve continuous footing, camera clearance, note access, and readable forward/back directions. Use low snow banks, trunk groups, shadow, tracks, and light to suggest the line without an objective arrow. Keep the recently added decorative clearance as a baseline, then inspect whether a uniform empty strip looks too artificial at particular bends.

Compose selected route sections by hand: the threshold, a sheltered bend, the delayed-step pocket, the window, the lookout approach, and the final posts. Procedural placement fills the space between them. Required interactions and clue sightlines use reserved volumes, not a lucky random seed.

### The scene around the path

Use clusters with an understandable origin: stones at an eroded bank, fallen branches near a tree, grass at the thaw edge, drifted snow on the leeward side of a structure. Vary silhouette and scale within a coherent group. Sink and orient assets convincingly, and inspect their source pivots before trusting placement offsets.

Remove isolated pieces that look dropped into the scene. A missing texture, harsh material mismatch, floating rock, card-tree edge, repeating mound, or obstructed camera is a quality defect even when the terrain itself is detailed.

### The horizon

Give the horizon a few recognizable mass shapes and a controlled light hierarchy. The finer terrain spacing should be measured for silhouette improvement and frame cost; extra vertices alone will not create better composition. Use vegetation groups and atmospheric depth to separate near, middle, and far space.

Maintain a snow-dominant story area with clear material transitions toward green land. Match snow hue, roughness, accumulation, and contact across terrain, props, roofs, footprints, and particles. One environment should not read as several unrelated asset packs.

## 12. Give impossible space explicit rules

The dream's current memory architecture stays embedded in the winter route. The player remains in one playable phase, with continuous ground and an open way forward. Additional self-contained flashback levels are outside this roadmap's initial scope.

Use three carefully authored classes of impossibility:

| Type | Concrete treatment | How the player discovers it |
| --- | --- | --- |
| Contradictory bearing | A lighthouse's relationship to the house cannot remain true across two viewpoints | Walk past trunks, then look back; ordinary parallax makes the inconsistency visible. |
| Folded extent | A plausible side path rises and returns somewhere its visible length cannot reach | Follow the shape with the eye while standing on a stable main route. |
| Overlapping place | An enclosed warm room shares the snow and exterior space in a way its wall should prevent | Approach its edge or move to a second viewpoint; the join reveals the contradiction. |

Prototype each with simple geometry, then finish the form before adding detailed assets. Maintain correct local proportions, material continuity, contact shadows, and complete building silhouettes. The impossibility belongs to spatial relationships; incomplete carpentry should not be asked to carry it.

Keep one dominant contradiction in a view. Let the rest of the image be plausible. Give each motif a reveal condition, a sustained state, and a quiet after-state. Essential information cannot require the player to catch a split-second illusion.

Actual traversable portals or runtime remapping of collision are deferred until the existing folded-space motifs are readable and performant. If later introduced, prototype one optional, short passage with consistent navigation, backtracking, and save behavior before expanding it.

## 13. Establish a visual hierarchy for shaders and light

The image priority is **safe footing and interaction → active speaker and words → emotional landmark → atmosphere and optical treatment**. An effect that reverses that order needs redesign.

Use grounded winter materials and a consistent stylized character treatment. The current character rig can remain; a believable winter coat, gloves, scarf, and boots would connect the visible body to the story's central coat imagery. Evaluate whether the existing fantastical anatomy is an intentional part of the setting before changing character identity. A new gallery roster is not required for this upgrade.

Mathilda's shadow retains the dark purple aura already requested. Shape it as a low luminance rim and small local spill, with the core silhouette darker than the surrounding snow. Give it a different animation on approach, listening, rambling, and withdrawal. Avoid a persistent bright halo that makes her read as a magical collectible.

The current visual pass keeps the persistent glow on her body silhouette, reserves the surrounding shell for brief cue accents, and replaces hard square motes with small soft flecks that fade over their lifetime. Lean graphics reduce their count; disabling screen effects removes the decorative spill and flecks while retaining the figure.

Build an effect hierarchy:

- **Persistent baseline:** material coherence, slow fine snow, atmospheric depth, restrained CRT marks, barely perceptible aura.
- **Local disturbance:** one delayed shadow, a slight boundary shimmer, a beam with an impossible bearing, an interior tone entering outdoor light.
- **Brief escalation:** a bounded perception pulse at an authored emotional turn, followed by recovery.
- **Rare dissolution:** the relationship between the player's outline, Mathilda's shadow, and the landscape becomes momentarily uncertain while the ground remains stable.

For dissolution, begin with softened body separation, a shared shadow direction, reduced environmental contrast, and a light rhythm that seems to breathe with both figures. Review the effect without words on screen. Repeated giant character copies and continuous chromatic smearing can suggest rendering faults; reproduce the current afterimage captures and establish a deliberate maximum size, count, duration, and screen coverage.

Use cold blue as the stable base, warm amber as a scarce relational invitation, and purple as Mathilda's perceptual edge. Reserve red for wool, interface emphasis, and selected danger associations. Validate compositions in greyscale so route and speaker readability do not depend on hue alone.

## 14. Choreograph bodies and camera as dramatic tools

Create a small, reusable acting vocabulary: arrive, hold distance, half-turn, look away, seek eye contact, begin an offer, withdraw it, step aside, match pace, and leave. Each action has an intention and a cue. Natural transitions between these actions matter more than a large animation library.

When Mathilda speaks directly, the two figures generally face one another. When she drifts into a monologue, she may orient toward the associated landmark while the player retains a readable view of her. A return to eye contact marks a return to the present. Do not force the player's free camera to imitate eye contact during traversal.

Apparition has a sequence: a plausible entrance or occlusion, a sound or light preparation, a stable silhouette, then a response to the player's attention. Disappearance has a direction, an emotional reason, and an aftermath. No visible relocation should occur because the player crossed an arbitrary distance while looking at her.

For each scene, record a default player view, an alternate approach, a close conversation composition, and a lookback. The camera can offer a gentle composed hold during an accepted conversation, with a reversible transition and clear cancellation. Camera collision, sudden recentering, body clipping, and inappropriate FOV changes remain unacceptable during a dramatic handoff.

Current reply handoffs preserve both actors' positions and ease their body turns without changing the player's camera heading. The composed camera is limited to partners within nine metres; more distant exchanges retain the ordinary player view and associated dialogue text. World geometry bounds camera movement during the hold and return, and snapshot restoration keeps the speaker in place.

Camera acquisition waits briefly for the player's spring arm after spawning or restoring a run. Reply placement gives Mathilda's silhouette priority over the player's body, and offering company produces a measured step even when the two figures are far apart.

Keep motion immediate and animation fluid. Evaluate starts, stops, reversals, low stick input, slope movement, and movement after leaving a conversation. Match the rig's foot speed to actual travel, especially if collision stops the body while its intended momentum remains high. Validate the recent start-impulse and camera-lead changes in motion before further tuning.

## 15. Make sound tell a parallel story

Give each mode an identifiable sound perspective. The dream relies on subtitles and nonverbal sound. The two chapters retain their distinct authored voice identities and mood performances.

| Scene or state | Main sound | Withheld sound | Narrative job |
| --- | --- | --- | --- |
| Cabin | Stove, boards, wind through a specific gap | Broad cinematic drone | Establish a lived space whose small changes will matter. |
| Open field | Wind with changing shelter, steps, cloth | Constant threatening footsteps | Let distance and exposure become physical. |
| Dream late step | One displaced step, then quiet | Repeated confirmation | Make the anomaly precise and doubtful. |
| Lighthouse | A low local resonance and slow beam-related change | Loud reveal sting | Give an impossible landmark a material presence. |
| Warm window | A restrained room tone leaking into snow | Spoken reenactment or an attack cue | Make shelter and remembered danger occupy one place. |
| Clearing | Reduced weather, a sparse ice resonance | New explanatory ambience | Give words and choices enough room. |
| Doorstep | Latch/board detail, weather ducked beneath each turn | Forgiveness music before consent | Let small actions carry the scene's change. |
| Lake | Ice, breath, the distance of the voice | A constant climax bed | Make standing still feel consequential. |

Use sound absences as cues, but maintain an audible baseline so quiet does not resemble a broken audio system. Delayed steps and creaks need limited repeat rules. Suspense comes from uncertainty about the next recurrence.

At the dream lantern, the live wind now responds to the player's choice and distance. The flame leans into the weather while exposed, steadies when sheltered, and holds a smaller warmth if the player leaves and returns. The existing storm bed eases down near a sheltered or revisited light, then opens again as the player walks away; this carries the action without a score or extra dialogue.

Score conversation as a mix state: retain world presence, lower competing layers, protect chapter voice intelligibility, then recover gently. Pause, interruption, loading, and title return must restore the correct mix rather than stacking ducks.

Preserve the title song's established start at seven seconds and one-second fade to full level at eight. Menu music ends when entering Dream, Ophelia, or Mathilda. Gameplay sound begins from its own state. No dream spoken lines are added by this roadmap.

## 16. Make interface identity support immersion

Retain the restrained computer/CRT identity already established for settings and the game menu, and use the same typography, spacing, focus treatment, and red emphasis across the HUD. The result should have an original visual identity suited to this game's domestic winter story.

Give each layer a clear job:

- The active Mathilda speech box sits above her head, readable at every subtitle size and safe distance. If a stable world anchor is unavailable, use a clearly associated accessible fallback with a speaker indicator.
- Player replies occupy one stable area associated with the player's turn. Focus remains visible on mouse, keyboard, and controller, including after input-device changes.
- Exploration prompts show the interaction the player can actually perform. Unavailable interactions give precise feedback without obscuring a conversation.
- The journal uses the same design language at a calmer density. A note is first a sheet of paper or an observation, not a decorative pile.
- Pause/settings remain a dependable conventional menu with save, load, and title return. Their flicker is decorative and governed by settings.
- Technical feed marks remain sparse. Japanese labels should be intentionally chosen and reviewed for meaning, with fonts that render them correctly.

Reduce simultaneous HUD layers during important scenes. A clue notice waits until a speech turn or reaction interval permits it. No permanent objective, numerical trust meter, or demand to complete a checklist is added to the exploration HUD.

Separate text readability from optical intensity. Offer control over flicker, distortion, camera shake/FOV changes, subtitle size, and text hold where practical. Essential conversation text remains available when ordinary exploration subtitles are disabled. Muted audio, reduced effects, and lean graphics preserve the same information and consequences.

## 17. Turn each scene into an art-directable specification

Before implementing another major landmark, give it a one-page scene sheet with these fields:

| Field | Required content |
| --- | --- |
| Identity | Stable scene ID, mode, route anchors, prerequisites, and optional/required status. |
| Dramatic action | What each woman wants now, what obstructs it, and what can change. |
| Player action | The concrete verbs available; a valid way to decline, leave, or pause. |
| Writing | Entry line, drift, return to the present, reply intentions, branch joins, and exit lines. |
| Blocking | Figure positions, walk paths, gaze targets, gesture cues, arrival and departure. |
| Composition | Dominant shape, light source, palette, player-camera views, and quiet visual areas for text. |
| Impossibility | The one contradiction, how movement exposes it, and its reduced-effects treatment. |
| Sound | Baseline, event cue, withheld layer, quiet interval, and mix recovery. |
| State | Stable IDs, commit point, replay rules, backtracking behavior, cancellation, and save/load restoration. |
| Cost and evidence | Asset provenance, mesh/texture/effect cost, captures, motion clip, and focused verification. |

Add an explicit attention schedule to each sheet. A starting pattern is preparation, readable reveal, speech, reaction, reply, consequence, and quiet travel. Durations are authored ranges and reading-sensitive; pauses and journal access suspend the dramatic timer. A player can walk quickly without making the speaker accelerate into an unreadable backlog.

**A scene is ready when its sheet explains how it begins, what the player can do, how it changes, and how it ends or resumes.**

## 18. Grow the architecture without losing the working game

Keep story content deterministic and authored. Let scene state own timing and presentation, while data owns words, choices, conditions, and stable cue IDs.

Evolve the current dream schema only as needed. Useful additions include explicit line IDs, reaction holds, gaze intent, motion cue, topic/permission changes, motif evidence, and named visual/audio cues. Every new field needs a runtime validator, Python normalizer support, Story Studio controls or preservation, and a safe default for old content. A Studio save must not erase staging metadata it does not yet edit.

Gradually separate three responsibilities from `DreamExperience`: conversation turns, figure choreography, and journal presentation. Start by extracting existing behavior behind the same interfaces. Integrate one extraction at a time with a behavior comparison; do not combine a large refactor with a wholesale narrative rewrite.

Story Studio should eventually show a scene's playable order, branches, motion/gaze cues, effect timing, and remembered consequences together. Add a branch preview that explains why an option or ending is available in a chosen state. Authors should be able to see a dead end, an unreachable repair, or a clue revealed before its line without launching a full run.

Use the existing animation workbench to audition the small acting vocabulary on the actual game rig. Preserve skeleton/rest transforms, foot contacts, clip provenance, and retargeting compatibility. Move measured hot loops to C# where profiling justifies it; narrative state and authoring data need clarity more than a language conversion.

### Save/load is part of scene design

Continue using the platform-local save system. New scenes must capture active IDs, completed cues, chosen responses, topic permissions, relevant figure position/pose, reveal progress, journal state, and outstanding transitions. Serialize stable state rather than callbacks or transient nodes.

Make response commitment atomic: once a choice is committed, a load cannot apply its consequence twice or reopen a conflicting selection. Restore a mid-line read state and a safe presentation pose without losing the fact that the line started. Document how interrupted gestures and audio resume; preserve the narrative state even when a transient effect restarts softly.

Version additions deliberately. Keep existing dream memory IDs and use explicit migrations or safe defaults for new scene data. A rolling run save and persistent completed-dream memory have different lifetimes and must not overwrite each other's meaning.

## 19. Budget performance around the important images

Use measured frame time on a named reference machine and a named lean configuration. Start with a 60 FPS target at the current 1600 × 900 viewport on the reference setup, then record median, 95th-percentile frame time, and long stalls at each dramatic landmark. Treat that target as a production objective until a baseline establishes what the hardware supports.

Prioritize the cost that is visible in the current camera: transparent snow/fog/afterimages, dynamic lights and shadows, active UI textures, material passes, and terrain/flora submission. Keep finished memory geometry mostly opaque; apply transition effects at boundaries where possible. Use bounded local light ranges and intentional shadow contributors.

Measure the finer terrain grid against its actual visual benefit. Keep integer-compatible terrain spacing and verify seams, collision, cache invalidation, and startup cost. Compose essential props and reserve their space independently of procedural detail.

Lean graphics may reduce distant vegetation, particle density, shadow refinement, and optical layers. It retains landmark silhouettes, clue visibility, the figure, response focus, and outcome cues. No ending depends on a decorative mesh or shader that disappears in lean mode.

Reuse assets with known provenance and consistent materials before sourcing replacements. Owner-supplied packs and downloads without verified redistribution rights stay local; a releasable fallback must support the same scene composition. New assets come from the owner's asset bank first (`C:\Users\soulwax\OneDrive - Biz\Desktop\Assets`), through a curation script and a manifest. **Proprietary assets live in the git-ignored `build/` folder** (`build/vendor/requested_<area>/`, decided 2026-10-15). Because `build/` is not imported by Godot, the game reads them at runtime through `VendorLoader`, and a release ships them in a `vendor/` folder beside the executable or falls back without them. The errand props are the first area built this way. The older `assets/vendor/requested_house|camp|dream|paper/` folders move one at a time after the errands, each checked against its probes and startup time (errands plan, Task 13). The current animation licensing makes the project non-commercial; presentation upgrades do not erase that constraint.

## 20. Implementation order and reviewable milestones

The first milestone is a polished playable dream whose images, branches, and wakeups express the same story. The second connects that language to both chapters. The third brings the whole game to consistent presentation and release quality. These are bounded slices, suitable for sequential work or small assigned tasks with one owner per file.

Priority labels mean **P0: correctness, readability, or a release blocker; P1: the dramatic upgrade; P2: consistent finish**. A later-numbered P0 requirement still receives attention as soon as an earlier slice exposes its dependency.

| Slice | Priority and ownership | Concrete deliverable | Exit criterion |
| --- | --- | --- | --- |
| **1. Baseline and story contract** | P0; story documents, JSON audit, current captures | Story bible, intentional-contradiction register, mode map, and a playthrough evidence set | Every existing ending and motif has a documented dramatic job; current defects are reproducible. |
| **2. Focus and readability** | P0; dream presentation, dialogue UI, `signal_glass.gd`, affected shaders | Eliminate unintended afterimage clutter, text collisions, detached speaker ambiguity, and simultaneous notice layers | Normal player camera reads the route, speaker, and choices in full/lean and reduced effects. **Visual review 1.** |
| **3. Threshold and human baseline** | P1; `dream.json`, story validators/Studio, figure staging | Revised opening and one complete threshold scene with ordinary small talk and intentional apparition | A new player can orient, identify the speaker, and choose a distance before the first major anomaly. |
| **4. Late step and lighthouse** | P1; route, memory architecture, soundscape, choreography | Two distinct scene sheets implemented with quiet travel between them | The anomaly is readable through player movement; cue, line, gesture, sound, and reveal share the same timing. **Visual review 2.** |
| **5. Conversation depth and journal** | P1; story/branch data, turn controller, dream journal, Studio | Plausible reply intentions, respectful deferrals, repair paths, contextual observations, and subtle clue feedback | All meaningful paths contain human detail; explicit boundary crossings have readable consequences and repairs. |
| **6. Window, clearing, and wake** | P1; memory architecture, dream flow, figure, dream outcome data | Finished warm room, final conversational arc, distinct physical closure for all three outcomes | A complete dream can be played slowly, quickly, privately, with repair, and with rupture. **Visual review 3.** |
| **7. Resume and interaction reliability** | P0 release dependency; `run_save.gd`, dialogue state, phase flow | Mid-scene snapshots and cancellation/return behavior for the new scenes | Save/load during speech, reply, reveal, gesture, journal, and wake preserves the committed story state exactly once. |
| **8. Ophelia's domestic and trail arc** | P1; house, pages/journal, Voice scripts, trail, lookout/lake | One opening practical action, stronger page progression, coherent false-light reveal, and a clear lake spine | Each major discovery changes a specific assumption and supports the ending's present choice. **Visual review 4.** |
| **9. Mathilda's agency and return** | P1; camp, `mathilda_pov.gd`, doorstep script/data/choreography | Distinct camp action arc, worthwhile Wait ending, composed return walk, and staged doorstep gestures | Mathilda's perspective feels complete; return retains her boundary and Wait retains dignity. |
| **10. Shared motif echoes** | P1; reflections, encounter references, small scene state | Contextual echoes of dream memories and practical actions across both chapters | Each echo changes a familiar object's meaning without repeating exposition or closing a chapter path unfairly. **Visual review 5.** |
| **11. Material, landscape, acting, and sound finish** | P2; relevant art owners and performance tools | Winter character treatment, composed route pockets, material consistency, acting transitions, final mix, and lean parity | No unfinished structures, floating props, distracting shader repetition, foot skating, or broken mix handoffs remain in the critical path. |
| **12. Whole-game review and release preparation** | P0 gate; build/export, data checks, evidence, documentation | Validated candidate, synchronized versions, license inventory, and short release copy | All critical paths and restoration cases pass, the exported build is exercised, and remaining defects are explicitly triaged. **Visual review 6.** |

Slice 8's practical actions are being delivered by the errands plan (tasks 0–12), and its Task 13, the asset move into `build/`, feeds slice 12's license inventory and release preparation.

Start a narrow save/load check whenever a slice adds persistent state; slice 7 completes the broader restoration pass. Similarly, record performance during each visual review rather than postponing all measurement until slice 11.

Each task handoff includes changed files, data/API additions, state ownership, asset provenance, known limitations, and review evidence. Shared files such as `dream_experience.gd`, `dream.json`, `main.gd`, and `run_save.gd` have one active owner. Art tasks can work against stable scene-sheet contracts before integration.

## 21. Verification that proves the experience

Review both function and feeling. Existing probes are useful for flow and state, while player-camera captures and short moving recordings establish whether a scene actually reads.

### Meaningful path coverage

Exercise: first entry to each mode; a resolved dream; a private final answer; incomplete observations; an explicit rupture; a repaired exchange; a player who sprints; a player who backtracks; and a player who leaves a conversation. Cover the lake and doorstep endings, the lookout checkpoint, Mathilda's Wait, and the day-limit outcome.

Exercise saving and loading at a completed cue, mid-line, with replies open, inside the journal, during a reveal, during figure movement, at the clearing, and immediately before/after a committed final choice. Verify damaged-primary recovery against the existing backup behavior. A load must not silently repeat a choice, clear a permission, or leave controls locked.

### Presentation review every other slice

At slices 2, 4, 6, 8, 10, and 12, capture the normal player camera and an overview, plus a short moving clip showing approach, speech, reply, and departure. Inspect full/lean, reduced screen effects, muted audio, the largest subtitle size, mouse/keyboard, and controller. Add varied aspect ratios and a lower frame rate to the final interface review.

Review artifacts should state scene/cue IDs, route seed, mode, graphics/effects settings, resolution, and frame timing. Keep generated evidence under ignored `build/` directories. A beautiful review camera does not excuse an unreadable player view.

### Existing tools to use proportionately

Run commands from the repository root in PowerShell. This workstation uses `$env:GODOT_BIN`; do not assume a generic `godot` command resolves to the matching Mono build.

```powershell
dotnet build OpheliasDream.csproj
& $env:GODOT_BIN --headless --path . --import
& $env:GODOT_BIN --headless --path . tools/dream_story_probe.tscn
& $env:GODOT_BIN --headless --path . tools/dream_flow_probe.tscn
& $env:GODOT_BIN --path . tools/dream_view.tscn
```

Use `tools/journal_probe.tscn`, `tools/meeting_probe.tscn`, `tools/encounter_probe.tscn`, `tools/mathilda_probe.tscn`, and relevant terrain/movement probes when their owned behavior changes. Use `tools/terrain_view.tscn`, `tools/camp_view.tscn`, and `tools/performance_probe.tscn` for their respective review surfaces. Verify changed chapter script/voice manifests before baking; keep existing speaker conditioning and archive rather than delete superseded clips.

The commands above are planned checks, not results from this documentation task.

### First-time player questions

After a session, ask the player to describe the experience without teaching its symbols first:

- What were you trying to do in each mode?
- When did Mathilda feel most like a person?
- What did you think she wanted from you in that scene?
- Which object changed meaning later?
- Where did the world seem impossible, and how did you notice?
- Did you understand when it was your turn and why the conversation changed?
- Was there a moment when navigation, text, or an effect pulled you out of the scene?
- What did the final action resolve, and what remains uncertain?

Their answers should reveal a human conflict and a remembered image. Knowing the mythology is optional. If players report a shader, a checklist, or a correct-answer quiz as the main experience, revise the composition and choices before adding content.

## 22. Scope discipline and release gate

Finish a small set of exceptional scenes before extending the world. The initial roadmap does not require new combat, a larger character roster, a complex inventory, a procedural dialogue generator, or a new renderer. Existing assets and systems can support the dramatic upgrade when their staging and state are coherent.

A release candidate is ready when:

1. Each mode has a clear beginning, a human stake, a playable change, and a complete ending.
2. Mathilda's personhood and agency survive every major interpretation of the story.
3. Dream dialogue is subtitle driven, one turn at a time, with legible responses and graceful cancellation.
4. The landscape and impossible architecture feel composed and finished from the normal player camera.
5. Surreal treatment supports the scene and can be reduced without losing information.
6. Every significant branch, clue, checkpoint, and saved mid-scene state remains playable.
7. Frame cost, startup cost, visual continuity, and input response meet the documented reference targets.
8. The export contains the required .NET runtime data and only assets with appropriate redistribution rights; all optional local packs have adequate fallbacks.
9. Authoritative scripts, story data, editor normalization, save schema, and player documentation agree.

Release notes can retain the requested cryptic haiku form after the practical build and compatibility notes have been recorded internally. Public mystery should arise from deliberate composition; production decisions and release validation should remain explicit.

The first work to schedule is **baseline/story contract → focus/readability → threshold**. That sequence makes a stronger foundation for every later monologue, impossible landmark, and ending.
