# Main menu eye

`mathilda_eye.png` is original AI-generated artwork made with the built-in
image generation tool on 2026-10-06, guided by the user’s supplied anime-eye
menu reference. It uses a tight graphic close-up, cyan iris, angular dark
lashes, slate skin and teal-black hair. No reference menu text is baked in.

Godot draws the title and navigation. The shader moves the globe within the
stationary eye opening. A radial iris remap contracts the pupil in brighter
light and dilates it in shadow, keeping the iris edge stable. The menu’s slowly
changing illumination drives both brightness and the smoothed pupil reflex.
Quit reduces gaze movement. Eye calibration is in `dream_menu.gd` and the
shader’s `iris_radius` and `source_pupil` parameters.
