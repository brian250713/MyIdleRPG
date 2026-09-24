class_name Offline
extends RefCounted

const MAX_SECONDS: int = 12 * 60 * 60
const EFFICIENCY: float = 0.50
const FALLBACK_KILLS_PER_MINUTE: float = 6.0
const DEFAULT_SEED: int = 20260924

static func calculate(state: Dictionary, now_unix: int, options: Dictionary = {}) -> Dictionary:
	var now: int = maxi(0, now_unix)
	var last_saved: int = maxi(0, int(state.get("last_saved_unix", 0)))
	var raw_seconds: int = 0 if last_saved <= 0 else now - last_saved
	var source_chest_state: Dictionary = state.get("chests", Chests.create_state()) if state.get("chests", {}) is Dictionary else Chests.create_state()
	var summary: Dictionary = {
		"ok": false,
		"now_unix": now,
		"clock_backwards": raw_seconds < 0,
		"raw_seconds": maxi(0, raw_seconds),
		"away_seconds": 0.0,
		"capped": false,
		"efficiency": EFFICIENCY,
		"gold": 0,
		"xp": 0,
		"xp_by_class": {},
		"white_chests": 0,
		"white_cooldown_after": maxf(0.0, float(source_chest_state.get("white_cooldown", 0.0))),
		"chests": [],
		"stage_index": clampi(int(state.get("current_stage", 0)), 0, StageData.get_stage_count() - 1),
		"difficulty_id": str(state.get("difficulty", "normal")),
		"estimated_kills": 0,
		"reason": "no_offline_time"
	}
	if raw_seconds <= 0:
		return summary
	var capped_seconds: int = mini(MAX_SECONDS, raw_seconds)
	summary["away_seconds"] = float(capped_seconds)
	summary["capped"] = raw_seconds > MAX_SECONDS
	var stage_index: int = int(summary["stage_index"])
	var difficulty_id: String = str(summary["difficulty_id"])
	var stage: Dictionary = StageData.get_stage_by_index(stage_index, difficulty_id)
	var recommended_level: int = maxi(1, int(stage.get("recommended_level", 1)))
	var hero_specs: Array = _get_hero_specs(state)
	var simulation: Dictionary = BattleSim.simulate_stage(stage_index, difficulty_id, hero_specs, {"max_time_seconds": 120.0, "seed": int(options.get("seed", DEFAULT_SEED))})
	var duration_seconds: float = maxf(1.0, float(simulation.get("time_taken", 60.0)))
	var kills: int = _estimate_kills(simulation)
	if kills <= 0:
		kills = maxi(1, int(round(FALLBACK_KILLS_PER_MINUTE * duration_seconds / 60.0)))
	var effective_minutes: float = float(capped_seconds) / 60.0 * EFFICIENCY
	var estimated_kills: int = maxi(0, int(floor(float(kills) / duration_seconds * 60.0 * effective_minutes)))
	summary["estimated_kills"] = estimated_kills
	var reward: Dictionary = Rewards.calculate_rewards(recommended_level, false)
	var max_gold_multiplier: float = 1.0
	var hero_runtime: Array[Dictionary] = []
	for hero_spec: Dictionary in hero_specs:
		var hero_stats: Dictionary = Stats.calculate_final_stats(str(hero_spec.get("class_id", "knight")), int(hero_spec.get("level", 1)), hero_spec.get("equipment", {}), hero_spec.get("skills", {}), state.get("runes", {}))
		max_gold_multiplier = maxf(max_gold_multiplier, 1.0 + float(hero_stats.get("gold_gain", 0.0)))
		hero_runtime.append({
			"class_id": str(hero_spec.get("class_id", "knight")),
			"level": int(hero_spec.get("level", 1)),
			"xp_progress": float(hero_spec.get("xp", 0)),
			"earned_xp": 0.0,
			"xp_gain": float(hero_stats.get("xp_gain", 0.0)),
			"level_before": int(hero_spec.get("level", 1))
		})
	var gold: int = maxi(0, int(floor(float(reward.get("gold", 0)) * float(estimated_kills) * max_gold_multiplier * EFFICIENCY)))
	var xp_by_class: Dictionary = {}
	var hero_levels_after: Array[int] = []
	for hero: Dictionary in hero_runtime:
		var current_level: int = int(hero.get("level", 1))
		var xp_progress: float = float(hero.get("xp_progress", 0.0))
		var earned_xp: float = 0.0
		for _kill_index: int in range(estimated_kills):
			var xp_reward: int = XPCurve.experience_reward(recommended_level, current_level, 1.0 + float(hero.get("xp_gain", 0.0)))
			var efficient_xp: float = float(xp_reward) * EFFICIENCY
			earned_xp += efficient_xp
			xp_progress += efficient_xp
			while current_level < XPCurve.MAX_LEVEL and xp_progress >= float(XPCurve.xp_to_next(current_level)):
				xp_progress -= float(XPCurve.xp_to_next(current_level))
				current_level += 1
		hero["level"] = current_level
		hero["earned_xp"] = earned_xp
		hero_levels_after.append(current_level)
		var class_id: String = str(hero.get("class_id", "knight"))
		xp_by_class[class_id] = int(xp_by_class.get(class_id, 0)) + int(floor(earned_xp))
	var xp_total: int = 0
	for raw_xp: Variant in xp_by_class.values():
		xp_total += int(raw_xp)
	summary["gold"] = gold
	summary["xp"] = xp_total
	summary["xp_by_class"] = xp_by_class
	summary["hero_levels_after"] = hero_levels_after
	var chest_state: Dictionary = source_chest_state.duplicate(true)
	var capacity: int = Chests.get_queue_capacity(chest_state)
	var current_queue_size: int = Chests.get_queue_size(chest_state)
	var cooldown_before: float = maxf(0.0, float(chest_state.get("white_cooldown", 0.0)))
	var cooldown_window: float = maxf(0.0, float(capped_seconds) - minf(cooldown_before, float(capped_seconds)))
	var cooldown_intervals: int = int(floor(cooldown_window / Chests.WHITE_COOLDOWN_SECONDS))
	var white_chests: int = clampi(cooldown_intervals, 0, maxi(0, capacity - current_queue_size))
	var cooldown_after: float = maxf(0.0, cooldown_before - float(capped_seconds))
	if white_chests > 0:
		var elapsed_after_first: float = maxf(0.0, cooldown_window - float(white_chests) * Chests.WHITE_COOLDOWN_SECONDS)
		cooldown_after = Chests.WHITE_COOLDOWN_SECONDS - fmod(elapsed_after_first, Chests.WHITE_COOLDOWN_SECONDS)
		if is_equal_approx(cooldown_after, Chests.WHITE_COOLDOWN_SECONDS):
			cooldown_after = 0.0
	var chest_entries: Array = []
	for index: int in range(white_chests):
		chest_entries.append({"type": "white", "level": recommended_level, "id": "offline_white_%d" % index})
	summary["white_chests"] = white_chests
	summary["white_cooldown_after"] = cooldown_after
	summary["chests"] = chest_entries
	summary["ok"] = gold > 0 or xp_total > 0 or white_chests > 0
	summary["reason"] = "calculated"
	return summary

static func apply_to_state(state: Dictionary, summary: Dictionary) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	if bool(summary.get("clock_backwards", false)):
		return next_state
	next_state["gold"] = maxi(0, int(next_state.get("gold", 0)) + int(summary.get("gold", 0)))
	var xp_by_class: Dictionary = summary.get("xp_by_class", {})
	for raw_class_id: Variant in xp_by_class.keys():
		var class_id: String = str(raw_class_id)
		var party: Array = next_state.get("party", [])
		for raw_hero: Variant in party:
			if raw_hero is Dictionary and str((raw_hero as Dictionary).get("class_id", "")) == class_id:
				var hero: Dictionary = raw_hero
				var xp_result: Dictionary = XPCurve.apply_xp(int(hero.get("level", 1)), int(hero.get("xp", 0)), int(xp_by_class[raw_class_id]))
				hero["level"] = int(xp_result.get("level", hero.get("level", 1)))
				hero["xp"] = int(xp_result.get("xp", 0))
				break
	var chest_state: Dictionary = next_state.get("chests", Chests.create_state())
	var queue: Array = chest_state.get("queue", [])
	for raw_chest: Variant in summary.get("chests", []):
		if raw_chest is Dictionary and Chests.get_queue_size(chest_state) < Chests.get_queue_capacity(chest_state):
			queue.append((raw_chest as Dictionary).duplicate(true))
	chest_state["queue"] = queue
	chest_state["white_cooldown"] = maxf(0.0, float(summary.get("white_cooldown_after", chest_state.get("white_cooldown", 0.0))))
	next_state["chests"] = chest_state
	next_state["last_saved_unix"] = maxi(int(next_state.get("last_saved_unix", 0)), int(summary.get("now_unix", 0)))
	return next_state

static func get_capped_seconds(seconds: int) -> int:
	return clampi(seconds, 0, MAX_SECONDS)

static func _estimate_kills(simulation: Dictionary) -> int:
	var kills: int = 0
	var wave_results: Array = simulation.get("wave_results", [])
	for raw_wave: Variant in wave_results:
		if raw_wave is Dictionary:
			kills += int((raw_wave as Dictionary).get("monster_count", 0))
	if bool(simulation.get("boss_reached", false)):
		kills += 1
	return kills

static func _get_hero_specs(state: Dictionary) -> Array:
	var result: Array = []
	var party: Array = state.get("party", [])
	for raw_hero: Variant in party:
		if raw_hero is Dictionary:
			result.append((raw_hero as Dictionary).duplicate(true))
	if result.is_empty():
		result.append({"class_id": "knight", "level": 1, "equipment": {}, "skills": {}})
	return result
