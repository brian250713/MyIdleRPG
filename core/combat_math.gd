class_name CombatMath
extends RefCounted

static func calculate_damage(attack: float, defense: float, crit_chance: float = 0.0, crit_damage: float = 1.5, rng: RandomNumberGenerator = null) -> Dictionary:
	var mitigation: float = 100.0 / (100.0 + maxf(0.0, defense))
	var raw_damage: float = maxf(1.0, maxf(0.0, attack) * mitigation)
	var is_crit: bool = false
	if crit_chance >= 1.0:
		is_crit = true
	elif crit_chance > 0.0 and rng != null:
		is_crit = rng.randf() < clampf(crit_chance, 0.0, 1.0)
	if is_crit:
		raw_damage *= maxf(1.0, crit_damage)
	return {
		"damage": raw_damage,
		"amount": maxi(1, int(round(raw_damage))),
		"is_crit": is_crit,
		"mitigation": mitigation
	}

static func calculate_damage_value(attack: float, defense: float) -> float:
	var result: Dictionary = calculate_damage(attack, defense)
	return float(result["damage"])

static func apply_resistance(damage: float, resistance: float) -> float:
	return maxf(1.0, maxf(0.0, damage) * (1.0 - clampf(resistance, 0.0, 0.75)))
