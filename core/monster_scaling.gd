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
	var is_boss: bool = bool(definition.get("is_boss", false))
	var balance: Dictionary = definition.get("balance", {}) if definition.get("balance", {}) is Dictionary else {}
	var stats: Dictionary = {}
	for raw_key: Variant in base_stats.keys():
		var key: String = str(raw_key)
		# 難度倍率放大生命、攻擊與防禦等核心強度；不把攻速/暴擊率再乘一次，
		# 否則 3× 噩夢會讓首領攻速失控。
		var stat_multiplier: float = multiplier
		if key == "attack_speed" or key == "crit_chance" or key == "crit_damage" or key == "life_steal":
			stat_multiplier = 1.0
		var base_value: float = float(base_stats.get(key, 0.0)) * stat_multiplier
		var growth_value: float = float(growth.get(key, 0.0)) * stat_multiplier
		if key == "attack" and not is_boss:
			var regular_attack_multiplier: float = float(balance.get("attack_multiplier", 1.0))
			base_value *= regular_attack_multiplier
			growth_value *= regular_attack_multiplier
		stats[key] = base_value + growth_value * float(safe_level - 1)
	if is_boss:
		var level_pressure: float = float(maxi(0, safe_level - 1))
		var hp_multiplier: float = minf(1.15, float(balance.get("hp_multiplier", 1.0)) + float(balance.get("hp_per_level", 0.0)) * level_pressure)
		var attack_multiplier: float = minf(1.10, float(balance.get("attack_multiplier", 1.0)) + float(balance.get("attack_per_level", 0.0)) * level_pressure)
		stats["max_hp"] = float(stats.get("max_hp", 1.0)) * hp_multiplier
		stats["attack"] = float(stats.get("attack", 0.0)) * attack_multiplier
		stats["defense"] = float(stats.get("defense", 0.0)) * float(balance.get("defense_multiplier", 1.0))
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
