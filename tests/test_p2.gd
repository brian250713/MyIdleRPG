extends RefCounted

func test_item_rarity_distribution() -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 987654
	var counts: Dictionary = {}
	for rarity_id: String in ItemData.get_rarity_ids():
		counts[rarity_id] = 0
	var sample_size: int = 50000
	for _index: int in range(sample_size):
		var item: Dictionary = ItemGen.generate_item(10, rng, "", "knight")
		var rarity_id: String = str(item.get("rarity", "common"))
		counts[rarity_id] = int(counts[rarity_id]) + 1
	for rarity_id: String in ItemData.get_rarity_ids():
		var expected: float = float(ItemData.get_rarity_definition(rarity_id).get("weight", 0.0)) / 100.0
		var actual: float = float(counts[rarity_id]) / float(sample_size)
		if absf(actual - expected) > 0.025:
			return false
	return true

func test_socket_layouts_and_affix_counts() -> bool:
	for rarity_id: String in ItemData.get_rarity_ids():
		var item: Dictionary = ItemGen.generate_item(20, RandomNumberGenerator.new(), rarity_id, "knight", "chest")
		var expected_sockets: Array[String] = ItemData.get_socket_layout(rarity_id)
		if item.get("sockets", []).size() != expected_sockets.size():
			return false
		if item.get("affixes", []).size() != int(ItemData.get_rarity_definition(rarity_id).get("affix_count", 0)):
			return false
		var actual_sockets: Array = item.get("sockets", [])
		for index: int in range(expected_sockets.size()):
			if str(actual_sockets[index].get("type", "")) != expected_sockets[index]:
				return false
	return true

func test_stat_aggregation_and_resistance_cap() -> bool:
	var equipment: Dictionary = {
		"weapon": ItemGen.generate_item(10, RandomNumberGenerator.new(), "rare", "knight", "weapon"),
		"amulet": {
			"slot": "amulet",
			"main_stat": "fire_resistance",
			"main_value": 0.5,
			"affixes": [{"stat": "fire_resistance", "value": 0.9, "percent": true}]
		}
	}
	var base_stats: Dictionary = Stats.calculate_class_stats("knight", 1)
	var final_stats: Dictionary = Stats.calculate_final_stats("knight", 1, equipment)
	return float(final_stats["attack"]) > float(base_stats["attack"]) and is_equal_approx(float(final_stats["fire_resistance"]), 0.75) and Power.calculate(final_stats) > 0

func test_chest_cooldown_capacity_and_boss_drops() -> bool:
	var state: Dictionary = Chests.create_state()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 111
	state["white_cooldown"] = 90.0
	if bool(Chests.try_white_drop(state, 5, rng).get("dropped", false)):
		return false
	state["white_cooldown"] = 0.0
	for _index: int in range(20):
		Chests.drop_chest(state, "white", 5)
	if bool(Chests.try_white_drop(state, 5, rng).get("dropped", false)):
		return false
	var boss_state: Dictionary = Chests.create_state()
	var boss_result: Dictionary = Chests.try_drop_for_kill(boss_state, 10, true, true, rng)
	var counts: Dictionary = Chests.get_counts(boss_state)
	return bool(boss_result.get("dropped", false)) and int(counts["blue"]) == 1 and int(counts["act_boss"]) == 1 and Chests.get_queue_size(boss_state) == 2

func test_chest_opening_outputs_items_and_gold() -> bool:
	var state: Dictionary = Chests.create_state()
	Chests.drop_chest(state, "blue", 12)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 654321
	var result: Dictionary = Chests.open_chest(state, 0, rng)
	var items: Array = result.get("items", [])
	return bool(result.get("opened", false)) and items.size() >= 1 and items.size() <= 3 and int(result.get("gold", 0)) > 0 and Chests.get_queue_size(state) == 0

func test_inventory_overflow_converts_to_gold() -> bool:
	var inventory: Dictionary = Inventory.create_inventory()
	var item: Dictionary = ItemGen.generate_item(5, RandomNumberGenerator.new(), "common", "knight", "ring")
	for index: int in range(40):
		Inventory.add_item(inventory, item)
	var overflow_item: Dictionary = ItemGen.generate_item(5, RandomNumberGenerator.new(), "rare", "knight", "weapon")
	var result: Dictionary = Inventory.add_item(inventory, overflow_item)
	return Inventory.count_items(inventory) == 40 and not bool(result.get("stored", false)) and bool(result.get("converted_to_gold", false)) and int(result.get("gold", 0)) > 0

func test_v1_to_v2_save_migration() -> bool:
	var old_state: Dictionary = {
		"version": 1,
		"gold": 123,
		"current_stage": 0,
		"unlocked_stage": 0,
		"party": [{"class_id": "knight", "level": 3, "xp": 4}, null, null],
		"settings": {"auto_advance": false}
	}
	var migrated: Dictionary = SaveCodec.normalize_state(old_state)
	var party: Array = migrated.get("party", [])
	var hero: Dictionary = party[0]
	var inventory: Dictionary = migrated.get("inventory", {})
	var equipment: Dictionary = hero.get("equipment", {})
	return int(migrated["version"]) == SaveCodec.VERSION and int(migrated["soul_stones"]) == 0 and inventory.get("slots", []).size() == 40 and Chests.get_queue_size(migrated["chests"]) == 0 and equipment.has("weapon") and equipment["weapon"] == null and int(hero["level"]) == 3
