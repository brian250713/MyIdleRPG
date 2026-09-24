class_name MonsterData
extends RefCounted

static func get_monster_ids() -> Array[String]:
	var ids: Array[String] = [
		"neutral_gnasher", "neutral_ghostlynx", "neutral_giantcrab", "neutral_golemstone",
		"neutral_mercpirate", "neutral_mercmelee1", "neutral_monsterdragonhawk",
		"neutral_monsterlightningbeetle", "neutral_monstercrystalwisp", "neutral_prongbok",
		"boss_andromeda", "boss_chaosknight", "boss_legion"
	]
	return ids

static func get_monster_definition(monster_id: String) -> Dictionary:
	var definitions: Dictionary = _get_definitions()
	if definitions.has(monster_id):
		var definition: Dictionary = definitions[monster_id]
		return definition.duplicate(true)
	return {}

static func get_all_definitions() -> Dictionary:
	return _get_definitions()

static func get_regular_pool() -> Array[String]:
	return [
		"neutral_gnasher", "neutral_ghostlynx", "neutral_giantcrab", "neutral_golemstone",
		"neutral_mercpirate", "neutral_mercmelee1", "neutral_monsterdragonhawk",
		"neutral_monsterlightningbeetle", "neutral_monstercrystalwisp", "neutral_prongbok"
	]

static func _get_definitions() -> Dictionary:
	return {
		"neutral_gnasher": _unit("neutral_gnasher", "裂齒野獸", 86.0, 12.0, 54.0, 8.0, 1.00, 0.03, 8.0, 0.08),
		"neutral_ghostlynx": _unit("neutral_ghostlynx", "幽影貓", 72.0, 15.0, 58.0, 6.0, 1.18, 0.08, 5.0, 0.06),
		"neutral_giantcrab": _unit("neutral_giantcrab", "巨岩蟹", 132.0, 16.0, 48.0, 18.0, 0.82, 0.03, 11.0, 0.12),
		"neutral_golemstone": _unit("neutral_golemstone", "石魔", 164.0, 18.0, 42.0, 24.0, 0.72, 0.02, 9.0, 0.14),
		"neutral_mercpirate": _unit("neutral_mercpirate", "潮汐海盜", 98.0, 20.0, 60.0, 11.0, 1.08, 0.07, 7.0, 0.10),
		"neutral_mercmelee1": _unit("neutral_mercmelee1", "傭兵戰士", 108.0, 18.0, 62.0, 13.0, 0.98, 0.05, 7.0, 0.10),
		"neutral_monsterdragonhawk": _ranged_unit("neutral_monsterdragonhawk", "飛龍", 94.0, 21.0, 110.0, 9.0, 1.05, 0.06, 6.0, 0.08),
		"neutral_monsterlightningbeetle": _ranged_unit("neutral_monsterlightningbeetle", "雷甲蟲", 86.0, 22.0, 128.0, 7.0, 1.00, 0.05, 5.0, 0.06),
		"neutral_monstercrystalwisp": _ranged_unit("neutral_monstercrystalwisp", "水晶精靈", 78.0, 24.0, 138.0, 5.0, 0.92, 0.10, 4.0, 0.05),
		"neutral_prongbok": _unit("neutral_prongbok", "角鹿", 94.0, 17.0, 70.0, 9.0, 1.12, 0.04, 8.0, 0.09),
		"boss_andromeda": _boss("boss_andromeda", "安德羅墨達", 510.0, 30.0, 72.0, 22.0, 0.92, 0.08, 1.18),
		"boss_chaosknight": _boss("boss_chaosknight", "混沌騎士", 660.0, 38.0, 68.0, 28.0, 0.86, 0.10, 1.25),
		"boss_legion": _boss("boss_legion", "無限軍團", 820.0, 44.0, 76.0, 34.0, 0.78, 0.12, 1.32)
	}

static func _unit(sprite_id: String, unit_name: String, max_hp: float, attack: float, attack_range: float, defense: float, attack_speed: float, crit_chance: float, hp_growth: float, defense_growth: float) -> Dictionary:
	return {
		"name": unit_name,
		"sprite": sprite_id,
		"attack_type": "melee",
		"range": attack_range,
		"is_boss": false,
		"visual_scale": 0.90,
		"base_stats": {
			"max_hp": max_hp,
			"attack": attack,
			"attack_speed": attack_speed,
			"crit_chance": crit_chance,
			"crit_damage": 1.5,
			"defense": defense,
			"fire_resistance": 0.0,
			"ice_resistance": 0.0,
			"lightning_resistance": 0.0,
			"chaos_resistance": 0.0,
			"life_steal": 0.0
		},
		"growth": {
			"max_hp": hp_growth,
			"attack": 1.8,
			"attack_speed": 0.0,
			"crit_chance": 0.0,
			"crit_damage": 0.0,
			"defense": defense_growth,
			"fire_resistance": 0.0,
			"ice_resistance": 0.0,
			"lightning_resistance": 0.0,
			"chaos_resistance": 0.0,
			"life_steal": 0.0
		}
	}

static func _ranged_unit(sprite_id: String, unit_name: String, max_hp: float, attack: float, attack_range: float, defense: float, attack_speed: float, crit_chance: float, hp_growth: float, defense_growth: float) -> Dictionary:
	var definition: Dictionary = _unit(sprite_id, unit_name, max_hp, attack, attack_range, defense, attack_speed, crit_chance, hp_growth, defense_growth)
	definition["attack_type"] = "ranged"
	return definition

static func _boss(sprite_id: String, boss_name: String, max_hp: float, attack: float, attack_range: float, defense: float, attack_speed: float, crit_chance: float, visual_scale: float) -> Dictionary:
	var definition: Dictionary = _unit(sprite_id, boss_name, max_hp, attack, attack_range, defense, attack_speed, crit_chance, 42.0, 2.0)
	definition["is_boss"] = true
	definition["visual_scale"] = visual_scale
	definition["growth"]["attack"] = 3.8
	definition["growth"]["crit_damage"] = 0.015
	return definition
