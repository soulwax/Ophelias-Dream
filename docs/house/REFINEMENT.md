# Scandinavian home refinement — planning revision 1

2026-10-06. Target: `F:\Workspace\run`. This is a proposed domestic refinement of the current house, not a replacement for its winter-horror setting. The existing game geometry and soundscape remain the baseline while the owner inspects candidate assets.

Implementation update: the first asset batch is now integrated. The bathroom reservation grew by 0.1 m to accommodate actual exterior wall thickness without shrinking the imported fixtures. See ASSET_BATCH_1.md for selected models, credits and validation.

## Spatial decision

Keep the 12.6 × 9.8 m upstairs interior, 3.15 m clear ceiling, pitched roof, exterior openings, bedside spawn/page, four main doors, and the cellar stair in their current positions. The oversized back hall has enough unused area for a compact bathroom with laundry in its west corner. It does not require expanding the roof or changing the world placement.

Reserve the bathroom at X `-6.3..-4.1`, Z `-4.9..-1.5`: a 2.2 × 3.4 m planning bay. Its south-facing 1.3 m doorway is centred at X `-5.25`, Z `-1.5`, opening into the bathroom. Keep a full-width front circulation strip at Z `-1.5..0.6`, linking the entry/back-hall door to that bathroom. The existing stair run ends at X `-3.9` and remains outside the new partition at X `-4.2`. Do not extend a bathroom wall down into the cellar landing below it.

The bathroom combines shower, toilet, small basin and one washing machine, as a practical compact home can. A separate laundry room would consume the stair approach; avoid adding one merely to display an asset. Fit the supplied fixtures into the reserved bay before committing partitions. Their current envelopes are provisional. The room's width allows roughly 2.02 m between the actual exterior and partition faces; test the real indoor camera because the controller uses a 1.75 m arm with a 0.22 m sweep sphere.

Use the north end of the existing east common room for the kitchen. Reserve a 0.65 m-deep cabinet run along the north wall, with a short west return/fridge. The current dining table stays near `(4.45,-2.7)`. Leave the west side of the common room open for the route between its entry door and back-hall passage. Appliance doors open into the kitchen working area, never into that through-route. Counter placement must retain the existing north window's light and avoid placing a tall unit across it.

Reserve the stove near `(5.4,-1.2)`, directly beneath the existing chimney. It sits between the dining and sitting zones, visible from the sofa, while the central west lane stays clear. The final hearth, flue connection and clearances depend on the selected stove mesh and its reference dimensions; the planning envelope is not a real installation specification.

Add a shallow drying/boot bench to the entry perimeter, with coats above and boots below. Retain the 3 m hall's turning space and every door sweep. Bedroom storage goes along its north perimeter away from the bedside page and reading nook. Preserve the existing sofa, armchair, daybed, tea table and pillows at their verified natural sizes.

## Material and light hierarchy

Use warm pale wall paint, restrained wood, oat/cream linen, worn rust wool and blackened stove metal. Keep the exterior weathered and cold. Avoid turning every surface into orange wood or adding a uniform warm ambient wash. The stove, bedside lantern and reading lamps are local warm pools; darker corners retain the horror atmosphere and let the cold windows read.

Keep the current roof and facade initially. Standing-seam metal is an optional later finish, not a dependency. Add practical domestic details in clusters: a coat and boots at the entry, towels near the washer, mugs at the tea table, logs near the stove. Keep the main route visually simple and readable.

## Preserve and refine sound

The existing recorded storm and gusts remain authoritative. `Weather` already eases the shelter transition over about 0.7 seconds. `StormAudio` filters the outside bus toward 650 Hz under shelter and places whistles at nearby windward windows. `Soundscape` already separates timber-room and stone-cellar reverberation. Retain that spatial/dynamic mix and all audio settings.

The stove adds a quiet local crackle through the established effects/room routing, with its level set alongside `Loudness` rather than hardcoded against Master. It should become intimate near the hearth, fade naturally at the entry, and be subdued or inaudible in the cellar. Avoid a global cosy loop, which would erase the distinction between rooms and compete with house creaks. Door handling, steps, notes and haunting cues still need audible space.

Opening the front door should eventually admit a directional wind leak near the threshold, even while the player remains geometrically inside. That is a separate measured improvement: the current shelter test is volume-based and does not yet respond to leaf angle. Blend using physical door opening and distance from its opening, preserve the established outside filter, and add no weather particle emission through walls. Test closed/open/partly-open states, both sides of the threshold, and return from the cellar before adopting it.

## Integration after assets arrive

1. Inspect actual model dimensions, origins, material slots, UVs and dependencies; record provenance and local destinations.
2. Fit kitchen/stove/bath meshes to the reserved blueprint envelopes. Revise the plan if fixtures do not fit; do not silently shrink them to toy scale.
3. Add the bathroom's three exposed partition edges and south doorway; keep the existing western/northern exterior walls. Register the bathroom room volume, label, lighting and audio surface metadata. Apply the project's door hinge and sweep conventions.
4. Expand upstairs acoustic/authoring data without changing `House.contains()` or the cellar volumes by accident. Keep gameplay room names stable or update every consumer together.
5. Update the layout revision and the existing snapshot migration/repack path so the stored house cannot silently restore old geometry. Preserve world seed, route and authored objects.
6. Run house-space and note-access probes; add a capsule and door sweep check for the new bathroom and camera checks around stove/counters. Inspect rendered views and listen to the actual mix.

## Review status

The companion `refined_layout.json` and `refined_blueprint.svg` describe planning reservations, including the retained stair void. The planning validator checks upstairs coverage, non-overlap, openings and conservative route envelopes. It does not prove camera comfort, hinge dynamics, model fit, acoustic quality, or construction safety. Those require the target game's actual runtime and the selected assets.
