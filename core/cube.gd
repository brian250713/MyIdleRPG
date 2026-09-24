class_name Cube
extends RefCounted

const REQUIRED_ITEM_COUNT: int = 3
const MAX_LEVEL: int = 100
const OVER_LEVEL_THRESHOLD: int = 10
const OVER_LEVEL_XP_MULTIPLIER: float = 0.5

static func create_state() -> Dictionary:
	return {"level": 1, "xp": 0}

static func normalize_state(source: Dictionary) -> Dictionary:
	return {
		"level": clampi(int(source.get("level", 1)), 1, MAX_LEVEL),
		"xp": maxi(0, int(source.get("xp", 0)))
	}

static func get_xp_to_next(level: int) -> int:
	return maxi(1, int(round(20.0 + float(maxi(1, level)) * 10.0)))

static func get_average_level(items: Array) -> int:
	if items.is_empty():
		return 0
	var total: int = 0
	for raw_item: Variant in items:
		if raw_item is Dictionary:
			total += maxi(1, int((raw_item as Dictionary).get("level", 1)))
	return int(round(float(total) / float(items.size())))

static func get_output_level(cube_level: int, items: Array) -> int:
	var average_level: int = get_average_level(items)
	return maxi(1, mini(maxi(1, cube_level), average_level + 5))

static func get_upgrade_chance(rarity_id: String) -> float:
	var rarity_index: int = ItemData.get_rarity_ids().find(rarity_id)
	if rarity_index < 0 or rarity_index >= ItemData.get_rarity_ids().size() - 1:
		return 0.0
	return 0.03 if rarity_index >= ItemData.get_rarity_ids().find("legendary") else 0.15

static func get_xp_gain(state: Dictionary, items: Array) -> int:
	if items.size() != REQUIRED_ITEM_COUNT:
		return 0
	var average_level: int = get_average_level(items)
	var cube_level: int = maxi(1, int(state.get("level", 1)))
	var base_gain: float = 8.0 + float(average_level) * 2.0
	var distance: float = absf(float(average_level - cube_level))
	var closeness: float = clampf(1.0 - distance / maxf(1.0, float(cube_level)), 0.10, 1.50)
	var gain: float = base_gain * closeness
	if average_level >= cube_level + OVER_LEVEL_THRESHOLD:
		gain *= OVER_LEVEL_XP_MULTIPLIER
	return maxi(1, int(round(gain)))

static func can_combine(items: Array) -> Dictionary:
	if items.size() != REQUIRED_ITEM_COUNT:
		return {"ok": false, "reason": "requires_three_items", "count": items.size()}
	var rarity_id: String = ""
	for raw_item: Variant in items:
		if not (raw_item is Dictionary):
			return {"ok": false, "reason": "invalid_item", "count": items.size()}
		var item: Dictionary = raw_item
		if rarity_id.is_empty():
			rarity_id = str(item.get("rarity", "common"))
		elif str(item.get("rarity", "common")) != rarity_id:
			return {"ok": false, "reason": "rarity_mismatch", "count": items.size(), "rarity": rarity_id}
	return {"ok": true, "reason": "ready", "count": items.size(), "rarity": rarity_id}

static func preview(state: Dictionary, items: Array, rng: RandomNumberGenerator = null) -> Dictionary:
	var check: Dictionary = can_combine(items)
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason": str(check.get("reason", "invalid")), "items": items.size()}
	var rarity_id: String = str(check.get("rarity", "common"))
	var level: int = get_output_level(int(state.get("level", 1)), items)
	var chance: float = get_upgrade_chance(rarity_id)
	var upgraded_rarity: String = ItemData.get_rarity_ids()[mini(ItemData.get_rarity_ids().find(rarity_id) + 1, ItemData.get_rarity_ids().size() - 1)]
	return {
		"ok": true,
		"items": items.size(),
		"input_rarity": rarity_id,
		"output_level": level,
		"level_min": level,
		"level_max": level,
		"upgrade_chance": chance,
		"possible_rarity": upgraded_rarity,
		"cube_level": int(state.get("level", 1)),
		"xp_to_next": get_xp_to_next(int(state.get("level", 1))),
		"xp_gain": get_xp_gain(state, items),
		"over_level_penalty": get_average_level(items) >= int(state.get("level", 1)) + OVER_LEVEL_THRESHOLD
	}

static func combine_items(state: Dictionary, items: Array, rng: RandomNumberGenerator) -> Dictionary:
	var check: Dictionary = can_combine(items)
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason": str(check.get("reason", "invalid")), "state": state.duplicate(true), "item": {}}
	var normalized_state: Dictionary = normalize_state(state)
	var safe_rng: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	var preview_result: Dictionary = preview(normalized_state, items, safe_rng)
	var input_rarity: String = str(preview_result.get("input_rarity", "common"))
	var upgraded: bool = safe_rng.randf() < float(preview_result.get("upgrade_chance", 0.0))
	var output_rarity: String = str(preview_result.get("possible_rarity", input_rarity)) if upgraded else input_rarity
	var template: Dictionary = items[0]
	var class_id: String = ""
	var classes: Array = template.get("classes", [])
	if not classes.is_empty():
		class_id = str(classes[0])
	var output_item: Dictionary = ItemGen.generate_item(int(preview_result.get("output_level", 1)), safe_rng, output_rarity, class_id, str(template.get("slot", "")))
	if output_item.is_empty():
		return {"ok": false, "reason": "item_generation_failed", "state": normalized_state, "item": {}}
	output_item["id"] = "cube_%d_%d" % [int(preview_result.get("output_level", 1)), safe_rng.randi()]
	var xp_gained: int = int(preview_result.get("xp_gain", 0))
	normalized_state["xp"] = int(normalized_state.get("xp", 0)) + xp_gained
	while int(normalized_state["xp"]) >= get_xp_to_next(int(normalized_state["level"])) and int(normalized_state["level"]) < MAX_LEVEL:
		normalized_state["xp"] = int(normalized_state["xp"]) - get_xp_to_next(int(normalized_state["level"]))
		normalized_state["level"] = int(normalized_state["level"]) + 1
	return {
		"ok": true,
		"reason": "combined",
		"state": normalized_state,
		"item": output_item,
		"input_rarity": input_rarity,
		"output_rarity": output_rarity,
		"rarity_upgraded": upgraded,
		"output_level": int(preview_result.get("output_level", 1)),
		"xp_gained": xp_gained,
		"xp_penalty": bool(preview_result.get("over_level_penalty", false))
	}

static func combine_materials(materials_state: Dictionary, cube_state: Dictionary, material_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var available: int = Materials.get_count(materials_state, material_id)
	if available < REQUIRED_ITEM_COUNT:
		return {"ok": false, "reason": "requires_three_materials", "material": {}, "state": materials_state.duplicate(true)}
	var definition: Dictionary = Materials.get_material_definition(material_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_material", "material": {}, "state": materials_state.duplicate(true)}
	var removed: Dictionary = Materials.remove_material(materials_state, material_id, REQUIRED_ITEM_COUNT)
	if not bool(removed.get("ok", false)):
		return {"ok": false, "reason": "insufficient_material", "material": {}, "state": materials_state.duplicate(true)}
	var source_material: Dictionary = removed.get("material", {})
	var source_rarity: String = str(source_material.get("rarity", Materials.get_rarity(material_id)))
	var chance: float = get_upgrade_chance(source_rarity)
	var upgraded: bool = (rng if rng != null else RandomNumberGenerator.new()).randf() < chance
	var output_rarity: String = Materials.get_next_rarity(source_rarity) if upgraded else source_rarity
	var output_material: Dictionary = Materials.make_material(material_id, int(source_material.get("level", 1)), output_rarity)
	Materials.add_material(materials_state, output_material)
	return {"ok": true, "reason": "combined_material", "material": output_material, "rarity_upgraded": upgraded, "upgrade_chance": chance, "state": materials_state.duplicate(true)}
