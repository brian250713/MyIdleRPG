class_name CombatMath
extends RefCounted

const ELEMENTS: Array[String] = ["physical", "fire", "ice", "lightning", "chaos"]
const MAX_RESISTANCE: float = 0.75

static func normalize_element(element: String) -> String:
	var normalized: String = element.strip_edges().to_lower()
	return normalized if ELEMENTS.has(normalized) else "physical"

static func calculate_damage(attack: float, defense: float, crit_chance: float = 0.0, crit_damage: float = 1.5, rng: RandomNumberGenerator = null, element: String = "physical", resistance: float = 0.0) -> Dictionary:
	var safe_element: String = normalize_element(element)
	var mitigation: float = 1.0
	if safe_element == "physical":
		mitigation = 100.0 / (100.0 + maxf(0.0, defense))
	else:
		mitigation = 1.0 - clampf(resistance, 0.0, MAX_RESISTANCE)
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
		"mitigation": mitigation,
		"element": safe_element,
		"resistance": clampf(resistance, 0.0, MAX_RESISTANCE) if safe_element != "physical" else 0.0,
		"defense": maxf(0.0, defense) if safe_element == "physical" else 0.0
	}

static func calculate_damage_for_target(attack: float, target_stats: Dictionary, crit_chance: float = 0.0, crit_damage: float = 1.5, rng: RandomNumberGenerator = null, element: String = "physical") -> Dictionary:
	var safe_element: String = normalize_element(element)
	var defense: float = float(target_stats.get("defense", 0.0)) if safe_element == "physical" else 0.0
	var resistance: float = get_resistance_for_element(target_stats, safe_element) if safe_element != "physical" else 0.0
	return calculate_damage(attack, defense, crit_chance, crit_damage, rng, safe_element, resistance)

static func calculate_damage_value(attack: float, defense: float) -> float:
	var result: Dictionary = calculate_damage(attack, defense)
	return float(result["damage"])

static func get_resistance_for_element(stats: Dictionary, element: String) -> float:
	var safe_element: String = normalize_element(element)
	if safe_element == "physical":
		return 0.0
	return clampf(float(stats.get("%s_resistance" % safe_element, 0.0)), 0.0, MAX_RESISTANCE)

static func apply_resistance(damage: float, resistance: float) -> float:
	return maxf(1.0, maxf(0.0, damage) * (1.0 - clampf(resistance, 0.0, MAX_RESISTANCE)))

static func get_element_color(element: String) -> Color:
	match normalize_element(element):
		"fire":
			return Color(1.0, 0.36, 0.16, 1.0)
		"ice":
			return Color(0.35, 0.78, 1.0, 1.0)
		"lightning":
			return Color(0.78, 0.52, 1.0, 1.0)
		"chaos":
			return Color(1.0, 0.20, 0.62, 1.0)
		_:
			return Color(1.0, 0.84, 0.35, 1.0)
