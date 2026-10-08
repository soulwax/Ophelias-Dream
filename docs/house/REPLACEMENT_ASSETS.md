# Replacing the remaining generated fittings

Searched 2026-10-06 for the house at `F:\Workspace\run`. Prioritise objects people recognise closely: sanitary ware, taps, fridge and lighting. Keep the original shell, simple collision, panelling, and custom relief; those are architectural composition rather than missing props.

## Downloaded directly

| Asset | Replacement | Notes |
| --- | --- | --- |
| [Modern Ceiling Lamp 01 — Poly Haven](https://polyhaven.com/a/modern_ceiling_lamp_01) | Generated dining pendant | CC0; downloaded 1K glTF, buffer and three texture maps. Final position uses measured model bounds, keeping its cable/shade intact. |
| [Painted Wooden Bench — Poly Haven](https://polyhaven.com/a/painted_wooden_bench) | Generated entry boot bench | CC0; approximately 1.165 m wide, 0.497 m deep and 0.889 m high including back. Rotate along the hall perimeter; verify the front-door sweep. |
| [Modern Wooden Cabinet — Poly Haven](https://polyhaven.com/a/modern_wooden_cabinet) | Generated kitchen cabinet fronts/carcasses | CC0; 2.44 m wide and 0.68 m high. Retain natural size, place on a 0.20 m plinth and move the cooker beside it. Original worktop remains. |

Recreate with `python tools/fetch_house_replacements.py`, then import through Godot. Exact file hashes, author metadata and declared dimensions are in `replacement_provenance.json`. Licensing: [Poly Haven asset licence](https://polyhaven.com/license).

## Next downloads: fittings with the highest visual payoff

| Candidate | Replaces | Why selected |
| --- | --- | --- |
| [Toilet — HippoStance](https://sketchfab.com/3d-models/toilet-132a8ee2af3a40d39d270fbed3d3666c) | Original tank, bowl and seat | Downloadable CC Attribution; 10.5k triangles, separate lid and seat, textured ceramic and water connection. Stronger detail than the current primitive fixture. |
| [Bathroom Sink / Low-Poly / Game-Ready — kEam](https://sketchfab.com/3d-models/bathroom-sink-low-poly-game-ready-45a6ab5e5a1a40b8913ab14314734ce8) | Basin, tap and mirror | Downloadable CC Attribution; about 2.7k triangles, includes mirror. Reduce supplied 4K textures to 1–2K for this small room. |
| [Kitchen Sink — HippoStance](https://sketchfab.com/3d-models/kitchen-sink-504248ed68e3480a807aced6f002b2d5) | Flat inset and box tap | Downloadable CC Attribution; 4.8k triangles, double bowl and faucet, 2K textures. Measure its width before fitting the 1.1 m cabinet; extend the cabinet if needed rather than crushing the model. |
| [Retro Fridge — CuongNguyen_Owen](https://sketchfab.com/3d-models/retro-fridge-4d2199cc5e9446aeae6729d19b36e8fc) | Box fridge and handle | Downloadable CC Attribution; 10k triangles, game-ready. A subdued cream finish suits the retained older furniture. Actual dimensions and material quality remain to be inspected. |

These are source-page candidates, not imported/scale-validated models. Sketchfab page retrieval returned HTTP 403 in this environment; its indexed source descriptions expose download and licence details, but source archives were not fetched. Download through the authorised site flow, preferably glTF/GLB with all textures and licence text, and add them to the existing `requested_assets_and_more` folder for the next import pass.

The toilet and basin have first priority. The bathroom door leaves little spare space: preserve its sweep, the 0.68 m player capsule and the camera sphere when selecting placement. A wide vanity is not an acceptable replacement merely because it looks good.

## Considered but not selected

- The initial one-for-one cabinet swap did not fit the narrow modules. Reconfiguring the north row permits the full Modern Wooden Cabinet without shrinking it, so it is now selected and placed.
- [Drawer Cabinet — Poly Haven](https://polyhaven.com/a/drawer_cabinet): tall storage rather than a kitchen base; it duplicates existing bedroom storage.
- The existing StylArts converted fridge and bathroom sink are substantially larger than the current reserved footprints and lack a clearly verified local redistribution licence. Their stylised geometry also differs from the scanned furniture, so they are lower-priority replacements.
- Stylised fridge and ornate/industrial lighting candidates do not fit the current restrained domestic palette as well as the shortlisted objects.

The worktop, fridge and sanitary placeholders remain until their replacement models fit. No paid asset purchase was made.

The full wooden cabinet is installed alongside the cooker at X=3.39, with its measured 2.44 m body centred at X=4.9. Original generated cabinet bodies are deactivated and replaced by a measured proxy. Its plinth raises the unscaled 0.68 m cabinet to the existing counter height.

The three Poly Haven replacements are now placed at normal scale in `HouseIdentity`: the real pendant hides the original shade/cord/glow, the entry bench replaces its visible placeholder and collision, and the cabinet replaces the original kitchen carcasses. The bench sits against the hall perimeter rather than intruding into the doorway. Layout revision 6 prevents an older house snapshot from restoring the previous furnishing branch.

Validation: all three detailed replacements load at scale 1; door/capsule and camera sphere checks pass; the front-door sweep, common-room passage and cellar descent pass. Rendered kitchen and entry views are saved in ignored `build/house-batch1-kitchen.png` and `build/house-batch1-entry.png`.
