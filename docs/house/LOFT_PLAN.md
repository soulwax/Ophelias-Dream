# Modern windows and Loft 16 room

Target `F:\Workspace\run`. The owner requested the supplied `loft-16-interior.zip` as a room, modernised windows/walls and paintings.

The imported floor plate is roughly 14.93 × 14.93 source units, with a roughly 8-unit wall height. A uniform 0.4 correction yields a 5.973 × 5.973 m room and approximately 3.17 m ceiling clearance. This preserves its furniture relationships and original artwork rather than squeezing the entire scene into the existing 4.8 m-wide living room.

Place the room centre at house-local `(9.3,0,0.9)`, facing its exported open side toward the existing house. The new upstairs room reservation is X `6.3..12.3`, Z `-2.1..3.9`; connect it to the living room with a 2.0 × 2.5 m opening centred at `(6.3,0,2.5)`. Move the old living sofa to the front wall so it does not block that route. The existing cellar stairs, entry, bedroom note and kitchen remain in place. The wing fits inside the existing levelled terrain pad and reserved house area.

The source room carries its own floor, walls, ceiling, furnishings and large artwork. Keep those materials and geometry, with static mesh collision for structural/furniture pieces and no collision for foliage cards/art. Close the otherwise exposed entrance side with the shared house wall. Provide a flush bridge at the floor joint and include the room in indoor weather/reverb volumes.

Modernise the main house with wider, taller glazing, thin charcoal frames and no crossbars. Kitchen glazing retains a higher sill above the worktop. Lower the painted wall band so it stays below the glass. Use quieter mineral wall paint, with the preserved timber and wool as warm accents. Add a smaller instance of the loft artwork to the bedroom; source images remain owner-supplied local content.

Validation must include the original house/notes/cellar probes, the new room's floor alignment and portal clearance, actual room collision, shelter/reverb registration, and rendered views of both rooms and the exterior junction. Source downloads and derived resources stay in their existing ignored directories.

Implemented in house layout revision 7. The original exported floor has a raised perimeter: its shared-wall edge is removed from the derived mesh to make a flush entrance, without changing the source FBX. Materials render on both sides, and an exterior roof cap encloses the wing. Imported furniture has mesh collision; foliage and artwork do not obstruct circulation.

Rebuild the supplied room after `python tools/import_requested_house.py` and Godot's asset import with `godot-mono --headless --path . --script tools/curate_loft_room.gd`. The source archive, FBX, textures and derived scenes remain untracked. Archive contents and hashes are recorded in `requested_assets_manifest.json`.

Validation: loft floor alignment and actual controller traversal, upstairs doors and cellar descent, domestic fixture/camera clearance, and recorded door-wind occlusion pass. The bedroom note is readable inside and blocked outside. The current broader note probe reports outdoor notes 0, 3 and 4 unreadable; outdoor terrain and route files have separate in-progress modifications and were not changed by this room pass. Rendered views are under `build/loft-*.png`.
