class_name Materials
extends RefCounted

## Phase 4 材料資料與堆疊。材料不占用 40 格裝備背包，而是以 id 堆疊。
## socket_type 使用 ItemData 既有命名：decorative / engraving / rune。

const SOCKET_DECORATIVE: String = "decorative"
const SOCKET_ENGRAVING: String = "engraving"
const SOCKET_RUNE: String = "rune"
const MATERIAL_TYPES: Array[String] = [SOCKET_DECORATIVE, SOCKET_ENGRAVING, SOCKET_RUNE]
const MATERIAL_RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
const DROP_CHANCE: Dictionary = {"white": 0.55, "blue": 1.0, "act_boss": 1.0}
const SCROLL_CHANCE: Dictionary = {"white": 0.01, "blue": 0.05, "act_boss": 0.15}

const MATERIAL_DEFINITIONS: Dictionary = {
	"ruby": {"name": "紅寶石", "type": SOCKET_DECORATIVE, "rarity": "common", "stats": {"fire_resistance": 0.035}},
	"sapphire": {"name": "藍寶石", "type": SOCKET_DECORATIVE, "rarity": "common", "stats": {"ice_resistance": 0.035}},
	"topaz": {"name": "黃玉", "type": SOCKET_DECORATIVE, "rarity": "common", "stats": {"lightning_resistance": 0.035}},
	"amethyst": {"name": "紫水晶", "type": SOCKET_DECORATIVE, "rarity": "uncommon", "stats": {"chaos_resistance": 0.035}},
	"emerald": {"name": "祖母綠", "type": SOCKET_DECORATIVE, "rarity": "rare", "stats": {"chaos_resistance": 0.025, "max_hp": 14.0}},
	"diamond": {"name": "鑽石", "type": SOCKET_DECORATIVE, "rarity": "epic", "stats": {"all_resistance": 0.025}},
	"strength_rune": {"name": "力量符石", "type": SOCKET_ENGRAVING, "rarity": "common", "stats": {"attack_percent": 0.050}},
	"haste_rune": {"name": "迅捷符石", "type": SOCKET_ENGRAVING, "rarity": "uncommon", "stats": {"attack_speed_percent": 0.040}},
	"crit_rune": {"name": "銳意符石", "type": SOCKET_ENGRAVING, "rarity": "rare", "stats": {"crit_chance": 0.025}},
	"vitality_rune": {"name": "生命符石", "type": SOCKET_ENGRAVING, "rarity": "rare", "stats": {"max_hp_percent": 0.050}},
	"ancient_scroll": {"name": "古老卷軸", "type": SOCKET_RUNE, "rarity": "rare", "stats": {"cooldown_reduction": 0.050}},
	"arcane_scroll": {"name": "秘法卷軸", "type": SOCKET_RUNE, "rarity": "epic", "stats": {"effect_radius_percent": 0.080}},
	"chaos_scroll": {"name": "混沌卷軸", "type": SOCKET_RUNE, "rarity": "legendary", "stats": {"elemental_damage_percent": 0.100, "skill_level_bonus": 1.0}}
}

static func get_material_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id: Variant in MATERIAL_DEFINITIONS.keys():
		result.append(str(raw_id))
	return result

static func get_material_ids_by_type(socket_type: String) -> Array[String]:
	var result: Array[String] = []
	for material_id: String in get_material_ids():
		if str(get_material_definition(material_id).get("type", "")) == socket_type:
			result.append(material_id)
	return result

static func get_material_definition(material_id: String) -> Dictionary:
	if MATERIAL_DEFINITIONS.has(material_id):
		return (MATERIAL_DEFINITIONS[material_id] as Dictionary).duplicate(true)
	return {}

static func get_material_name(material_id: String) -> String:
	return str(get_material_definition(material_id).get("name", material_id))

static func get_socket_type(material_id: String) -> String:
	return str(get_material_definition(material_id).get("type", ""))

static func get_rarity(material_id: String) -> String:
	return str(get_material_definition(material_id).get("rarity", "common"))

static func get_rarity_name(rarity_id: String) -> String:
	return ItemData.get_rarity_name(rarity_id)

static func get_rarity_color(rarity_id: String) -> Color:
	return ItemData.get_rarity_color(rarity_id)

static func create_state() -> Dictionary:
	return {"stacks": {}}

static func make_material(material_id: String, level: int = 1, rarity_id: String = "") -> Dictionary:
	var definition: Dictionary = get_material_definition(material_id)
	if definition.is_empty():
		return {}
	var safe_level: int = clampi(level, 1, 100)
	var safe_rarity: String = rarity_id if ItemData.get_rarity_definition(rarity_id).size() > 0 else get_rarity(material_id)
	return {
		"id": material_id,
		"name": get_material_name(material_id),
		"type": get_socket_type(material_id),
		"socket_type": get_socket_type(material_id),
		"rarity": safe_rarity,
		"level": safe_level,
		"count": 1
	}

static func normalize_state(source: Dictionary) -> Dictionary:
	var normalized: Dictionary = create_state()
	var stacks: Dictionary = normalized["stacks"]
	var source_stacks: Variant = source.get("stacks", null)
	if source_stacks is Dictionary:
		for raw_id: Variant in (source_stacks as Dictionary).keys():
			var material_id: String = str(raw_id)
			if get_material_definition(material_id).is_empty():
				continue
			var raw_value: Variant = (source_stacks as Dictionary).get(raw_id, 0)
			if raw_value is Dictionary:
				var entry: Dictionary = raw_value
				var count: int = maxi(0, int(entry.get("count", entry.get("quantity", 0))))
				if count > 0:
					stacks[material_id] = _make_stack(material_id, count, int(entry.get("level", 1)), str(entry.get("rarity", "")))
			else:
				var count_from_flat: int = maxi(0, int(raw_value))
				if count_from_flat > 0:
					stacks[material_id] = _make_stack(material_id, count_from_flat, 1, "")
	# 支援舊版/測試用的分類字典與直接 id 字典。
	for type_key: String in ["gems", "decorative", "engravings", "engraving", "scrolls", "rune"]:
		var grouped_value: Variant = source.get(type_key, null)
		if grouped_value is Dictionary:
			for raw_id: Variant in (grouped_value as Dictionary).keys():
				var material_id: String = str(raw_id)
				if get_material_definition(material_id).is_empty() or stacks.has(material_id):
					continue
				var count_value: Variant = (grouped_value as Dictionary).get(raw_id, 0)
				var count: int = maxi(0, int(count_value.get("count", 0)) if count_value is Dictionary else int(count_value))
				if count > 0:
					stacks[material_id] = _make_stack(material_id, count, int((count_value as Dictionary).get("level", 1)) if count_value is Dictionary else 1, str((count_value as Dictionary).get("rarity", "")) if count_value is Dictionary else "")
	for raw_id: Variant in source.keys():
		var material_id: String = str(raw_id)
		if stacks.has(material_id) or get_material_definition(material_id).is_empty():
			continue
		var count_value: Variant = source.get(raw_id, 0)
		var count: int = maxi(0, int(count_value.get("count", 0)) if count_value is Dictionary else int(count_value))
		if count > 0:
			stacks[material_id] = _make_stack(material_id, count, int((count_value as Dictionary).get("level", 1)) if count_value is Dictionary else 1, str((count_value as Dictionary).get("rarity", "")) if count_value is Dictionary else "")
	return normalized

static func add_material(state: Dictionary, material: Variant, count: int = 1) -> Dictionary:
	var material_id: String = str(material.get("id", material)) if material is Dictionary else str(material)
	var definition: Dictionary = get_material_definition(material_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_material", "count": 0, "material": {}}
	var safe_count: int = maxi(1, count)
	var level: int = int((material as Dictionary).get("level", 1)) if material is Dictionary else 1
	var rarity_id: String = str((material as Dictionary).get("rarity", "")) if material is Dictionary else ""
	var stacks: Dictionary = state.get("stacks", {})
	var existing: Dictionary = stacks.get(material_id, {})
	if existing.is_empty():
		stacks[material_id] = _make_stack(material_id, safe_count, level, rarity_id)
	else:
		existing["count"] = int(existing.get("count", 0)) + safe_count
		if level > int(existing.get("level", 1)):
			existing["level"] = level
		if not rarity_id.is_empty():
			existing["rarity"] = rarity_id
		stacks[material_id] = existing
	state["stacks"] = stacks
	return {"ok": true, "reason": "added", "count": safe_count, "material_id": material_id, "total": get_count(state, material_id)}

static func remove_material(state: Dictionary, material_id: String, count: int = 1) -> Dictionary:
	var safe_count: int = maxi(1, count)
	var stacks: Dictionary = state.get("stacks", {})
	var stack: Dictionary = stacks.get(material_id, {})
	if stack.is_empty() or int(stack.get("count", 0)) < safe_count:
		return {"ok": false, "reason": "insufficient_material", "removed": 0, "material": {}}
	var removed: int = safe_count
	stack["count"] = int(stack.get("count", 0)) - removed
	var material: Dictionary = stack.duplicate(true)
	if int(stack.get("count", 0)) <= 0:
		stacks.erase(material_id)
	else:
		stacks[material_id] = stack
	state["stacks"] = stacks
	return {"ok": true, "reason": "removed", "removed": removed, "material": material}

static func get_count(state: Dictionary, material_id: String) -> int:
	var stacks: Dictionary = state.get("stacks", {})
	var stack_value: Variant = stacks.get(material_id, 0)
	if stack_value is Dictionary:
		return maxi(0, int((stack_value as Dictionary).get("count", 0)))
	var flat_value: Variant = state.get(material_id, 0)
	if flat_value is Dictionary:
		return maxi(0, int((flat_value as Dictionary).get("count", 0)))
	return maxi(0, int(flat_value))

static func get_stack(state: Dictionary, material_id: String) -> Dictionary:
	var stacks: Dictionary = state.get("stacks", {})
	var stack: Dictionary = stacks.get(material_id, {})
	return stack.duplicate(true)

static func get_stacks(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stacks: Dictionary = state.get("stacks", {})
	for raw_id: Variant in stacks.keys():
		var stack_value: Variant = stacks[raw_id]
		if stack_value is Dictionary:
			result.append((stack_value as Dictionary).duplicate(true))
	return result

static func get_total_count(state: Dictionary) -> int:
	var total: int = 0
	for stack: Dictionary in get_stacks(state):
		total += int(stack.get("count", 0))
	return total

static func get_materials_by_socket_type(state: Dictionary, socket_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stack: Dictionary in get_stacks(state):
		if str(stack.get("socket_type", stack.get("type", ""))) == socket_type and int(stack.get("count", 0)) > 0:
			result.append(stack)
	return result

static func get_material_bonus(material: Variant, level_override: int = 0) -> Dictionary:
	var material_id: String = str(material.get("id", material)) if material is Dictionary else str(material)
	var definition: Dictionary = get_material_definition(material_id)
	if definition.is_empty():
		return {}
	var level: int = level_override if level_override > 0 else (int((material as Dictionary).get("level", 1)) if material is Dictionary else 1)
	var rarity_id: String = str((material as Dictionary).get("rarity", "")) if material is Dictionary else get_rarity(material_id)
	if rarity_id.is_empty():
		rarity_id = get_rarity(material_id)
	var rarity_multiplier: float = float(ItemData.get_rarity_definition(rarity_id).get("multiplier", 1.0))
	var level_multiplier: float = 1.0 + float(maxi(1, level) - 1) * 0.06
	var result: Dictionary = {}
	var source_stats: Dictionary = definition.get("stats", {})
	for raw_stat: Variant in source_stats.keys():
		var stat_id: String = str(raw_stat)
		var value: float = float(source_stats[raw_stat]) * rarity_multiplier * level_multiplier
		if stat_id == "skill_level_bonus":
			result[stat_id] = float(source_stats[raw_stat])
		elif stat_id.ends_with("_resistance") or stat_id == "all_resistance" or stat_id.ends_with("_percent") or stat_id == "crit_chance" or stat_id == "cooldown_reduction" or stat_id == "elemental_damage_percent":
			result[stat_id] = roundf(value * 10000.0) / 10000.0
		else:
			result[stat_id] = roundf(value * 100.0) / 100.0
	return result

static func roll_material(material_type: String = "", level: int = 1, rng: RandomNumberGenerator = null, forced_id: String = "") -> Dictionary:
	var safe_rng: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	var candidate_ids: Array[String] = get_material_ids_by_type(material_type) if MATERIAL_TYPES.has(material_type) else get_material_ids()
	if not forced_id.is_empty() and get_material_definition(forced_id).size() > 0:
		candidate_ids = [forced_id]
	if candidate_ids.is_empty():
		return {}
	var selected_id: String = candidate_ids[safe_rng.randi_range(0, candidate_ids.size() - 1)]
	return make_material(selected_id, level)

static func roll_material_drop(chest_type: String, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var safe_type: String = chest_type if DROP_CHANCE.has(chest_type) else "white"
	if rng.randf() >= float(DROP_CHANCE.get(safe_type, 0.0)):
		return {}
	var use_scroll: bool = rng.randf() < float(SCROLL_CHANCE.get(safe_type, 0.0))
	var material_type: String = SOCKET_RUNE if use_scroll else (SOCKET_DECORATIVE if rng.randf() < 0.60 else SOCKET_ENGRAVING)
	return roll_material(material_type, level, rng)

static func get_next_rarity(rarity_id: String) -> String:
	var index: int = ItemData.get_rarity_ids().find(rarity_id)
	if index < 0 or index >= ItemData.get_rarity_ids().size() - 1:
		return rarity_id
	return ItemData.get_rarity_ids()[index + 1]

static func _make_stack(material_id: String, count: int, level: int, rarity_id: String) -> Dictionary:
	var material: Dictionary = make_material(material_id, level, rarity_id)
	material["count"] = maxi(1, count)
	return material
