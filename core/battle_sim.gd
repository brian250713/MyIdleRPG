class_name BattleSim
extends RefCounted

## 無頭的單關平衡模擬器。
##
## 這個模型刻意貼近目前戰場的節奏：固定時間步長、近戰需要接觸時間、
## 遠程視為立即攻擊；傷害、暴擊、元素抗性、等級成長與波次組成都直接
## 使用正式資料表。技能使用 Skills 的核心結果，因此可在無 SceneTree
## 的測試中驗證，而不建立 BattleUnit 節點。

const DEFAULT_MAX_TIME_SECONDS: float = 240.0
const DEFAULT_SEED: int = 20260924
const DEFAULT_WAVE_HEAL_RATIO: float = 0.30
const DEFAULT_CONTACT_DELAY_MELEE: float = 3.25
const DEFAULT_CONTACT_DELAY_RANGED: float = 0.15
const DEFAULT_BOSS_SPAWN_DELAY: float = 0.05
const SIMULATION_STEP: float = 0.10
const MAX_SIMULATION_STEPS: int = 6000

static func simulate_stage(stage_index: int, difficulty_id: String = "normal", hero_specs: Array = [], options: Dictionary = {}) -> Dictionary:
	var safe_difficulty_id: String = DifficultyData.normalize_difficulty_id(difficulty_id)
	var stage: Dictionary = StageData.get_stage_by_index(stage_index, safe_difficulty_id)
	if stage.is_empty():
		return _empty_result(stage_index, safe_difficulty_id, "invalid_stage")
	var max_time: float = maxf(1.0, float(options.get("max_time_seconds", options.get("max_time", DEFAULT_MAX_TIME_SECONDS))))
	var seed_value: int = int(options.get("seed", DEFAULT_SEED))
	var wave_heal_ratio: float = clampf(float(options.get("wave_heal_ratio", StageData.WAVE_HEAL_RATIO)), 0.0, 1.0)
	var use_skills: bool = bool(options.get("use_skills", true))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var heroes: Array[Dictionary] = _prepare_heroes(hero_specs)
	if heroes.is_empty():
		heroes = _prepare_heroes([{"class_id": "knight", "level": 1, "equipment": {}, "skills": {}}])
	_fully_heal_party(heroes)
	var result: Dictionary = {
		"win": false,
		"outcome": "timeout",
		"time_taken": 0.0,
		"hp_left": 0.0,
		"hp_max": 0.0,
		"hp_ratio": 0.0,
		"stage_index": stage_index,
		"difficulty_id": safe_difficulty_id,
		"stage_name": str(stage.get("display_name", "")),
		"recommended_level": int(stage.get("recommended_level", 1)),
		"wave_count": int(stage.get("wave_count", 5)),
		"waves_cleared": 0,
		"boss_reached": false,
		"boss_defeated": false,
		"hero_levels": _hero_level_snapshot(heroes),
		"wave_results": [],
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
		"skill_casts": 0,
		"boss": {},
		"boss_start_time": -1.0,
		"hero_hp_at_boss": 0.0,
		"hero_hp_at_boss_ratio": 0.0,
		"seed": seed_value,
		"wave_heal_ratio": wave_heal_ratio,
		"use_skills": use_skills
	}
	var elapsed: float = 0.0
	var waves_completed: int = 0
	var phase: String = "waiting_wave"
	var phase_timer: float = 0.65
	var wave_start_time: float = 0.0
	var wave_start_hp: float = _party_hp(heroes)
	var monsters: Array[Dictionary] = []
	var step_count: int = 0
	if bool(options.get("skip_waves", false)):
		monsters = _spawn_boss(stage, safe_difficulty_id)
		result["boss_reached"] = true
		result["boss_start_time"] = 0.0
		result["hero_hp_at_boss"] = _party_hp(heroes)
		result["hero_hp_at_boss_ratio"] = _party_hp_ratio(heroes)
		result["boss"] = _boss_snapshot(monsters, heroes)
		result["waves_cleared"] = int(stage.get("wave_count", 5))
		phase = "boss"
	while elapsed < max_time and step_count < MAX_SIMULATION_STEPS:
		step_count += 1
		if not _has_living_hero(heroes):
			result["outcome"] = "lose"
			result["time_taken"] = elapsed
			break
		if phase == "waiting_wave":
			phase_timer -= SIMULATION_STEP
			if phase_timer <= 0.0:
				monsters = _spawn_wave(stage, waves_completed, safe_difficulty_id)
				wave_start_time = elapsed
				wave_start_hp = _party_hp(heroes)
				phase = "wave"
		elif phase == "wave":
			_simulate_combat_step(heroes, monsters, elapsed - wave_start_time, rng, use_skills, result)
			if not _has_living_monster(monsters):
				var wave_result: Dictionary = _make_wave_result(waves_completed + 1, elapsed - wave_start_time, wave_start_hp, heroes, monsters, result)
				(result["wave_results"] as Array).append(wave_result)
				waves_completed += 1
				result["waves_cleared"] = waves_completed
				_heal_living_party(heroes, wave_heal_ratio)
				if waves_completed < int(stage.get("wave_count", 5)):
					phase = "waiting_wave"
					phase_timer = 0.70
				else:
					phase = "waiting_boss"
					phase_timer = DEFAULT_BOSS_SPAWN_DELAY
		elif phase == "waiting_boss":
			phase_timer -= SIMULATION_STEP
			if phase_timer <= 0.0:
				monsters = _spawn_boss(stage, safe_difficulty_id)
				result["boss_reached"] = true
				result["boss_start_time"] = elapsed
				result["hero_hp_at_boss"] = _party_hp(heroes)
				result["hero_hp_at_boss_ratio"] = _party_hp_ratio(heroes)
				result["boss"] = _boss_snapshot(monsters, heroes)
				phase = "boss"
		elif phase == "boss":
			_simulate_combat_step(heroes, monsters, elapsed - float(result["boss_start_time"]), rng, use_skills, result)
			if not _has_living_monster(monsters):
				result["boss_defeated"] = true
				result["win"] = true
				result["outcome"] = "win"
				result["time_taken"] = elapsed
				break
		elapsed += SIMULATION_STEP
	if not bool(result["win"]) and str(result["outcome"]) == "timeout":
		result["outcome"] = "lose" if not _has_living_hero(heroes) else "timeout"
		result["time_taken"] = elapsed
	result["hp_left"] = _party_hp(heroes)
	result["hp_max"] = _party_max_hp(heroes)
	result["hp_ratio"] = _party_hp_ratio(heroes)
	result["hero_levels"] = _hero_level_snapshot(heroes)
	result["hero_hp"] = _hero_hp_snapshot(heroes)
	return result

static func simulate(stage_index: int, difficulty_id: String = "normal", hero_specs: Array = [], options: Dictionary = {}) -> Dictionary:
	return simulate_stage(stage_index, difficulty_id, hero_specs, options)

static func run_stage(stage_index: int, difficulty_id: String = "normal", hero_specs: Array = [], options: Dictionary = {}) -> Dictionary:
	return simulate_stage(stage_index, difficulty_id, hero_specs, options)

static func make_standard_equipment(item_level: int, class_id: String, seed_value: int = DEFAULT_SEED, rarity_id: String = "rare") -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var equipment: Dictionary = {}
	for slot_id: String in ItemData.get_slot_ids():
		equipment[slot_id] = ItemGen.generate_item(item_level, rng, rarity_id, class_id, slot_id)
	return equipment

static func make_hero_spec(class_id: String, level: int, equipment_level: int = 0, seed_value: int = DEFAULT_SEED, rarity_id: String = "rare") -> Dictionary:
	var equipment: Dictionary = {}
	if equipment_level > 0:
		equipment = make_standard_equipment(equipment_level, class_id, seed_value, rarity_id)
	return {"class_id": class_id, "level": level, "equipment": equipment, "skills": {}}

static func _prepare_heroes(hero_specs: Array) -> Array[Dictionary]:
	var heroes: Array[Dictionary] = []
	for raw_spec: Variant in hero_specs:
		if not (raw_spec is Dictionary):
			continue
		var spec: Dictionary = raw_spec
		var class_id: String = str(spec.get("class_id", "knight"))
		var class_definition: Dictionary = ClassData.get_class_definition(class_id)
		if class_definition.is_empty():
			continue
		var level: int = clampi(int(spec.get("level", 1)), 1, Stats.MAX_LEVEL)
		var equipment_value: Variant = spec.get("equipment", {})
		var equipment: Dictionary = equipment_value if equipment_value is Dictionary else {}
		var skills_value: Variant = spec.get("skills", {})
		var skills: Dictionary = Skills.normalize_skill_state(skills_value if skills_value is Dictionary else {}, class_id)
		var stats: Dictionary = Stats.calculate_final_stats(class_id, level, equipment, skills)
		if stats.is_empty():
			continue
		var max_hp: float = maxf(1.0, float(stats.get("max_hp", 1.0)))
		heroes.append({
			"id": "hero_%d" % heroes.size(),
			"class_id": class_id,
			"level": level,
			"xp": maxi(0, int(spec.get("xp", 0))),
			"stats": stats,
			"max_hp": max_hp,
			"hp": max_hp,
			"attack_type": str(class_definition.get("attack_type", "melee")),
			"range": maxf(1.0, float(class_definition.get("range", 80.0))),
			"element": ClassData.get_default_element(class_id),
			"skills": skills,
			"equipped_active_skills": Skills.get_equipped_active_ids(skills),
			"cooldowns": {},
			"attack_timer": 0.0,
			"stun_time": 0.0,
			"slow_time": 0.0,
			"slow_multiplier": 1.0,
			"shield": 0.0,
			"party_buff_time": 0.0,
			"party_buff_attack": 0.0,
			"party_buff_attack_speed": 0.0,
			"burst_time": 0.0,
			"burst_multiplier": 1.0,
			"is_dead": false,
			"is_tank": class_id == "knight" or class_id == "priest",
			"damage_dealt": 0.0,
			"damage_taken": 0.0,
			"kills": 0
		})
	return heroes

static func _spawn_wave(stage: Dictionary, wave_index: int, difficulty_id: String) -> Array[Dictionary]:
	var monsters: Array[Dictionary] = []
	var pool_value: Variant = stage.get("monster_pool", [])
	if not (pool_value is Array) or (pool_value as Array).is_empty():
		return monsters
	var pool: Array = pool_value
	var level: int = maxi(1, int(stage.get("recommended_level", 1)))
	var count: int = 2 + (1 if wave_index >= 3 else 0)
	for index: int in range(count):
		var monster_id: String = str(pool[(index + wave_index) % pool.size()])
		var definition: Dictionary = MonsterScaling.scale_monster(monster_id, level, difficulty_id)
		if definition.is_empty():
			continue
		monsters.append(_make_monster_state(monster_id, definition, index))
	return monsters

static func _spawn_boss(stage: Dictionary, difficulty_id: String) -> Array[Dictionary]:
	var boss_id: String = str(stage.get("boss", "boss_andromeda"))
	var level: int = maxi(1, int(stage.get("recommended_level", 1)))
	var definition: Dictionary = MonsterScaling.scale_monster(boss_id, level, difficulty_id)
	var monsters: Array[Dictionary] = []
	if not definition.is_empty():
		monsters.append(_make_monster_state(boss_id, definition, 0))
	return monsters

static func _make_monster_state(monster_id: String, definition: Dictionary, index: int) -> Dictionary:
	var stats: Dictionary = definition.get("stats", {}) if definition.get("stats", {}) is Dictionary else {}
	var max_hp: float = maxf(1.0, float(stats.get("max_hp", 1.0)))
	return {
		"id": "%s_%d" % [monster_id, index],
		"monster_id": monster_id,
		"name": str(definition.get("name", monster_id)),
		"level": int(definition.get("level", stats.get("level", 1))),
		"stats": stats.duplicate(true),
		"max_hp": max_hp,
		"hp": max_hp,
		"attack_type": str(definition.get("attack_type", "melee")),
		"range": maxf(1.0, float(definition.get("range", 55.0))),
		"element": str(definition.get("element", "physical")),
		"is_boss": bool(definition.get("is_boss", false)),
		"attack_timer": 0.0,
		"stun_time": 0.0,
		"slow_time": 0.0,
		"slow_multiplier": 1.0,
		"shield": 0.0,
		"is_dead": false,
		"taunt_time": 0.0
	}

static func _simulate_combat_step(heroes: Array[Dictionary], monsters: Array[Dictionary], combat_elapsed: float, rng: RandomNumberGenerator, use_skills: bool, result: Dictionary) -> void:
	for hero: Dictionary in heroes:
		_tick_temporary_effects(hero)
		if bool(hero.get("is_dead", false)):
			continue
		if use_skills:
			_try_cast_skill(hero, heroes, monsters, rng, result)
		if bool(hero.get("is_dead", false)):
			continue
		if not _is_engaged(hero, combat_elapsed):
			continue
		if float(hero.get("attack_timer", 0.0)) > 0.0 or float(hero.get("stun_time", 0.0)) > 0.0:
			continue
		var target: Dictionary = _first_living_monster(monsters)
		if target.is_empty():
			continue
		var damage: Dictionary = CombatMath.calculate_damage_for_target(_hero_attack(hero), target.get("stats", {}), float(hero["stats"].get("crit_chance", 0.0)), float(hero["stats"].get("crit_damage", 1.5)), rng, str(hero.get("element", "physical")))
		hero["attack_timer"] = 1.0 / maxf(0.1, _hero_attack_speed(hero))
		_apply_monster_damage(target, int(damage.get("amount", 1)), bool(damage.get("is_crit", false)), str(hero.get("element", "physical")), heroes, result)
	for monster: Dictionary in monsters:
		_tick_temporary_effects(monster)
		if bool(monster.get("is_dead", false)):
			continue
		if not _is_engaged(monster, combat_elapsed):
			continue
		if float(monster.get("attack_timer", 0.0)) > 0.0 or float(monster.get("stun_time", 0.0)) > 0.0:
			continue
		var target_hero: Dictionary = _first_living_hero(heroes)
		if target_hero.is_empty():
			continue
		var hero_damage: Dictionary = CombatMath.calculate_damage_for_target(float(monster.get("stats", {}).get("attack", 1.0)), target_hero.get("stats", {}), float(monster.get("stats", {}).get("crit_chance", 0.0)), float(monster.get("stats", {}).get("crit_damage", 1.5)), rng, str(monster.get("element", "physical")))
		monster["attack_timer"] = 1.0 / maxf(0.1, float(monster.get("stats", {}).get("attack_speed", 1.0)))
		_apply_hero_damage(target_hero, int(hero_damage.get("amount", 1)), bool(hero_damage.get("is_crit", false)), str(monster.get("element", "physical")), result)

static func _is_engaged(unit: Dictionary, combat_elapsed: float) -> bool:
	var attack_type: String = str(unit.get("attack_type", "melee"))
	var delay: float = DEFAULT_CONTACT_DELAY_RANGED if attack_type == "ranged" else DEFAULT_CONTACT_DELAY_MELEE
	return combat_elapsed >= delay

static func _tick_temporary_effects(unit: Dictionary) -> void:
	unit["attack_timer"] = maxf(0.0, float(unit.get("attack_timer", 0.0)) - SIMULATION_STEP)
	unit["stun_time"] = maxf(0.0, float(unit.get("stun_time", 0.0)) - SIMULATION_STEP)
	unit["slow_time"] = maxf(0.0, float(unit.get("slow_time", 0.0)) - SIMULATION_STEP)
	if float(unit.get("slow_time", 0.0)) <= 0.0:
		unit["slow_multiplier"] = 1.0
	unit["party_buff_time"] = maxf(0.0, float(unit.get("party_buff_time", 0.0)) - SIMULATION_STEP)
	if float(unit.get("party_buff_time", 0.0)) <= 0.0:
		unit["party_buff_attack"] = 0.0
		unit["party_buff_attack_speed"] = 0.0
	unit["burst_time"] = maxf(0.0, float(unit.get("burst_time", 0.0)) - SIMULATION_STEP)
	if float(unit.get("burst_time", 0.0)) <= 0.0:
		unit["burst_multiplier"] = 1.0

static func _hero_attack(hero: Dictionary) -> float:
	return maxf(0.0, float(hero.get("stats", {}).get("attack", 0.0)) * (1.0 + float(hero.get("party_buff_attack", 0.0))))

static func _hero_attack_speed(hero: Dictionary) -> float:
	var base_speed: float = maxf(0.1, float(hero.get("stats", {}).get("attack_speed", 1.0)))
	return maxf(0.1, base_speed * (1.0 + float(hero.get("party_buff_attack_speed", 0.0))) * float(hero.get("burst_multiplier", 1.0)))

static func _first_living_monster(monsters: Array[Dictionary]) -> Dictionary:
	for monster: Dictionary in monsters:
		if not bool(monster.get("is_dead", false)) and float(monster.get("hp", 0.0)) > 0.0:
			return monster
	return {}

static func _first_living_hero(heroes: Array[Dictionary]) -> Dictionary:
	for hero: Dictionary in heroes:
		if not bool(hero.get("is_dead", false)) and float(hero.get("hp", 0.0)) > 0.0:
			return hero
	return {}

static func _apply_monster_damage(monster: Dictionary, amount: int, is_crit: bool, element: String, heroes: Array[Dictionary], result: Dictionary) -> void:
	if bool(monster.get("is_dead", false)) or amount <= 0:
		return
	var final_amount: int = maxi(0, amount)
	if float(monster.get("shield", 0.0)) > 0.0:
		var absorbed: float = minf(float(monster.get("shield", 0.0)), float(final_amount))
		monster["shield"] = maxf(0.0, float(monster.get("shield", 0.0)) - absorbed)
		final_amount = maxi(0, final_amount - int(round(absorbed)))
	monster["hp"] = maxf(0.0, float(monster.get("hp", 0.0)) - float(final_amount))
	for hero: Dictionary in heroes:
		if not bool(hero.get("is_dead", false)):
			hero["damage_dealt"] = float(hero.get("damage_dealt", 0.0)) + float(final_amount)
	result["damage_dealt"] = float(result.get("damage_dealt", 0.0)) + float(final_amount)
	if float(monster.get("hp", 0.0)) <= 0.0:
		monster["is_dead"] = true
		_grant_monster_xp(monster, heroes)

static func _apply_hero_damage(hero: Dictionary, amount: int, is_crit: bool, element: String, result: Dictionary) -> void:
	if bool(hero.get("is_dead", false)) or amount <= 0:
		return
	var final_amount: int = maxi(0, amount)
	if float(hero.get("shield", 0.0)) > 0.0:
		var absorbed: float = minf(float(hero.get("shield", 0.0)), float(final_amount))
		hero["shield"] = maxf(0.0, float(hero.get("shield", 0.0)) - absorbed)
		final_amount = maxi(0, final_amount - int(round(absorbed)))
	var passive_reduction: float = clampf(float(hero.get("stats", {}).get("damage_absorption_percent", 0.0)), 0.0, 0.75)
	final_amount = maxi(0, int(round(float(final_amount) * (1.0 - passive_reduction))))
	hero["hp"] = maxf(0.0, float(hero.get("hp", 0.0)) - float(final_amount))
	hero["damage_taken"] = float(hero.get("damage_taken", 0.0)) + float(final_amount)
	result["damage_taken"] = float(result.get("damage_taken", 0.0)) + float(final_amount)
	if float(hero.get("hp", 0.0)) <= 0.0:
		hero["is_dead"] = true

static func _grant_monster_xp(monster: Dictionary, heroes: Array[Dictionary]) -> void:
	var xp_multiplier: float = 5.0 if bool(monster.get("is_boss", false)) else 1.0
	for hero: Dictionary in heroes:
		var xp_amount: int = XPCurve.experience_reward(int(monster.get("level", 1)), int(hero.get("level", 1)), xp_multiplier)
		var xp_result: Dictionary = XPCurve.apply_xp(int(hero.get("level", 1)), int(hero.get("xp", 0)), xp_amount)
		hero["level"] = int(xp_result.get("level", hero.get("level", 1)))
		hero["xp"] = int(xp_result.get("xp", 0))
		hero["kills"] = int(hero.get("kills", 0)) + 1

static func _try_cast_skill(hero: Dictionary, heroes: Array[Dictionary], monsters: Array[Dictionary], rng: RandomNumberGenerator, result: Dictionary) -> void:
	var equipped: Array = hero.get("equipped_active_skills", [])
	if equipped.is_empty():
		return
	var context: Dictionary = _build_skill_context(hero, heroes, monsters, rng)
	var chosen_skill: String = Skills.choose_auto_skill(hero.get("skills", {}), int(hero.get("level", 1)), context, hero.get("cooldowns", {}))
	if chosen_skill.is_empty():
		return
	var effect: Dictionary = Skills.get_effect_definition(chosen_skill, Skills.get_skill_level(hero.get("skills", {}), chosen_skill))
	var passive_modifiers: Dictionary = Skills.get_passive_modifiers(str(hero.get("class_id", "knight")), hero.get("skills", {}).get("skill_levels", {}))
	hero["cooldowns"][chosen_skill] = Skills.get_cooldown_seconds(effect, passive_modifiers)
	var cast_result: Dictionary = Skills.cast_skill(chosen_skill, Skills.get_skill_level(hero.get("skills", {}), chosen_skill), context, passive_modifiers)
	if not bool(cast_result.get("ok", false)):
		return
	result["skill_casts"] = int(result.get("skill_casts", 0)) + 1
	_apply_skill_result(cast_result, heroes, monsters, result)

static func _build_skill_context(hero: Dictionary, heroes: Array[Dictionary], monsters: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var allies: Array = []
	for index: int in range(heroes.size()):
		allies.append(_unit_context(heroes[index], float(index * 10.0)))
	var enemies: Array = []
	for index: int in range(monsters.size()):
		enemies.append(_unit_context(monsters[index], 100.0 + float(index * 20.0)))
	var target: Dictionary = _first_living_monster(monsters)
	var targeted_units: Array = []
	var non_tank_targeted: bool = false
	for monster: Dictionary in monsters:
		if bool(monster.get("is_dead", false)):
			continue
		var target_hero: Dictionary = _first_living_hero(heroes)
		if not target_hero.is_empty():
			var target_data: Dictionary = _unit_context(target_hero, 0.0)
			targeted_units.append(target_data)
			if not bool(target_data.get("is_tank", false)):
				non_tank_targeted = true
	var party_hp: float = 0.0
	var party_max_hp: float = 0.0
	for ally: Dictionary in allies:
		if not bool(ally.get("is_dead", false)):
			party_hp += float(ally.get("hp", 0.0))
			party_max_hp += float(ally.get("max_hp", 0.0))
	return {
		"caster": _unit_context(hero, 0.0),
		"allies": allies,
		"enemies": enemies,
		"line_enemies": enemies,
		"target": _unit_context(target, 100.0) if not target.is_empty() else {},
		"targeted_units": targeted_units,
		"non_tank_targeted": non_tank_targeted,
		"caster_hp_ratio": float(hero.get("hp", 0.0)) / maxf(1.0, float(hero.get("max_hp", 1.0))),
		"party_hp_ratio": party_hp / maxf(1.0, party_max_hp),
		"boss_active": _has_boss(monsters),
		"rng": rng
	}

static func _unit_context(unit: Dictionary, x: float) -> Dictionary:
	return {
		"id": str(unit.get("id", "")),
		"position": Vector2(x, 0.0),
		"hp": float(unit.get("hp", 0.0)),
		"max_hp": float(unit.get("max_hp", 1.0)),
		"level": int(unit.get("level", 1)),
		"is_dead": bool(unit.get("is_dead", false)),
		"stats": unit.get("stats", {}).duplicate(true) if unit.get("stats", {}) is Dictionary else {},
		"element": str(unit.get("element", "physical")),
		"is_tank": bool(unit.get("is_tank", false))
	}

static func _apply_skill_result(cast_result: Dictionary, heroes: Array[Dictionary], monsters: Array[Dictionary], result: Dictionary) -> void:
	var hits: Array = cast_result.get("hits", [])
	for hit_value: Variant in hits:
		if not (hit_value is Dictionary):
			continue
		var hit: Dictionary = hit_value
		var monster: Dictionary = _find_unit_by_id(monsters, str(hit.get("id", "")))
		if not monster.is_empty():
			_apply_monster_damage(monster, int(hit.get("amount", 0)), bool(hit.get("crit", false)), str(cast_result.get("element", "physical")), heroes, result)
	var targets: Array = cast_result.get("targets", [])
	for target_value: Variant in targets:
		if not (target_value is Dictionary):
			continue
		var target_data: Dictionary = target_value
		var target_id: String = str(target_data.get("id", ""))
		var hero: Dictionary = _find_unit_by_id(heroes, target_id)
		if not hero.is_empty():
			if cast_result.get("effect_type", "") == "heal":
				hero["hp"] = minf(float(hero.get("max_hp", 1.0)), float(hero.get("hp", 0.0)) + float(target_data.get("amount", 0.0)))
			elif cast_result.get("effect_type", "") == "resurrect":
				hero["is_dead"] = false
				hero["hp"] = maxf(1.0, float(hero.get("max_hp", 1.0)) * float(target_data.get("hp_ratio", 0.5)))
			elif cast_result.get("effect_type", "") == "damage_absorption":
				hero["shield"] = maxf(float(hero.get("shield", 0.0)), float(target_data.get("amount", 0.0)))
	var effect_type: String = str(cast_result.get("effect_type", ""))
	if effect_type == "party_buff":
		var stat_id: String = str(cast_result.get("stat_id", ""))
		var stat_value: float = float(cast_result.get("stat_value", 0.0))
		for ally: Dictionary in heroes:
			ally["party_buff_time"] = maxf(float(ally.get("party_buff_time", 0.0)), float(cast_result.get("duration", 0.0)))
			if stat_id == "attack_speed_percent":
				ally["party_buff_attack_speed"] = maxf(float(ally.get("party_buff_attack_speed", 0.0)), stat_value)
			else:
				ally["party_buff_attack"] = maxf(float(ally.get("party_buff_attack", 0.0)), stat_value)
	elif effect_type == "attack_speed_burst":
		for burst_target_value: Variant in cast_result.get("targets", []):
			if burst_target_value is Dictionary:
				var burst_target: Dictionary = _find_unit_by_id(heroes, str((burst_target_value as Dictionary).get("id", "")))
				if not burst_target.is_empty():
					burst_target["burst_multiplier"] = maxf(1.0, float(cast_result.get("value", 1.0)))
					burst_target["burst_time"] = maxf(float(burst_target.get("burst_time", 0.0)), float(cast_result.get("duration", 0.0)))
	elif effect_type == "stun":
		for target_value: Variant in cast_result.get("status_targets", cast_result.get("targets", [])):
			if target_value is Dictionary:
				var monster: Dictionary = _find_unit_by_id(monsters, str((target_value as Dictionary).get("id", "")))
				if not monster.is_empty():
					monster["stun_time"] = maxf(float(monster.get("stun_time", 0.0)), float(cast_result.get("stun_duration", cast_result.get("duration", 0.0))))
	elif effect_type == "slow":
		for target_value: Variant in cast_result.get("status_targets", cast_result.get("targets", [])):
			if target_value is Dictionary:
				var monster: Dictionary = _find_unit_by_id(monsters, str((target_value as Dictionary).get("id", "")))
				if not monster.is_empty():
					monster["slow_time"] = maxf(float(monster.get("slow_time", 0.0)), float(cast_result.get("duration", 0.0)))
					monster["slow_multiplier"] = clampf(float(cast_result.get("slow_multiplier", 1.0)), 0.1, 1.0)

static func _find_unit_by_id(units: Array[Dictionary], unit_id: String) -> Dictionary:
	for unit: Dictionary in units:
		if str(unit.get("id", "")) == unit_id:
			return unit
	return {}

static func _has_boss(units: Array[Dictionary]) -> bool:
	for unit: Dictionary in units:
		if bool(unit.get("is_boss", false)) and not bool(unit.get("is_dead", false)):
			return true
	return false

static func _fully_heal_party(heroes: Array[Dictionary]) -> void:
	for hero: Dictionary in heroes:
		hero["hp"] = float(hero.get("max_hp", 1.0))
		hero["is_dead"] = false
		hero["shield"] = 0.0
		hero["stun_time"] = 0.0
		hero["slow_time"] = 0.0
		hero["slow_multiplier"] = 1.0
		hero["party_buff_time"] = 0.0
		hero["party_buff_attack"] = 0.0
		hero["party_buff_attack_speed"] = 0.0
		hero["burst_time"] = 0.0
		hero["burst_multiplier"] = 1.0

static func _heal_living_party(heroes: Array[Dictionary], ratio: float) -> void:
	var safe_ratio: float = clampf(ratio, 0.0, 1.0)
	for hero: Dictionary in heroes:
		if bool(hero.get("is_dead", false)):
			continue
		hero["hp"] = minf(float(hero.get("max_hp", 1.0)), float(hero.get("hp", 0.0)) + float(hero.get("max_hp", 1.0)) * safe_ratio)

static func _make_wave_result(wave_number: int, duration: float, hp_before: float, heroes: Array[Dictionary], monsters: Array[Dictionary], result: Dictionary) -> Dictionary:
	return {
		"wave": wave_number,
		"duration": duration,
		"hp_before": hp_before,
		"hp_after": _party_hp(heroes),
		"hp_ratio_after": _party_hp_ratio(heroes),
		"hero_levels": _hero_level_snapshot(heroes),
		"monster_count": monsters.size(),
		"damage_dealt": float(result.get("damage_dealt", 0.0)),
		"damage_taken": float(result.get("damage_taken", 0.0))
	}

static func _boss_snapshot(monsters: Array[Dictionary], heroes: Array[Dictionary]) -> Dictionary:
	var boss: Dictionary = _first_living_monster(monsters)
	if boss.is_empty() and not monsters.is_empty():
		boss = monsters[0]
	if boss.is_empty():
		return {}
	var boss_stats: Dictionary = boss.get("stats", {})
	var hero: Dictionary = _first_living_hero(heroes)
	var hero_damage: float = 0.0
	var boss_damage: float = 0.0
	if not hero.is_empty():
		hero_damage = float(CombatMath.calculate_damage_for_target(_hero_attack(hero), boss_stats, 0.0, 1.5, null, str(hero.get("element", "physical"))).get("amount", 0))
		boss_damage = float(CombatMath.calculate_damage_for_target(float(boss_stats.get("attack", 1.0)), hero.get("stats", {}), 0.0, 1.5, null, str(boss.get("element", "physical"))).get("amount", 0))
	return {
		"id": str(boss.get("id", "")),
		"name": str(boss.get("name", "boss")),
		"level": int(boss.get("level", 1)),
		"max_hp": float(boss.get("max_hp", 1.0)),
		"hp": float(boss.get("hp", 1.0)),
		"attack": float(boss_stats.get("attack", 0.0)),
		"defense": float(boss_stats.get("defense", 0.0)),
		"attack_speed": float(boss_stats.get("attack_speed", 1.0)),
		"hero_damage_per_hit": hero_damage,
		"boss_damage_per_hit": boss_damage,
		"estimated_boss_kill_time": float(boss.get("max_hp", 1.0)) / maxf(0.1, hero_damage * _hero_attack_speed(hero)) if not hero.is_empty() else 0.0,
		"estimated_hero_survival_time": float(hero.get("hp", 0.0)) / maxf(0.1, boss_damage * float(boss_stats.get("attack_speed", 1.0))) if not hero.is_empty() else 0.0
	}

static func _has_living_hero(heroes: Array[Dictionary]) -> bool:
	for hero: Dictionary in heroes:
		if not bool(hero.get("is_dead", false)) and float(hero.get("hp", 0.0)) > 0.0:
			return true
	return false

static func _has_living_monster(monsters: Array[Dictionary]) -> bool:
	for monster: Dictionary in monsters:
		if not bool(monster.get("is_dead", false)) and float(monster.get("hp", 0.0)) > 0.0:
			return true
	return false

static func _party_hp(heroes: Array[Dictionary]) -> float:
	var total: float = 0.0
	for hero: Dictionary in heroes:
		total += maxf(0.0, float(hero.get("hp", 0.0)))
	return total

static func _party_max_hp(heroes: Array[Dictionary]) -> float:
	var total: float = 0.0
	for hero: Dictionary in heroes:
		total += maxf(0.0, float(hero.get("max_hp", 1.0)))
	return total

static func _party_hp_ratio(heroes: Array[Dictionary]) -> float:
	return _party_hp(heroes) / maxf(1.0, _party_max_hp(heroes))

static func _hero_level_snapshot(heroes: Array[Dictionary]) -> Array[int]:
	var levels: Array[int] = []
	for hero: Dictionary in heroes:
		levels.append(int(hero.get("level", 1)))
	return levels

static func _hero_hp_snapshot(heroes: Array[Dictionary]) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for hero: Dictionary in heroes:
		snapshot.append({"id": str(hero.get("id", "")), "level": int(hero.get("level", 1)), "hp": float(hero.get("hp", 0.0)), "max_hp": float(hero.get("max_hp", 1.0)), "is_dead": bool(hero.get("is_dead", false))})
	return snapshot

static func _empty_result(stage_index: int, difficulty_id: String, outcome: String) -> Dictionary:
	return {"win": false, "outcome": outcome, "time_taken": 0.0, "hp_left": 0.0, "hp_max": 0.0, "hp_ratio": 0.0, "stage_index": stage_index, "difficulty_id": difficulty_id, "waves_cleared": 0, "boss_reached": false, "boss_defeated": false, "hero_levels": [], "wave_results": [], "damage_dealt": 0.0, "damage_taken": 0.0, "skill_casts": 0, "boss": {}}
