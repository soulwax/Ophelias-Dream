class_name Tune
extends RefCounted

# Balance for one run of the ridge. Change feel here, not in the systems.

# Formal walk, half again as quick as the quiet pace, still one clip.
# The jog only starts once she is clearly faster than this.
const WALK_SPEED := 1.83
const SPRINT_SPEED := 6.85
const HUNTER_CREEP := 1.4
const HUNTER_CHASE := 5.7
# Momentum (m/s per second). Speed and heading move separately: she gets
# going at once, eases off a sprint, skids a short way to a stop, and plants
# and brakes when asked to reverse.
const STRIDE_ACCEL_WALK := 9.0
const STRIDE_ACCEL_SPRINT := 12.0
const STRIDE_EASE := 6.0
const STRIDE_STOP_WALK := 14.0
const STRIDE_STOP_SPRINT := 12.0
const STRIDE_BRAKE := 20.0
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
# In the air she keeps her momentum: keys nudge it (m/s per second) but
# never slow her below the speed she left the ground with.
const AIR_ACCEL := 5.0
const AIR_DRAG := 0.6

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
const ANOMALIES_PER_RUN := 1
const GRAVITY := 20.0

const HUNT_NOTES := 3
const CATCH_GAP := 2.15
const EXIT_MARGIN := 8.0
const EXIT_RADIUS := 13.0
const READ_DISTANCE := 2.6

const REVEAL_EYES := 22.0
const REVEAL_BODY := 36.0

const INTRO_TIME := 3.2
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
const GROUND_CELL := 3.0
# Vertical depth of the snowpack. The walkable surface stays put; the
# snow continues this far down, and the shell shows at every cut edge.
const SNOW_DEPTH := 0.2

const LAYER_WORLD := 1
const LAYER_ACTOR := 2
