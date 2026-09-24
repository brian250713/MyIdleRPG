extends RefCounted

## 平衡測試使用固定種子，避免暴擊隨機性讓回歸測試偶發失敗。
const SIM_SEED: int = 20260924

func test_fresh_solo_stage_one_clears() -> bool:
	var hero_specs: Array = [{"class_id": "knight", "level": 1, "equipment": {}, "skills": {}}]
	var result: Dictionary = BattleSim.simulate_stage(0, "normal", hero_specs, {"seed": SIM_SEED, "max_time_seconds": 120.0})
	return bool(result.get("win", false)) and str(result.get("outcome", "")) == "win" and float(result.get("time_taken", 999.0)) <= 90.0 and int(result.get("waves_cleared", 0)) == 5 and bool(result.get("boss_defeated", false)) and float(result.get("hp_left", 0.0)) > 0.0

func test_recommended_gear_clears_normal_stages() -> bool:
	var stage_one_five: Dictionary = BattleSim.simulate_stage(4, "normal", [BattleSim.make_hero_spec("knight", 5, 5, 5101)], {"seed": SIM_SEED, "max_time_seconds": 120.0})
	var act_boss: Dictionary = BattleSim.simulate_stage(19, "normal", [BattleSim.make_hero_spec("knight", 20, 20, 20201)], {"seed": SIM_SEED, "max_time_seconds": 120.0})
	return _is_stage_clear(stage_one_five) and _is_stage_clear(act_boss) and float(stage_one_five.get("time_taken", 999.0)) <= 90.0 and float(act_boss.get("time_taken", 999.0)) <= 90.0

func test_hero_five_levels_under_fails_at_act_boss() -> bool:
	var under_level: Dictionary = BattleSim.simulate_stage(19, "normal", [BattleSim.make_hero_spec("knight", 15, 15, 15151)], {"seed": SIM_SEED, "max_time_seconds": 120.0})
	return not bool(under_level.get("win", true)) and bool(under_level.get("boss_reached", false)) and int(under_level.get("waves_cleared", 0)) == 5 and float(under_level.get("hp_left", 1.0)) <= 0.0

func test_nightmare_stage_accepts_level_matched_party() -> bool:
	var party: Array = [
		_trained_spec("knight", 31, 31, 3101),
		_trained_spec("priest", 31, 31, 3102),
		_trained_spec("ranger", 31, 31, 3103)
	]
	var result: Dictionary = BattleSim.simulate_stage(0, "nightmare", party, {"seed": SIM_SEED, "max_time_seconds": 120.0})
	return _is_stage_clear(result) and float(result.get("time_taken", 999.0)) <= 120.0 and float(result.get("hp_left", 0.0)) > 0.0

func test_every_stage_has_a_separate_boss() -> bool:
	for stage_index: int in [0, 4, 19, 29]:
		var stage: Dictionary = StageData.get_stage_by_index(stage_index, "normal")
		var boss_id: String = str(stage.get("boss", ""))
		var pool: Array = stage.get("monster_pool", [])
		if boss_id.is_empty() or pool.has(boss_id):
			return false
	return true

func test_wave_heal_and_new_stage_reset_are_modeled() -> bool:
	var result: Dictionary = BattleSim.simulate_stage(0, "normal", [{"class_id": "knight", "level": 1, "equipment": {}, "skills": {}}], {"seed": SIM_SEED, "max_time_seconds": 120.0})
	var wave_results: Array = result.get("wave_results", [])
	if wave_results.size() < 2:
		return false
	var first_wave: Dictionary = wave_results[0]
	var second_wave: Dictionary = wave_results[1]
	var starting_hp: float = float(result.get("hp_max", 0.0))
	return is_equal_approx(float(first_wave.get("hp_before", 0.0)), starting_hp) and float(second_wave.get("hp_before", 0.0)) > float(first_wave.get("hp_after", 0.0)) and is_equal_approx(float(result.get("wave_heal_ratio", 0.0)), StageData.WAVE_HEAL_RATIO)

func _is_stage_clear(result: Dictionary) -> bool:
	return bool(result.get("win", false)) and str(result.get("outcome", "")) == "win" and int(result.get("waves_cleared", 0)) == int(result.get("wave_count", 0)) and bool(result.get("boss_reached", false)) and bool(result.get("boss_defeated", false)) and float(result.get("hp_left", 0.0)) > 0.0

func _trained_spec(class_id: String, level: int, gear_level: int, seed_value: int) -> Dictionary:
	var spec: Dictionary = BattleSim.make_hero_spec(class_id, level, gear_level, seed_value, "epic")
	var skill_levels: Dictionary = {}
	for definition: Dictionary in SkillData.get_class_skills(class_id, "active"):
		skill_levels[str(definition.get("id", ""))] = 3
	for definition: Dictionary in SkillData.get_class_skills(class_id, "passive"):
		skill_levels[str(definition.get("id", ""))] = 3
	spec["skills"] = {"skill_levels": skill_levels, "equipped_actives": SkillData.get_active_skill_ids(class_id).slice(0, 2)}
	return spec
