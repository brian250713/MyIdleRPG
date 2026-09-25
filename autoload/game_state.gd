extends Node

signal state_changed
signal gold_changed(new_gold: int)
signal hero_xp_changed(class_id: String, level: int, xp: int)
signal hero_leveled_up(class_id: String, level: int)
signal stage_changed(stage_index: int, display_name: String)
signal setting_changed(key: String, value: Variant)

var state: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _offline_summary: Dictionary = {}

func _ready() -> void:
	state = SaveCodec.make_default_state()
	_rng.seed = 20260924

func _process(delta: float) -> void:
	if state.has("chests"):
		Chests.tick(state["chests"], delta)

func apply_loaded_state(loaded_state: Dictionary) -> void:
	state = SaveCodec.normalize_state(loaded_state)
	_offline_summary = {}
	_sync_rune_effects()
	var settings: Dictionary = state.get("settings", {})
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, clampf(float(settings.get("master_volume", 0.8)), 0.0, 1.0))))
	_notify_state_changed()
	gold_changed.emit(get_gold())
	EventBus.gold_changed.emit(get_gold())
	stage_changed.emit(get_current_stage(), StageData.get_display_name(get_current_stage(), get_current_difficulty()))
	EventBus.stage_changed.emit(get_current_stage(), StageData.get_display_name(get_current_stage(), get_current_difficulty()))

func get_save_state() -> Dictionary:
	return state.duplicate(true)

func get_gold() -> int:
	return int(state.get("gold", 0))

func add_gold(amount: int) -> int:
	state["gold"] = maxi(0, get_gold() + amount)
	gold_changed.emit(get_gold())
	EventBus.gold_changed.emit(get_gold())
	_notify_state_changed()
	return get_gold()

func get_current_stage() -> int:
	return clampi(int(state.get("current_stage", 0)), 0, StageData.get_stage_count() - 1)

func get_unlocked_stage() -> int:
	var progress: Dictionary = state.get("difficulty_progress", {})
	return clampi(int(progress.get(get_current_difficulty(), state.get("unlocked_stage", 0))), 0, StageData.get_stage_count() - 1)

func set_current_stage(stage_index: int) -> void:
	var safe_stage: int = clampi(stage_index, 0, get_unlocked_stage())
	state["current_stage"] = safe_stage
	stage_changed.emit(safe_stage, StageData.get_display_name(safe_stage, get_current_difficulty()))
	EventBus.stage_changed.emit(safe_stage, StageData.get_display_name(safe_stage, get_current_difficulty()))
	_notify_state_changed()

func unlock_stage(stage_index: int) -> void:
	var difficulty_id: String = get_current_difficulty()
	var progress: Dictionary = state.get("difficulty_progress", {})
	progress[difficulty_id] = clampi(maxi(int(progress.get(difficulty_id, 0)), stage_index), 0, StageData.get_stage_count() - 1)
	state["difficulty_progress"] = progress
	state["unlocked_stage"] = int(progress[difficulty_id])
	if stage_index >= Difficulty.FINAL_STAGE_INDEX:
		var unlocked: Array = Difficulty.unlock_after_stage(difficulty_id, stage_index, get_unlocked_difficulties())
		state["unlocked_difficulties"] = unlocked
		var cleared: Array = state.get("cleared_difficulties", [])
		if not cleared.has(difficulty_id):
			cleared.append(difficulty_id)
		state["cleared_difficulties"] = cleared
	_notify_state_changed()

func get_current_difficulty() -> String:
	var difficulty_id: String = str(state.get("difficulty", "normal"))
	return difficulty_id if DifficultyData.get_difficulty_ids().has(difficulty_id) else "normal"

func get_difficulty_definition(difficulty_id: String = "") -> Dictionary:
	var safe_id: String = difficulty_id if not difficulty_id.is_empty() else get_current_difficulty()
	return DifficultyData.get_difficulty_definition(safe_id)

func get_unlocked_difficulties() -> Array:
	var result: Array = []
	var source: Variant = state.get("unlocked_difficulties", ["normal"])
	if source is Array:
		for raw_id: Variant in source:
			var difficulty_id: String = str(raw_id)
			if DifficultyData.get_difficulty_ids().has(difficulty_id) and not result.has(difficulty_id):
				result.append(difficulty_id)
	if not result.has("normal"):
		result.append("normal")
	return result

func is_difficulty_unlocked(difficulty_id: String) -> bool:
	return Difficulty.is_unlocked(difficulty_id, get_unlocked_difficulties())

func set_difficulty(difficulty_id: String) -> bool:
	if not is_difficulty_unlocked(difficulty_id):
		return false
	state["difficulty"] = difficulty_id
	var progress: Dictionary = state.get("difficulty_progress", {})
	state["current_stage"] = clampi(int(progress.get(difficulty_id, 0)), 0, StageData.get_stage_count() - 1)
	state["unlocked_stage"] = int(progress.get(difficulty_id, 0))
	var current_stage: int = get_current_stage()
	stage_changed.emit(current_stage, StageData.get_display_name(current_stage, difficulty_id))
	EventBus.stage_changed.emit(current_stage, StageData.get_display_name(current_stage, difficulty_id))
	_notify_state_changed()
	EventBus.difficulty_changed.emit(difficulty_id)
	return true

func get_setting(key: String, default_value: Variant = null) -> Variant:
	var settings: Dictionary = state.get("settings", {})
	return settings.get(key, default_value)

func set_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = state.get("settings", {})
	settings[key] = value
	state["settings"] = settings
	if key == "master_volume":
		var volume: float = clampf(float(value), 0.0, 1.0)
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	setting_changed.emit(key, value)
	EventBus.setting_changed.emit(key, value)
	_notify_state_changed()

func reset_state() -> void:
	state = SaveCodec.make_default_state()
	_offline_summary = {}
	_sync_rune_effects()
	AudioServer.set_bus_volume_db(0, linear_to_db(0.8))
	_notify_state_changed()
	EventBus.reset_completed.emit()

func get_party() -> Array:
	var party_value: Variant = state.get("party", [])
	if party_value is Array:
		return party_value.duplicate(true)
	return []

func get_active_heroes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var party: Array = get_party()
	for hero_value: Variant in party:
		if hero_value is Dictionary:
			var hero: Dictionary = hero_value
			if not str(hero.get("class_id", "")).is_empty():
				result.append(hero.duplicate(true))
	return result

func get_hero(class_id: String) -> Dictionary:
	for hero: Dictionary in get_active_heroes():
		if str(hero.get("class_id", "")) == class_id:
			return hero
	return {}

func get_hero_level(class_id: String) -> int:
	var hero: Dictionary = get_hero(class_id)
	return int(hero.get("level", 1))

func get_hero_stats(class_id: String) -> Dictionary:
	var hero: Dictionary = get_hero(class_id)
	return Stats.calculate_final_stats(class_id, int(hero.get("level", 1)), get_equipment(class_id), get_skill_state(class_id), get_rune_state())

func get_hero_power(class_id: String) -> int:
	return Power.calculate(get_hero_stats(class_id))

func get_equipment(class_id: String) -> Dictionary:
	var hero: Dictionary = get_hero(class_id)
	var equipment_value: Variant = hero.get("equipment", {})
	if equipment_value is Dictionary:
		return (equipment_value as Dictionary).duplicate(true)
	return {}

func get_skill_state(class_id: String) -> Dictionary:
	var hero: Dictionary = get_hero(class_id)
	var skill_value: Variant = hero.get("skills", {})
	return Skills.normalize_skill_state(skill_value if skill_value is Dictionary else {}, class_id)

func get_skill_points(class_id: String) -> int:
	var hero: Dictionary = get_hero(class_id)
	return Skills.get_available_points(int(hero.get("level", 1)), get_skill_state(class_id))

func upgrade_skill(class_id: String, skill_id: String, amount: int = 1) -> Dictionary:
	var hero: Dictionary = get_hero(class_id)
	if hero.is_empty():
		return {"ok": false, "reason": "missing_hero"}
	var result: Dictionary = Skills.upgrade_skill(get_skill_state(class_id), int(hero.get("level", 1)), skill_id, amount)
	if bool(result.get("ok", false)):
		hero["skills"] = result["state"]
		_update_party_hero(hero)
		_notify_state_changed()
		EventBus.equipment_changed.emit(class_id)
		EventBus.skills_changed.emit(class_id)
	return result

func equip_active_skill(class_id: String, skill_id: String, slot_index: int) -> Dictionary:
	var hero: Dictionary = get_hero(class_id)
	if hero.is_empty():
		return {"ok": false, "reason": "missing_hero"}
	var result: Dictionary = Skills.equip_active_skill(get_skill_state(class_id), skill_id, slot_index)
	if bool(result.get("ok", false)):
		hero["skills"] = result["state"]
		_update_party_hero(hero)
		_notify_state_changed()
		EventBus.equipment_changed.emit(class_id)
		EventBus.skills_changed.emit(class_id)
	return result

func get_equipped_active_skills(class_id: String) -> Array[String]:
	return Skills.get_equipped_active_ids(get_skill_state(class_id))

func get_highest_party_level() -> int:
	var highest: int = 1
	for hero: Dictionary in get_active_heroes():
		highest = maxi(highest, int(hero.get("level", 1)))
	return highest

func get_lead_level() -> int:
	var party: Array = get_party()
	if party.is_empty():
		return 1
	var lead_value: Variant = party[0]
	if lead_value is Dictionary:
		return int(lead_value.get("level", 1))
	return 1

func get_stage_level_requirement(stage_index: int, difficulty_id: String = "") -> int:
	var safe_difficulty_id: String = difficulty_id if not difficulty_id.is_empty() else get_current_difficulty()
	return StageData.get_required_level(stage_index, safe_difficulty_id)

func is_stage_level_ready(stage_index: int, difficulty_id: String = "") -> bool:
	return get_lead_level() >= get_stage_level_requirement(stage_index, difficulty_id)

func get_stage_level_gate_text(stage_index: int, difficulty_id: String = "") -> String:
	var safe_difficulty_id: String = difficulty_id if not difficulty_id.is_empty() else get_current_difficulty()
	return "等級不足：需 Lv.%d（目前 Lv.%d）" % [get_stage_level_requirement(stage_index, safe_difficulty_id), get_lead_level()]

func get_unlocked_party_slots() -> int:
	var stored_unlocked: int = clampi(int(state.get("unlocked_party_slots", 1)), 1, 3)
	var lead_level: int = get_lead_level()
	var level_unlocked: int = 1
	if lead_level >= 15:
		level_unlocked = 3
	elif lead_level >= 5:
		level_unlocked = 2
	var result: int = maxi(stored_unlocked, level_unlocked)
	if result != stored_unlocked:
		state["unlocked_party_slots"] = result
	return result

func is_party_slot_unlocked(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < get_unlocked_party_slots()

func set_party_slot(slot_index: int, class_id: String) -> bool:
	if not is_party_slot_unlocked(slot_index) or ClassData.get_class_definition(class_id).is_empty():
		return false
	var party: Array = get_party()
	for index: int in range(party.size()):
		if index == slot_index:
			continue
		var hero_value: Variant = party[index]
		if hero_value is Dictionary and str(hero_value.get("class_id", "")) == class_id:
			return false
	while party.size() < 3:
		party.append(null)
	party[slot_index] = _make_hero_state(class_id)
	state["party"] = party
	_notify_state_changed()
	EventBus.equipment_changed.emit(class_id)
	return true

func add_hero_xp(class_id: String, amount: int) -> Dictionary:
	var hero: Dictionary = get_hero(class_id)
	if hero.is_empty():
		return {"level": 0, "xp": 0, "levels_gained": 0}
	var result: Dictionary = XPCurve.apply_xp(int(hero.get("level", 1)), int(hero.get("xp", 0)), amount)
	hero["level"] = int(result["level"])
	hero["xp"] = int(result["xp"])
	_update_party_hero(hero)
	hero_xp_changed.emit(class_id, int(hero["level"]), int(hero["xp"]))
	EventBus.hero_xp_changed.emit(class_id, int(hero["level"]), int(hero["xp"]))
	if int(result["levels_gained"]) > 0:
		hero_leveled_up.emit(class_id, int(hero["level"]))
		EventBus.hero_leveled_up.emit(class_id, int(hero["level"]))
	_notify_state_changed()
	return result

func grant_monster_rewards(monster_level: int, is_boss: bool = false) -> Dictionary:
	var reward: Dictionary = Rewards.calculate_rewards(monster_level, is_boss)
	var gold_multiplier: float = 1.0
	for hero: Dictionary in get_active_heroes():
		var hero_stats: Dictionary = get_hero_stats(str(hero.get("class_id", "")))
		gold_multiplier = maxf(gold_multiplier, 1.0 + float(hero_stats.get("gold_gain", 0.0)))
	var granted_gold: int = maxi(1, int(round(float(reward.get("gold", 0)) * gold_multiplier)))
	add_gold(granted_gold)
	var total_xp: int = 0
	var multiplier: float = 5.0 if is_boss else 1.0
	for hero: Dictionary in get_active_heroes():
		var class_id: String = str(hero.get("class_id", ""))
		var hero_stats: Dictionary = get_hero_stats(class_id)
		var xp_multiplier: float = multiplier * (1.0 + float(hero_stats.get("xp_gain", 0.0)))
		var amount: int = XPCurve.experience_reward(monster_level, int(hero.get("level", 1)), xp_multiplier)
		add_hero_xp(class_id, amount)
		total_xp += amount
	return {"gold": granted_gold, "xp": total_xp, "is_boss": is_boss}

func get_inventory() -> Dictionary:
	var inventory: Dictionary = state.get("inventory", Inventory.create_inventory()) as Dictionary
	Inventory.ensure_pages(inventory, Runes.get_inventory_pages(get_rune_state()))
	state["inventory"] = inventory
	return inventory.duplicate(true)

func get_inventory_item(slot_index: int) -> Dictionary:
	return Inventory.get_item_at(get_inventory(), slot_index)

func add_item(item: Dictionary) -> Dictionary:
	var inventory: Dictionary = get_inventory()
	var result: Dictionary = Inventory.add_item(inventory, item, bool(get_setting("auto_sell_common", false)), bool(get_setting("auto_sell_uncommon", false)))
	state["inventory"] = inventory
	if bool(result.get("converted_to_gold", false)):
		add_gold(int(result.get("gold", 0)))
	_notify_state_changed()
	EventBus.inventory_changed.emit()
	return result

func equip_item(class_id: String, inventory_index: int) -> Dictionary:
	var item: Dictionary = get_inventory_item(inventory_index)
	if item.is_empty() or not ItemData.can_equip_item(item, class_id):
		return {"equipped": false, "reason": "incompatible"}
	var hero: Dictionary = get_hero(class_id)
	if hero.is_empty():
		return {"equipped": false, "reason": "missing_hero"}
	var slot_id: String = str(item.get("slot", ""))
	var inventory: Dictionary = get_inventory()
	var removed: Dictionary = Inventory.remove_item(inventory, inventory_index)
	if not bool(removed.get("removed", false)):
		return {"equipped": false, "reason": "missing_item"}
	var equipment: Dictionary = get_equipment(class_id)
	var old_item_value: Variant = equipment.get(slot_id, null)
	if old_item_value is Dictionary:
		var old_result: Dictionary = Inventory.add_item(inventory, old_item_value, bool(get_setting("auto_sell_common", false)), bool(get_setting("auto_sell_uncommon", false)))
		if bool(old_result.get("converted_to_gold", false)):
			add_gold(int(old_result.get("gold", 0)))
	equipment[slot_id] = item.duplicate(true)
	hero["equipment"] = equipment
	state["inventory"] = inventory
	_update_party_hero(hero)
	_notify_state_changed()
	EventBus.inventory_changed.emit()
	EventBus.equipment_changed.emit(class_id)
	return {"equipped": true, "slot": slot_id, "item": item.duplicate(true)}

func unequip_item(class_id: String, slot_id: String) -> Dictionary:
	var hero: Dictionary = get_hero(class_id)
	if hero.is_empty() or not ItemData.get_slot_ids().has(slot_id):
		return {"removed": false, "reason": "invalid_slot"}
	var equipment: Dictionary = get_equipment(class_id)
	var item_value: Variant = equipment.get(slot_id, null)
	if not (item_value is Dictionary):
		return {"removed": false, "reason": "empty_slot"}
	var item: Dictionary = item_value
	equipment[slot_id] = null
	hero["equipment"] = equipment
	_update_party_hero(hero)
	var inventory: Dictionary = get_inventory()
	var add_result: Dictionary = Inventory.add_item(inventory, item, bool(get_setting("auto_sell_common", false)), bool(get_setting("auto_sell_uncommon", false)))
	state["inventory"] = inventory
	if bool(add_result.get("converted_to_gold", false)):
		add_gold(int(add_result.get("gold", 0)))
	_notify_state_changed()
	EventBus.inventory_changed.emit()
	EventBus.equipment_changed.emit(class_id)
	return {"removed": true, "item": item, "converted_to_gold": bool(add_result.get("converted_to_gold", false)), "gold": int(add_result.get("gold", 0))}

func sell_inventory_item(slot_index: int) -> Dictionary:
	var inventory: Dictionary = get_inventory()
	var result: Dictionary = Inventory.sell_item(inventory, slot_index)
	state["inventory"] = inventory
	if bool(result.get("removed", false)):
		add_gold(int(result.get("gold", 0)))
		_notify_state_changed()
		EventBus.inventory_changed.emit()
	return result

func sell_items_by_rarity(rarity: String) -> Dictionary:
	var inventory: Dictionary = get_inventory()
	var result: Dictionary = Inventory.sell_by_rarity(inventory, rarity)
	state["inventory"] = inventory
	if int(result.get("sold_count", 0)) > 0:
		add_gold(int(result.get("gold", 0)))
		_notify_state_changed()
		EventBus.inventory_changed.emit()
	return result

func get_chest_state() -> Dictionary:
	var chest_state: Dictionary = state.get("chests", Chests.create_state()) as Dictionary
	Chests.set_rune_effects(chest_state, Runes.get_white_chest_rate(get_rune_state()), Runes.get_chest_capacity(get_rune_state()), Runes.get_boss_chest_quality(get_rune_state()))
	state["chests"] = chest_state
	return chest_state.duplicate(true)

func get_chest_counts() -> Dictionary:
	return Chests.get_counts(get_chest_state())

func get_soul_stones() -> int:
	return maxi(0, int(state.get("soul_stones", 0)))

func get_materials() -> Dictionary:
	return Materials.normalize_state(state.get("materials", Materials.create_state()))

func get_material_count(material_id: String) -> int:
	return Materials.get_count(get_materials(), material_id)

func add_material(material: Variant, count: int = 1) -> Dictionary:
	var materials: Dictionary = get_materials()
	var result: Dictionary = Materials.add_material(materials, material, count)
	state["materials"] = materials
	if bool(result.get("ok", false)):
		_notify_state_changed()
		EventBus.inventory_changed.emit()
	return result

func socket_inventory_material(inventory_index: int, socket_index: int, material_id: String) -> Dictionary:
	var inventory: Dictionary = get_inventory()
	var item: Dictionary = Inventory.get_item_at(inventory, inventory_index)
	if item.is_empty():
		return {"ok": false, "reason": "missing_item"}
	var materials: Dictionary = get_materials()
	if Materials.get_count(materials, material_id) <= 0:
		return {"ok": false, "reason": "missing_material"}
	var result: Dictionary = Socketing.socket_material(item, socket_index, Materials.get_stack(materials, material_id))
	if not bool(result.get("ok", false)):
		return result
	var removed: Dictionary = Materials.remove_material(materials, material_id, 1)
	if not bool(removed.get("ok", false)):
		return {"ok": false, "reason": "missing_material"}
	var slots: Array = inventory.get("slots", [])
	slots[inventory_index] = result.get("item", item)
	state["inventory"] = inventory
	state["materials"] = materials
	_notify_state_changed()
	EventBus.inventory_changed.emit()
	return {"ok": true, "item": result.get("item", {}), "material_id": material_id, "reason": "socketed"}

func unsocket_inventory_material(inventory_index: int, socket_index: int) -> Dictionary:
	var inventory: Dictionary = get_inventory()
	var item: Dictionary = Inventory.get_item_at(inventory, inventory_index)
	if item.is_empty():
		return {"ok": false, "reason": "missing_item"}
	var result: Dictionary = Socketing.unsocket_material(item, socket_index)
	if not bool(result.get("ok", false)):
		return result
	var materials: Dictionary = get_materials()
	Materials.add_material(materials, result.get("material", {}))
	var slots: Array = inventory.get("slots", [])
	slots[inventory_index] = result.get("item", item)
	state["inventory"] = inventory
	state["materials"] = materials
	_notify_state_changed()
	EventBus.inventory_changed.emit()
	return {"ok": true, "item": result.get("item", {}), "material": result.get("material", {}), "reason": "unsocketed"}

func socket_equipment_material(class_id: String, slot_id: String, socket_index: int, material_id: String) -> Dictionary:
	var hero: Dictionary = get_hero(class_id)
	var equipment: Dictionary = get_equipment(class_id)
	var item_value: Variant = equipment.get(slot_id, null)
	if hero.is_empty() or not (item_value is Dictionary):
		return {"ok": false, "reason": "missing_item"}
	var materials: Dictionary = get_materials()
	if Materials.get_count(materials, material_id) <= 0:
		return {"ok": false, "reason": "missing_material"}
	var result: Dictionary = Socketing.socket_material(item_value as Dictionary, socket_index, Materials.get_stack(materials, material_id))
	if not bool(result.get("ok", false)):
		return result
	if not bool(Materials.remove_material(materials, material_id, 1).get("ok", false)):
		return {"ok": false, "reason": "missing_material"}
	equipment[slot_id] = result.get("item", {})
	hero["equipment"] = equipment
	_update_party_hero(hero)
	state["materials"] = materials
	_notify_state_changed()
	EventBus.equipment_changed.emit(class_id)
	return result

func unsocket_equipment_material(class_id: String, slot_id: String, socket_index: int) -> Dictionary:
	var hero: Dictionary = get_hero(class_id)
	var equipment: Dictionary = get_equipment(class_id)
	var item_value: Variant = equipment.get(slot_id, null)
	if hero.is_empty() or not (item_value is Dictionary):
		return {"ok": false, "reason": "missing_item"}
	var result: Dictionary = Socketing.unsocket_material(item_value as Dictionary, socket_index)
	if not bool(result.get("ok", false)):
		return result
	equipment[slot_id] = result.get("item", {})
	hero["equipment"] = equipment
	_update_party_hero(hero)
	var materials: Dictionary = get_materials()
	Materials.add_material(materials, result.get("material", {}))
	state["materials"] = materials
	_notify_state_changed()
	EventBus.equipment_changed.emit(class_id)
	return result

func get_cube_state() -> Dictionary:
	return Cube.normalize_state(state.get("cube", Cube.create_state()))

func get_cube_preview(items: Array) -> Dictionary:
	return Cube.preview(get_cube_state(), items, _rng)

func combine_cube_items(inventory_indices: Array) -> Dictionary:
	var inventory: Dictionary = get_inventory()
	var unique_indices: Array[int] = []
	var items: Array = []
	for raw_index: Variant in inventory_indices:
		var index: int = int(raw_index)
		if unique_indices.has(index):
			continue
		unique_indices.append(index)
		var item: Dictionary = Inventory.get_item_at(inventory, index)
		if not item.is_empty():
			items.append(item)
	var result: Dictionary = Cube.combine_items(get_cube_state(), items, _rng)
	if not bool(result.get("ok", false)):
		return result
	for index: int in unique_indices:
		var slots: Array = inventory.get("slots", [])
		if index >= 0 and index < slots.size():
			slots[index] = null
	var add_result: Dictionary = Inventory.add_item(inventory, result.get("item", {}), bool(get_setting("auto_sell_common", false)), bool(get_setting("auto_sell_uncommon", false)))
	state["inventory"] = inventory
	state["cube"] = result.get("state", get_cube_state())
	if bool(add_result.get("converted_to_gold", false)):
		add_gold(int(add_result.get("gold", 0)))
	elif not bool(add_result.get("stored", false)):
		return {"ok": false, "reason": "output_inventory_full", "state": result.get("state", {}), "item": {}}
	_notify_state_changed()
	EventBus.inventory_changed.emit()
	return result

func combine_cube_material(material_id: String) -> Dictionary:
	var materials: Dictionary = get_materials()
	var result: Dictionary = Cube.combine_materials(materials, get_cube_state(), material_id, _rng)
	if bool(result.get("ok", false)):
		state["materials"] = result.get("state", materials)
		_notify_state_changed()
		EventBus.inventory_changed.emit()
	return result

func get_rune_state() -> Dictionary:
	return Runes.normalize_state(state.get("runes", Runes.create_state()))

func get_rune_level(rune_id: String) -> int:
	return Runes.get_level(get_rune_state(), rune_id)

func get_rune_modifiers() -> Dictionary:
	return Runes.get_modifiers(get_rune_state())

func get_inventory_page_count() -> int:
	return Runes.get_inventory_pages(get_rune_state())

func purchase_rune(rune_id: String) -> Dictionary:
	var result: Dictionary = Runes.purchase(get_rune_state(), rune_id, get_gold())
	if not bool(result.get("ok", false)):
		return result
	var cost: int = int(result.get("cost", 0))
	state["runes"] = result.get("state", get_rune_state())
	add_gold(-cost)
	_sync_rune_effects()
	_notify_state_changed()
	EventBus.runes_changed.emit()
	return result

func get_stage_requirement(stage_index: int) -> Dictionary:
	var difficulty_id: String = get_current_difficulty()
	var is_act_boss: bool = SoulStones.is_act_boss_stage(stage_index)
	var text: String = SoulStones.get_requirement_text(state, difficulty_id, stage_index)
	return {"is_act_boss": is_act_boss, "can_enter": is_act_boss == false or SoulStones.can_pay(state, difficulty_id, stage_index), "text": text, "fallback_stage": SoulStones.get_fallback_stage(stage_index)}

func admit_stage(stage_index: int) -> Dictionary:
	var requirement: Dictionary = get_stage_requirement(stage_index)
	if not bool(requirement.get("can_enter", false)):
		return {"ok": false, "reason": "needs_soul_stone", "fallback_stage": int(requirement.get("fallback_stage", stage_index)), "text": "需要靈魂石"}
	var payment: Dictionary = SoulStones.pay_for_stage(state, get_current_difficulty(), stage_index)
	if not bool(payment.get("ok", false)):
		return {"ok": false, "reason": "needs_soul_stone", "fallback_stage": int(requirement.get("fallback_stage", stage_index)), "text": "需要靈魂石"}
	state = payment.get("state", state)
	_sync_rune_effects()
	_notify_state_changed()
	return {"ok": true, "paid": bool(payment.get("paid", false)), "already_paid": bool(payment.get("already_paid", false)), "text": str(requirement.get("text", ""))}

func mark_act_boss_cleared(stage_index: int) -> void:
	state = SoulStones.clear_paid(state, get_current_difficulty(), stage_index)
	_notify_state_changed()

func get_offline_summary() -> Dictionary:
	return _offline_summary.duplicate(true)

func apply_offline_progress(summary: Dictionary) -> Dictionary:
	state = Offline.apply_to_state(state, summary)
	_offline_summary = summary.duplicate(true)
	_sync_rune_effects()
	_notify_state_changed()
	EventBus.offline_progress.emit(_offline_summary)
	return state

func debug_apply_offline_preview(seconds_ago: int) -> Dictionary:
	var now: int = int(Time.get_unix_time_from_system())
	state["last_saved_unix"] = maxi(0, now - maxi(0, seconds_ago))
	var summary: Dictionary = Offline.calculate(state, now)
	apply_offline_progress(summary)
	return summary

func _sync_rune_effects() -> void:
	var rune_state: Dictionary = get_rune_state()
	var inventory: Dictionary = state.get("inventory", Inventory.create_inventory()) as Dictionary
	Inventory.ensure_pages(inventory, Runes.get_inventory_pages(rune_state))
	state["inventory"] = inventory
	var chest_state: Dictionary = state.get("chests", Chests.create_state()) as Dictionary
	Chests.set_rune_effects(chest_state, Runes.get_white_chest_rate(rune_state), Runes.get_chest_capacity(rune_state), Runes.get_boss_chest_quality(rune_state))
	state["chests"] = chest_state

func set_auto_open(chest_type: String, enabled: bool) -> void:
	var chests: Dictionary = get_chest_state()
	Chests.set_auto_open(chests, chest_type, enabled)
	state["chests"] = chests
	var setting_key: String = "auto_open_%s" % chest_type
	set_setting(setting_key, enabled)
	_notify_state_changed()

func try_drop_chest(monster_level: int, is_stage_boss: bool, is_act_boss: bool) -> Dictionary:
	var chests: Dictionary = get_chest_state()
	var result: Dictionary = Chests.try_drop_for_kill(chests, monster_level, is_stage_boss, is_act_boss, _rng)
	state["chests"] = chests
	if bool(result.get("dropped", false)):
		var chest_values: Array = result.get("chests", [])
		for chest_value: Variant in chest_values:
			if chest_value is Dictionary:
				EventBus.chest_dropped.emit(str(chest_value.get("type", "white")), int(chest_value.get("level", monster_level)))
		open_auto_chests()
		EventBus.chest_changed.emit()
	_notify_state_changed()
	return result

func open_chest(queue_index: int) -> Dictionary:
	var chests: Dictionary = get_chest_state()
	var result: Dictionary = Chests.open_chest(chests, queue_index, _rng)
	state["chests"] = chests
	if not bool(result.get("opened", false)):
		return result
	var items: Array = result.get("items", [])
	for item_value: Variant in items:
		if item_value is Dictionary:
			var item: Dictionary = item_value
			add_item(item)
			var rarity_index: int = ItemData.get_rarity_ids().find(str(item.get("rarity", "common")))
			if rarity_index >= ItemData.get_rarity_ids().find("epic"):
				EventBus.rare_drop.emit(item)
	var materials: Array = result.get("materials", [])
	for material_value: Variant in materials:
		if material_value is Dictionary:
			add_material(material_value)
	if int(result.get("gold", 0)) > 0:
		add_gold(int(result.get("gold", 0)))
	if int(result.get("soul_stones", 0)) > 0:
		state["soul_stones"] = get_soul_stones() + int(result.get("soul_stones", 0))
	_notify_state_changed()
	EventBus.inventory_changed.emit()
	EventBus.chest_opened.emit(result)
	EventBus.chest_changed.emit()
	return result

func open_next_chest() -> Dictionary:
	var chests: Dictionary = get_chest_state()
	var queue: Array = chests.get("queue", [])
	if queue.is_empty():
		return {"opened": false, "reason": "empty_queue"}
	return open_chest(0)

func open_auto_chests() -> void:
	var chests: Dictionary = get_chest_state()
	var queue: Array[Dictionary] = Chests.get_queue(chests)
	var opened_any: bool = true
	var attempts: int = 0
	while opened_any and attempts < 256:
		attempts += 1
		opened_any = false
		queue = Chests.get_queue(chests)
		for index: int in range(queue.size()):
			var chest_type: String = str(queue[index].get("type", "white"))
			if Chests.is_auto_open_enabled(chests, chest_type):
				var result: Dictionary = open_chest(index)
				if bool(result.get("opened", false)):
					opened_any = true
				break
		chests = get_chest_state()

func seed_debug_loot() -> void:
	var debug_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	debug_rng.seed = 424242
	var generated: Array[Dictionary] = [
		ItemGen.generate_item(5, debug_rng, "rare", "knight", "weapon"),
		ItemGen.generate_item(6, debug_rng, "epic", "knight", "chest"),
		ItemGen.generate_item(4, debug_rng, "uncommon", "knight", "ring"),
		ItemGen.generate_item(7, debug_rng, "legendary", "", "helmet"),
		ItemGen.generate_item(8, debug_rng, "rare", "", "boots"),
		ItemGen.generate_item(9, debug_rng, "immortal", "", "gloves"),
		ItemGen.generate_item(10, debug_rng, "common", "", "amulet")
	]
	var inventory: Dictionary = get_inventory()
	for item: Dictionary in generated:
		Inventory.add_item(inventory, item)
	state["inventory"] = inventory
	var hero: Dictionary = get_hero("knight")
	if not hero.is_empty():
		var equipment: Dictionary = get_equipment("knight")
		equipment["weapon"] = generated[0].duplicate(true)
		equipment["chest"] = generated[1].duplicate(true)
		equipment["ring"] = generated[2].duplicate(true)
		hero["equipment"] = equipment
		_update_party_hero(hero)
	var chest_state: Dictionary = Chests.create_state()
	chest_state["queue"] = [
		{"type": "white", "level": 5, "id": "debug_white"},
		{"type": "blue", "level": 10, "id": "debug_blue"},
		{"type": "act_boss", "level": 10, "id": "debug_act"}
	]
	state["chests"] = chest_state
	state["soul_stones"] = 2
	add_gold(2500)
	_notify_state_changed()
	EventBus.inventory_changed.emit()
	EventBus.chest_changed.emit()

func seed_debug_cube() -> void:
	var debug_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	debug_rng.seed = 424243
	var inventory: Dictionary = get_inventory()
	for index: int in range(3):
		Inventory.add_item(inventory, ItemGen.generate_item(8 + index, debug_rng, "rare", "knight", "weapon"))
	state["inventory"] = inventory
	var materials: Dictionary = get_materials()
	Materials.add_material(materials, Materials.make_material("strength_rune", 8), 3)
	state["materials"] = materials
	state["cube"] = Cube.create_state()
	_notify_state_changed()
	EventBus.inventory_changed.emit()

func seed_debug_sockets() -> void:
	var debug_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	debug_rng.seed = 424244
	state["inventory"] = Inventory.create_inventory()
	var item: Dictionary = ItemGen.generate_item(12, debug_rng, "rare", "knight", "weapon")
	var materials: Dictionary = Materials.create_state()
	var material: Dictionary = Materials.make_material("ruby", 12, "rare")
	Materials.add_material(materials, material, 3)
	var socket_result: Dictionary = Socketing.socket_material(item, 0, material)
	if bool(socket_result.get("ok", false)):
		Materials.remove_material(materials, "ruby", 1)
		var inventory: Dictionary = get_inventory()
		var slots: Array = inventory.get("slots", [])
		slots[0] = socket_result.get("item", item)
		inventory["slots"] = slots
		state["inventory"] = inventory
	state["materials"] = materials
	_notify_state_changed()
	EventBus.inventory_changed.emit()

func seed_debug_act_boss() -> void:
	state["difficulty"] = "normal"
	state["current_stage"] = 9
	state["unlocked_stage"] = 9
	state["difficulty_progress"] = {"normal": 9, "nightmare": 0, "hell": 0, "torture": 0}
	state["soul_stones"] = 0
	state["paid_act_bosses"] = {}
	_notify_state_changed()

func debug_emit_rare_drop() -> void:
	var debug_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	debug_rng.seed = 424245
	EventBus.rare_drop.emit(ItemGen.generate_item(18, debug_rng, "epic", "knight", "weapon"))

func seed_debug_runes() -> void:
	var levels: Dictionary = {}
	for rune_id: String in RuneData.get_rune_ids():
		levels[rune_id] = 2
	state["runes"] = Runes.normalize_state({"levels": levels})
	state["gold"] = maxi(get_gold(), 5000)
	_sync_rune_effects()
	_notify_state_changed()
	EventBus.runes_changed.emit()

func seed_debug_skills() -> void:
	var hero: Dictionary = get_hero("knight")
	if hero.is_empty():
		return
	hero["level"] = 5
	var skill_state: Dictionary = Skills.make_skill_state("knight")
	var skill_levels: Dictionary = skill_state["skill_levels"]
	var active_ids: Array[String] = SkillData.get_active_skill_ids("knight")
	var passive_ids: Array[String] = SkillData.get_passive_skill_ids("knight")
	if not active_ids.is_empty():
		skill_levels[active_ids[0]] = 2
	if active_ids.size() > 1:
		skill_levels[active_ids[1]] = 2
	if not passive_ids.is_empty():
		skill_levels[passive_ids[0]] = 1
	skill_state["skill_levels"] = skill_levels
	skill_state["equipped_actives"] = active_ids.slice(0, 2)
	hero["skills"] = Skills.normalize_skill_state(skill_state, "knight")
	_update_party_hero(hero)
	_notify_state_changed()
	EventBus.skills_changed.emit("knight")

func set_last_saved_unix(unix_time: int) -> void:
	state["last_saved_unix"] = maxi(0, unix_time)

func _notify_state_changed() -> void:
	state_changed.emit()
	EventBus.state_changed.emit()

func get_rng() -> RandomNumberGenerator:
	return _rng

func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value

func _make_hero_state(class_id: String) -> Dictionary:
	var equipment: Dictionary = {}
	for slot_id: String in ItemData.get_slot_ids():
		equipment[slot_id] = null
	return {"class_id": class_id, "level": 1, "xp": 0, "equipment": equipment, "skills": Skills.make_skill_state(class_id)}

func _update_party_hero(hero: Dictionary) -> void:
	var party: Array = get_party()
	for index: int in range(party.size()):
		var hero_value: Variant = party[index]
		if hero_value is Dictionary and str(hero_value.get("class_id", "")) == str(hero.get("class_id", "")):
			party[index] = hero.duplicate(true)
			break
	state["party"] = party
