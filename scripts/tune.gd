class_name Tune
extends RefCounted

# Balance for one run of the ridge. Change feel here, not in the systems.

# Her walk, brisker than the take's own pace and still one clip. The jog only
# starts once she is clearly faster than this. Walking slowly (the held key,
# or a stick part-way) is close to the take's own pace.
const WALK_SPEED := 1.83
const WALK_SLOW_SPEED := 0.95
const SPRINT_SPEED := 6.85
# Momentum (m/s per second). Speed and heading move separately: she gets
# going at once, eases off a sprint, skids a short way to a stop, and plants
# and brakes when asked to reverse.
const STRIDE_ACCEL_WALK := 9.0
const STRIDE_ACCEL_SPRINT := 12.0
const STRIDE_EASE := 6.0
const STRIDE_STOP_WALK := 9.0
const STRIDE_STOP_SPRINT := 12.0
const STRIDE_BRAKE := 20.0
# From standing, the first tick of input already moves her this fast (m/s).
const START_BURST := 0.55
# Indoors, pushing into the edge of a door frame slips her sideways into the
# opening at up to this speed (m/s).
const DOOR_ASSIST := 1.1
# Read / open pressed a moment too early or too fast is kept this long (s).
const INTERACT_BUFFER := 0.35
# Sticks: radial dead zone, and the curve that makes a small push a careful
# step (movement) or a fine turn (look). Look rates are rad/s at full push;
# held all the way, the turn quickens by RAMP_BOOST over RAMP_TIME.
const STICK_DEADZONE := 0.18
const STICK_CURVE := 1.6
const STICK_LOOK_CURVE := 1.8
const STICK_YAW_RATE := 3.4
const STICK_PITCH_RATE := 2.2
const STICK_RAMP_TIME := 0.35
const STICK_RAMP_BOOST := 0.6
# Glance back: the camera swings round over her right shoulder in GLANCE_TIME
# (s); her chest and head turn with it (rad).
const GLANCE_TIME := 0.18
const GLANCE_CHEST := 0.45
const GLANCE_HEAD := 1.0
# The camera arm pulls in at once when something comes between them, and
# lets back out at this speed (m/s) instead of popping.
const ARM_EXTEND := 2.6
# Heading (rad/s): nearly instant at a walk, a committed sweep at a sprint,
# where hard cornering also bleeds speed (share of speed per radian). Mouse
# steering bleeds less than she regains; a hard key turn dips for a moment.
const TURN_RATE_WALK := 14.0
const TURN_RATE_SPRINT := 6.5
const TURN_BLEED := 0.35
# Turning further than this (rad) at speed is a reversal; below PIVOT_SPEED
# (m/s) she simply sets off the new way.
const REVERSE_ANGLE := 2.4
const PIVOT_SPEED := 0.9
# How quickly her body turns to face where she is going (1/s).
const FACE_RATE_WALK := 7.5
const FACE_RATE_SPRINT := 10.0
# Natural ground speed of the movement clips at playback 1.
const STRIDE_WALK := 1.02
const STRIDE_JOG := 3.2
const STRIDE_SPRINT := 4.3
# Her carriage over the clips (Grace), in radians unless noted.
const GRACE_ARM_SWING := 0.34
const GRACE_COUNTER_TURN := 0.09
const GRACE_CHEST_LIFT := 0.05
# Standing still this long (s) she rises onto her toes, once per cycle (s).
const TIPTOE_AFTER := 5.0
const TIPTOE_CYCLE := 7.5
# Most her heels lift her (skeleton metres) and the steepest foot pitch.
const TIPTOE_LIFT := 0.075
const TIPTOE_PITCH := 1.3
# Per-step speed swing: checks on impact, surges on push-off.
const STEP_SURGE_WALK := 0.03
const STEP_SURGE_SPRINT := 0.06

# Jump: instant takeoff, cut short by letting go, forgiving at edges and on
# early presses, a little heavier on the way down.
const JUMP_VELOCITY := 5.4
const JUMP_CUT := 0.5
const JUMP_STAMINA := 0.45
const COYOTE := 0.12
const JUMP_BUFFER := 0.14
const FALL_GRAVITY := 1.3
# Held through the top of a jump (|vertical speed| under APEX_SPEED m/s),
# gravity eases to this share, so the peak floats and the fall stays crisp.
const APEX_HANG := 0.6
const APEX_SPEED := 1.2
# In the air she keeps her momentum: keys nudge it (m/s per second) but
# never slow her below the speed she left the ground with.
const AIR_ACCEL := 5.0
const AIR_DRAG := 0.6
# The running leap. A jump taken at LEAP_FROM or faster is one long stride,
# off the foot she last planted onto the other. leap (0..1 from LEAP_FROM to
# SPRINT_SPEED at takeoff) lowers the arc to LEAP_LIFT of a hop and adds
# LEAP_CARRY of forward speed, never past LEAP_MAX_SPEED; the air takes
# LEAP_DRAG_CUT less of her speed. A jog leap shows LEAP_LINE_JOG of the line.
const LEAP_FROM := 3.2
const LEAP_LIFT := 0.88
const LEAP_CARRY := 0.06
const LEAP_MAX_SPEED := 7.3
const LEAP_DRAG_CUT := 0.9
const LEAP_LINE_JOG := 0.6
# Flight: time leads to LEAP_REACH_HOLD of the way, then only the ground
# coming within LEAP_REACH_HEIGHT metres finishes her reach for it.
const LEAP_REACH_HOLD := 0.85
const LEAP_REACH_HEIGHT := 0.35
# Her line in the air, in radians at a full leap: the split at its widest,
# pointed toes, arms opening, chest lifted.
const LEAP_SPLIT := 0.35
const LEAP_POINT := 0.5
const LEAP_ARMS := 0.45
const LEAP_CHEST := 0.08
# The catlike dip: metres on an ordinary leap and on a hard drop, the
# spring's frequency (rad/s) and damping ratio, and the chest's forward lean
# per metre of dip.
const LEAP_DIP_DEPTH := 0.03
const LEAP_DIP_DROP := 0.15
const LEAP_DIP_FREQ := 20.0
const LEAP_DIP_ZETA := 0.6
const LEAP_DIP_LEAN := 0.8
# The camera at a full leap: degrees of field of view and metres of boom.
const LEAP_FOV := 3.0
const LEAP_BOOM := 0.25

# Slide out of a sprint: a kick of speed, low snow friction, gravity along
# the slope, a little steering.
const SLIDE_MIN_SPEED := 4.2
const SLIDE_BOOST := 1.3
const SLIDE_FRICTION := 2.8
const SLIDE_SLOPE := 9.0
const SLIDE_STEER := 1.4
const SLIDE_MAX_TIME := 1.3
const SLIDE_MIN_TIME := 0.35
const SLIDE_END_SPEED := 2.2
const SLIDE_STAMINA := 0.4
const STAMINA_MAX := 4.6
const STAMINA_REGEN := 1.35
const EXHAUST_LOCK := 0.85
const SPRINT_RESUME := 1.6
const HOLD_DRAIN := 0.6
const GRAVITY := 20.0

# The danger begins after this many pages, or this far (m) beyond the start.
const HUNT_NOTES := 3
const HUNT_ROUTE_DISTANCE := 85.0
# The first page sits 22 m from the start. Passing it sets up a changed return.
const RETURN_CLUE_ROUTE_DISTANCE := 22.0
# The extra boots appear on a stretch the player can retrace before the hunt.
const WRONG_TRACK_ROUTE_DISTANCE := 30.0
const EVIDENCE_HOLD := 240.0
const EXIT_MARGIN := 8.0
const EXIT_RADIUS := 13.0
const READ_DISTANCE := 2.6

# Aiming at things (Aim). The ray from the screen centre reaches AIM_RANGE
# (m). A door or switch is in reach when the nearest point of it is within
# INTERACT_REACH of her chest; a page, within READ_DISTANCE of her feet. With
# nothing under the reticle, the nearest thing within AIM_CONE (degrees) of it
# is chosen, and a held choice only gives way to one AIM_STICKY degrees
# closer to the centre.
const AIM_RANGE := 9.0
const INTERACT_REACH := 1.7
const AIM_CONE := 22.0
const AIM_STICKY := 5.0

const INTRO_TIME := 3.2
# Standing still this long (s) she mutters. Another line waits VOICE_GAP.
const BORED_AFTER := 18.0
const VOICE_GAP := 14.0
const VOICE_SPL := 55.0
# Within this flat distance (m) of the exit she is at "the lights".
const LIGHTS_NEAR := 40.0
# After the last page, holding glance-back this long (s) outdoors is turning around.
const TURN_HOLD := 1.0
# A landing at least this fast (m/s) is a fall she remarks on.
const FALL_HARD := 7.5
# How long (s) "Added to the journal" stays after a page is found.
const JOURNAL_TOAST := 3.0


const TYPE_CPS := 42.0
# Radians per screen pixel at sensitivity 1, and the pitch range (rad).
const MOUSE_SENS := 0.0022
const PITCH_DOWN := -0.87
const PITCH_UP := 0.38

const PROP_SCALE := 1.0
const ACTOR_SCALE := 1.0
const PLAYER_MODEL_SCALE := 0.8

const FENCE_MIN_X := -150.0
const FENCE_MAX_X := 150.0
const FENCE_MIN_Z := -224.0
const FENCE_MAX_Z := 76.0
const GROUND_PAD := 26.0
const GROUND_CELL := 1.5
# Vertical depth of the snowpack. The walkable surface stays put; the
# snow continues this far down, and the shell shows at every cut edge.
const SNOW_DEPTH := 0.2
# The land. Warped hills (TERRAIN_HILLS metres of relief, wavelength about
# 1 / TERRAIN_HILL_FREQ), a route valley (the ground eases onto a walking floor
# within VALLEY_HALF of the path, no steeper than VALLEY_GRADE, and rises
# VALLEY_BANK per metre beyond it up to VALLEY_BANK_MAX), a rim of
# TERRAIN_RIM metres beyond the fence.
const TERRAIN_HILLS := 9.0
const TERRAIN_HILL_FREQ := 0.0085
const TERRAIN_WARP := 25.0
const TERRAIN_DETAIL := 1.2
const TERRAIN_RIM := 14.0
const VALLEY_HALF := 8.0
const VALLEY_GRADE := 0.08
const VALLEY_BANK := 0.18
const VALLEY_BANK_MAX := 6.0
# Cliffs: where the cliff noise crosses CLIFF_THRESHOLD the ground steps up
# CLIFF_RISE_MIN..MAX metres over a band CLIFF_SHARPNESS wide in noise units,
# only CLIFF_CLEAR metres or more from the route and CLIFF_FENCE inside the
# fence. Rock faces dress them, at least CLIFF_ROCK_GAP apart, CLIFF_ROCKS_MAX at most.
const CLIFF_FREQ := 0.012
const CLIFF_THRESHOLD := 0.18
const CLIFF_SHARPNESS := 0.05
const CLIFF_RISE_MIN := 6.0
const CLIFF_RISE_MAX := 12.0
const CLIFF_CLEAR := 20.0
const CLIFF_FENCE := 6.0
const CLIFF_ROCKS_MAX := 70
const CLIFF_ROCK_GAP := 12.0
# The ravine: the stretch of the played route (as fractions from start to
# exit) where walls RAVINE_RISE metres high rise from RAVINE_INNER to
# RAVINE_OUTER metres either side of the path.
const RAVINE_FROM := 0.45
const RAVINE_TO := 0.6
const RAVINE_RISE := 10.0
const RAVINE_INNER := 6.0
const RAVINE_OUTER := 9.0

const LAYER_WORLD := 1
const LAYER_ACTOR := 2

# A place's second line waits this long (s) after its first.
const REVISIT_AFTER := 60.0
# Wrong readings in the journal: at most one muttered line per MISREAD_GAP s.
const MISREAD_GAP := 8.0

# Her calls for Mathilda outdoors: a shout, dB SPL at 1 m.
const CALL_SPL := 82.0

# The first call comes CALL_FIRST s after she steps out, then every CALL_EVERY s.
const CALL_FIRST := Vector2(20.0, 30.0)
const CALL_EVERY := Vector2(45.0, 80.0)
# The trees answer at most ECHO_MAX times, this much quieter than her call.
const ECHO_DROP_DB := 14.0
const ECHO_MAX := 2
