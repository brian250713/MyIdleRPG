class_name ItemGen
extends RefCounted

const RARITY_TOTAL_WEIGHT: float = 100.0

static func roll_rarity(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf_range(0.0, RARITY_TOTAL_WEIGHT)
	var cumulative: float = 0.0
	for rarity_id: String in ItemData.get_rarity_ids():
		cumulative += float(ItemData.get_rarity_definition(rarity_id).get("weight", 0.0))
		if roll < cumulative:
			return rarity_id
	return "transcendent"

static func generate_item(item_level: int, rng: RandomNumberGenerator, forced_rarity: String = "", class_id: String = "", forced_slot: String = "") -> Dictionary:
	var safe_level: int = clampi(item_level, 1, 100)
	var rarity_id: String = forced_rarity if ItemData.get_rarity_definition(forced_rarity).size() > 0 else roll_rarity(rng)
	var slot_id: String = forced_slot if ItemData.get_slot_ids().has(forced_slot) else str(ItemData.get_slot_ids()[rng.randi_range(0, ItemData.get_slot_ids().size() - 1)])
	var subtype: String = ""
	var classes: Array = []
	if slot_id == "weapon":
		var subtype_ids: Array[String] = ItemData.get_weapon_subtypes_for_class(class_id)
		if subtype_ids.is_empty():
			subtype_ids = ["sword", "staff", "bow", "wand"]
		subtype = subtype_ids[rng.randi_range(0, subtype_ids.size() - 1)]
		var subtype_definition: Dictionary = ItemData.WEAPON_SUBTYPES[subtype]
		classes = (subtype_definition.get("classes", []) as Array).duplicate()
	var rarity_definition: Dictionary = ItemData.get_rarity_definition(rarity_id)
	var rarity_multiplier: float = float(rarity_definition.get("multiplier", 1.0))
	var main_stat: String = _main_stat_for_slot(slot_id)
	var main_value: float = _main_value_for_slot(slot_id, safe_level, rarity_multiplier)
	var affixes: Array[Dictionary] = _roll_affixes(safe_level, rarity_multiplier, int(rarity_definition.get("affix_count", 0)), rng)
	var sockets: Array[Dictionary] = []
	for socket_type: String in ItemData.get_socket_layout(rarity_id):
		sockets.append({"type": socket_type, "item_id": null})
	var item_name: String = _make_item_name(slot_id, subtype, rarity_id)
	var item: Dictionary = {
		"id": "item_%d_%d" % [safe_level, rng.randi()],
		"name": item_name,
		"slot": slot_id,
		"subtype": subtype,
		"rarity": rarity_id,
		"level": safe_level,
		"main_stat": main_stat,
		"main_value": main_value,
		"affixes": affixes,
		"sockets": sockets,
		"classes": classes,
		"icon": ItemData.get_icon_id({"slot": slot_id, "subtype": subtype}),
		"sell_value": _sell_value(safe_level, rarity_multiplier)
	}
	return item

static func generate_items(item_level: int, count: int, rng: RandomNumberGenerator, class_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _index: int in range(maxi(0, count)):
		result.append(generate_item(item_level, rng, "", class_id))
	return result

static func get_main_stat_for_slot(slot_id: String) -> String:
	return _main_stat_for_slot(slot_id)

static func get_rarity_weight_total() -> float:
	var total: float = 0.0
	for rarity_id: String in ItemData.get_rarity_ids():
		total += float(ItemData.get_rarity_definition(rarity_id).get("weight", 0.0))
	return total

static func _main_stat_for_slot(slot_id: String) -> String:
	match slot_id:
		"weapon":
			return "attack"
		"helmet":
			return "defense"
		"chest":
			return "max_hp"
		"gloves":
			return "attack"
		"boots":
			return "defense"
		"ring":
			return "crit_chance"
		"amulet":
			return "fire_resistance"
		_:
			return "max_hp"

static func _main_value_for_slot(slot_id: String, item_level: int, rarity_multiplier: float) -> float:
	match slot_id:
		"weapon":
			return roundf((4.0 + float(item_level) * 1.8) * rarity_multiplier)
		"helmet":
			return roundf((2.0 + float(item_level) * 1.1) * rarity_multiplier)
		"chest":
			return roundf((12.0 + float(item_level) * 5.0) * rarity_multiplier)
		"gloves":
			return roundf((2.0 + float(item_level) * 0.9) * rarity_multiplier)
		"boots":
			return roundf((1.0 + float(item_level) * 0.7) * rarity_multiplier)
		"ring":
			return roundf((0.01 + float(item_level) * 0.0008) * rarity_multiplier * 10000.0) / 10000.0
		"amulet":
			return roundf((0.02 + float(item_level) * 0.0015) * rarity_multiplier * 10000.0) / 10000.0
		_:
			return 0.0

static func _roll_affixes(item_level: int, rarity_multiplier: float, count: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pool: Array[Dictionary] = []
	for definition: Dictionary in ItemData.AFFIX_POOL:
		pool.append(definition.duplicate(true))
	for _index: int in range(mini(maxi(0, count), pool.size())):
		var selected_index: int = rng.randi_range(0, pool.size() - 1)
		var definition: Dictionary = pool[selected_index]
		pool.remove_at(selected_index)
		var stat_id: String = str(definition.get("stat", "max_hp"))
		var value: float = _affix_value(stat_id, item_level, rarity_multiplier)
		result.append({
			"id": str(definition.get("id", stat_id)),
			"name": str(definition.get("name", stat_id)),
			"stat": stat_id,
			"value": value,
			"percent": bool(definition.get("percent", false))
		})
	return result

static func _affix_value(stat_id: String, item_level: int, rarity_multiplier: float) -> float:
	var level_scale: float = 1.0 + (rarity_multiplier - 1.0) * 0.5
	match stat_id:
		"attack_percent":
			return roundf((0.03 + float(item_level) * 0.0015) * level_scale * 10000.0) / 10000.0
		"attack_speed_percent":
			return roundf((0.02 + float(item_level) * 0.0010) * level_scale * 10000.0) / 10000.0
		"crit_chance":
			return roundf((0.01 + float(item_level) * 0.0006) * level_scale * 10000.0) / 10000.0
		"crit_damage":
			return roundf((0.04 + float(item_level) * 0.0020) * level_scale * 10000.0) / 10000.0
		"max_hp":
			return roundf((8.0 + float(item_level) * 2.0) * level_scale)
		"defense":
			return roundf((3.0 + float(item_level) * 1.2) * level_scale)
		"fire_resistance", "ice_resistance", "lightning_resistance", "chaos_resistance":
			return roundf((0.02 + float(item_level) * 0.0010) * level_scale * 10000.0) / 10000.0
		"life_steal":
			return roundf((0.01 + float(item_level) * 0.0005) * level_scale * 10000.0) / 10000.0
		"gold_gain", "xp_gain":
			return roundf((0.03 + float(item_level) * 0.0012) * level_scale * 10000.0) / 10000.0
		_:
			return 0.0

static func _make_item_name(slot_id: String, subtype: String, rarity_id: String) -> String:
	var slot_name: String = ItemData.get_slot_name(slot_id)
	if slot_id == "weapon":
		slot_name = str(ItemData.WEAPON_SUBTYPES.get(subtype, {}).get("name", "武器"))
	return "%s %s" % [ItemData.get_rarity_name(rarity_id), slot_name]

static func _sell_value(item_level: int, rarity_multiplier: float) -> int:
	return maxi(1, int(round((5.0 + float(item_level) * 2.0) * rarity_multiplier)))
