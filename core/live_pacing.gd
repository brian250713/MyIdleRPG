class_name LivePacing
extends RefCounted

## Live timing profile used by the headless balance report.
## The values are calibrated from the real battlefield soak's frame cadence
## (time_scale=8): the renderer produces fewer simulation updates as the
## scene grows, so a fixed 0.10 BattleSim step overstates real progress.
## This is a timing model, not an added wait: rewards and kills still come
## from the same core modules as the game.

const STAGE_COUNT_PER_ACT: int = 10
const SIMULATION_STEP_START: float = 0.205
const SIMULATION_STEP_END: float = 0.370
const EARLY_TIME_MULTIPLIER: float = 1.50
const ACT1_LATE_TIME_MULTIPLIER: float = 2.20
const ACT2_TIME_MULTIPLIER: float = 2.00
const LATER_TIME_MULTIPLIER: float = 1.30
const GOLD_MULTIPLIER_START: float = 1.10
const GOLD_MULTIPLIER_END: float = 0.65
const CONTACT_DELAY_MELEE: float = 7.80
const CONTACT_DELAY_RANGED: float = 0.15

static func get_simulation_step(elapsed_seconds: float) -> float:
	var progress: float = clampf(elapsed_seconds / (60.0 * 60.0), 0.0, 1.0)
	return lerpf(SIMULATION_STEP_START, SIMULATION_STEP_END, progress)

static func get_time_multiplier(stage_index: int) -> float:
	if stage_index < 5:
		return EARLY_TIME_MULTIPLIER
	if stage_index < STAGE_COUNT_PER_ACT:
		return ACT1_LATE_TIME_MULTIPLIER
	if stage_index < STAGE_COUNT_PER_ACT * 2:
		return ACT2_TIME_MULTIPLIER
	return LATER_TIME_MULTIPLIER

static func get_gold_multiplier(elapsed_seconds: float) -> float:
	var progress: float = clampf(elapsed_seconds / (60.0 * 60.0), 0.0, 1.0)
	return lerpf(GOLD_MULTIPLIER_START, GOLD_MULTIPLIER_END, progress)
