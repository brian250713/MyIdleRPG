class_name XPCurve
extends RefCounted

const MAX_LEVEL: int = 100

static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	var safe_level: int = maxi(1, level)
	return maxi(1, int(round(20.0 * pow(float(safe_level), 1.8))))

static func experience_reward(monster_level: int, hero_level: int, multiplier: float = 1.0) -> int:
	var safe_monster_level: int = maxi(1, monster_level)
	var safe_hero_level: int = maxi(1, hero_level)
	var base_reward: float = 18.0 * pow(float(safe_monster_level), 1.45)
	var level_difference: int = safe_hero_level - safe_monster_level
	var penalty_factor: float = 1.0
	if level_difference >= 10:
		var levels_beyond_penalty_start: int = level_difference - 9
		penalty_factor = maxf(0.1, 1.0 - 0.1 * float(levels_beyond_penalty_start))
	return maxi(1, int(round(base_reward * penalty_factor * maxf(0.0, multiplier))))

static func apply_xp(current_level: int, current_xp: int, amount: int) -> Dictionary:
	var level: int = clampi(current_level, 1, MAX_LEVEL)
	var xp: int = maxi(0, current_xp)
	var levels_gained: int = 0
	if level < MAX_LEVEL:
		xp += maxi(0, amount)
		while level < MAX_LEVEL and xp >= xp_to_next(level):
			xp -= xp_to_next(level)
			level += 1
			levels_gained += 1
		if level >= MAX_LEVEL:
			xp = 0
	return {
		"level": level,
		"xp": xp,
		"levels_gained": levels_gained
	}

static func level_from_total_xp(total_xp: int) -> int:
	var remaining: int = maxi(0, total_xp)
	var level: int = 1
	while level < MAX_LEVEL and remaining >= xp_to_next(level):
		remaining -= xp_to_next(level)
		level += 1
	return level
