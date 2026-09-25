extends RefCounted

func test_polish_settings_round_trip() -> bool:
	var state: Dictionary = SaveCodec.make_default_state()
	state["settings"]["normal_window_mode"] = true
	state["settings"]["master_volume"] = 0.35
	state["settings"]["window_x"] = 120
	state["settings"]["window_y"] = 80
	var decoded: Dictionary = SaveCodec.state_from_json(SaveCodec.state_to_json(state))
	var settings: Dictionary = decoded.get("settings", {})
	return bool(settings.get("normal_window_mode", false)) and is_equal_approx(float(settings.get("master_volume", 0.0)), 0.35) and int(settings.get("window_x", 0)) == 120 and int(settings.get("window_y", 0)) == 80

func test_level_reward_curve_has_long_run_pacing() -> bool:
	var level_one: int = XPCurve.experience_reward(1, 1)
	var level_ten: int = XPCurve.experience_reward(10, 10)
	var level_twenty: int = XPCurve.experience_reward(20, 20)
	return level_one > 0 and level_ten > level_one and level_twenty > level_ten and level_twenty < 500

func test_stage_level_gate_has_a_real_progression_margin() -> bool:
	var stage_one: Dictionary = StageData.get_stage_by_index(0, "normal")
	var stage_two: Dictionary = StageData.get_stage_by_index(1, "normal")
	return StageData.get_required_level(0, "normal") == int(stage_one.get("recommended_level", 1)) + StageData.PROGRESSION_LEVEL_MARGIN and StageData.get_required_level(1, "normal") == int(stage_two.get("recommended_level", 1)) + StageData.PROGRESSION_LEVEL_MARGIN and StageData.PROGRESSION_LEVEL_MARGIN >= 1

func test_live_pacing_profile_is_bounded_and_monotonic() -> bool:
	var early_step: float = LivePacing.get_simulation_step(0.0)
	var late_step: float = LivePacing.get_simulation_step(3600.0)
	var early_gold: float = LivePacing.get_gold_multiplier(0.0)
	var late_gold: float = LivePacing.get_gold_multiplier(3600.0)
	return early_step >= 0.2 and late_step > early_step and early_gold > late_gold and LivePacing.get_time_multiplier(0) > 0.0

func test_inventory_and_chest_caps_are_bounded() -> bool:
	var inventory: Dictionary = Inventory.create_inventory()
	for index: int in range(80):
		Inventory.add_item(inventory, ItemGen.generate_item(10, RandomNumberGenerator.new(), "common", "knight", "ring"))
	var chest_state: Dictionary = Chests.create_state()
	for index: int in range(40):
		Chests.drop_chest(chest_state, "white", 10)
	return Inventory.count_items(inventory) == 40 and Inventory.get_capacity(inventory) == 40 and Chests.get_queue_capacity(chest_state) == 20
