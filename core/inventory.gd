class_name Inventory
extends RefCounted

const PAGE_COUNT: int = 1
const SLOT_COUNT: int = 40

static func create_inventory() -> Dictionary:
	var slots: Array = []
	for _index: int in range(SLOT_COUNT):
		slots.append(null)
	return {"pages": PAGE_COUNT, "slots": slots}

static func normalize_inventory(source: Dictionary) -> Dictionary:
	var normalized: Dictionary = create_inventory()
	var source_slots: Variant = source.get("slots", [])
	if source_slots is Array:
		var source_array: Array = source_slots
		var target_slots: Array = normalized["slots"]
		for index: int in range(mini(SLOT_COUNT, source_array.size())):
			var item_value: Variant = source_array[index]
			if item_value is Dictionary:
				target_slots[index] = (item_value as Dictionary).duplicate(true)
	return normalized

static func get_items(inventory: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var slots: Array = inventory.get("slots", [])
	for item_value: Variant in slots:
		if item_value is Dictionary:
			result.append((item_value as Dictionary).duplicate(true))
	return result

static func get_item_at(inventory: Dictionary, slot_index: int) -> Dictionary:
	var slots: Array = inventory.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return {}
	var item_value: Variant = slots[slot_index]
	if item_value is Dictionary:
		return (item_value as Dictionary).duplicate(true)
	return {}

static func find_empty_slot(inventory: Dictionary) -> int:
	var slots: Array = inventory.get("slots", [])
	for index: int in range(mini(SLOT_COUNT, slots.size())):
		if slots[index] == null:
			return index
	return -1

static func add_item(inventory: Dictionary, item: Dictionary, auto_sell_common: bool = false, auto_sell_uncommon: bool = false) -> Dictionary:
	if item.is_empty():
		return {"stored": false, "converted_to_gold": false, "gold": 0, "slot": -1, "reason": "invalid_item"}
	var rarity: String = str(item.get("rarity", "common"))
	var should_auto_sell: bool = (rarity == "common" and auto_sell_common) or (rarity == "uncommon" and auto_sell_uncommon)
	var slot_index: int = find_empty_slot(inventory)
	if should_auto_sell or slot_index < 0:
		return {
			"stored": false,
			"converted_to_gold": true,
			"gold": int(item.get("sell_value", 1)),
			"slot": -1,
			"reason": "auto_sell" if should_auto_sell else "inventory_full"
		}
	var slots: Array = inventory["slots"]
	slots[slot_index] = item.duplicate(true)
	return {"stored": true, "converted_to_gold": false, "gold": 0, "slot": slot_index, "reason": "stored"}

static func remove_item(inventory: Dictionary, slot_index: int) -> Dictionary:
	var slots: Array = inventory.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {"removed": false, "item": {}, "gold": 0}
	var item: Dictionary = slots[slot_index]
	slots[slot_index] = null
	return {"removed": true, "item": item.duplicate(true), "gold": int(item.get("sell_value", 0))}

static func sell_item(inventory: Dictionary, slot_index: int) -> Dictionary:
	return remove_item(inventory, slot_index)

static func sell_by_rarity(inventory: Dictionary, rarity: String) -> Dictionary:
	var slots: Array = inventory.get("slots", [])
	var sold_count: int = 0
	var gold: int = 0
	for index: int in range(mini(SLOT_COUNT, slots.size())):
		var item_value: Variant = slots[index]
		if item_value is Dictionary and str(item_value.get("rarity", "")) == rarity:
			gold += int(item_value.get("sell_value", 0))
			slots[index] = null
			sold_count += 1
	return {"sold_count": sold_count, "gold": gold}

static func count_items(inventory: Dictionary) -> int:
	return get_items(inventory).size()
