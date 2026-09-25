extends SceneTree

const MAX_SIMULATED_HOURS: float = 24.0
const STUCK_LIMIT_SECONDS: float = 45.0 * 60.0
const SOUL_WAIT_LIMIT_SECONDS: float = 60.0 * 60.0
const CROSSCHECK_WINDOWS: Array[float] = [10.0 * 60.0, 60.0 * 60.0]
const AUTO_EQUIP_DROPS: bool = false
const REPORT_SEED: int = 20260924

## Report time is only BattleSim duration plus the real 2.2s/1.25s battlefield transitions.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _party: Array[Dictionary] = []
var _inventory: Array[Dictionary] = []
var _chest_state: Dictionary = {}
var _gold: int = 0
var _total_kills: int = 0
var _total_chests: int = 0
var _chest_tick_seconds: float = 0.0
var _white_chests: int = 0
var _blue_chests: int = 0
var _act_chests: int = 0
var _stage_clears: int = 0
var _soul_farm_seconds: float = 0.0
var _soul_stones: int = 0
var _difficulty_id: String = "normal"
var _stage_index: int = 0
var _elapsed_seconds: float = 0.0
var _visited: Dictionary = {}
var _stage_seconds: Dictionary = {}
var _soul_wait_seconds: Dictionary = {}
var _stuck_points: Array[Dictionary] = []
var _rows: Array[Dictionary] = []
var _paid_act_bosses: Dictionary = {}
var _act_boss_farm_marks: Dictionary = {}
var _act_boss_reported: Dictionary = {}
var _crosscheck_index: int = 0

func _init() -> void:
	OS.set_environment("MYIDLE_TEST_MODE", "1")
	OS.set_environment("MYIDLE_SAVE_PATH", "user://balance_report_save.json")
	call_deferred("_run")

func _run() -> void:
	_rng.seed = REPORT_SEED
	_party = [_new_hero("knight")]
	_chest_state = Chests.create_state()
	_materials_state = Materials.create_state()
	_difficulty_id = "normal"
	_stage_index = 0
	_elapsed_seconds = 0.0
	_print_header()
	while _elapsed_seconds < MAX_SIMULATED_HOURS * 3600.0:
		var stage: Dictionary = StageData.get_stage_by_index(_stage_index, _difficulty_id)
		if stage.is_empty():
			break
		var key: String = "%s:%d" % [_difficulty_id, _stage_index]
		if not _visited.has(key):
			_visited[key] = true
			_record_row(str(stage.get("display_name", key)))
			if bool(stage.get("is_act_boss", false)):
				_act_boss_farm_marks[key] = _soul_farm_seconds
		if _crosscheck_index < CROSSCHECK_WINDOWS.size() and _elapsed_seconds >= CROSSCHECK_WINDOWS[_crosscheck_index]:
			_print_crosscheck_prediction(CROSSCHECK_WINDOWS[_crosscheck_index])
		var is_act_boss: bool = bool(stage.get("is_act_boss", false))
		if is_act_boss and _soul_stones > 0 and not bool(_act_boss_reported.get(key, false)):
			_act_boss_reported[key] = true
			var farm_mark: float = float(_act_boss_farm_marks.get(key, _soul_farm_seconds))
			print("BALANCE_ACT_BOSS|%s|soul_stones=%d|gold=%d|soul_farm_minutes=%.1f" % [str(stage.get("display_name", key)), _soul_stones, _gold, (_soul_farm_seconds - farm_mark) / 60.0])
		if is_act_boss and _soul_stones <= 0 and not bool(_paid_act_bosses.get(key, false)):
			_farm_for_soul(key)
			continue
		if is_act_boss and not bool(_paid_act_bosses.get(key, false)):
			_soul_stones = maxi(0, _soul_stones - 1)
			_paid_act_bosses[key] = true
		var result: Dictionary = _attempt_stage(_stage_index, _difficulty_id)
		var won: bool = bool(result.get("win", false))
		_track_stage_time(key, float(result.get("time_taken", 0.0)), won)
		if not won:
			continue
		_stage_clears += 1
		if is_act_boss:
			_paid_act_bosses.erase(key)
		if not _can_enter_next_stage():
			continue
		if _stage_index >= StageData.get_stage_count() - 1:
			_difficulty_id = Difficulty.get_next_difficulty(_difficulty_id)
			_stage_index = 0
			_record_row("噩夢 1-1")
			break
		_stage_index += 1
	_print_summary()
	quit(0)

func _attempt_stage(stage_index: int, difficulty_id: String) -> Dictionary:
	var heroes: Array = []
	for hero: Dictionary in _party:
		heroes.append(hero.duplicate(true))
	var result: Dictionary = BattleSim.simulate_stage(stage_index, difficulty_id, heroes, {"max_time_seconds": 180.0, "seed": _rng.randi(), "simulation_step": LivePacing.get_simulation_step(_elapsed_seconds), "contact_delay_melee": LivePacing.CONTACT_DELAY_MELEE, "contact_delay_ranged": LivePacing.CONTACT_DELAY_RANGED})
	var duration: float = maxf(1.0, float(result.get("time_taken", 60.0)) * LivePacing.get_time_multiplier(stage_index))
	_elapsed_seconds += duration + (2.2 if bool(result.get("win", false)) else 1.25)
	var stage: Dictionary = StageData.get_stage_by_index(stage_index, difficulty_id)
	var stage_level: int = maxi(1, int(stage.get("recommended_level", 1)))
	var wave_results: Array = result.get("wave_results", [])
	var monster_count: int = 0
	for raw_wave: Variant in wave_results:
		if raw_wave is Dictionary:
			monster_count += int((raw_wave as Dictionary).get("monster_count", 0))
	var total_kills: int = monster_count + (1 if bool(result.get("boss_defeated", false)) else 0)
	var seconds_per_kill: float = duration / maxf(1.0, float(maxi(total_kills, 1)))
	for raw_wave: Variant in wave_results:
		if not (raw_wave is Dictionary):
			continue
		var wave: Dictionary = raw_wave
		for _monster_index: int in range(int(wave.get("monster_count", 0))):
			_process_kill(stage_level, false, seconds_per_kill)
	if bool(result.get("boss_defeated", false)):
		_process_kill(stage_level, true, seconds_per_kill)
	_open_chests()
	return result

func _farm_for_soul(key: String) -> void:
	var farm_stage: int = maxi(0, _stage_index - 1)
	var wait_before: float = float(_soul_wait_seconds.get(key, 0.0))
	var result: Dictionary = _attempt_stage(farm_stage, _difficulty_id)
	var added: float = float(result.get("time_taken", 0.0)) * LivePacing.get_time_multiplier(farm_stage) + 1.25
	_soul_wait_seconds[key] = wait_before + added
	_soul_farm_seconds += added
	if float(_soul_wait_seconds.get(key, 0.0)) > SOUL_WAIT_LIMIT_SECONDS and not _has_stuck(key, "soul_farm"):
		_stuck_points.append({"key": key, "reason": "soul_farm", "minutes": float(_soul_wait_seconds[key]) / 60.0})

func _process_kill(monster_level: int, is_boss: bool, elapsed_for_cooldown: float) -> void:
	_total_kills += 1
	_chest_tick_seconds += elapsed_for_cooldown
	Chests.tick(_chest_state, elapsed_for_cooldown)
	var reward: Dictionary = Rewards.calculate_rewards(monster_level, is_boss)
	var max_gold_multiplier: float = 1.0
	var hero_count: int = _party.size()
	for hero_index: int in range(hero_count):
		var hero_for_gold: Dictionary = _party[hero_index]
		var stats: Dictionary = _hero_stats(hero_for_gold)
		max_gold_multiplier = maxf(max_gold_multiplier, 1.0 + float(stats.get("gold_gain", 0.0)))
	_gold += maxi(1, int(round(float(reward.get("gold", 0)) * max_gold_multiplier * LivePacing.get_gold_multiplier(_elapsed_seconds))))
	for hero_index: int in range(hero_count):
		var hero: Dictionary = _party[hero_index]
		var stats: Dictionary = _hero_stats(hero)
		var multiplier: float = (5.0 if is_boss else 1.0) * (1.0 + float(stats.get("xp_gain", 0.0)))
		var xp_amount: int = XPCurve.experience_reward(monster_level, int(hero.get("level", 1)), multiplier)
		_apply_xp(hero, xp_amount)
	var stage: Dictionary = StageData.get_stage_by_index(_stage_index, _difficulty_id)
	var is_act_boss: bool = bool(stage.get("is_act_boss", false)) and is_boss
	Chests.try_drop_for_kill(_chest_state, monster_level, is_boss, is_act_boss, _rng)

func _open_chests() -> void:
	var guard: int = 0
	while Chests.get_queue_size(_chest_state) > 0 and guard < 128:
		guard += 1
		var result: Dictionary = Chests.open_chest(_chest_state, 0, _rng)
		if not bool(result.get("opened", false)):
			break
		var opened_type: String = str((result.get("chest", {}) as Dictionary).get("type", "white"))
		if opened_type == "white":
			_white_chests += 1
		elif opened_type == "blue":
			_blue_chests += 1
		elif opened_type == "act_boss":
			_act_chests += 1
		_gold += maxi(0, int(round(float(result.get("gold", 0)) * LivePacing.get_gold_multiplier(_elapsed_seconds))))
		_total_chests += 1
		_soul_stones += int(result.get("soul_stones", 0))
		var items: Array = result.get("items", [])
		for raw_item: Variant in items:
			if raw_item is Dictionary:
				_receive_item(raw_item as Dictionary)
		var materials: Array = result.get("materials", [])
		for raw_material: Variant in materials:
			if raw_material is Dictionary:
				Materials.add_material(_materials_state, raw_material as Dictionary)

var _materials_state: Dictionary = {}

func _receive_item(item: Dictionary) -> void:
	if not AUTO_EQUIP_DROPS:
		_add_inventory_or_sell(item)
		return
	var best_hero: Dictionary = {}
	var best_slot: String = ""
	var best_improvement: int = 0
	for hero: Dictionary in _party:
		if not ItemData.can_equip_item(item, str(hero.get("class_id", "knight"))):
			continue
		var equipment: Dictionary = hero.get("equipment", {})
		var current_power: int = Power.calculate(Stats.calculate_final_stats(str(hero.get("class_id", "knight")), int(hero.get("level", 1)), equipment, hero.get("skills", {})))
		var candidate: Dictionary = equipment.duplicate(true)
		candidate[str(item.get("slot", "weapon"))] = item.duplicate(true)
		var candidate_power: int = Power.calculate(Stats.calculate_final_stats(str(hero.get("class_id", "knight")), int(hero.get("level", 1)), candidate, hero.get("skills", {})))
		var improvement: int = candidate_power - current_power
		if improvement > best_improvement:
			best_improvement = improvement
			best_hero = hero
			best_slot = str(item.get("slot", ""))
	if not best_hero.is_empty():
		var equipment: Dictionary = best_hero.get("equipment", {})
		var old_item: Variant = equipment.get(best_slot, null)
		equipment[best_slot] = item.duplicate(true)
		best_hero["equipment"] = equipment
		if old_item is Dictionary:
			_add_inventory_or_sell(old_item as Dictionary)
		return
	_add_inventory_or_sell(item)

func _add_inventory_or_sell(item: Dictionary) -> void:
	if _inventory.size() < Inventory.SLOT_COUNT:
		_inventory.append(item.duplicate(true))
	else:
		_gold += int(item.get("sell_value", 1))

func _new_hero(class_id: String) -> Dictionary:
	var equipment: Dictionary = {}
	for slot_id: String in ItemData.get_slot_ids():
		equipment[slot_id] = null
	return {"class_id": class_id, "level": 1, "xp": 0, "equipment": equipment, "skills": Skills.make_skill_state(class_id)}

func _hero_stats(hero: Dictionary) -> Dictionary:
	return Stats.calculate_final_stats(str(hero.get("class_id", "knight")), int(hero.get("level", 1)), hero.get("equipment", {}), hero.get("skills", {}))

func _apply_xp(hero: Dictionary, amount: int) -> void:
	var result: Dictionary = XPCurve.apply_xp(int(hero.get("level", 1)), int(hero.get("xp", 0)), amount)
	var old_level: int = int(hero.get("level", 1))
	hero["level"] = int(result.get("level", old_level))
	hero["xp"] = int(result.get("xp", 0))
	if int(hero.get("level", 1)) > old_level:
		_spend_skill_points(hero)
		_fill_party_slots()

func _spend_skill_points(hero: Dictionary) -> void:
	var skill_state: Dictionary = Skills.normalize_skill_state(hero.get("skills", {}), str(hero.get("class_id", "knight")))
	var available: int = Skills.get_available_points(int(hero.get("level", 1)), skill_state)
	var skill_ids: Array[String] = []
	for definition: Dictionary in SkillData.get_class_skills(str(hero.get("class_id", "knight")), "passive"):
		skill_ids.append(str(definition.get("id", "")))
	for definition: Dictionary in SkillData.get_class_skills(str(hero.get("class_id", "knight")), "active"):
		skill_ids.append(str(definition.get("id", "")))
	for skill_id: String in skill_ids:
		if available <= 0:
			break
		var result: Dictionary = Skills.upgrade_skill(skill_state, int(hero.get("level", 1)), skill_id, 1)
		if bool(result.get("ok", false)):
			skill_state = result.get("state", skill_state)
			available = maxi(0, available - 1)
	hero["skills"] = skill_state

func _fill_party_slots() -> void:
	var lead: Dictionary = _party[0] if not _party.is_empty() else {}
	var lead_level: int = int(lead.get("level", 1)) if not lead.is_empty() else 1
	if lead_level >= 5 and _party.size() < 2:
		_party.append(_new_hero("priest"))
	if lead_level >= 15 and _party.size() < 3:
		_party.append(_new_hero("ranger"))

func _can_enter_next_stage() -> bool:
	var lead_level: int = int(_party[0].get("level", 1)) if not _party.is_empty() else 1
	if _stage_index < StageData.get_stage_count() - 1:
		return lead_level >= StageData.get_required_level(_stage_index + 1, _difficulty_id)
	var next_difficulty: String = Difficulty.get_next_difficulty(_difficulty_id)
	return next_difficulty.is_empty() or lead_level >= StageData.get_required_level(0, next_difficulty)

func _track_stage_time(key: String, seconds: float, won: bool) -> void:
	_stage_seconds[key] = float(_stage_seconds.get(key, 0.0)) + seconds
	if not won and float(_stage_seconds.get(key, 0.0)) > STUCK_LIMIT_SECONDS and not _has_stuck(key, "stage_retry"):
		_stuck_points.append({"key": key, "reason": "stage_retry", "minutes": float(_stage_seconds[key]) / 60.0})

func _has_stuck(key: String, reason: String) -> bool:
	for point: Dictionary in _stuck_points:
		if str(point.get("key", "")) == key and str(point.get("reason", "")) == reason:
			return true
	return false

func _record_row(stage_name: String) -> void:
	var levels: Array[String] = []
	for hero: Dictionary in _party:
		levels.append("%s%d" % [str(hero.get("class_id", "?")), int(hero.get("level", 1))])
	var row: Dictionary = {"stage": stage_name, "hours": _elapsed_seconds / 3600.0, "levels": ",".join(levels), "gold": _gold, "stuck": _stuck_points.size()}
	_rows.append(row)
	print("BALANCE_STAGE|%s|%.3f|%s|%d|%d" % [stage_name, row["hours"], row["levels"], _gold, _stuck_points.size()])

func _print_crosscheck_prediction(seconds: float) -> void:
	_crosscheck_index += 1
	var levels: Array[String] = []
	for hero: Dictionary in _party:
		levels.append("%s%d" % [str(hero.get("class_id", "?")), int(hero.get("level", 1))])
	var stage: Dictionary = StageData.get_stage_by_index(_stage_index, _difficulty_id)
	print("BALANCE_CROSSCHECK_PREDICTION simulated_minutes=%d stage=%d stage_name=%s levels=%s gold=%d kills=%d opened_chests=%d white_chests=%d blue_chests=%d act_chests=%d stage_clears=%d chest_tick_seconds=%.1f white_cooldown=%.1f" % [int(seconds / 60.0), _stage_index, str(stage.get("display_name", "")), ",".join(levels), _gold, _total_kills, _total_chests, _white_chests, _blue_chests, _act_chests, _stage_clears, _chest_tick_seconds, float(_chest_state.get("white_cooldown", 0.0))])

func _print_header() -> void:
	print("BALANCE_REPORT_BEGIN seed=%d" % REPORT_SEED)
	print("stage|hours|heroes|gold|stuck_points")

func _print_summary() -> void:
	var last: Dictionary = _rows.back() if not _rows.is_empty() else {"stage": "none", "hours": 0.0, "levels": "", "gold": _gold, "stuck": 0}
	print("BALANCE_SUMMARY|hours=%.3f|stage=%s|levels=%s|gold=%d|stuck_points=%d|soul_stones=%d|inventory=%d|chests=%d|kills=%d|opened_chests=%d soul_farm_minutes=%.1f" % [float(last.get("hours", 0.0)), str(last.get("stage", "none")), str(last.get("levels", "")), _gold, _stuck_points.size(), _soul_stones, _inventory.size(), Chests.get_queue_size(_chest_state), _total_kills, _total_chests, _soul_farm_seconds / 60.0])
	for point: Dictionary in _stuck_points:
		print("BALANCE_STUCK|%s|%s|%.1f" % [str(point.get("key", "")), str(point.get("reason", "")), float(point.get("minutes", 0.0))])
	print("BALANCE_REPORT_END")
