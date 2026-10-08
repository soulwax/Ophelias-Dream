# Winterkeeper's home

The house should feel like a specific person's shelter in a harsh landscape: maintained where it matters, worn where hands and feet have passed. The visual direction combines pale painted ceilings, smoked timber, moss-grey joinery, rust wool, and black iron. Old furniture remains useful rather than becoming a matching showroom suite.

Three compositions organise the assets:

1. **Gathering:** the stove, restrained wool pattern, sofa and warm reading light. The bright zigzag pillows become quiet rust/flax fabric so the rug carries the pattern. A small real timber side table and wooden lantern create a second pool of light near the front window.
2. **Daily ritual:** a plain moss-grey kitchen, existing worn dining table, and tea set. A shaded pendant focuses light on the table rather than washing every wall orange. Counters stay clean enough to read their function.
3. **Quiet refuge:** the retained old daybed, a softer second woven rug, storage and reading nook. The personal bedside note remains the focus of the waking sequence.

Painted low panelling and a slate stove surround give the room an architectural identity beyond its loose furniture. A small original geometric relief evokes a pine ridge; it supplies a local handmade object without importing a random gallery collection. A few books are grouped on the shelves rather than scattering decoration across the floor or routes.

Material changes apply to local instances, preserving downloaded originals. The large interior collections, poster atlas and industrial pendant remain unplaced: they do not serve these compositions. The two wool rugs have different roles and patterns rather than repeating one texture everywhere. All prop placement is subordinate to the controller, door sweeps, notes and cellar path.

Lighting keeps cold daylight at the windows, small warm domestic sources and darker transitions toward the cellar. The established storm mix and physical front-door wind leak remain intact. This is visual refinement, not a new gameplay system.

The imported curtains are drawn apart at the front window, with their fold depth reduced to fit inside the wall and clear the lantern. The original relief sits to their left. Its simple pine-ridge geometry is deliberately small; it is one personal object rather than a repeated motif on every wall.

Added source selections: Paloma wool rug (showroom floor removed), Side Table 01 and Wooden Lantern 01 from the owner's downloads. Dimensions, hashes and archive membership are recorded by the existing importer/curator. The three originals remain unchanged, with ignored local derivatives and existing fallback furnishings.

Implementation: `scripts/house/identity.gd` applies the panelling, palette, relief, shelf books and compositions. `House.settle_comfort()` reapplies the focused lighting after snapshot handling; layout revision 5 retains the coherent updated house branch. The added side-table collider is small and against the front perimeter.

Validation: ten detailed imported visuals load, full bathroom door/capsule checks pass, all sampled camera sphere directions pass, and bedside/field note-access checks pass. Five rendered interior views were inspected under Forward+ in lean mode. These checks preserve the existing geometric routes; they do not replace a full subjective walkthrough or audio listening review.
