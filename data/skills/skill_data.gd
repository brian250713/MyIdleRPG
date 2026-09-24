class_name SkillData
extends RefCounted

## Phase 3 技能數值表。
##
## 規則：
## - 每個主動技能消耗 1 技能點升 1 級；等級上限 5。
## - `cooldown` 以秒為單位，冷卻會被被動的 cooldown_reduction 縮短。
## - 傷害技能的 `base_value` 是攻擊力倍率；`repeat_count` 是同次施放的命中次數。
## - 治療、吸收、緩速和復活技能使用 `base_value` 的原始單位；被動的
##   heal_power、effect_radius_percent、elemental_damage_percent 會由核心套用。
## - 數值是 P3 的可調整基準，優先保持效果可讀、而不是追求最終平衡。

const MAX_SKILL_LEVEL: int = 5

static func get_all_definitions() -> Dictionary:
	var definitions: Dictionary = {}
	var skill_list: Array[Dictionary] = [
		_active("knight_shield_bash", "knight", "盾擊", "對目標造成物理傷害並短暫眩暈。", "stun", "physical", 8.0, 1.20, 0.15, 1.2, "icon_f1_aegisbarrier", "fx_impact", "enemy", 0.0, 1.0),
		_active("knight_taunt", "knight", "嘲諷", "強制附近怪物轉為攻擊自己。", "taunt", "physical", 10.0, 0.0, 0.0, 3.0, "generalspell_f1_roar", "fx_buff", "party", 110.0, 1.0),
		_active("knight_bulwark", "knight", "鐵壁", "短時間內吸收自身受到的傷害。", "damage_absorption", "physical", 14.0, 35.0, 8.0, 5.0, "generalspell_f1_kingsguard", "fx_buff", "self", 0.0, 0.0),
		_active("knight_holy_retribution", "knight", "聖光審判", "對自身周圍敵人造成範圍物理傷害。", "aoe", "physical", 12.0, 1.35, 0.12, 0.0, "icon_f1_holyimmolation", "fx_impact2", "self", 110.0, 0.0),
		_passive("knight_iron_will", "knight", "鋼鐵意志", "每級增加最大生命。", "max_hp", 18.0, 6.0, "生命 +18"),
		_passive("knight_damage_absorption", "knight", "受傷硬化", "每級減少 3% 受到的傷害。", "damage_absorption_percent", 0.03, 0.01, "受到傷害 -3%"),
		_passive("knight_defense_training", "knight", "防禦訓練", "每級增加 4% 防禦。", "defense_percent", 0.04, 0.015, "防禦 +4%"),
		_passive("knight_battle_focus", "knight", "戰鬥專注", "每級縮短 3% 主動技能冷卻。", "cooldown_reduction", 0.03, 0.01, "技能冷卻 -3%"),
		_active("priest_heal", "priest", "治癒", "治療生命比例最低的隊友。", "heal", "physical", 7.0, 0.35, 0.04, 0.0, "icon_f1_blessing", "fx_heal", "lowest_ally", 0.0, 0.0),
		_active("priest_might_blessing", "priest", "力量祝福", "短時間提高全隊攻擊力。", "party_buff", "physical", 16.0, 0.12, 0.015, 6.0, "icon_f1_lionheartblessing", "fx_buff", "party", 0.0, 0.0),
		_active("priest_sanctuary", "priest", "聖域", "為全隊提供傷害吸收。", "damage_absorption_party", "physical", 18.0, 0.20, 0.02, 5.0, "generalspell_f1_kingsguard", "fx_buff", "party", 0.0, 0.0),
		_active("priest_resurrect", "priest", "復活", "復活等級最高的死亡隊友。", "resurrect", "physical", 45.0, 0.50, 0.05, 0.0, "bossspell_restoringlight", "fx_heal", "dead_ally", 0.0, 0.0),
		_passive("priest_elemental_faith", "priest", "元素信仰", "每級增加所有元素抗性。", "all_resistance", 0.025, 0.01, "全抗性 +2.5%"),
		_passive("priest_mercy", "priest", "慈悲", "每級增加治療效果。", "heal_power", 0.08, 0.02, "治療效果 +8%"),
		_passive("priest_shroud", "priest", "禱言", "每級縮短 4% 主動技能冷卻。", "cooldown_reduction", 0.04, 0.015, "技能冷卻 -4%"),
		_passive("priest_consecration", "priest", "奉獻", "每級增加 3% 傷害吸收。", "damage_absorption_percent", 0.03, 0.01, "受到傷害 -3%"),
		_active("ranger_piercing_shot", "ranger", "穿透之箭", "射出貫穿直線上所有敵人的箭矢。", "pierce", "physical", 8.0, 1.80, 0.12, 0.0, "icon_f2_etherealblades", "fx_impact2", "line", 260.0, 0.0),
		_active("ranger_rapid_fire", "ranger", "快速射擊", "短時間內爆發攻擊速度。", "attack_speed_burst", "physical", 12.0, 2.0, 0.12, 4.0, "icon_f2_kagelightning", "fx_buff", "self", 0.0, 0.0),
		_active("ranger_multishot", "ranger", "多重射擊", "對範圍內敵人造成三次箭傷。", "aoe", "physical", 10.0, 1.25, 0.10, 0.0, "icon_f2_phoenixbarrage", "fx_impact", "enemy", 105.0, 3.0),
		_active("ranger_swift_awakening", "ranger", "迅捷覺醒", "短時間提高全隊攻速。", "party_buff", "physical", 20.0, 0.20, 0.02, 6.0, "icon_f6_lightningblitz", "fx_buff", "party", 0.0, 0.0),
		_passive("ranger_deadly_aim", "ranger", "致命瞄準", "每級增加暴擊率。", "crit_chance", 0.025, 0.01, "暴擊率 +2.5%"),
		_passive("ranger_blood_pact", "ranger", "血契", "每級增加生命吸取。", "life_steal", 0.02, 0.008, "生命吸取 +2%"),
		_passive("ranger_critical_edge", "ranger", "致命邊刃", "每級增加暴擊傷害。", "crit_damage", 0.06, 0.02, "暴擊傷害 +6%"),
		_passive("ranger_fast_hands", "ranger", "疾風手", "每級增加攻速。", "attack_speed_percent", 0.04, 0.015, "攻速 +4%"),
		_active("mage_fireball", "mage", "火球術", "對單一敵人造成火焰傷害。", "direct_damage", "fire", 5.0, 2.20, 0.18, 0.0, "icon_f2_ghost_lightning", "fx_fireimpact", "enemy", 0.0, 0.0),
		_active("mage_flame_hydra", "mage", "烈焰九頭蛇", "在目標區域造成三次火焰範圍傷害。", "aoe", "fire", 10.0, 1.50, 0.12, 3.0, "icon_f2_firestormofagony", "fx_fireimpact", "enemy", 125.0, 3.0),
		_active("mage_chain_lightning", "mage", "閃電術", "閃電貫穿直線上的所有敵人。", "pierce", "lightning", 9.0, 1.70, 0.12, 0.0, "icon_f6_lightningblitz", "fx_chainlightning", "line", 270.0, 0.0),
		_active("mage_blizzard", "mage", "暴風雪", "造成冰霜範圍傷害並減速敵人。", "slow", "ice", 12.0, 0.40, 0.03, 3.0, "icon_f6_snowstorm", "fx_impactblue", "enemy", 130.0, 3.0),
		_passive("mage_focus", "mage", "專注", "每級縮短 3% 主動技能冷卻。", "cooldown_reduction", 0.03, 0.01, "技能冷卻 -3%"),
		_passive("mage_arcane_reach", "mage", "奧術範圍", "每級增加 6% 技能效果半徑。", "effect_radius_percent", 0.06, 0.02, "技能範圍 +6%"),
		_passive("mage_elemental_affinity", "mage", "元素親和", "每級增加 4% 元素傷害。", "elemental_damage_percent", 0.04, 0.015, "元素傷害 +4%"),
		_passive("mage_arcane_flow", "mage", "魔力流動", "每級增加 3% 攻擊力。", "attack_percent", 0.03, 0.012, "攻擊力 +3%")
	]
	for skill: Dictionary in skill_list:
		definitions[str(skill.get("id", ""))] = skill
	return definitions

static func get_skill_definition(skill_id: String) -> Dictionary:
	var definition: Dictionary = get_all_definitions().get(skill_id, {})
	return definition.duplicate(true)

static func get_class_skills(class_id: String, kind: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: Dictionary in get_all_definitions().values():
		if str(definition.get("class_id", "")) != class_id:
			continue
		if not kind.is_empty() and str(definition.get("kind", "")) != kind:
			continue
		result.append(definition.duplicate(true))
	return result

static func get_active_skill_ids(class_id: String) -> Array[String]:
	var result: Array[String] = []
	for definition: Dictionary in get_class_skills(class_id, "active"):
		result.append(str(definition.get("id", "")))
	return result

static func get_passive_skill_ids(class_id: String) -> Array[String]:
	var result: Array[String] = []
	for definition: Dictionary in get_class_skills(class_id, "passive"):
		result.append(str(definition.get("id", "")))
	return result

static func get_skill_name(skill_id: String) -> String:
	return str(get_skill_definition(skill_id).get("name", skill_id))

static func get_skill_icon(skill_id: String) -> String:
	return str(get_skill_definition(skill_id).get("icon", "icon_f1_blessing"))

static func get_skill_fx(skill_id: String) -> String:
	return str(get_skill_definition(skill_id).get("fx", "fx_impact"))

static func _active(id: String, class_id: String, skill_name: String, description: String, effect_type: String, element: String, cooldown: float, base_value: float, value_per_level: float, duration: float, icon: String, fx: String, target: String, radius: float, repeat_count: float) -> Dictionary:
	return {
		"id": id,
		"class_id": class_id,
		"name": skill_name,
		"description": description,
		"kind": "active",
		"effect_type": effect_type,
		"element": element,
		"cooldown": cooldown,
		"skill_point_cost": 1,
		"max_level": MAX_SKILL_LEVEL,
		"base_value": base_value,
		"value_per_level": value_per_level,
		"duration": duration,
		"radius": radius,
		"repeat_count": repeat_count,
		"icon": icon,
		"fx": fx,
		"target": target
	}

static func _passive(id: String, class_id: String, skill_name: String, description: String, stat_id: String, base_value: float, value_per_level: float, effect_text: String) -> Dictionary:
	return {
		"id": id,
		"class_id": class_id,
		"name": skill_name,
		"description": description,
		"kind": "passive",
		"stat_id": stat_id,
		"base_value": base_value,
		"value_per_level": value_per_level,
		"effect_text": effect_text,
		"skill_point_cost": 1,
		"max_level": MAX_SKILL_LEVEL,
		"icon": "icon_f1_blessing",
		"fx": "fx_buff"
	}
