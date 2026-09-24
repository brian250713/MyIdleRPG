class_name Skills
extends RefCounted

const DEFAULT_SKILL_POINTS_PER_LEVEL: int = 1
const MAX_CONTEXT_TARGETS: int = 64
const MAX_REPEAT_COUNT: int = 8

static func make_skill_state(_class_id: String = "") -> Dictionary:
	return {"skill_levels": {}, "equipped_actives": []}

static func normalize_skill_state(source: Dictionary, class_id: String) -> Dictionary:
	var normalized: Dictionary = make_skill_state(class_id)
	var skill_levels: Dictionary = {}
	var source_levels: Variant = source.get("skill_levels", {})
	if source_levels is Dictionary:
		for raw_skill_id: Variant in (source_levels as Dictionary).keys():
			var skill_id: String = str(raw_skill_id)
			var definition: Dictionary = SkillData.get_skill_definition(skill_id)
			if definition.is_empty():
				continue
			if str(definition.get("class_id", "")) != class_id:
				continue
			if str(definition.get("kind", "")) != "passive" and str(definition.get("kind", "")) != "active":
				continue
			skill_levels[skill_id] = clampi(int((source_levels as Dictionary).get(skill_id, 0)), 0, int(definition.get("max_level", 5)))
	normalized["skill_levels"] = skill_levels
	var equipped: Array[String] = []
	var source_equipped: Variant = source.get("equipped_actives", source.get("equipped_skills", source.get("equipped_active_skills", [])))
	if source_equipped is Array:
		for raw_skill_id: Variant in source_equipped:
			var skill_id: String = str(raw_skill_id)
			var definition: Dictionary = SkillData.get_skill_definition(skill_id)
			if definition.is_empty() or str(definition.get("class_id", "")) != class_id or str(definition.get("kind", "")) != "active":
				continue
			if int(skill_levels.get(skill_id, 0)) <= 0 or equipped.has(skill_id) or equipped.size() >= 2:
				continue
			equipped.append(skill_id)
	normalized["equipped_actives"] = equipped
	return normalized

static func get_skill_level(skill_state: Dictionary, skill_id: String) -> int:
	var source_levels: Variant = skill_state.get("skill_levels", skill_state)
	var skill_levels: Dictionary = source_levels if source_levels is Dictionary else {}
	return maxi(0, int(skill_levels.get(skill_id, 0)))

static func get_skill_point_cost(skill_id: String) -> int:
	var definition: Dictionary = SkillData.get_skill_definition(skill_id)
	return maxi(1, int(definition.get("skill_point_cost", 1))) if not definition.is_empty() else 0

static func get_skill_points_for_level(level: int) -> int:
	return maxi(0, level) * DEFAULT_SKILL_POINTS_PER_LEVEL

static func get_spent_points(skill_state: Dictionary) -> int:
	var total: int = 0
	var source_levels: Variant = skill_state.get("skill_levels", skill_state)
	var skill_levels: Dictionary = source_levels if source_levels is Dictionary else {}
	for raw_skill_id: Variant in skill_levels.keys():
		total += maxi(0, int(skill_levels[raw_skill_id]))
	return total

static func get_available_points(hero_level: int, skill_state: Dictionary) -> int:
	return maxi(0, get_skill_points_for_level(hero_level) - get_spent_points(skill_state))

static func upgrade_skill(skill_state: Dictionary, hero_level: int, skill_id: String, amount: int = 1) -> Dictionary:
	var definition: Dictionary = SkillData.get_skill_definition(skill_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_skill", "state": skill_state.duplicate(true), "points_spent": 0}
	var normalized: Dictionary = normalize_skill_state(skill_state, str(definition.get("class_id", "")))
	var current_level: int = get_skill_level(normalized, skill_id)
	var point_cost: int = get_skill_point_cost(skill_id)
	var max_safe_amount: int = int(definition.get("max_level", 5)) - current_level
	var safe_amount: int = clampi(amount, 0, max_safe_amount / maxi(1, point_cost))
	var available: int = get_available_points(hero_level, normalized)
	if safe_amount <= 0:
		return {"ok": false, "reason": "max_level", "state": normalized, "points_spent": 0}
	if safe_amount * point_cost > available:
		return {"ok": false, "reason": "not_enough_points", "state": normalized, "points_spent": 0}
	var skill_levels: Dictionary = normalized["skill_levels"]
	skill_levels[skill_id] = current_level + safe_amount * point_cost
	normalized["equipped_actives"] = _remove_invalid_equipped(normalized["equipped_actives"], normalized["skill_levels"])
	return {"ok": true, "reason": "upgraded", "state": normalized, "points_spent": safe_amount * point_cost}

static func equip_active_skill(skill_state: Dictionary, skill_id: String, slot_index: int) -> Dictionary:
	var definition: Dictionary = SkillData.get_skill_definition(skill_id)
	if definition.is_empty() or str(definition.get("kind", "")) != "active":
		return {"ok": false, "reason": "not_active", "state": skill_state.duplicate(true)}
	if slot_index < 0 or slot_index >= 2:
		return {"ok": false, "reason": "invalid_slot", "state": skill_state.duplicate(true)}
	var normalized: Dictionary = normalize_skill_state(skill_state, str(definition.get("class_id", "")))
	if get_skill_level(normalized, skill_id) <= 0:
		return {"ok": false, "reason": "skill_not_learned", "state": normalized}
	var equipped_value: Variant = normalized.get("equipped_actives", [])
	var equipped: Array = equipped_value.duplicate() if equipped_value is Array else []
	while equipped.size() < 2:
		equipped.append("")
	equipped[slot_index] = skill_id
	var unique_equipped: Array[String] = []
	for raw_skill_id: Variant in equipped:
		var equipped_id: String = str(raw_skill_id)
		if not equipped_id.is_empty() and not unique_equipped.has(equipped_id) and get_skill_level(normalized, equipped_id) > 0:
			unique_equipped.append(equipped_id)
	normalized["equipped_actives"] = unique_equipped
	return {"ok": true, "reason": "equipped", "state": normalized}

static func get_equipped_active_ids(skill_state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var equipped_value: Variant = skill_state.get("equipped_actives", [])
	if equipped_value is Array:
		for raw_skill_id: Variant in equipped_value:
			if result.size() >= 2:
				break
			var skill_id: String = str(raw_skill_id)
			var definition: Dictionary = SkillData.get_skill_definition(skill_id)
			if definition.is_empty() or str(definition.get("kind", "")) != "active":
				continue
			if not skill_id.is_empty() and get_skill_level(skill_state, skill_id) > 0 and not result.has(skill_id):
				result.append(skill_id)
	return result

static func get_passive_modifiers(class_id: String, skill_levels: Dictionary) -> Dictionary:
	var source_levels: Variant = skill_levels.get("skill_levels", skill_levels)
	var levels: Dictionary = source_levels if source_levels is Dictionary else {}
	var modifiers: Dictionary = {}
	for definition: Dictionary in SkillData.get_class_skills(class_id, "passive"):
		var skill_id: String = str(definition.get("id", ""))
		var level: int = clampi(int(levels.get(skill_id, 0)), 0, int(definition.get("max_level", 5)))
		if level <= 0:
			continue
		var stat_id: String = str(definition.get("stat_id", ""))
		if stat_id.is_empty():
			continue
		var value: float = float(definition.get("base_value", 0.0)) + float(definition.get("value_per_level", 0.0)) * float(level - 1)
		modifiers[stat_id] = float(modifiers.get(stat_id, 0.0)) + value
	return modifiers

static func get_effect_definition(skill_id: String, level: int) -> Dictionary:
	var definition: Dictionary = SkillData.get_skill_definition(skill_id)
	if definition.is_empty():
		return {}
	var safe_level: int = clampi(level, 1, int(definition.get("max_level", 5)))
	var effect: Dictionary = definition.duplicate(true)
	effect["level"] = safe_level
	effect["value"] = float(definition.get("base_value", 0.0)) + float(definition.get("value_per_level", 0.0)) * float(safe_level - 1)
	effect["cooldown"] = maxf(0.1, float(definition.get("cooldown", 1.0)))
	effect["radius"] = maxf(0.0, float(definition.get("radius", 0.0)))
	effect["duration"] = maxf(0.0, float(definition.get("duration", 0.0)))
	effect["repeat_count"] = clampi(int(definition.get("repeat_count", 1)), 1, MAX_REPEAT_COUNT)
	return effect

static func get_cooldown_seconds(effect: Dictionary, passive_modifiers: Dictionary = {}) -> float:
	var cooldown: float = maxf(0.1, float(effect.get("cooldown", 1.0)))
	var reduction: float = clampf(float(passive_modifiers.get("cooldown_reduction", 0.0)), 0.0, 0.75)
	return maxf(0.1, cooldown * (1.0 - reduction))

static func can_auto_cast(skill_id: String, context: Dictionary) -> bool:
	var definition: Dictionary = SkillData.get_skill_definition(skill_id)
	if definition.is_empty() or str(definition.get("kind", "")) != "active":
		return false
	var allies: Array = _context_array(context, "allies")
	var enemies: Array = _context_array(context, "enemies")
	match str(definition.get("effect_type", "")):
		"heal":
			return _find_lowest_living_ratio(allies) < 0.60
		"resurrect":
			return _has_dead_ally(allies)
		"taunt":
			return not enemies.is_empty() and bool(context.get("non_tank_targeted", not _context_has_non_tank(context)))
		"damage_absorption":
			return float(context.get("caster_hp_ratio", 1.0)) < 0.82 or bool(context.get("boss_active", false))
		"damage_absorption_party":
			return not allies.is_empty() and (float(context.get("party_hp_ratio", 1.0)) < 0.80 or bool(context.get("boss_active", false)))
		"party_buff":
			return not allies.is_empty()
		"attack_speed_burst":
			return float(context.get("caster_hp_ratio", 1.0)) > 0.0
		_:
			return not enemies.is_empty()

static func choose_auto_skill(skill_state: Dictionary, _hero_level: int, context: Dictionary, cooldown_state: Dictionary) -> String:
	var equipped: Array[String] = get_equipped_active_ids(skill_state)
	for skill_id: String in equipped:
		var effect: Dictionary = get_effect_definition(skill_id, get_skill_level(skill_state, skill_id))
		if effect.is_empty():
			continue
		var cooldown_key: String = str(skill_id)
		if float(cooldown_state.get(cooldown_key, 0.0)) > 0.0:
			continue
		if can_auto_cast(skill_id, context):
			return skill_id
	return ""

static func cast_skill(skill_id: String, level: int, context: Dictionary, passive_modifiers: Dictionary = {}) -> Dictionary:
	var effect: Dictionary = get_effect_definition(skill_id, level)
	if effect.is_empty() or str(effect.get("kind", "active")) != "active":
		return {"ok": false, "reason": "unknown_or_inactive_skill", "targets": []}
	var effect_type: String = str(effect.get("effect_type", ""))
	var caster: Dictionary = context.get("caster", {}) if context.get("caster", {}) is Dictionary else {}
	var caster_stats: Dictionary = caster.get("stats", {}) if caster.get("stats", {}) is Dictionary else {}
	var attack: float = maxf(0.0, float(caster_stats.get("attack", 0.0)))
	var radius_multiplier: float = 1.0 + maxf(0.0, float(passive_modifiers.get("effect_radius_percent", 0.0)))
	effect["radius"] = float(effect.get("radius", 0.0)) * radius_multiplier
	var targets: Array = _targets_for_effect(effect, context)
	var result: Dictionary = {
		"ok": true,
		"skill_id": skill_id,
		"name": str(effect.get("name", skill_id)),
		"effect_type": effect_type,
		"element": CombatMath.normalize_element(str(effect.get("element", "physical"))),
		"icon": str(effect.get("icon", "")),
		"fx": str(effect.get("fx", "fx_impact")),
		"value": float(effect.get("value", 0.0)),
		"duration": float(effect.get("duration", 0.0)),
		"radius": float(effect.get("radius", 0.0)),
		"repeat_count": int(effect.get("repeat_count", 1)),
		"cooldown": get_cooldown_seconds(effect, passive_modifiers),
		"targets": targets
	}
	var rng_value: Variant = context.get("rng", null)
	var rng: RandomNumberGenerator = rng_value as RandomNumberGenerator
	match effect_type:
		"direct_damage", "stun", "pierce", "aoe", "slow":
			var is_pierce: bool = effect_type == "pierce"
			_add_damage_to_targets(
				result,
				targets,
				attack * float(effect.get("value", 1.0)),
				str(effect.get("element", "physical")),
				is_pierce,
				float(caster_stats.get("crit_chance", 0.0)),
				float(caster_stats.get("crit_damage", 1.5)),
				rng,
				int(effect.get("repeat_count", 1)),
				float(passive_modifiers.get("elemental_damage_percent", 0.0))
			)
			if effect_type == "stun":
				result["stun_duration"] = float(effect.get("duration", 1.0))
			elif effect_type == "slow":
				result["slow_multiplier"] = clampf(1.0 - float(effect.get("value", 0.4)), 0.10, 1.0)
				result["status_targets"] = _copy_context_values(targets)
		"taunt":
			result["taunt_duration"] = float(effect.get("duration", 3.0))
			result["taunt_target_id"] = str(caster.get("id", ""))
		"heal":
			result["targets"] = []
			var heal_target: Dictionary = _find_lowest_living(allies_from_context(context))
			if not heal_target.is_empty():
				var max_heal: float = maxf(0.0, float(heal_target.get("max_hp", 1.0)) - float(heal_target.get("hp", 0.0)))
				var heal_amount: float = minf(max_heal, maxf(1.0, float(heal_target.get("max_hp", 1.0)) * float(effect.get("value", 0.0)) * (1.0 + maxf(0.0, float(passive_modifiers.get("heal_power", 0.0))))))
				result["targets"] = [{"id": str(heal_target.get("id", "")), "position": heal_target.get("position", Vector2.ZERO), "amount": int(round(heal_amount)), "hp_ratio": float(heal_target.get("hp", 0.0)) / maxf(1.0, float(heal_target.get("max_hp", 1.0)))}]
		"party_buff":
			result["stat_id"] = _active_buff_stat(skill_id)
			result["stat_value"] = float(effect.get("value", 0.0))
			result["aura"] = true
			result["targets"] = _copy_context_values(targets)
		"attack_speed_burst":
			result["targets"] = [{"id": str(caster.get("id", "")), "position": caster.get("position", Vector2.ZERO), "multiplier": maxf(1.0, float(effect.get("value", 1.0))), "duration": float(effect.get("duration", 0.0))}]
		"damage_absorption":
			result["targets"] = [{"id": str(caster.get("id", "")), "position": caster.get("position", Vector2.ZERO), "amount": maxf(0.0, float(effect.get("value", 0.0))), "duration": float(effect.get("duration", 0.0))}]
		"damage_absorption_party":
			# 不要把結果 append 回 context 的 allies 陣列，否則會在迭代時無限增長。
			var absorption_targets: Array = _copy_context_values(allies_from_context(context))
			result["targets"] = []
			for ally: Dictionary in absorption_targets:
				result["targets"].append({"id": str(ally.get("id", "")), "position": ally.get("position", Vector2.ZERO), "amount": float(effect.get("value", 0.0)) * maxf(1.0, float(ally.get("max_hp", 1.0))) * 0.01, "duration": float(effect.get("duration", 0.0))})
		"resurrect":
			result["targets"] = []
			var dead_target: Dictionary = _find_best_dead_ally(allies_from_context(context))
			if not dead_target.is_empty():
				result["targets"] = [{"id": str(dead_target.get("id", "")), "position": dead_target.get("position", Vector2.ZERO), "hp_ratio": clampf(float(effect.get("value", 0.5)), 0.1, 1.0)}]
		_:
			result["ok"] = false
			result["reason"] = "unsupported_effect"
	return result

static func _targets_for_effect(effect: Dictionary, context: Dictionary) -> Array:
	var effect_type: String = str(effect.get("effect_type", ""))
	var enemies: Array = _context_array(context, "enemies")
	var target_value: Variant = context.get("target", {})
	var target: Dictionary = target_value if target_value is Dictionary else {}
	if effect_type == "heal" or effect_type == "party_buff" or effect_type == "damage_absorption_party" or effect_type == "resurrect":
		return _copy_context_values(_context_array(context, "allies"))
	if effect_type == "attack_speed_burst" or effect_type == "damage_absorption":
		return []
	if effect_type == "taunt":
		if not target.is_empty():
			return [target.duplicate(true)]
		return [] if enemies.is_empty() else [enemies[0].duplicate(true)]
	if effect_type == "pierce":
		var line_value: Variant = context.get("line_enemies", [])
		var line_source: Array = line_value if line_value is Array else enemies
		var caster_value: Variant = context.get("caster", {})
		var caster: Dictionary = caster_value if caster_value is Dictionary else {}
		var caster_position: Vector2 = _position_from(caster)
		var line_width: float = maxf(1.0, float(effect.get("line_width", 48.0)))
		var line_targets: Array = []
		for enemy: Dictionary in _copy_context_values(line_source):
			if absf(_position_from(enemy).y - caster_position.y) <= line_width:
				line_targets.append(enemy)
		return line_targets if not line_targets.is_empty() else _copy_context_values(enemies)
	if effect_type == "aoe" or effect_type == "slow":
		var center: Vector2 = _position_from(target)
		if str(effect.get("target", "enemy")) == "self":
			var caster_value: Variant = context.get("caster", {})
			if caster_value is Dictionary:
				center = _position_from(caster_value as Dictionary)
		var radius: float = maxf(0.0, float(effect.get("radius", 0.0)))
		var selected: Array = []
		for enemy: Dictionary in _copy_context_values(enemies):
			var distance: float = center.distance_to(_position_from(enemy))
			if radius <= 0.0 or distance <= radius:
				selected.append(enemy)
		if selected.is_empty() and not target.is_empty():
			selected.append(target.duplicate(true))
		return selected
	if target.is_empty() and not enemies.is_empty():
		return [enemies[0].duplicate(true)]
	return [] if target.is_empty() else [target.duplicate(true)]

static func _add_damage_to_targets(result: Dictionary, targets: Array, attack: float, element: String, pierce: bool, crit_chance: float = 0.0, crit_damage: float = 1.5, rng: RandomNumberGenerator = null, repeat_count: int = 1, elemental_damage_percent: float = 0.0) -> void:
	var hits: Array = []
	var safe_targets: Array = _copy_context_values(targets)
	var safe_element: String = CombatMath.normalize_element(element)
	var element_multiplier: float = 1.0
	if safe_element != "physical":
		element_multiplier += maxf(0.0, elemental_damage_percent)
	for target: Dictionary in safe_targets:
		var target_stats: Dictionary = target.get("stats", {}) if target.get("stats", {}) is Dictionary else {}
		for _hit_index: int in range(clampi(repeat_count, 1, MAX_REPEAT_COUNT)):
			var damage_attack: float = maxf(0.0, attack) * element_multiplier
			var damage: Dictionary = CombatMath.calculate_damage_for_target(damage_attack, target_stats, crit_chance, crit_damage, rng, safe_element)
			hits.append({"id": str(target.get("id", "")), "amount": int(damage.get("amount", 1)), "element": safe_element, "crit": bool(damage.get("is_crit", false)), "mitigation": float(damage.get("mitigation", 1.0))})
	result["hits"] = hits
	result["pierce"] = pierce
	result["targets"] = hits

static func allies_from_context(context: Dictionary) -> Array:
	return _copy_context_values(_context_array(context, "allies"))

static func _context_array(context: Dictionary, key: String) -> Array:
	var value: Variant = context.get(key, [])
	return value if value is Array else []

static func _copy_context_values(source: Array) -> Array:
	var result: Array = []
	var count: int = mini(source.size(), MAX_CONTEXT_TARGETS)
	for index: int in range(count):
		var value: Variant = source[index]
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result

static func _position_from(value: Dictionary) -> Vector2:
	var raw_position: Variant = value.get("position", Vector2.ZERO)
	return raw_position if raw_position is Vector2 else Vector2.ZERO

static func _find_lowest_living_ratio(allies: Array) -> float:
	var lowest: float = 1.0
	for ally: Dictionary in allies:
		if bool(ally.get("is_dead", false)) or float(ally.get("hp", 0.0)) <= 0.0:
			continue
		lowest = minf(lowest, float(ally.get("hp", 0.0)) / maxf(1.0, float(ally.get("max_hp", 1.0))))
	return lowest

static func _find_lowest_living(allies: Array) -> Dictionary:
	var result: Dictionary = {}
	var lowest_ratio: float = 1.1
	for ally: Dictionary in allies:
		if bool(ally.get("is_dead", false)) or float(ally.get("hp", 0.0)) <= 0.0:
			continue
		var ratio: float = float(ally.get("hp", 0.0)) / maxf(1.0, float(ally.get("max_hp", 1.0)))
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			result = ally
	return result

static func _has_dead_ally(allies: Array) -> bool:
	return not _find_dead_ally(allies).is_empty()

static func _find_dead_ally(allies: Array) -> Dictionary:
	for ally: Dictionary in allies:
		if bool(ally.get("is_dead", false)) or float(ally.get("hp", 0.0)) <= 0.0:
			return ally
	return {}

static func _find_best_dead_ally(allies: Array) -> Dictionary:
	var result: Dictionary = {}
	var best_level: int = -1
	for ally: Dictionary in allies:
		if not bool(ally.get("is_dead", false)) and float(ally.get("hp", 0.0)) > 0.0:
			continue
		var level: int = int(ally.get("level", 1))
		if level > best_level:
			best_level = level
			result = ally
	return result

static func _active_buff_stat(skill_id: String) -> String:
	if skill_id == "ranger_swift_awakening":
		return "attack_speed_percent"
	return "attack_percent"

static func _context_has_non_tank(context: Dictionary) -> bool:
	var targeted_value: Variant = context.get("targeted_units", [])
	if targeted_value is Array:
		for target: Dictionary in targeted_value:
			if not bool(target.get("is_tank", false)):
				return true
	return false

static func _remove_invalid_equipped(equipped_value: Variant, skill_levels: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not (equipped_value is Array):
		return result
	for raw_skill_id: Variant in equipped_value:
		if result.size() >= 2:
			break
		var skill_id: String = str(raw_skill_id)
		var definition: Dictionary = SkillData.get_skill_definition(skill_id)
		if not skill_id.is_empty() and str(definition.get("kind", "")) == "active" and not result.has(skill_id) and int(skill_levels.get(skill_id, 0)) > 0:
			result.append(skill_id)
	return result
