class_name Loudness
extends RefCounted

# How loud a sound is, from what it is and how far away. Every recording is
# levelled to the same impact (one-shots) or RMS (loops) by
# tools/make_soundscape.py, so the numbers here are all that set sounds
# apart: a typical sound pressure level in dB SPL at 1 m from the source.
# From there the inverse-distance law takes 6 dB per doubling of distance,
# the air dulls the highs of anything far off, and a sound is cut once it
# falls below the threshold of hearing. Her ears are the listener.

# The SPL a levelled recording represents when it plays at 0 dB at 1 m.
const CALIBRATION := 80.0
# Quieter than this at the ears (dB SPL) and a sound is gone: its reach.
const HEARING_FLOOR := 20.0
const FARTHEST := 420.0

# Typical levels at 1 m, dB SPL. A boot in squeaky cold snow, on a hollow
# plank floor, on stone; a running stride or landing hits harder.
const SNOW_STEP := 57.0
const WOOD_STEP := 61.0
const STONE_STEP := 64.0
const STRIDE_FORCE := 7.0
const FLOOR_CREAK := 52.0
# Out on the field: one caw carries far; a whole pine thrashing in a gust;
# a load of snow sliding off a branch; a trunk creaking; a branch breaking.
const CROW := 84.0
const RAVEN := 80.0
const SONGBIRDS := 64.0
const TREE_RUSTLE := 70.0
const SNOW_FLUMP := 66.0
const TREE_CREAK := 63.0
const BRANCH_SNAP := 92.0
# The storm as it reaches her ears, not at 1 m from anything: from a light
# wind to a blizzard, with gusts on top. The cabin walls take WALLS of it,
# the cellar a good deal more; wind whistles in at the windows.
const WIND_CALM := 56.0
const WIND_STORM := 74.0
const GUST := 80.0
const WALLS := 24.0
const CELLAR := 14.0
const WINDOW_WHISTLE := 58.0


## The volume_db that plays a levelled recording as a source of this level.
static func volume(spl: float) -> float:
	return spl - CALIBRATION


## How far a source of this level can still be heard.
static func reach(spl: float) -> float:
	return clampf(pow(10.0, (spl - HEARING_FLOOR) / 20.0), 4.0, FARTHEST)


## A positional voice for a source of this level. far: the source is often
## tens of metres off, so the air takes its highs.
static func voice(spl: float, bus: String, far := false) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = bus
	place(player, spl, far)
	return player


static func place(player: AudioStreamPlayer3D, spl: float, far := false) -> void:
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 1.0
	player.volume_db = volume(spl)
	player.max_db = 3.0
	player.max_distance = reach(spl)
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	# Godot dulls by how much a sound has already fallen, so a footstep a
	# metre or two away would lose its crunch: only far sources use it.
	player.attenuation_filter_cutoff_hz = 4500.0
	player.attenuation_filter_db = -10.0 if far else 0.0
