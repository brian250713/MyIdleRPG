class_name Stats
extends RefCounted

const MAX_LEVEL: int = 100

static func calculate_class_stats(class_id: String, level: int) -> Dictionary:
	var definition: Dictionary = ClassData.get_class_definition(class_id)
	if definition.is_empty():
		return {}
	return _calculate_from_definition(definition, level)

static func calculate_monster_stats(monster_id: String, level: int, difficulty_id: String = "normal") -> Dictionary:
	var scaled: Dictionary = MonsterScaling.scale_monster(monster_id, level, difficulty_id)
	return scaled.get("stats", {})

static func calculate_final_stats(class_id: String, level: int, equipment: Dictionary = {}, skill_state: Dictionary = {}) -> Dictionary:
	var base_stats: Dictionary = calculate_class_stats(class_id, level)
	if base_stats.is_empty():
		return {}
	var final_stats: Dictionary = base_stats.duplicate(true)
	var flat_adds: Dictionary = {}
	var percent_adds: Dictionary = {}
	var skill_levels_value: Variant = skill_state.get("skill_levels", skill_state)
	var skill_levels: Dictionary = skill_levels_value if skill_levels_value is Dictionary else {}
	var skill_modifiers: Dictionary = Skills.get_passive_modifiers(class_id, skill_levels)
	for slot_id: String in ItemData.get_slot_ids():
		var item_value: Variant = equipment.get(slot_id, null)
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value
		var main_stat: String = str(item.get("main_stat", ItemGen.get_main_stat_for_slot(slot_id)))
		_add_stat(main_stat, float(item.get("main_value", 0.0)), flat_adds, percent_adds)
		var affixes: Array = item.get("affixes", [])
		for affix_value: Variant in affixes:
			if not (affix_value is Dictionary):
				continue
			var affix: Dictionary = affix_value
			_add_stat(str(affix.get("stat", "max_hp")), float(affix.get("value", 0.0)), flat_adds, percent_adds)
	for raw_skill_stat: Variant in skill_modifiers.keys():
		var skill_stat: String = str(raw_skill_stat)
		var skill_value: float = float(skill_modifiers[raw_skill_stat])
		if skill_stat == "all_resistance":
			for resistance_key: String in ["fire_resistance", "ice_resistance", "lightning_resistance", "chaos_resistance"]:
				percent_adds[resistance_key] = float(percent_adds.get(resistance_key, 0.0)) + skill_value
		elif skill_stat == "max_hp_percent" or skill_stat == "defense_percent":
			percent_adds[skill_stat] = float(percent_adds.get(skill_stat, 0.0)) + skill_value
		elif skill_stat == "damage_absorption_percent" or skill_stat == "heal_power" or skill_stat == "cooldown_reduction" or skill_stat == "effect_radius_percent" or skill_stat == "elemental_damage_percent":
			percent_adds[skill_stat] = float(percent_adds.get(skill_stat, 0.0)) + skill_value
		else:
			_add_stat(skill_stat, skill_value, flat_adds, percent_adds)

	var attack: float = float(final_stats.get("attack", 0.0)) + float(flat_adds.get("attack", 0.0))
	attack *= 1.0 + float(percent_adds.get("attack_percent", 0.0))
	var max_hp: float = float(final_stats.get("max_hp", 0.0)) + float(flat_adds.get("max_hp", 0.0))
	max_hp *= 1.0 + float(percent_adds.get("max_hp_percent", 0.0))
	var defense: float = float(final_stats.get("defense", 0.0)) + float(flat_adds.get("defense", 0.0))
	defense *= 1.0 + float(percent_adds.get("defense_percent", 0.0))
	var attack_speed: float = float(final_stats.get("attack_speed", 0.0)) + float(flat_adds.get("attack_speed", 0.0))
	attack_speed *= 1.0 + float(percent_adds.get("attack_speed_percent", 0.0))
	final_stats["attack"] = maxf(0.0, attack)
	final_stats["max_hp"] = maxf(1.0, max_hp)
	final_stats["defense"] = maxf(0.0, defense)
	final_stats["attack_speed"] = maxf(0.1, attack_speed)
	final_stats["crit_chance"] = clampf(float(final_stats.get("crit_chance", 0.0)) + float(percent_adds.get("crit_chance", 0.0)), 0.0, 0.95)
	final_stats["crit_damage"] = maxf(1.0, float(final_stats.get("crit_damage", 1.0)) + float(percent_adds.get("crit_damage", 0.0)))
	for resistance_key: String in ["fire_resistance", "ice_resistance", "lightning_resistance", "chaos_resistance"]:
		final_stats[resistance_key] = clampf(float(final_stats.get(resistance_key, 0.0)) + float(percent_adds.get(resistance_key, 0.0)), 0.0, 0.75)
	final_stats["life_steal"] = clampf(float(final_stats.get("life_steal", 0.0)) + float(percent_adds.get("life_steal", 0.0)), 0.0, 0.75)
	final_stats["gold_gain"] = maxf(0.0, float(final_stats.get("gold_gain", 0.0)) + float(percent_adds.get("gold_gain", 0.0)))
	final_stats["xp_gain"] = maxf(0.0, float(final_stats.get("xp_gain", 0.0)) + float(percent_adds.get("xp_gain", 0.0)))
	final_stats["attack_percent"] = float(percent_adds.get("attack_percent", 0.0))
	final_stats["attack_speed_percent"] = float(percent_adds.get("attack_speed_percent", 0.0))
	final_stats["damage_absorption_percent"] = clampf(float(percent_adds.get("damage_absorption_percent", 0.0)), 0.0, 0.75)
	final_stats["heal_power"] = maxf(0.0, float(percent_adds.get("heal_power", 0.0)))
	final_stats["cooldown_reduction"] = clampf(float(percent_adds.get("cooldown_reduction", 0.0)), 0.0, 0.75)
	final_stats["effect_radius_percent"] = maxf(0.0, float(percent_adds.get("effect_radius_percent", 0.0)))
	final_stats["elemental_damage_percent"] = maxf(0.0, float(percent_adds.get("elemental_damage_percent", 0.0)))
	final_stats["level"] = clampi(level, 1, MAX_LEVEL)
	return final_stats

static func calculate_equipped_stats(class_id: String, level: int, equipment: Dictionary = {}, skill_state: Dictionary = {}) -> Dictionary:
	return calculate_final_stats(class_id, level, equipment, skill_state)

static func calculate_hero_stats(class_id: String, level: int, equipment: Dictionary = {}, skill_state: Dictionary = {}) -> Dictionary:
	return calculate_final_stats(class_id, level, equipment, skill_state)

static func get_stat(stat_name: String, class_id: String, level: int) -> float:
	var stats: Dictionary = calculate_class_stats(class_id, level)
	return float(stats.get(stat_name, 0.0))

static func _add_stat(stat_id: String, value: float, flat_adds: Dictionary, percent_adds: Dictionary) -> void:
	if stat_id == "attack_percent" or stat_id == "attack_speed_percent" or stat_id == "crit_chance" or stat_id == "crit_damage" or stat_id.ends_with("_resistance") or stat_id == "life_steal" or stat_id == "gold_gain" or stat_id == "xp_gain":
		percent_adds[stat_id] = float(percent_adds.get(stat_id, 0.0)) + value
	else:
		flat_adds[stat_id] = float(flat_adds.get(stat_id, 0.0)) + value

static func _calculate_from_definition(definition: Dictionary, level: int) -> Dictionary:
	var safe_level: int = clampi(level, 1, MAX_LEVEL)
	var base_stats: Dictionary = definition.get("base_stats", {})
	var growth: Dictionary = definition.get("growth", {})
	var result: Dictionary = {}
	for raw_key: Variant in base_stats.keys():
		var key: String = str(raw_key)
		var base_value: float = float(base_stats.get(key, 0.0))
		var growth_value: float = float(growth.get(key, 0.0))
		var value: float = base_value + growth_value * float(safe_level - 1)
		if key == "attack_speed":
			value = maxf(0.1, value)
		elif key == "crit_chance" or key.ends_with("_resistance") or key == "life_steal":
			value = clampf(value, 0.0, 0.75)
		elif key == "max_hp":
			value = maxf(1.0, value)
		result[key] = value
	result["level"] = safe_level
	return result
