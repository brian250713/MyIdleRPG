extends RefCounted

func test_class_and_stage_data_tables() -> bool:
	var table: Array[Dictionary] = StageData.get_stage_table()
	var act_one_boss: Dictionary = table[9]
	var act_two_boss: Dictionary = table[19]
	var act_three_boss: Dictionary = table[29]
	return ClassData.get_class_ids().size() == 4 and table.size() == 30 and bool(act_one_boss["is_act_boss"]) and bool(act_two_boss["is_act_boss"]) and bool(act_three_boss["is_act_boss"]) and str(act_one_boss["boss"]) == "boss_andromeda" and str(act_three_boss["boss"]) == "boss_legion" and str(MonsterData.get_monster_definition("neutral_gnasher")["sprite"]) == "neutral_gnasher"

func test_class_stats_scale_per_level() -> bool:
	var level_one: Dictionary = Stats.calculate_class_stats("knight", 1)
	var level_two: Dictionary = Stats.calculate_class_stats("knight", 2)
	return level_one.has("max_hp") and level_two.has("max_hp") and float(level_two["max_hp"]) > float(level_one["max_hp"]) and float(level_two["attack"]) > float(level_one["attack"]) and int(level_two["level"]) == 2

func test_damage_uses_defense_and_crit() -> bool:
	var no_crit: Dictionary = CombatMath.calculate_damage(100.0, 50.0, 0.0, 1.5, null)
	var crit: Dictionary = CombatMath.calculate_damage(100.0, 50.0, 1.0, 2.0, null)
	return float(no_crit["damage"]) < 100.0 and float(no_crit["damage"]) > 0.0 and bool(crit["is_crit"]) and int(crit["amount"]) > int(no_crit["amount"])

func test_xp_curve_and_low_level_penalty() -> bool:
	var same_level: int = XPCurve.experience_reward(10, 10)
	var difference_nine: int = XPCurve.experience_reward(10, 19)
	var difference_ten: int = XPCurve.experience_reward(10, 20)
	var low_level: int = XPCurve.experience_reward(1, 30)
	var level_result: Dictionary = XPCurve.apply_xp(1, 0, XPCurve.xp_to_next(1))
	return XPCurve.xp_to_next(1) == 20 and difference_nine == same_level and difference_ten < difference_nine and float(difference_ten) <= float(difference_nine) * 0.91 and low_level < difference_ten and int(level_result["level"]) == 2 and int(level_result["levels_gained"]) == 1

func test_monster_scaling_increases_level_stats() -> bool:
	var level_one: Dictionary = MonsterScaling.scale_monster("neutral_gnasher", 1)
	var level_ten: Dictionary = MonsterScaling.scale_monster("neutral_gnasher", 10)
	var one_stats: Dictionary = level_one["stats"]
	var ten_stats: Dictionary = level_ten["stats"]
	return float(ten_stats["max_hp"]) > float(one_stats["max_hp"]) and float(ten_stats["attack"]) > float(one_stats["attack"]) and int(level_ten["level"]) == 10

func test_gold_and_xp_rewards() -> bool:
	var normal: Dictionary = Rewards.calculate_rewards(5, false)
	var boss: Dictionary = Rewards.calculate_rewards(10, true)
	return int(normal["gold"]) > 0 and int(normal["xp"]) > 0 and int(boss["gold"]) > int(normal["gold"]) and int(boss["xp"]) > int(normal["xp"])

func test_stage_progression_waves_boss_and_auto_advance() -> bool:
	var progression: StageProgression = StageProgression.new()
	progression.start_stage(0, 2)
	if progression.on_wave_cleared() != "wave_started":
		return false
	if progression.on_wave_cleared() != "boss_started":
		return false
	if progression.on_boss_defeated() != "stage_cleared":
		return false
	if progression.get_unlocked_stage() != 1:
		return false
	if progression.advance_to_next_stage() != "next_stage_started" or progression.get_current_stage() != 1:
		return false
	progression.set_auto_advance(false)
	progression.start_stage(0, 1)
	progression.on_wave_cleared()
	progression.on_boss_defeated()
	return progression.advance_to_next_stage() == "waiting_for_manual_advance" and progression.get_current_stage() == 0

func test_stage_progression_wipe_retreats_one_stage() -> bool:
	var progression: StageProgression = StageProgression.new({"current_stage": 2, "unlocked_stage": 2, "wave_count": 5, "phase": StageProgression.Phase.WAVES})
	var result: String = progression.on_party_wiped()
	return result == "retreated" and progression.get_current_stage() == 1 and progression.get_phase() == StageProgression.Phase.RETREATING

func test_save_state_round_trip() -> bool:
	var state: Dictionary = SaveCodec.make_default_state()
	state["gold"] = 987
	state["current_stage"] = 4
	state["unlocked_stage"] = 5
	state["party"][0]["level"] = 7
	state["party"][0]["xp"] = 12
	state["settings"]["auto_advance"] = false
	var json_text: String = SaveCodec.state_to_json(state)
	var decoded: Dictionary = SaveCodec.state_from_json(json_text)
	return int(decoded["version"]) == SaveCodec.VERSION and int(decoded["gold"]) == 987 and int(decoded["current_stage"]) == 4 and int(decoded["unlocked_stage"]) == 5 and int(decoded["party"][0]["level"]) == 7 and int(decoded["party"][0]["xp"]) == 12 and not bool(decoded["settings"]["auto_advance"])
