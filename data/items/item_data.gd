class_name ItemData
extends RefCounted

const SLOT_IDS: Array[String] = ["weapon", "helmet", "chest", "gloves", "boots", "ring", "amulet"]
const RARITY_IDS: Array[String] = ["common", "uncommon", "rare", "epic", "immortal", "legendary", "transcendent"]

const SLOT_NAMES: Dictionary = {
	"weapon": "武器",
	"helmet": "頭盔",
	"chest": "胸甲",
	"gloves": "手套",
	"boots": "靴子",
	"ring": "戒指",
	"amulet": "項鍊"
}

const RARITIES: Dictionary = {
	"common": {
		"name": "普通",
		"color": Color(0.92, 0.92, 0.92),
		"weight": 60.0,
		"affix_count": 0,
		"multiplier": 1.0,
		"sockets": []
	},
	"uncommon": {
		"name": "優良",
		"color": Color(0.30, 0.90, 0.36),
		"weight": 25.0,
		"affix_count": 1,
		"multiplier": 1.1,
		"sockets": []
	},
	"rare": {
		"name": "稀有",
		"color": Color(0.25, 0.58, 1.0),
		"weight": 10.0,
		"affix_count": 2,
		"multiplier": 1.25,
		"sockets": ["decorative"]
	},
	"epic": {
		"name": "史詩",
		"color": Color(0.70, 0.32, 1.0),
		"weight": 3.5,
		"affix_count": 3,
		"multiplier": 1.45,
		"sockets": ["decorative", "decorative"]
	},
	"immortal": {
		"name": "不朽",
		"color": Color(1.0, 0.24, 0.24),
		"weight": 1.2,
		"affix_count": 3,
		"multiplier": 1.7,
		"sockets": ["decorative", "decorative", "engraving"]
	},
	"legendary": {
		"name": "傳奇",
		"color": Color(1.0, 0.52, 0.12),
		"weight": 0.28,
		"affix_count": 4,
		"multiplier": 2.0,
		"sockets": ["decorative", "decorative", "engraving", "engraving"]
	},
	"transcendent": {
		"name": "超凡",
		"color": Color(1.0, 0.84, 0.22),
		"weight": 0.02,
		"affix_count": 4,
		"multiplier": 2.4,
		"sockets": ["decorative", "decorative", "engraving", "engraving", "rune"]
	}
}

const WEAPON_SUBTYPES: Dictionary = {
	"sword": {
		"name": "劍",
		"classes": ["knight", "priest"],
		"icon": "artifact_f3_spinecleaver"
	},
	"staff": {
		"name": "杖",
		"classes": ["mage"],
		"icon": "artifact_f3_repairstaff"
	},
	"bow": {
		"name": "弓",
		"classes": ["ranger"],
		"icon": "artifact_f2_crescentspear"
	},
	"wand": {
		"name": "法器",
		"classes": ["mage"],
		"icon": "artifact_f2_spellfan"
	}
}

const SLOT_ICONS: Dictionary = {
	"helmet": "artifact_f2_maskofshadows",
	"chest": "artifact_f1_bigshield",
	"gloves": "artifact_f1_sunstonebracers",
	"boots": "artifact_f6_snowshovel",
	"ring": "artifact_f4_darkstonering",
	"amulet": "artifact_f2_unboundedenergyamulet"
}

const AFFIX_POOL: Array[Dictionary] = [
	{"id": "attack_percent", "name": "攻擊%", "stat": "attack_percent", "percent": true},
	{"id": "attack_speed_percent", "name": "攻速%", "stat": "attack_speed_percent", "percent": true},
	{"id": "crit_chance", "name": "暴擊率", "stat": "crit_chance", "percent": true},
	{"id": "crit_damage", "name": "暴擊傷害", "stat": "crit_damage", "percent": true},
	{"id": "max_hp", "name": "最大生命", "stat": "max_hp", "percent": false},
	{"id": "defense", "name": "防禦", "stat": "defense", "percent": false},
	{"id": "fire_resistance", "name": "火抗", "stat": "fire_resistance", "percent": true},
	{"id": "ice_resistance", "name": "冰抗", "stat": "ice_resistance", "percent": true},
	{"id": "lightning_resistance", "name": "電抗", "stat": "lightning_resistance", "percent": true},
	{"id": "chaos_resistance", "name": "混沌抗", "stat": "chaos_resistance", "percent": true},
	{"id": "life_steal", "name": "生命吸取", "stat": "life_steal", "percent": true},
	{"id": "gold_gain", "name": "金幣獲取%", "stat": "gold_gain", "percent": true},
	{"id": "xp_gain", "name": "經驗獲取%", "stat": "xp_gain", "percent": true}
]

static func get_slot_ids() -> Array[String]:
	var result: Array[String] = SLOT_IDS.duplicate()
	return result

static func get_rarity_ids() -> Array[String]:
	var result: Array[String] = RARITY_IDS.duplicate()
	return result

static func get_rarity_definition(rarity_id: String) -> Dictionary:
	if RARITIES.has(rarity_id):
		var definition: Dictionary = RARITIES[rarity_id]
		return definition.duplicate(true)
	return {}

static func get_slot_name(slot_id: String) -> String:
	return str(SLOT_NAMES.get(slot_id, slot_id))

static func get_rarity_name(rarity_id: String) -> String:
	return str(get_rarity_definition(rarity_id).get("name", rarity_id))

static func get_rarity_color(rarity_id: String) -> Color:
	return get_rarity_definition(rarity_id).get("color", Color.WHITE)

static func get_socket_layout(rarity_id: String) -> Array[String]:
	var layout: Array[String] = []
	var definition: Dictionary = get_rarity_definition(rarity_id)
	var raw_layout: Array = definition.get("sockets", [])
	for socket_type: String in raw_layout:
		layout.append(socket_type)
	return layout

static func get_weapon_subtypes_for_class(class_id: String) -> Array[String]:
	var result: Array[String] = []
	for subtype: String in WEAPON_SUBTYPES.keys():
		var definition: Dictionary = WEAPON_SUBTYPES[subtype]
		var classes: Array = definition.get("classes", [])
		if classes.has(class_id):
			result.append(subtype)
	return result

static func can_equip_item(item: Dictionary, class_id: String) -> bool:
	if item.is_empty():
		return false
	var restrictions: Array = item.get("classes", [])
	return restrictions.is_empty() or restrictions.has(class_id)

static func get_icon_id(item: Dictionary) -> String:
	var slot_id: String = str(item.get("slot", ""))
	if slot_id == "weapon":
		var subtype: String = str(item.get("subtype", "sword"))
		return str(WEAPON_SUBTYPES.get(subtype, {}).get("icon", "artifact_f3_spinecleaver"))
	return str(SLOT_ICONS.get(slot_id, "artifact_f1_bigshield"))
