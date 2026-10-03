class_name Tune
extends RefCounted

# Balance for one run of the ridge. Change feel here, not in the systems.

# Formal walk, half again as quick as the quiet pace, still one clip.
# The jog only starts once she is clearly faster than this.
const WALK_SPEED := 1.83
const SPRINT_SPEED := 6.85
const HUNTER_CREEP := 1.4
const HUNTER_CHASE := 5.7
# Momentum (m/s per second): quick to get going, a short coast to a stop,
# hard braking when she reverses.
const STRIDE_ACCEL_WALK := 4.2
const STRIDE_ACCEL_SPRINT := 9.5
const STRIDE_COAST := 3.6
const STRIDE_BRAKE := 11.0
# Natural ground speed of the movement clips at playback 1.
const STRIDE_WALK := 1.02
const STRIDE_JOG := 3.2
const STRIDE_SPRINT := 4.3
# Per-step speed swing: checks on impact, surges on push-off.
const STEP_SURGE_WALK := 0.03
const STEP_SURGE_SPRINT := 0.12

# Jump: instant takeoff, cut short by letting go, forgiving at edges and on
# early presses, a little heavier on the way down.
const JUMP_VELOCITY := 5.4
const JUMP_CUT := 0.5
const JUMP_STAMINA := 0.45
const COYOTE := 0.12
const JUMP_BUFFER := 0.14
const AIR_CONTROL := 0.35
const FALL_GRAVITY := 1.3

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
const MOUSE_SENS := 0.0022

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
