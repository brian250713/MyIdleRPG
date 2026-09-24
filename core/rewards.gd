class_name Rewards
extends RefCounted

static func calculate_rewards(monster_level: int, is_boss: bool = false) -> Dictionary:
	var safe_level: int = maxi(1, monster_level)
	var gold: int = maxi(1, int(round((6.0 + float(safe_level) * 3.0 + pow(float(safe_level), 1.2) * 1.5) * (5.0 if is_boss else 1.0))))
	var xp_multiplier: float = 5.0 if is_boss else 1.0
	return {
		"xp": XPCurve.experience_reward(safe_level, safe_level, xp_multiplier),
		"gold": gold,
		"is_boss": is_boss
	}

static func apply_to_state(state: Dictionary, rewards: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	next_state["gold"] = maxi(0, int(next_state.get("gold", 0)) + int(rewards.get("gold", 0)))
	return next_state
