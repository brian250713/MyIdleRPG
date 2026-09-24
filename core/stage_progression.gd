class_name StageProgression
extends RefCounted

enum Phase { IDLE, WAVES, BOSS, CLEARED, WIPED, RETREATING, NEXT_STAGE }

const MAX_STAGE_INDEX: int = 29

var _state: Dictionary = {}

func _init(initial_state: Dictionary = {}) -> void:
	_state = _make_initial_state()
	if not initial_state.is_empty():
		_apply_state(initial_state)

func get_state() -> Dictionary:
	return _state.duplicate(true)

func get_phase() -> int:
	return int(_state.get("phase", Phase.IDLE))

func get_phase_name() -> String:
	match get_phase():
		Phase.WAVES:
			return "waves"
		Phase.BOSS:
			return "boss"
		Phase.CLEARED:
			return "cleared"
		Phase.WIPED:
			return "wiped"
		Phase.RETREATING:
			return "retreating"
		Phase.NEXT_STAGE:
			return "next_stage"
		_:
			return "idle"

func get_current_stage() -> int:
	return int(_state.get("current_stage", 0))

func get_unlocked_stage() -> int:
	return int(_state.get("unlocked_stage", 0))

func get_wave_index() -> int:
	return int(_state.get("wave_index", 0))

func get_wave_count() -> int:
	return maxi(1, int(_state.get("wave_count", 5)))

func is_boss_active() -> bool:
	return bool(_state.get("boss_active", false))

func set_auto_advance(enabled: bool) -> void:
	_state["auto_advance"] = enabled

func is_auto_advance() -> bool:
	return bool(_state.get("auto_advance", true))

func start_stage(stage_index: int, wave_count: int = 5) -> String:
	var safe_stage: int = clampi(stage_index, 0, MAX_STAGE_INDEX)
	_state["current_stage"] = safe_stage
	_state["wave_count"] = maxi(1, wave_count)
	_state["wave_index"] = 0
	_state["boss_active"] = false
	_state["phase"] = Phase.WAVES
	_state["stage_attempts"] = int(_state.get("stage_attempts", 0)) + 1
	return "wave_started"

func on_wave_cleared() -> String:
	if get_phase() != Phase.WAVES:
		return "ignored"
	var next_wave: int = get_wave_index() + 1
	if next_wave >= get_wave_count():
		_state["wave_index"] = get_wave_count() - 1
		_state["boss_active"] = true
		_state["phase"] = Phase.BOSS
		return "boss_started"
	_state["wave_index"] = next_wave
	return "wave_started"

func on_boss_defeated() -> String:
	if get_phase() != Phase.BOSS:
		return "ignored"
	_state["unlocked_stage"] = maxi(get_unlocked_stage(), mini(MAX_STAGE_INDEX, get_current_stage() + 1))
	_state["boss_active"] = false
	_state["phase"] = Phase.CLEARED
	return "stage_cleared"

func advance_to_next_stage() -> String:
	if get_phase() != Phase.CLEARED:
		return "ignored"
	if not is_auto_advance():
		return "waiting_for_manual_advance"
	var next_stage: int = get_current_stage() + 1
	if next_stage > get_unlocked_stage() or next_stage > MAX_STAGE_INDEX:
		_state["phase"] = Phase.CLEARED
		return "all_stages_unlocked"
	start_stage(next_stage, get_wave_count())
	_state["phase"] = Phase.NEXT_STAGE
	return "next_stage_started"

func on_party_wiped() -> String:
	if get_current_stage() > 0:
		_state["current_stage"] = get_current_stage() - 1
		_state["wave_index"] = 0
		_state["boss_active"] = false
		_state["phase"] = Phase.RETREATING
		return "retreated"
	_state["wave_index"] = 0
	_state["boss_active"] = false
	_state["phase"] = Phase.WIPED
	return "wiped"

func select_stage(stage_index: int) -> String:
	if stage_index < 0 or stage_index > get_unlocked_stage() or stage_index > MAX_STAGE_INDEX:
		return "locked"
	start_stage(stage_index, get_wave_count())
	return "wave_started"

func _make_initial_state() -> Dictionary:
	return {
		"current_stage": 0,
		"unlocked_stage": 0,
		"wave_count": 5,
		"wave_index": 0,
		"boss_active": false,
		"phase": Phase.IDLE,
		"auto_advance": true,
		"stage_attempts": 0
	}

func _apply_state(source: Dictionary) -> void:
	_state["current_stage"] = clampi(int(source.get("current_stage", 0)), 0, MAX_STAGE_INDEX)
	_state["unlocked_stage"] = clampi(int(source.get("unlocked_stage", 0)), 0, MAX_STAGE_INDEX)
	_state["wave_count"] = maxi(1, int(source.get("wave_count", 5)))
	_state["wave_index"] = clampi(int(source.get("wave_index", 0)), 0, _state["wave_count"] - 1)
	_state["boss_active"] = bool(source.get("boss_active", false))
	_state["phase"] = clampi(int(source.get("phase", Phase.IDLE)), Phase.IDLE, Phase.NEXT_STAGE)
	_state["auto_advance"] = bool(source.get("auto_advance", true))
	_state["stage_attempts"] = maxi(0, int(source.get("stage_attempts", 0)))
