class_name MonsterScaling
extends RefCounted

static func scale_definition(definition: Dictionary, level: int) -> Dictionary:
	if definition.is_empty():
		return {}
	var scaled: Dictionary = definition.duplicate(true)
	var safe_level: int = maxi(1, level)
	var base_stats: Dictionary = definition.get("base_stats", {})
	var growth: Dictionary = definition.get("growth", {})
	var stats: Dictionary = {}
	for raw_key: Variant in base_stats.keys():
		var key: String = str(raw_key)
		var base_value: float = float(base_stats.get(key, 0.0))
		var growth_value: float = float(growth.get(key, 0.0))
		stats[key] = base_value + growth_value * float(safe_level - 1)
	stats["level"] = safe_level
	scaled["level"] = safe_level
	scaled["stats"] = stats
	return scaled

static func scale_monster(monster_id: String, level: int) -> Dictionary:
	var definition: Dictionary = MonsterData.get_monster_definition(monster_id)
	return scale_definition(definition, level)

static func get_stat(monster_id: String, level: int, stat_name: String) -> float:
	var scaled: Dictionary = scale_monster(monster_id, level)
	var stats: Dictionary = scaled.get("stats", {})
	return float(stats.get(stat_name, 0.0))
