class_name Power
extends RefCounted

static func calculate(stats: Dictionary) -> int:
	if stats.is_empty():
		return 0
	var value: float = 0.0
	value += float(stats.get("max_hp", 0.0)) * 0.45
	value += float(stats.get("attack", 0.0)) * 3.0
	value += float(stats.get("defense", 0.0)) * 2.0
	value += float(stats.get("attack_speed", 0.0)) * 20.0
	value += float(stats.get("crit_chance", 0.0)) * 100.0
	value += float(stats.get("crit_damage", 0.0)) * 45.0
	value += float(stats.get("fire_resistance", 0.0)) * 35.0
	value += float(stats.get("ice_resistance", 0.0)) * 35.0
	value += float(stats.get("lightning_resistance", 0.0)) * 35.0
	value += float(stats.get("chaos_resistance", 0.0)) * 35.0
	value += float(stats.get("life_steal", 0.0)) * 80.0
	return maxi(0, int(round(value)))

static func calculate_power(stats: Dictionary) -> int:
	return calculate(stats)

static func compare(first: Dictionary, second: Dictionary) -> int:
	return calculate(first) - calculate(second)
