class_name Stats
extends RefCounted

const MAX_LEVEL: int = 100

static func calculate_class_stats(class_id: String, level: int) -> Dictionary:
	var definition: Dictionary = ClassData.get_class_definition(class_id)
	if definition.is_empty():
		return {}
	return _calculate_from_definition(definition, level)

static func calculate_monster_stats(monster_id: String, level: int) -> Dictionary:
	var definition: Dictionary = MonsterData.get_monster_definition(monster_id)
	if definition.is_empty():
		return {}
	return _calculate_from_definition(definition, level)

static func get_stat(stat_name: String, class_id: String, level: int) -> float:
	var stats: Dictionary = calculate_class_stats(class_id, level)
	return float(stats.get(stat_name, 0.0))

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
