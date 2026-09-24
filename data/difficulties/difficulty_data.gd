class_name DifficultyData
extends RefCounted

const DIFFICULTY_IDS: Array[String] = ["normal", "nightmare", "hell", "torture"]

static func get_difficulty_ids() -> Array[String]:
	return DIFFICULTY_IDS.duplicate()

static func normalize_difficulty_id(difficulty_id: String) -> String:
	return difficulty_id if DIFFICULTY_IDS.has(difficulty_id) else "normal"

static func get_difficulty_definition(difficulty_id: String) -> Dictionary:
	var definitions: Dictionary = {
		"normal": {
			"id": "normal",
			"name": "普通",
			"level_offset": 0,
			"stat_multiplier": 1.0,
			"description": "基礎難度，適合第一次組隊冒險。",
			"element_pool": ["physical", "fire", "ice", "lightning", "chaos"]
		},
		"nightmare": {
			"id": "nightmare",
			"name": "噩夢",
			"level_offset": 30,
			"stat_multiplier": 3.0,
			"description": "怪物等級 +30、強度 3 倍，並加入火焰與混沌重傷怪。",
			"element_pool": ["physical", "fire", "ice", "lightning", "chaos"]
		},
		"hell": {
			"id": "hell",
			"name": "地獄",
			"level_offset": 60,
			"stat_multiplier": 8.0,
			"description": "怪物等級 +60、強度 8 倍，元素傷害更加致命。",
			"element_pool": ["physical", "fire", "ice", "lightning", "chaos"]
		},
		"torture": {
			"id": "torture",
			"name": "折磨",
			"level_offset": 80,
			"stat_multiplier": 20.0,
			"description": "怪物等級 +80、強度 20 倍，只有完全成形的隊伍才適合挑戰。",
			"element_pool": ["physical", "fire", "ice", "lightning", "chaos"]
		}
	}
	var normalized_id: String = normalize_difficulty_id(difficulty_id)
	if definitions.has(normalized_id):
		var definition: Dictionary = definitions[normalized_id]
		return definition.duplicate(true)
	return get_difficulty_definition("normal")

static func get_difficulty_name(difficulty_id: String) -> String:
	return str(get_difficulty_definition(difficulty_id).get("name", difficulty_id))

static func get_level_offset(difficulty_id: String) -> int:
	return int(get_difficulty_definition(difficulty_id).get("level_offset", 0))

static func get_stat_multiplier(difficulty_id: String) -> float:
	return maxf(0.0, float(get_difficulty_definition(difficulty_id).get("stat_multiplier", 1.0)))
