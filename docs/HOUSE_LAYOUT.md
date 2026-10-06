# Roomier house layout

Planned 2026-10-06, before geometry and furnishing changes. Coordinates are house-local metres: +Z faces the snowfield; y=0 is the upstairs floor.

## Player and camera metrics

The player collider is 0.68 m wide and 1.55 m high; the indoor camera arm is 1.75 m with a 0.22 m sphere sweep. Design with that actual controller rather than scaling a real floor plan indiscriminately. [Epic's blockout guidance](https://dev.epicgames.com/documentation/en-us/unreal-engine/designer-01-project-setup-and-level-blockout-in-unreal-engine) recommends testing player-scale references, third-person hallway clearance, and believable rather than strictly real-world proportions.

| Element | Target | Reason |
| --- | --- | --- |
| Upstairs interior | 12.6 × 9.8 m (123.5 m²) | Up from 9 × 7 m; room to turn and orbit |
| Bedroom | 4.8 × 4.3 m | Clear walk from bed/page to door |
| Entry hall | 3 × 4.3 m | Turn, open doors, see the front exit |
| Living / kitchen | 4.8 × 9.8 m | Distinct sitting and dining zones |
| Back hall | 7.8 × 5.5 m | Open approach to the existing cellar stair |
| Ceiling | 3.15 m | Head and camera clearance without cathedral scale |
| Door openings | 1.3 × 2.3 m | Clearance for collider, camera and swung leaf |
| Main circulation | At least 1.4 m clear; hall 3 m | Keep furniture and collision out of the route |
| Side-table height | About 0.7 m | Believable scale cues; furniture stays normal size |

Dimensions are blockout targets, not universal standards. Existing cellar geometry remains the colder, tighter contrast; its stairs and terrain opening stay aligned.

## Plan

```text
                         BACK (-Z)
         x=-6.3              x=1.5             x=6.3
 z=-4.9  +---------------------+----------------+
         | Back hall           | Kitchen/dining |
         | Existing stair down | Table and tea  |
         | <- cellar           |                |
         |                     | Open passage   |
 z= 0.6  +-----------+ door ---+                |
         | Bedroom   | Entry   | Living room    |
         | Bed/page  D hall    D Sofa / rug     |
         | Reading   | 3m wide | Armchair       |
 z= 4.9  +-----------+ front --+----------------+
                         PORCH / SNOW (+Z)
                  x=-1.5       x=1.5
```

Preserve the gameplay sequence: wake beside the bedside page → hall → optional living room/back hall → cellar or front door → field. Furniture anchors perimeter seating and a reading nook; a broad central lane connects both living-room openings. Page, lantern, spawn, windows, room volumes, porch, reverb and door sweeps must move with the walls.

## Cosy asset shortlist

Use the existing warm wood, sofa, bed, books, lantern and tea set. Add three small [Poly Haven CC0](https://polyhaven.com/license) models at 1K texture resolution:

- [Arm Chair 01](https://polyhaven.com/a/ArmChair_01): upholstered reading chair beside the bedroom window.
- [Round Wooden Table 02](https://polyhaven.com/a/round_wooden_table_02): tea table beside the chair, kept outside circulation.
- [Throw Pillows 01](https://polyhaven.com/a/throw_pillows_01): woven rust/ochre accents on the living sofa.

The central bank contains imported house packs, but no verified redistribution license was found for the selected paid-pack candidates. Public CC0 models match the project's existing scanned furniture and can be stored with the source repository. Record authors, source URLs, license, hashes and local destinations in the existing Poly Haven provenance file; retain unmodified originals.

## Implementation and acceptance

Build structural dimensions explicitly; reposition furniture without scaling its meshes. Refresh the house portion of the editable snapshot while retaining the existing authored route/world. Avoid an old snapshot silently restoring the cramped shell.

Verify note access from inside and blockage through walls, spawn clearance, door openings/sweeps, travel from bedroom through both hall and living-room branches, and stair/cellar continuity. Inspect rendered bedroom, living room, entry and exterior views under Forward+; confirm cosy props, natural scale, roof coverage, lighting, and clear camera sight lines. Leave version/release work for an explicit release request.

## Completed validation

- `tools/house_space_probe.tscn`: the saved layout uses the expanded room volumes; all three imported models stay at scale 1; the default spawn is beside the bed and clear of collisions; all four upstairs doors open and admit the complete player capsule; the kitchen passage stays clear; a physical descent reaches the cellar landing.
- `tools/note_access_probe.tscn`: the bedroom page remains readable from inside, blocked through the exterior wall, and all five field pages remain accessible.
- Forward+ captures on Intel Iris Xe with `RUN_GRAPHICS=lean`: bedroom reading nook, living/kitchen circulation, and exterior roof/porch inspected. Captures stay in ignored `build/house-*.png`.
- Editable scene repacked with its existing seed and authored route. Layout-revision migration retains the new house as a coherent branch and resets an older saved spawn to the new bedside position.

The door leaf is 1.24 m wide within a 1.3 m opening. The 3 cm gap at each jamb is needed for its rotating hinge corner; the original 1 cm gap stalled the wider leaf near 65 degrees, caught by the passage probe.
