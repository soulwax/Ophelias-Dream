class_name Tune
extends RefCounted

# Balance for one run of the ridge. Change feel here, not in the systems.

const WALK_SPEED := 2.55
const SPRINT_SPEED := 6.85
const HUNTER_CREEP := 1.4
const HUNTER_CHASE := 5.7
# Momentum (m/s per second): quick to get going, a short coast to a stop,
# hard braking when she reverses.
const STRIDE_ACCEL_WALK := 7.0
const STRIDE_ACCEL_SPRINT := 9.5
const STRIDE_COAST := 6.0
const STRIDE_BRAKE := 11.0
# Natural ground speed of each clip at playback 1 (tools/stride_probe.gd).
const STRIDE_WALK := 1.02
const STRIDE_JOG := 3.2
const STRIDE_SPRINT := 4.3
const STAMINA_MAX := 4.6
const STAMINA_REGEN := 1.35
const EXHAUST_LOCK := 0.85
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

const FENCE_MIN_X := -150.0
const FENCE_MAX_X := 150.0
const FENCE_MIN_Z := -224.0
const FENCE_MAX_Z := 76.0
const GROUND_PAD := 26.0
const GROUND_CELL := 3.0

const LAYER_WORLD := 1
const LAYER_ACTOR := 2
