class_name ClassData
extends RefCounted

static func get_class_ids() -> Array[String]:
	var ids: Array[String] = ["knight", "priest", "ranger", "mage"]
	return ids

static func get_class_definition(class_id: String) -> Dictionary:
	var definitions: Dictionary = _get_definitions()
	if definitions.has(class_id):
		var definition: Dictionary = definitions[class_id]
		return definition.duplicate(true)
	return {}

static func get_all_definitions() -> Dictionary:
	return _get_definitions()

static func get_default_element(class_id: String) -> String:
	return str(get_class_definition(class_id).get("element", "physical"))

static func _get_definitions() -> Dictionary:
	return {
		"knight": {
			"name": "騎士",
			"element": "physical",
			"sprite": "f1_general",
			"attack_type": "melee",
			"range": 82.0,
			"role": "坦",
			"visual_scale": 1.0,
			"base_stats": {
				"max_hp": 380.0,
				"attack": 38.0,
				"attack_speed": 1.05,
				"crit_chance": 0.05,
				"crit_damage": 1.5,
				"defense": 40.0,
				"fire_resistance": 0.10,
				"ice_resistance": 0.10,
				"lightning_resistance": 0.05,
				"chaos_resistance": 0.05,
				"life_steal": 0.0
			},
			"growth": {
				"max_hp": 25.0,
				"attack": 3.8,
				"attack_speed": 0.012,
				"crit_chance": 0.002,
				"crit_damage": 0.010,
				"defense": 3.0,
				"fire_resistance": 0.002,
				"ice_resistance": 0.002,
				"lightning_resistance": 0.001,
				"chaos_resistance": 0.001,
				"life_steal": 0.001
			}
		},
		"priest": {
			"name": "牧師",
			"element": "physical",
			"sprite": "f1_altgeneral",
			"attack_type": "melee",
			"range": 76.0,
			"role": "坦補",
			"visual_scale": 1.0,
			"base_stats": {
				"max_hp": 230.0,
				"attack": 22.0,
				"attack_speed": 0.95,
				"crit_chance": 0.04,
				"crit_damage": 1.5,
				"defense": 24.0,
				"fire_resistance": 0.12,
				"ice_resistance": 0.08,
				"lightning_resistance": 0.10,
				"chaos_resistance": 0.08,
				"life_steal": 0.0
			},
			"growth": {
				"max_hp": 19.0,
				"attack": 2.7,
				"attack_speed": 0.010,
				"crit_chance": 0.001,
				"crit_damage": 0.010,
				"defense": 2.1,
				"fire_resistance": 0.002,
				"ice_resistance": 0.002,
				"lightning_resistance": 0.002,
				"chaos_resistance": 0.002,
				"life_steal": 0.002
			}
		},
		"ranger": {
			"name": "遊俠",
			"element": "physical",
			"sprite": "f1_ranged",
			"attack_type": "ranged",
			"range": 245.0,
			"role": "主輸出",
			"visual_scale": 1.0,
			"base_stats": {
				"max_hp": 175.0,
				"attack": 34.0,
				"attack_speed": 1.15,
				"crit_chance": 0.12,
				"crit_damage": 1.65,
				"defense": 15.0,
				"fire_resistance": 0.05,
				"ice_resistance": 0.05,
				"lightning_resistance": 0.05,
				"chaos_resistance": 0.05,
				"life_steal": 0.0
			},
			"growth": {
				"max_hp": 14.0,
				"attack": 4.0,
				"attack_speed": 0.014,
				"crit_chance": 0.003,
				"crit_damage": 0.012,
				"defense": 1.4,
				"fire_resistance": 0.001,
				"ice_resistance": 0.001,
				"lightning_resistance": 0.001,
				"chaos_resistance": 0.001,
				"life_steal": 0.002
			}
		},
		"mage": {
			"name": "法師",
			"element": "fire",
			"sprite": "f2_caster",
			"attack_type": "ranged",
			"range": 265.0,
			"role": "控場 / AOE",
			"visual_scale": 1.0,
			"base_stats": {
				"max_hp": 160.0,
				"attack": 38.0,
				"attack_speed": 0.90,
				"crit_chance": 0.08,
				"crit_damage": 1.6,
				"defense": 11.0,
				"fire_resistance": 0.15,
				"ice_resistance": 0.15,
				"lightning_resistance": 0.15,
				"chaos_resistance": 0.10,
				"life_steal": 0.0
			},
			"growth": {
				"max_hp": 12.5,
				"attack": 4.5,
				"attack_speed": 0.010,
				"crit_chance": 0.002,
				"crit_damage": 0.012,
				"defense": 1.2,
				"fire_resistance": 0.002,
				"ice_resistance": 0.002,
				"lightning_resistance": 0.002,
				"chaos_resistance": 0.002,
				"life_steal": 0.0
			}
		}
	}
