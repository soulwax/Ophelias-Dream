# Main menu eye

`mathilda_eye.png` is original AI-generated artwork made with the built-in
image generation tool on 2026-10-06, guided by the user's supplied anime-eye
menu reference. It uses a tight graphic close-up, cyan iris, angular dark
lashes, slate skin and teal-black hair. No reference menu text is baked in.

Godot draws the title and navigation. `dream_menu.gdshader` uses a geometric
eye-opening mask traced in the original 1672 x 941 image coordinates, keeping
all lids and lashes stationary. A shaded sclera replaces the entire original
globe so the old dark iris rim cannot remain behind during gaze movement.

The moving iris reconstructs its hidden upper half from bounded samples of
the unobstructed lower half of the original artwork. Its dark rim, pupil and
painted cyan detail move together. The pupil contracts with brighter light;
separate corneal reflections follow gaze without stretching with dilation.
Quit reduces gaze movement. Eye calibration is in `dream_menu.gd` and the
shader's `iris_radius` and `source_pupil` parameters. Replacing the portrait
requires retracing the shader's `OPENING` polygon.
