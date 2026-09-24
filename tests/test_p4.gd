extends RefCounted

func test_socket_unsocket_round_trip_and_stats() -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7001
	var item: Dictionary = ItemGen.generate_item(10, rng, "rare", "knight", "weapon")
	var material: Dictionary = Materials.make_material("ruby", 10, "rare")
	var wrong_material: Dictionary = Materials.make_material("strength_rune", 10, "common")
	var wrong_result: Dictionary = Socketing.socket_material(item, 0, wrong_material)
	if bool(wrong_result.get("ok", false)):
		return false
	var socket_result: Dictionary = Socketing.socket_material(item, 0, material)
	if not bool(socket_result.get("ok", false)):
		return false
	var socketed_item: Dictionary = socket_result.get("item", {})
	var base_stats: Dictionary = Stats.calculate_final_stats("knight", 1, {"weapon": item}, {})
	var socketed_stats: Dictionary = Stats.calculate_final_stats("knight", 1, {"weapon": socketed_item}, {})
	if float(socketed_stats.get("fire_resistance", 0.0)) <= float(base_stats.get("fire_resistance", 0.0)):
		return false
	var unsocket_result: Dictionary = Socketing.unsocket_material(socketed_item, 0)
	var returned: Dictionary = unsocket_result.get("material", {})
	var final_item: Dictionary = unsocket_result.get("item", {})
	return bool(unsocket_result.get("ok", false)) and str(returned.get("id", "")) == "ruby" and Socketing.get_socketed_bonus(final_item).is_empty() and float(Stats.calculate_final_stats("knight", 1, {"weapon": final_item}, {}).get("fire_resistance", 0.0)) == float(base_stats.get("fire_resistance", 0.0))

func test_cube_level_rule_xp_and_material_upgrade() -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7002
	var items: Array = [
		ItemGen.generate_item(20, rng, "rare", "knight", "weapon"),
		ItemGen.generate_item(20, rng, "rare", "knight", "helmet"),
		ItemGen.generate_item(20, rng, "rare", "knight", "chest")
	]
	var cube_state: Dictionary = Cube.create_state()
	cube_state["level"] = 10
	var preview: Dictionary = Cube.preview(cube_state, items, rng)
	if int(preview.get("output_level", 0)) != 10 or int(preview.get("level_min", 0)) != int(preview.get("level_max", -1)):
		return false
	var high_state: Dictionary = Cube.create_state()
	high_state["level"] = 1
	var high_preview: Dictionary = Cube.preview(high_state, items, rng)
	var near_state: Dictionary = Cube.create_state()
	near_state["level"] = 20
	var near_gain: int = Cube.get_xp_gain(near_state, items)
	if not bool(high_preview.get("over_level_penalty", false)) or int(high_preview.get("xp_gain", 0)) >= near_gain:
		return false
	var result: Dictionary = Cube.combine_items(cube_state, items, rng)
	var materials: Dictionary = Materials.create_state()
	Materials.add_material(materials, Materials.make_material("ruby", 5, "common"), 3)
	var material_result: Dictionary = Cube.combine_materials(materials, cube_state, "ruby", rng)
	return bool(result.get("ok", false)) and int(result.get("output_level", 0)) == 10 and int(result.get("state", {}).get("xp", 0)) > 0 and bool(material_result.get("ok", false)) and Materials.get_count(materials, "ruby") >= 1

func test_rune_price_formula_and_all_effects() -> bool:
	if RuneData.get_rune_ids().size() != 9:
		return false
	var state: Dictionary = Runes.create_state()
	var gold: int = 100000
	var first: Dictionary = Runes.purchase(state, "gold_gain", gold)
	if not bool(first.get("ok", false)) or int(first.get("cost", 0)) != 100:
		return false
	state = first.get("state", state)
	var second_cost: int = Runes.get_next_cost(state, "gold_gain")
	if second_cost != 160:
		return false
	var levels: Dictionary = {}
	for rune_id: String in RuneData.get_rune_ids():
		levels[rune_id] = 1 if rune_id != "inventory_pages" else 4
	var rune_state: Dictionary = Runes.normalize_state({"levels": levels})
	var modifiers: Dictionary = Runes.get_modifiers(rune_state)
	var base: Dictionary = Stats.calculate_final_stats("knight", 10, {}, {}, {})
	var buffed: Dictionary = Stats.calculate_final_stats("knight", 10, {}, {}, rune_state)
	var inventory: Dictionary = Inventory.create_inventory()
	Inventory.ensure_pages(inventory, Runes.get_inventory_pages(rune_state))
	var chest_state: Dictionary = Chests.create_state()
	Chests.set_rune_effects(chest_state, Runes.get_white_chest_rate(rune_state), Runes.get_chest_capacity(rune_state), Runes.get_boss_chest_quality(rune_state))
	return is_equal_approx(float(modifiers.get("gold_gain", 0.0)), 0.10) and is_equal_approx(float(modifiers.get("xp_gain", 0.0)), 0.10) and Inventory.get_page_count(inventory) == 5 and Chests.get_queue_capacity(chest_state) == 25 and float(buffed.get("attack", 0.0)) > float(base.get("attack", 0.0)) and float(buffed.get("max_hp", 0.0)) > float(base.get("max_hp", 0.0)) and float(buffed.get("fire_resistance", 0.0)) > float(base.get("fire_resistance", 0.0)) and float(buffed.get("gold_gain", 0.0)) > float(base.get("gold_gain", 0.0)) and float(buffed.get("xp_gain", 0.0)) > float(base.get("xp_gain", 0.0))

func test_soul_stone_gating_and_loss_does_not_refund() -> bool:
	var state: Dictionary = SaveCodec.make_default_state()
	state["unlocked_stage"] = 9
	state["current_stage"] = 9
	state["soul_stones"] = 0
	var requirement: String = SoulStones.get_requirement_text(state, "normal", 9)
	var denied: Dictionary = SoulStones.pay_for_stage(state, "normal", 9)
	if not requirement.contains("需要") or bool(denied.get("ok", false)):
		return false
	state["soul_stones"] = 1
	var paid: Dictionary = SoulStones.pay_for_stage(state, "normal", 9)
	if not bool(paid.get("ok", false)) or int(paid.get("state", {}).get("soul_stones", 0)) != 0:
		return false
	var retry: Dictionary = SoulStones.pay_for_stage(paid.get("state", state), "normal", 9)
	return bool(retry.get("ok", false)) and bool(retry.get("already_paid", false)) and int(retry.get("state", {}).get("soul_stones", 0)) == 0 and SoulStones.get_fallback_stage(9) == 8

func test_offline_cap_efficiency_capacity_and_clock_guard() -> bool:
	var state: Dictionary = SaveCodec.make_default_state()
	var now: int = 1000000
	state["last_saved_unix"] = now - 13 * 60 * 60
	var summary: Dictionary = Offline.calculate(state, now)
	if not bool(summary.get("capped", false)) or not is_equal_approx(float(summary.get("away_seconds", 0.0)), float(Offline.MAX_SECONDS)) or not is_equal_approx(float(summary.get("efficiency", 0.0)), 0.5):
		return false
	if int(summary.get("white_chests", 0)) > Chests.get_queue_capacity(state.get("chests", Chests.create_state())) or int(summary.get("gold", 0)) <= 0 or int(summary.get("xp", 0)) <= 0:
		return false
	var cooldown_state: Dictionary = state.duplicate(true)
	cooldown_state["last_saved_unix"] = now - 100
	cooldown_state["chests"] = Chests.create_state()
	cooldown_state["chests"]["white_cooldown"] = 89.0
	var cooldown_summary: Dictionary = Offline.calculate(cooldown_state, now)
	if int(cooldown_summary.get("white_chests", -1)) != 0:
		return false
	var backwards_state: Dictionary = state.duplicate(true)
	backwards_state["last_saved_unix"] = now + 100
	var backwards: Dictionary = Offline.calculate(backwards_state, now)
	var unchanged: Dictionary = Offline.apply_to_state(backwards_state, backwards)
	return bool(backwards.get("clock_backwards", false)) and int(backwards.get("gold", -1)) == 0 and int(unchanged.get("last_saved_unix", 0)) == now + 100

func test_chest_materials_and_boss_quality_flow() -> bool:
	var state: Dictionary = Chests.create_state()
	state["boss_chest_quality_bonus"] = 0.5
	Chests.drop_chest(state, "blue", 20)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7003
	var result: Dictionary = Chests.open_chest(state, 0, rng)
	return bool(result.get("opened", false)) and is_equal_approx(float(result.get("quality_bonus", 0.0)), 0.5) and (result.get("materials", []) as Array).is_empty() == false

func test_offline_gold_xp_are_separate_and_apply_level_penalty() -> bool:
	var now: int = 2000000
	var state: Dictionary = SaveCodec.make_default_state()
	state["last_saved_unix"] = now - 20000
	state["party"][0]["level"] = 14
	var summary: Dictionary = Offline.calculate(state, now)
	var applied: Dictionary = Offline.apply_to_state(state, summary)
	var hero: Dictionary = (applied.get("party", []) as Array)[0]
	return int(summary.get("gold", 0)) != int(summary.get("xp", 0)) and int(summary.get("gold", 0)) > 0 and int(summary.get("xp", 0)) > 0 and int(hero.get("level", 0)) < 23 and (summary.get("hero_levels_after", []) as Array).size() == 1

func test_test_boot_does_not_touch_real_save() -> bool:
	var real_path: String = "user://save.json"
	if not FileAccess.file_exists(real_path):
		return SaveManager.is_test_mode() and SaveManager.get_active_save_path() != real_path
	var before_md5: String = FileAccess.get_md5(real_path)
	var before_modified: int = FileAccess.get_modified_time(real_path)
	SaveManager.load_game()
	var after_md5: String = FileAccess.get_md5(real_path)
	var after_modified: int = FileAccess.get_modified_time(real_path)
	return SaveManager.is_test_mode() and SaveManager.get_active_save_path() != real_path and before_md5 == after_md5 and before_modified == after_modified

func test_capture_save_path_is_overridable() -> bool:
	return SaveManager.get_save_path_for_mode(false) == "user://save.json" and SaveManager.get_save_path_for_mode(true) == "user://capture_save.json" and SaveManager.get_save_path_for_mode(true) != SaveManager.get_save_path_for_mode(false)

func test_v4_save_round_trip_preserves_phase4_state() -> bool:
	var state: Dictionary = SaveCodec.make_default_state()
	var materials: Dictionary = state["materials"]
	Materials.add_material(materials, Materials.make_material("ruby", 12, "rare"), 4)
	state["cube"] = {"level": 4, "xp": 17}
	state["runes"] = Runes.normalize_state({"levels": {"gold_gain": 2, "inventory_pages": 4}})
	state["paid_act_bosses"] = {"normal:9": true}
	var decoded: Dictionary = SaveCodec.state_from_json(SaveCodec.state_to_json(state))
	return int(decoded.get("version", 0)) == 4 and Materials.get_count(decoded.get("materials", {}), "ruby") == 4 and int(decoded.get("cube", {}).get("level", 0)) == 4 and Runes.get_level(decoded.get("runes", {}), "gold_gain") == 2 and Inventory.get_page_count(decoded.get("inventory", {})) == 5 and Chests.get_queue_capacity(decoded.get("chests", {})) == 20 and bool((decoded.get("paid_act_bosses", {}) as Dictionary).get("normal:9", false))

func test_v3_to_v4_save_migration() -> bool:
	var old_state: Dictionary = {
		"version": 3,
		"gold": 777,
		"current_stage": 3,
		"unlocked_stage": 3,
		"party": [{"class_id": "knight", "level": 6, "xp": 2}, null, null],
		"inventory": Inventory.create_inventory(),
		"chests": Chests.create_state(),
		"settings": {"auto_advance": true}
	}
	var migrated: Dictionary = SaveCodec.normalize_state(old_state)
	return int(migrated.get("version", 0)) == 4 and Materials.get_total_count(migrated.get("materials", {})) == 0 and int(migrated.get("cube", {}).get("level", 0)) == 1 and Runes.get_level(migrated.get("runes", {}), "gold_gain") == 0 and (migrated.get("paid_act_bosses", {}) as Dictionary).is_empty() and int(migrated.get("inventory", {}).get("pages", 0)) == 1
