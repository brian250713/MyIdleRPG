class_name MonsterScaling
extends RefCounted

static func scale_definition(definition: Dictionary, level: int, difficulty_id: String = "normal") -> Dictionary:
	if definition.is_empty():
		return {}
	var scaled: Dictionary = definition.duplicate(true)
	var safe_level: int = maxi(1, level)
	var safe_difficulty_id: String = DifficultyData.normalize_difficulty_id(difficulty_id)
	var multiplier: float = DifficultyData.get_stat_multiplier(safe_difficulty_id)
	var base_stats: Dictionary = definition.get("base_stats", {})
	var growth: Dictionary = definition.get("growth", {})
	var stats: Dictionary = {}
	for raw_key: Variant in base_stats.keys():
		var key: String = str(raw_key)
		var base_value: float = float(base_stats.get(key, 0.0)) * multiplier
		var growth_value: float = float(growth.get(key, 0.0)) * multiplier
		stats[key] = base_value + growth_value * float(safe_level - 1)
	stats["level"] = safe_level
	scaled["level"] = safe_level
	scaled["difficulty_id"] = safe_difficulty_id
	scaled["element"] = str(definition.get("element", "physical"))
	scaled["stats"] = stats
	return scaled

static func scale_monster(monster_id: String, level: int, difficulty_id: String = "normal") -> Dictionary:
	var definition: Dictionary = MonsterData.get_monster_definition(monster_id)
	return scale_definition(definition, level, difficulty_id)

static func get_stat(monster_id: String, level: int, stat_name: String, difficulty_id: String = "normal") -> float:
	var scaled: Dictionary = scale_monster(monster_id, level, difficulty_id)
	var stats: Dictionary = scaled.get("stats", {})
	return float(stats.get(stat_name, 0.0))
