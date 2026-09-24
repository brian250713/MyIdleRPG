class_name Runes
extends RefCounted

const DEFAULT_INVENTORY_PAGES: int = 1
const MAX_INVENTORY_PAGES: int = 5
const BASE_CHEST_CAPACITY: int = Chests.WHITE_QUEUE_CAPACITY

static func create_state() -> Dictionary:
	return {"levels": {}}

static func normalize_state(source: Dictionary) -> Dictionary:
	var normalized: Dictionary = create_state()
	var levels: Dictionary = normalized["levels"]
	var source_levels: Variant = source.get("levels", source)
	if source_levels is Dictionary:
		for raw_id: Variant in (source_levels as Dictionary).keys():
			var rune_id: String = str(raw_id)
			var definition: Dictionary = RuneData.get_rune_definition(rune_id)
			if definition.is_empty():
				continue
			levels[rune_id] = clampi(int((source_levels as Dictionary).get(raw_id, 0)), 0, int(definition.get("max_level", 10)))
	return normalized

static func get_level(state: Dictionary, rune_id: String) -> int:
	var definition: Dictionary = RuneData.get_rune_definition(rune_id)
	if definition.is_empty():
		return 0
	var levels: Dictionary = state.get("levels", {})
	return clampi(int(levels.get(rune_id, 0)), 0, int(definition.get("max_level", 10)))

static func get_next_cost(state: Dictionary, rune_id: String) -> int:
	var definition: Dictionary = RuneData.get_rune_definition(rune_id)
	if definition.is_empty():
		return -1
	var level: int = get_level(state, rune_id)
	if level >= int(definition.get("max_level", 10)):
		return -1
	return int(round(float(definition.get("base_cost", 100)) * pow(1.6, float(level))))

static func get_total_invested(state: Dictionary) -> int:
	var total: int = 0
	for rune_id: String in RuneData.get_rune_ids():
		var level: int = get_level(state, rune_id)
		var definition: Dictionary = RuneData.get_rune_definition(rune_id)
		var base_cost: float = float(definition.get("base_cost", 0.0))
		for level_index: int in range(level):
			total += int(round(base_cost * pow(1.6, float(level_index))))
	return total

static func get_modifiers(state: Dictionary) -> Dictionary:
	var modifiers: Dictionary = {
		"gold_gain": 0.0,
		"xp_gain": 0.0,
		"white_chest_rate": 0.0,
		"boss_chest_quality": 0.0,
		"party_attack": 0.0,
		"party_hp": 0.0,
		"all_resistance": 0.0,
		"inventory_pages": 0,
		"chest_capacity": 0
	}
	for rune_id: String in RuneData.get_rune_ids():
		var definition: Dictionary = RuneData.get_rune_definition(rune_id)
		var level: int = get_level(state, rune_id)
		var effect_id: String = str(definition.get("effect", rune_id))
		var value: float = float(definition.get("value", 0.0)) * float(level)
		modifiers[effect_id] = float(modifiers.get(effect_id, 0.0)) + value
	return modifiers

static func get_reward_multipliers(state: Dictionary) -> Dictionary:
	var modifiers: Dictionary = get_modifiers(state)
	return {
		"gold": 1.0 + float(modifiers.get("gold_gain", 0.0)),
		"xp": 1.0 + float(modifiers.get("xp_gain", 0.0))
	}

static func get_inventory_pages(state: Dictionary) -> int:
	var modifiers: Dictionary = get_modifiers(state)
	return clampi(DEFAULT_INVENTORY_PAGES + int(modifiers.get("inventory_pages", 0)), DEFAULT_INVENTORY_PAGES, MAX_INVENTORY_PAGES)

static func get_chest_capacity(state: Dictionary) -> int:
	var modifiers: Dictionary = get_modifiers(state)
	return BASE_CHEST_CAPACITY + int(modifiers.get("chest_capacity", 0))

static func get_white_chest_rate(state: Dictionary) -> float:
	var modifiers: Dictionary = get_modifiers(state)
	return Chests.WHITE_DROP_CHANCE + float(modifiers.get("white_chest_rate", 0.0))

static func get_boss_chest_quality(state: Dictionary) -> float:
	var modifiers: Dictionary = get_modifiers(state)
	return float(modifiers.get("boss_chest_quality", 0.0))

static func purchase(state: Dictionary, rune_id: String, gold: int) -> Dictionary:
	var normalized: Dictionary = normalize_state(state)
	var definition: Dictionary = RuneData.get_rune_definition(rune_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_rune", "state": normalized, "cost": 0}
	var level: int = get_level(normalized, rune_id)
	if level >= int(definition.get("max_level", 10)):
		return {"ok": false, "reason": "max_level", "state": normalized, "cost": 0}
	var cost: int = get_next_cost(normalized, rune_id)
	if gold < cost:
		return {"ok": false, "reason": "not_enough_gold", "state": normalized, "cost": cost}
	var levels: Dictionary = normalized["levels"]
	levels[rune_id] = level + 1
	normalized["levels"] = levels
	return {"ok": true, "reason": "purchased", "state": normalized, "cost": cost, "rune_id": rune_id, "level": level + 1}

static func get_effect_text(state: Dictionary, rune_id: String) -> String:
	var definition: Dictionary = RuneData.get_rune_definition(rune_id)
	if definition.is_empty():
		return ""
	var level: int = get_level(state, rune_id)
	var value: float = float(definition.get("value", 0.0)) * float(level)
	var effect_id: String = str(definition.get("effect", rune_id))
	if effect_id == "inventory_pages" or effect_id == "chest_capacity":
		return "+%d" % int(value)
	return "+%.1f%%" % (value * 100.0)
