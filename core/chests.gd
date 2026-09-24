class_name Chests
extends RefCounted

const WHITE_QUEUE_CAPACITY: int = 20
const WHITE_COOLDOWN_SECONDS: float = 90.0
const WHITE_DROP_CHANCE: float = 0.25
const BLUE_SOUL_STONE_CHANCE: float = 0.10
const ACT_SOUL_STONE_CHANCE: float = 0.30

static func create_state() -> Dictionary:
	return {
		"queue": [],
		"white_cooldown": 0.0,
		"capacity": WHITE_QUEUE_CAPACITY,
		"white_drop_chance": WHITE_DROP_CHANCE,
		"boss_chest_quality_bonus": 0.0,
		"auto_open": {
			"white": false,
			"blue": false,
			"act_boss": false
		}
	}

static func normalize_state(source: Dictionary) -> Dictionary:
	var normalized: Dictionary = create_state()
	normalized["white_cooldown"] = maxf(0.0, float(source.get("white_cooldown", 0.0)))
	normalized["capacity"] = maxi(WHITE_QUEUE_CAPACITY, int(source.get("capacity", WHITE_QUEUE_CAPACITY)))
	normalized["white_drop_chance"] = clampf(float(source.get("white_drop_chance", WHITE_DROP_CHANCE)), 0.0, 1.0)
	normalized["boss_chest_quality_bonus"] = maxf(0.0, float(source.get("boss_chest_quality_bonus", 0.0)))
	var source_queue: Variant = source.get("queue", [])
	if source_queue is Array:
		var queue: Array = []
		for chest_value: Variant in source_queue:
			if chest_value is Dictionary:
				var chest: Dictionary = chest_value
				var chest_type: String = str(chest.get("type", "white"))
				if not ["white", "blue", "act_boss"].has(chest_type):
					chest_type = "white"
				queue.append({
					"type": chest_type,
					"level": maxi(1, int(chest.get("level", 1))),
					"id": str(chest.get("id", "chest_%d" % queue.size()))
				})
		normalized["queue"] = queue
	var source_auto_open: Variant = source.get("auto_open", {})
	if source_auto_open is Dictionary:
		var auto_open: Dictionary = source_auto_open
		var normalized_auto_open: Dictionary = normalized["auto_open"]
		for key: String in ["white", "blue", "act_boss"]:
			normalized_auto_open[key] = bool(auto_open.get(key, false))
	return normalized

static func tick(state: Dictionary, delta: float) -> Dictionary:
	state["white_cooldown"] = maxf(0.0, float(state.get("white_cooldown", 0.0)) - maxf(0.0, delta))
	return state

static func get_queue(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var queue: Array = state.get("queue", [])
	for chest_value: Variant in queue:
		if chest_value is Dictionary:
			result.append((chest_value as Dictionary).duplicate(true))
	return result

static func get_queue_size(state: Dictionary) -> int:
	var queue: Array = state.get("queue", [])
	return queue.size()

static func get_queue_capacity(state: Dictionary) -> int:
	return maxi(WHITE_QUEUE_CAPACITY, int(state.get("capacity", WHITE_QUEUE_CAPACITY)))

static func get_white_drop_chance(state: Dictionary) -> float:
	return clampf(float(state.get("white_drop_chance", WHITE_DROP_CHANCE)), 0.0, 1.0)

static func get_boss_chest_quality_bonus(state: Dictionary) -> float:
	return maxf(0.0, float(state.get("boss_chest_quality_bonus", 0.0)))

static func set_rune_effects(state: Dictionary, white_chest_rate: float, chest_capacity: int, boss_chest_quality: float) -> Dictionary:
	state["white_drop_chance"] = clampf(white_chest_rate, 0.0, 1.0)
	state["capacity"] = maxi(WHITE_QUEUE_CAPACITY, chest_capacity)
	state["boss_chest_quality_bonus"] = maxf(0.0, boss_chest_quality)
	return state

static func get_counts(state: Dictionary) -> Dictionary:
	var counts: Dictionary = {"white": 0, "blue": 0, "act_boss": 0}
	var queue: Array = state.get("queue", [])
	for chest_value: Variant in queue:
		if chest_value is Dictionary:
			var chest_type: String = str(chest_value.get("type", "white"))
			if counts.has(chest_type):
				counts[chest_type] = int(counts[chest_type]) + 1
	return counts

static func is_auto_open_enabled(state: Dictionary, chest_type: String) -> bool:
	var auto_open: Dictionary = state.get("auto_open", {})
	return bool(auto_open.get(chest_type, false))

static func set_auto_open(state: Dictionary, chest_type: String, enabled: bool) -> void:
	if not ["white", "blue", "act_boss"].has(chest_type):
		return
	var auto_open: Dictionary = state.get("auto_open", {})
	auto_open[chest_type] = enabled
	state["auto_open"] = auto_open

static func try_drop_for_kill(state: Dictionary, monster_level: int, is_stage_boss: bool, is_act_boss: bool, rng: RandomNumberGenerator) -> Dictionary:
	if is_act_boss:
		var blue_result: Dictionary = drop_chest(state, "blue", monster_level)
		var act_result: Dictionary = drop_chest(state, "act_boss", monster_level)
		return {"dropped": true, "chests": [blue_result["chest"], act_result["chest"]], "reason": "act_boss"}
	if is_stage_boss:
		var result: Dictionary = drop_chest(state, "blue", monster_level)
		return {"dropped": true, "chests": [result["chest"]], "reason": "stage_boss"}
	return try_white_drop(state, monster_level, rng)

static func try_white_drop(state: Dictionary, monster_level: int, rng: RandomNumberGenerator) -> Dictionary:
	if float(state.get("white_cooldown", 0.0)) > 0.0:
		return {"dropped": false, "chests": [], "reason": "cooldown"}
	if get_queue_size(state) >= get_queue_capacity(state):
		return {"dropped": false, "chests": [], "reason": "queue_full"}
	if rng.randf() >= get_white_drop_chance(state):
		return {"dropped": false, "chests": [], "reason": "roll_failed"}
	var result: Dictionary = drop_chest(state, "white", monster_level)
	state["white_cooldown"] = WHITE_COOLDOWN_SECONDS
	return {"dropped": true, "chests": [result["chest"]], "reason": "white_roll"}

static func drop_chest(state: Dictionary, chest_type: String, item_level: int) -> Dictionary:
	var safe_type: String = chest_type if ["white", "blue", "act_boss"].has(chest_type) else "white"
	var chest: Dictionary = {
		"type": safe_type,
		"level": clampi(item_level, 1, 100),
		"id": "chest_%s_%d" % [safe_type, get_queue_size(state)]
	}
	var queue: Array = state.get("queue", [])
	queue.append(chest)
	state["queue"] = queue
	return {"dropped": true, "chest": chest.duplicate(true), "reason": safe_type}

static func open_chest(state: Dictionary, queue_index: int, rng: RandomNumberGenerator) -> Dictionary:
	var queue: Array = state.get("queue", [])
	if queue_index < 0 or queue_index >= queue.size() or not (queue[queue_index] is Dictionary):
		return {"opened": false, "reason": "invalid_index", "items": [], "materials": [], "gold": 0, "soul_stones": 0}
	var chest: Dictionary = queue[queue_index]
	queue.remove_at(queue_index)
	state["queue"] = queue
	var chest_type: String = str(chest.get("type", "white"))
	var level: int = maxi(1, int(chest.get("level", 1)))
	var item_count: int = rng.randi_range(1, 3)
	var quality_bonus: float = get_boss_chest_quality_bonus(state) if chest_type != "white" else 0.0
	var items: Array[Dictionary] = ItemGen.generate_items(level, item_count, rng, "", quality_bonus)
	var materials: Array[Dictionary] = []
	var material: Dictionary = Materials.roll_material_drop(chest_type, level, rng)
	if not material.is_empty():
		materials.append(material)
	var gold: int = rng.randi_range(3, 10) + level * 2
	var soul_stones: int = 0
	if chest_type == "blue" and rng.randf() < BLUE_SOUL_STONE_CHANCE:
		soul_stones = 1
	elif chest_type == "act_boss" and rng.randf() < ACT_SOUL_STONE_CHANCE:
		soul_stones = 1
	if chest_type != "white":
		gold *= 3
	return {
		"opened": true,
		"chest": chest.duplicate(true),
		"items": items,
		"materials": materials,
		"gold": gold,
		"soul_stones": soul_stones,
		"quality_bonus": quality_bonus,
		"reason": chest_type
	}
