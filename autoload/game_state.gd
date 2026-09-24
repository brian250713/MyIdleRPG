extends Node

signal state_changed
signal gold_changed(new_gold: int)
signal hero_xp_changed(class_id: String, level: int, xp: int)
signal hero_leveled_up(class_id: String, level: int)
signal stage_changed(stage_index: int, display_name: String)
signal setting_changed(key: String, value: Variant)

var state: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	state = SaveCodec.make_default_state()
	_rng.seed = 20260924

func apply_loaded_state(loaded_state: Dictionary) -> void:
	state = SaveCodec.normalize_state(loaded_state)
	_notify_state_changed()
	gold_changed.emit(get_gold())
	EventBus.gold_changed.emit(get_gold())
	stage_changed.emit(get_current_stage(), StageData.get_display_name(get_current_stage()))
	EventBus.stage_changed.emit(get_current_stage(), StageData.get_display_name(get_current_stage()))

func get_save_state() -> Dictionary:
	return state.duplicate(true)

func get_gold() -> int:
	return int(state.get("gold", 0))

func add_gold(amount: int) -> int:
	state["gold"] = maxi(0, get_gold() + amount)
	gold_changed.emit(get_gold())
	EventBus.gold_changed.emit(get_gold())
	_notify_state_changed()
	return get_gold()

func get_current_stage() -> int:
	return clampi(int(state.get("current_stage", 0)), 0, StageData.get_stage_count() - 1)

func get_unlocked_stage() -> int:
	return clampi(int(state.get("unlocked_stage", 0)), 0, StageData.get_stage_count() - 1)

func set_current_stage(stage_index: int) -> void:
	var safe_stage: int = clampi(stage_index, 0, get_unlocked_stage())
	state["current_stage"] = safe_stage
	stage_changed.emit(safe_stage, StageData.get_display_name(safe_stage))
	EventBus.stage_changed.emit(safe_stage, StageData.get_display_name(safe_stage))
	_notify_state_changed()

func unlock_stage(stage_index: int) -> void:
	state["unlocked_stage"] = clampi(maxi(get_unlocked_stage(), stage_index), 0, StageData.get_stage_count() - 1)
	_notify_state_changed()

func get_setting(key: String, default_value: Variant = null) -> Variant:
	var settings: Dictionary = state.get("settings", {})
	return settings.get(key, default_value)

func set_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = state.get("settings", {})
	settings[key] = value
	state["settings"] = settings
	setting_changed.emit(key, value)
	EventBus.setting_changed.emit(key, value)
	_notify_state_changed()

func get_party() -> Array:
	var party_value: Variant = state.get("party", [])
	if party_value is Array:
		return party_value.duplicate(true)
	return []

func get_active_heroes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var party: Array = get_party()
	for hero_value: Variant in party:
		if hero_value is Dictionary:
			var hero: Dictionary = hero_value
			if not str(hero.get("class_id", "")).is_empty():
				result.append(hero.duplicate(true))
	return result

func get_hero(class_id: String) -> Dictionary:
	for hero: Dictionary in get_active_heroes():
		if str(hero.get("class_id", "")) == class_id:
			return hero
	return {}

func get_hero_level(class_id: String) -> int:
	var hero: Dictionary = get_hero(class_id)
	return int(hero.get("level", 1))

func get_highest_party_level() -> int:
	var highest: int = 1
	for hero: Dictionary in get_active_heroes():
		highest = maxi(highest, int(hero.get("level", 1)))
	return highest

func get_lead_level() -> int:
	var party: Array = get_party()
	if party.is_empty():
		return 1
	var lead_value: Variant = party[0]
	if lead_value is Dictionary:
		return int(lead_value.get("level", 1))
	return 1

func get_unlocked_party_slots() -> int:
	var stored_unlocked: int = clampi(int(state.get("unlocked_party_slots", 1)), 1, 3)
	var lead_level: int = get_lead_level()
	var level_unlocked: int = 1
	if lead_level >= 15:
		level_unlocked = 3
	elif lead_level >= 5:
		level_unlocked = 2
	var result: int = maxi(stored_unlocked, level_unlocked)
	if result != stored_unlocked:
		state["unlocked_party_slots"] = result
	return result

func is_party_slot_unlocked(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= get_unlocked_party_slots():
		return false
	return true

func set_party_slot(slot_index: int, class_id: String) -> bool:
	if not is_party_slot_unlocked(slot_index):
		return false
	if ClassData.get_class_definition(class_id).is_empty():
		return false
	var party: Array = get_party()
	for index: int in range(party.size()):
		if index == slot_index:
			continue
		var hero_value: Variant = party[index]
		if hero_value is Dictionary and str(hero_value.get("class_id", "")) == class_id:
			return false
	while party.size() < 3:
		party.append(null)
	party[slot_index] = {
		"class_id": class_id,
		"level": 1,
		"xp": 0
	}
	state["party"] = party
	_notify_state_changed()
	return true

func add_hero_xp(class_id: String, amount: int) -> Dictionary:
	var hero: Dictionary = get_hero(class_id)
	if hero.is_empty():
		return {"level": 0, "xp": 0, "levels_gained": 0}
	var result: Dictionary = XPCurve.apply_xp(int(hero.get("level", 1)), int(hero.get("xp", 0)), amount)
	hero["level"] = int(result["level"])
	hero["xp"] = int(result["xp"])
	var party: Array = get_party()
	for index: int in range(party.size()):
		var party_value: Variant = party[index]
		if party_value is Dictionary and str(party_value.get("class_id", "")) == class_id:
			party[index] = hero
			break
	state["party"] = party
	hero_xp_changed.emit(class_id, int(hero["level"]), int(hero["xp"]))
	EventBus.hero_xp_changed.emit(class_id, int(hero["level"]), int(hero["xp"]))
	if int(result["levels_gained"]) > 0:
		hero_leveled_up.emit(class_id, int(hero["level"]))
		EventBus.hero_leveled_up.emit(class_id, int(hero["level"]))
	_notify_state_changed()
	return result

func grant_monster_rewards(monster_level: int, is_boss: bool = false) -> Dictionary:
	var reward: Dictionary = Rewards.calculate_rewards(monster_level, is_boss)
	add_gold(int(reward.get("gold", 0)))
	var total_xp: int = 0
	var multiplier: float = 5.0 if is_boss else 1.0
	for hero: Dictionary in get_active_heroes():
		var class_id: String = str(hero.get("class_id", ""))
		var amount: int = XPCurve.experience_reward(monster_level, int(hero.get("level", 1)), multiplier)
		add_hero_xp(class_id, amount)
		total_xp += amount
	return {
		"gold": int(reward.get("gold", 0)),
		"xp": total_xp,
		"is_boss": is_boss
	}

func set_last_saved_unix(unix_time: int) -> void:
	state["last_saved_unix"] = maxi(0, unix_time)

func _notify_state_changed() -> void:
	state_changed.emit()
	EventBus.state_changed.emit()

func get_rng() -> RandomNumberGenerator:
	return _rng

func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value
