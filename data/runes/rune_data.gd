class_name RuneData
extends RefCounted

const RUNE_IDS: Array[String] = [
	"gold_gain",
	"xp_gain",
	"white_chest_rate",
	"boss_chest_quality",
	"party_attack",
	"party_hp",
	"all_resistance",
	"inventory_pages",
	"chest_capacity"
]

const RUNE_DEFINITIONS: Dictionary = {
	"gold_gain": {"name": "財富符文", "base_cost": 100, "max_level": 10, "effect": "gold_gain", "value": 0.10, "description": "金幣獲取 +10%／級"},
	"xp_gain": {"name": "求知符文", "base_cost": 120, "max_level": 10, "effect": "xp_gain", "value": 0.10, "description": "經驗獲取 +10%／級"},
	"white_chest_rate": {"name": "尋寶符文", "base_cost": 180, "max_level": 10, "effect": "white_chest_rate", "value": 0.10, "description": "白箱掉落率 +10%／級"},
	"boss_chest_quality": {"name": "掠奪符文", "base_cost": 260, "max_level": 10, "effect": "boss_chest_quality", "value": 0.05, "description": "首領箱品質 +5%／級"},
	"party_attack": {"name": "戰意符文", "base_cost": 300, "max_level": 10, "effect": "party_attack", "value": 0.03, "description": "全隊攻擊 +3%／級"},
	"party_hp": {"name": "生機符文", "base_cost": 300, "max_level": 10, "effect": "party_hp", "value": 0.03, "description": "全隊生命 +3%／級"},
	"all_resistance": {"name": "守護符文", "base_cost": 420, "max_level": 10, "effect": "all_resistance", "value": 0.01, "description": "全元素抗性 +1%／級"},
	"inventory_pages": {"name": "儲物符文", "base_cost": 500, "max_level": 4, "effect": "inventory_pages", "value": 1.0, "description": "背包頁數 +1（最多 5 頁）"},
	"chest_capacity": {"name": "收藏符文", "base_cost": 360, "max_level": 10, "effect": "chest_capacity", "value": 5.0, "description": "寶箱容量 +5／級"}
}

static func get_rune_ids() -> Array[String]:
	return RUNE_IDS.duplicate()

static func get_rune_definition(rune_id: String) -> Dictionary:
	if RUNE_DEFINITIONS.has(rune_id):
		return (RUNE_DEFINITIONS[rune_id] as Dictionary).duplicate(true)
	return {}

static func get_rune_name(rune_id: String) -> String:
	return str(get_rune_definition(rune_id).get("name", rune_id))
