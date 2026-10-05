# Threats

The figure in the tree line and the Listener (2-117) are gone, with their code, their records and their place in the editable level. The six threats below are possible ideas only: none is chosen or scheduled yet. What stays is the interface a threat plugs into:

- `Game.closeness` (0..1) for the one that hunts her, and `Game.dread` with `Game.threat_hint` for any other pressure. The HUD vignette, the heart, the warning line and the birds already answer to `Game.threat()`.
- `Game.catch_player(title, body)` ends the run with the threat's own card.
- `Game.hunt_started` turns true after `Tune.HUNT_NOTES` pages or `Tune.HUNT_ROUTE_DISTANCE` metres. `Game.seconds_hunting()` counts from then.
- `Game.something_at_door` makes the house knock hard. `Game.shown_threat` makes a raven scold from the nearest pine.
- `Trail/Threats` is the authoring slot for their markers (kept before `Route` so the editable level keeps its order).
- A record page is a `NoteEntry` with `record_of` set to the threat's code; reading it sets `Game.knows(code)`.

Escape no longer depends on a threat: `Game` ends the run as soon as she is within `EXIT_RADIUS` of the road.

Each idea below has one rule, tells the player can learn without a meter, a counter that uses something already in the game, and a short ending. None of them reuses the old rules (stillness and being watched; visible breath). Holding her breath stays a player mechanic with nothing that listens for it yet.

## 1. The Second Walker

**Rule.** It walks her trail exactly, print by print. It only ever steps where she has left a print, and it never steps off them.

**Tells.** A second footfall lands a beat behind her own, in her rhythm, on the snow. Prints she has passed fill into doubled bowls, one sole nested in another (`Footprints.Mark`). It is never seen.

**Counter.** Break the line. Boards, stone and the porch take no prints, so the cabin and the rocks are where it loses her. A slide leaves a smear it cannot read. A squall fills prints faster than they fade. Doubling back makes it walk the whole loop she made. Standing still lets it close.

**Ending.** It reaches the print she is standing in. *Every print has two in it.*

**Uses.** The footprint pool (positions and order), `FootLock`, `Soundscape.play_step`, the weather. No mesh. It is what the second page already counted: *the second count had one more.*

## 2. The Undertow

**Rule.** Something moves under the snow toward impacts. Running and landing are loud to it, walking slowly is not, and anything solid underfoot (boards, stone, a rock, the porch) is a wall.

**Tells.** A raised line ploughs through the snow toward her last hard step (the berm the prints already raise), powder lifts along it, and the pad rumbles low. Prints near it sink.

**Counter.** Cross open snow at a slow walk, and move between hard islands. Land jumps on rock, not snow. Stay still on the porch and it circles.

**Ending.** The snow opens under her. *The snow closed over the place you were.*

**Uses.** The footprint shader for the wake, `SnowKick`, `FootLock` step power, surface tags, `walk_slow`, `Game.rumble`. No mesh.

## 3. The Counter

**Rule.** It counts sounds louder than a footstep on snow, each one by its level at the door (`Loudness`). Every third sound, it knocks back three times. Every three knocks, it is one room nearer: the step, the porch, the hall.

**Tells.** The house answers her with knocks in threes. Boards creak under her at a walk and not at a slow walk. Silence lets the count fall back.

**Counter.** Walk slowly indoors, keep to the rugs, ease doors and leave switches alone. The cabin is safest when she is quiet in it, which is the opposite of what the warm light suggests.

**Ending.** *You counted for it.* This is the last page's warning made literal: *if you hear three strikes on the door you are counting for whatever is on the step.*

**Uses.** The SPL model, the haunting's knock and creak, doors, switches, rugs, `walk_slow`. No mesh.

## 4. The Draught

**Rule.** It goes to the warmest light it can see. Light it reaches goes out, and the cold comes in behind it.

**Tells.** Lamps gutter in the order it passes them. Frost creeps across the windows. The warm bounce indoors drains toward blue. Her hair and hem stir in a room with no open door.

**Counter.** Darkness. Switch rooms off before it arrives (the wall switches), and cup her own lamp with a held key at the cost of seeing nothing in the storm. Move between pools of light it has not reached yet.

**Ending.** It reaches her in the dark it made. *The lamp was the last warm thing in the room.*

**Uses.** `WallSwitch`, `House.room_lights`, the player's lantern, `Atmosphere.shelter`, the haunting's flicker. It turns the warm cabin into the beacon.

## 5. The Shepherd

**Rule.** It is there only when the weather closes (squall, whiteout). It stands at the edge of what she can see, always on the route, so she walks away from it. It herds her off the path.

**Tells.** A shape at exactly the distance the fog allows, moving to stay ahead of her. The fence hum grows as she drifts toward it.

**Counter.** Navigate by something it cannot stand on: her own prints, the landmarks, the fence's hum. Or stop and wait for the weather to lift.

**Ending.** She walks far enough off the route in a whiteout. *You walked until the snow was the only direction.*

**Uses.** The weather regimes and visibility, the route curve, the fence. It needs a silhouette. Source it (the Quaternius rig is still on disk as the animation source); do not model one.

## 6. The Caller

**Rule.** It cannot open a door. It can only come through one she opens for it, and it knocks in her own rhythm to make her.

**Tells.** The knocks match her footfall cadence. The steps overhead in the cellar walk the way she walks. The house's murmur lines quote the pages.

**Counter.** Never open the door it knocked on. Wait it out, or leave by a way it is not at.

**Ending.** *It knocked the way you walk.*

**Uses.** The haunting's knocks, steps above and murmur, and the doors. No mesh. It needs a second way out of the cabin to be fair.

## Pairing

One outside and one inside works best. The Second Walker or the Undertow cover the field. The Counter or the Draught cover the cabin, and each pushes against the warm room in a different way. The Second Walker fits the pages most closely, and the Counter fits the last page.
