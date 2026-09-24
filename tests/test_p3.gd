extends RefCounted

func test_element_mitigation_and_resistance_cap() -> bool:
	var physical: Dictionary = CombatMath.calculate_damage(100.0, 100.0, 0.0, 1.5, null, "physical", 0.0)
	var fire: Dictionary = CombatMath.calculate_damage(100.0, 100.0, 0.0, 1.5, null, "fire", 0.75)
	var over_capped: Dictionary = CombatMath.calculate_damage(100.0, 100.0, 0.0, 1.5, null, "fire", 2.0)
	return int(physical["amount"]) == 50 and int(fire["amount"]) == 25 and int(over_capped["amount"]) == 25 and is_equal_approx(float(fire["resistance"]), 0.75)

func test_elements_are_declared_for_classes_and_monsters() -> bool:
	for class_id: String in ClassData.get_class_ids():
		if not CombatMath.ELEMENTS.has(ClassData.get_default_element(class_id)):
			return false
	for monster_id: String in ["neutral_gnasher", "fire_drake", "chaos_reaver", "boss_legion"]:
		if not CombatMath.ELEMENTS.has(MonsterData.get_element(monster_id)):
			return false
	return ClassData.get_default_element("mage") == "fire" and MonsterData.get_element("chaos_reaver") == "chaos"

func test_all_skill_effects_execute_at_core_level() -> bool:
	var expected_types: Dictionary = {
		"direct_damage": true,
		"stun": true,
		"taunt": true,
		"damage_absorption": true,
		"aoe": true,
		"heal": true,
		"party_buff": true,
		"damage_absorption_party": true,
		"resurrect": true,
		"pierce": true,
		"attack_speed_burst": true,
		"slow": true
	}
	var seen_types: Dictionary = {}
	for class_id: String in ClassData.get_class_ids():
		var active_skills: Array[Dictionary] = SkillData.get_class_skills(class_id, "active")
		if active_skills.size() != 4 or SkillData.get_class_skills(class_id, "passive").size() != 4:
			return false
		for definition: Dictionary in active_skills:
			var result: Dictionary = Skills.cast_skill(str(definition.get("id", "")), 1, _make_skill_context(), {})
			if not bool(result.get("ok", false)) or not _effect_result_is_valid(str(result.get("effect_type", "")), result):
				return false
			seen_types[str(result.get("effect_type", ""))] = true
	return seen_types.size() == expected_types.size()

func test_skill_values_repeat_hits_and_passive_effects() -> bool:
	var context: Dictionary = _make_skill_context()
	var fireball_level_one: Dictionary = Skills.cast_skill("mage_fireball", 1, context, {})
	var fireball_level_five: Dictionary = Skills.cast_skill("mage_fireball", 5, context, {})
	var hydra: Dictionary = Skills.cast_skill("mage_flame_hydra", 1, context, {})
	var radius_definition: Dictionary = SkillData.get_skill_definition("mage_blizzard")
	var radius_modifiers: Dictionary = {"effect_radius_percent": 0.10}
	var blizzard: Dictionary = Skills.cast_skill("mage_blizzard", 1, context, radius_modifiers)
	var elemental_modifiers: Dictionary = {"elemental_damage_percent": 0.50}
	var stronger_fireball: Dictionary = Skills.cast_skill("mage_fireball", 1, context, elemental_modifiers)
	return int((fireball_level_five["hits"] as Array)[0]["amount"]) > int((fireball_level_one["hits"] as Array)[0]["amount"]) and (hydra["hits"] as Array).size() >= 3 and float(blizzard["radius"]) > float(radius_definition["radius"]) and int((stronger_fireball["hits"] as Array)[0]["amount"]) > int((fireball_level_one["hits"] as Array)[0]["amount"])

func test_skill_points_and_equipped_actives() -> bool:
	var skill_state: Dictionary = Skills.make_skill_state("knight")
	var first_upgrade: Dictionary = Skills.upgrade_skill(skill_state, 1, "knight_shield_bash")
	if not bool(first_upgrade.get("ok", false)) or Skills.get_available_points(1, first_upgrade["state"]) != 0:
		return false
	var no_points: Dictionary = Skills.upgrade_skill(first_upgrade["state"], 1, "knight_taunt")
	if bool(no_points.get("ok", false)):
		return false
	var level_five: Dictionary = Skills.upgrade_skill(first_upgrade["state"], 5, "knight_taunt", 1)
	var equip_result: Dictionary = Skills.equip_active_skill(level_five["state"], "knight_taunt", 0)
	var equipped: Array[String] = Skills.get_equipped_active_ids(equip_result["state"])
	return equipped.size() == 1 and equipped[0] == "knight_taunt" and Skills.get_skill_level(equip_result["state"], "knight_taunt") == 1

func test_passives_use_stat_pipeline() -> bool:
	var skill_state: Dictionary = Skills.make_skill_state("knight")
	var levels: Dictionary = skill_state["skill_levels"]
	levels["knight_iron_will"] = 1
	levels["priest_elemental_faith"] = 1
	skill_state["skill_levels"] = levels
	var base_stats: Dictionary = Stats.calculate_class_stats("knight", 1)
	var final_stats: Dictionary = Stats.calculate_final_stats("knight", 1, {}, skill_state)
	var priest_skill_state: Dictionary = Skills.make_skill_state("priest")
	var priest_levels: Dictionary = priest_skill_state["skill_levels"]
	priest_levels["priest_elemental_faith"] = 1
	priest_skill_state["skill_levels"] = priest_levels
	var priest_stats: Dictionary = Stats.calculate_final_stats("priest", 1, {}, priest_skill_state)
	return float(final_stats["max_hp"]) > float(base_stats["max_hp"]) and float(priest_stats["fire_resistance"]) > float(Stats.calculate_class_stats("priest", 1)["fire_resistance"])

func test_skill_auto_cast_conditions() -> bool:
	var skill_state: Dictionary = Skills.make_skill_state("priest")
	var levels: Dictionary = skill_state["skill_levels"]
	levels["priest_heal"] = 1
	levels["priest_resurrect"] = 1
	skill_state["skill_levels"] = levels
	skill_state["equipped_actives"] = ["priest_heal", "priest_resurrect"]
	var hurt_context: Dictionary = _make_skill_context()
	hurt_context["allies"] = [{"id": "ally_1", "hp": 50.0, "max_hp": 100.0, "is_dead": false}]
	var full_context: Dictionary = _make_skill_context()
	full_context["allies"] = [{"id": "ally_1", "hp": 100.0, "max_hp": 100.0, "is_dead": false}]
	var dead_context: Dictionary = _make_skill_context()
	dead_context["allies"] = [{"id": "ally_1", "hp": 100.0, "max_hp": 100.0, "is_dead": false}, {"id": "ally_2", "hp": 0.0, "max_hp": 100.0, "is_dead": true}]
	return Skills.choose_auto_skill(skill_state, 1, hurt_context, {}) == "priest_heal" and Skills.choose_auto_skill(skill_state, 1, full_context, {}) == "" and Skills.choose_auto_skill(skill_state, 1, dead_context, {}) == "priest_resurrect"

func test_difficulty_scaling_and_unlock() -> bool:
	var nightmare: Dictionary = StageData.get_stage_by_index(0, "nightmare")
	var hell: Dictionary = StageData.get_stage_by_index(0, "hell")
	var torture: Dictionary = StageData.get_stage_by_index(0, "torture")
	var nightmare_pool: Array = nightmare.get("monster_pool", [])
	var unlocked: Array[String] = Difficulty.unlock_after_stage("normal", Difficulty.FINAL_STAGE_INDEX, ["normal"])
	var hell_unlocked: Array[String] = Difficulty.unlock_after_stage("nightmare", Difficulty.FINAL_STAGE_INDEX, ["normal", "nightmare"])
	return int(nightmare["recommended_level"]) == 31 and int(hell["recommended_level"]) == 61 and int(torture["recommended_level"]) == 81 and is_equal_approx(Difficulty.get_stat_multiplier("nightmare"), 3.0) and is_equal_approx(Difficulty.get_stat_multiplier("hell"), 8.0) and is_equal_approx(Difficulty.get_stat_multiplier("torture"), 20.0) and nightmare_pool.has("fire_drake") and nightmare_pool.has("chaos_reaver") and unlocked.has("nightmare") and hell_unlocked.has("hell") and not Difficulty.unlock_after_stage("normal", 28, ["normal"]).has("nightmare")

func test_v2_to_v3_save_migration() -> bool:
	var old_state: Dictionary = {
		"version": 2,
		"gold": 456,
		"current_stage": 7,
		"unlocked_stage": 7,
		"party": [{"class_id": "knight", "level": 4, "xp": 12, "skills": {"skill_levels": {"knight_shield_bash": 2, "knight_taunt": 1}, "equipped_actives": ["knight_shield_bash", "knight_taunt"]}}, null, null],
		"settings": {"auto_advance": false}
	}
	var migrated: Dictionary = SaveCodec.normalize_state(old_state)
	var hero: Dictionary = (migrated["party"] as Array)[0]
	var skills: Dictionary = hero.get("skills", {})
	var progress: Dictionary = migrated.get("difficulty_progress", {})
	return int(migrated["version"]) == SaveCodec.VERSION and str(migrated["difficulty"]) == "normal" and int(progress["normal"]) == 7 and int(skills["skill_levels"]["knight_shield_bash"]) == 2 and (skills["equipped_actives"] as Array).size() == 2

func test_v3_save_round_trip_includes_skills_and_difficulty() -> bool:
	var state: Dictionary = SaveCodec.make_default_state()
	state["difficulty"] = "nightmare"
	state["unlocked_difficulties"] = ["normal", "nightmare"]
	state["difficulty_progress"] = {"normal": 29, "nightmare": 4, "hell": 0, "torture": 0}
	state["current_stage"] = 4
	state["unlocked_stage"] = 4
	state["party"][0]["skills"] = {"skill_levels": {"knight_shield_bash": 2}, "equipped_actives": ["knight_shield_bash"]}
	var decoded: Dictionary = SaveCodec.state_from_json(SaveCodec.state_to_json(state))
	var hero: Dictionary = (decoded["party"] as Array)[0]
	var skills: Dictionary = hero.get("skills", {})
	return int(decoded["version"]) == SaveCodec.VERSION and str(decoded["difficulty"]) == "nightmare" and int((decoded["difficulty_progress"] as Dictionary)["nightmare"]) == 4 and int((skills["skill_levels"] as Dictionary)["knight_shield_bash"]) == 2 and (skills["equipped_actives"] as Array).size() == 1

func _effect_result_is_valid(effect_type: String, result: Dictionary) -> bool:
	var hits: Array = result.get("hits", [])
	var targets: Array = result.get("targets", [])
	match effect_type:
		"direct_damage", "stun", "aoe", "pierce", "slow":
			if hits.is_empty():
				return false
		"taunt":
			if targets.is_empty() or float(result.get("taunt_duration", 0.0)) <= 0.0:
				return false
		"damage_absorption":
			if targets.is_empty() or float(targets[0].get("amount", 0.0)) <= 0.0:
				return false
		"heal":
			if targets.is_empty() or int(targets[0].get("amount", 0)) <= 0:
				return false
		"party_buff":
			if not bool(result.get("aura", false)) or str(result.get("stat_id", "")).is_empty():
				return false
		"damage_absorption_party":
			if targets.size() != 2:
				return false
		"resurrect":
			if targets.size() != 1:
				return false
		"attack_speed_burst":
			if targets.is_empty() or float(targets[0].get("multiplier", 1.0)) <= 1.0:
				return false
		"slow":
			if (result.get("status_targets", []) as Array).is_empty() or float(result.get("slow_multiplier", 1.0)) >= 1.0:
				return false
		_:
			return false
	return true

func _make_skill_context() -> Dictionary:
	var enemies: Array = [
		{"id": "enemy_1", "position": Vector2(100.0, 0.0), "hp": 100.0, "max_hp": 100.0, "is_dead": false, "stats": {"defense": 10.0, "fire_resistance": 0.0, "ice_resistance": 0.0, "lightning_resistance": 0.0, "chaos_resistance": 0.0}},
		{"id": "enemy_2", "position": Vector2(160.0, 0.0), "hp": 80.0, "max_hp": 80.0, "is_dead": false, "stats": {"defense": 10.0}}
	]
	var allies: Array = [
		{"id": "ally_1", "position": Vector2.ZERO, "hp": 50.0, "max_hp": 100.0, "is_dead": false, "stats": {"attack": 20.0}},
		{"id": "ally_2", "position": Vector2(10.0, 0.0), "hp": 0.0, "max_hp": 100.0, "is_dead": true, "stats": {"attack": 20.0}}
	]
	return {
		"caster": {"id": "caster", "position": Vector2.ZERO, "hp": 100.0, "max_hp": 100.0, "stats": {"attack": 30.0}},
		"allies": allies,
		"enemies": enemies,
		"line_enemies": enemies,
		"target": enemies[0],
		"caster_hp_ratio": 1.0,
		"party_hp_ratio": 0.5,
		"boss_active": false
	}
