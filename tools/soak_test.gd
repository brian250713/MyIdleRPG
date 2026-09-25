extends SceneTree

const DEFAULT_SIMULATED_SECONDS: float = 8.0 * 60.0 * 60.0
const TIME_SCALE: float = 8.0
const MAX_REAL_SECONDS: float = 300.0
const MAX_TRANSIENT_NODES: int = 128
const MEMORY_GROWTH_LIMIT_MB: int = 256

var _simulated_seconds: float = DEFAULT_SIMULATED_SECONDS
var _main_scene: Node
var _game_state: Node
var _event_bus: Node
var _max_nodes: int = 0
var _max_transient: int = 0
var _max_inventory: int = 0
var _max_chests: int = 0
var _max_memory: int = 0
var _start_memory: int = 0
var _monster_kills: int = 0
var _hero_deaths: int = 0
var _stages_cleared: int = 0
var _chests_dropped: int = 0
var _white_chests_dropped: int = 0
var _blue_chests_dropped: int = 0
var _act_chests_dropped: int = 0
var _items_gained: int = 0
var _frames: int = 0
var _predicted_stage: int = -1
var _predicted_lead_level: int = -1
var _predicted_levels: Dictionary = {}
var _predicted_gold: int = -1
var _failed: bool = false

func _init() -> void:
	OS.set_environment("MYIDLE_TEST_MODE", "1")
	OS.set_environment("MYIDLE_SAVE_PATH", "user://soak_save.json")
	_simulated_seconds = maxf(60.0, _read_env_float("SOAK_SIM_SECONDS", DEFAULT_SIMULATED_SECONDS))
	_predicted_stage = _read_env_int("CROSSCHECK_PREDICTED_STAGE", -1)
	_predicted_lead_level = _read_env_int("CROSSCHECK_PREDICTED_LEAD_LEVEL", -1)
	_predicted_gold = _read_env_int("CROSSCHECK_PREDICTED_GOLD", -1)
	var predicted_levels: String = OS.get_environment("CROSSCHECK_PREDICTED_LEVELS")
	for raw_level: String in predicted_levels.split(",", false):
		var pieces: PackedStringArray = raw_level.strip_edges().split(":", false)
		if pieces.size() == 2:
			_predicted_levels[pieces[0].strip_edges()] = pieces[1].strip_edges().to_int()
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if packed_scene == null:
		print("SOAK_RESULT=error missing_main_scene")
		quit(1)
		return
	_game_state = root.get_node("GameState")
	_event_bus = root.get_node("EventBus")
	_connect_activity_signals()
	_game_state.call("set_auto_open", "white", true)
	_game_state.call("set_auto_open", "blue", true)
	_game_state.call("set_auto_open", "act_boss", true)
	_main_scene = packed_scene.instantiate()
	root.add_child(_main_scene)
	await process_frame
	_start_memory = _get_memory()
	Engine.time_scale = TIME_SCALE
	var start_msec: int = Time.get_ticks_msec()
	var max_real_seconds: float = maxf(MAX_REAL_SECONDS, _simulated_seconds / TIME_SCALE * 1.5)
	var simulated_seconds: float = 0.0
	while simulated_seconds < _simulated_seconds and not _failed:
		await process_frame
		_frames += 1
		simulated_seconds = float(Time.get_ticks_msec() - start_msec) / 1000.0 * TIME_SCALE
		_sample()
		var real_seconds: float = float(Time.get_ticks_msec() - start_msec) / 1000.0
		if real_seconds > max_real_seconds:
			_failed = true
			print("SOAK_ERROR=real_time_limit real_seconds=%.2f" % real_seconds)
			break
	Engine.time_scale = 1.0
	_sample()
	var inventory: Dictionary = _game_state.call("get_inventory") as Dictionary
	var chest_state: Dictionary = _game_state.call("get_chest_state") as Dictionary
	var inventory_capacity: int = Inventory.get_capacity(inventory)
	var chest_capacity: int = Chests.get_queue_capacity(chest_state)
	var final_cooldown: float = float(chest_state.get("white_cooldown", 0.0))
	var effective_step: float = simulated_seconds / maxf(1.0, float(_frames))
	var memory_growth_mb: int = int(maxi(0, _max_memory - _start_memory) / (1024 * 1024))
	var activity_ok: bool = _monster_kills > 0 and _stages_cleared > 0 and _chests_dropped > 0 and _items_gained > 0
	var real_seconds: float = float(Time.get_ticks_msec() - start_msec) / 1000.0
	var final_state: Dictionary = _game_state.call("get_save_state") as Dictionary
	var final_stage: int = int(final_state.get("current_stage", 0))
	var final_lead_level: int = int(_game_state.call("get_lead_level"))
	var final_party: Array = final_state.get("party", []) as Array
	var actual_levels: Dictionary = {}
	var final_levels: Array[String] = []
	for raw_hero: Variant in final_party:
		if raw_hero is Dictionary:
			var hero: Dictionary = raw_hero as Dictionary
			var class_id: String = str(hero.get("class_id", "?"))
			var level: int = int(hero.get("level", 1))
			actual_levels[class_id] = level
			final_levels.append("%s%d" % [class_id, level])
	var stage_delta: int = absi(final_stage - _predicted_stage) if _predicted_stage >= 0 else 0
	var stage_match: bool = _predicted_stage < 0 or stage_delta <= 1
	var lead_error_percent: float = 0.0
	if _predicted_lead_level > 0:
		lead_error_percent = absf(float(final_lead_level - _predicted_lead_level)) / float(_predicted_lead_level) * 100.0
	var max_level_error_percent: float = 0.0
	var levels_match: bool = true
	for raw_class_id: Variant in _predicted_levels.keys():
		var class_id: String = str(raw_class_id)
		var predicted_level: int = int(_predicted_levels[raw_class_id])
		var actual_level: int = int(actual_levels.get(class_id, 0))
		var level_error: float = 0.0 if predicted_level <= 0 else absf(float(actual_level - predicted_level)) / float(predicted_level) * 100.0
		max_level_error_percent = maxf(max_level_error_percent, level_error)
		if level_error > 20.1:
			levels_match = false
	var gold_error_percent: float = 0.0
	if _predicted_gold > 0:
		gold_error_percent = absf(float(int(final_state.get("gold", 0)) - _predicted_gold)) / float(_predicted_gold) * 100.0
	var crosscheck_ok: bool = stage_match and levels_match and (_predicted_gold <= 0 or gold_error_percent <= 20.1) and (_predicted_lead_level <= 0 or lead_error_percent <= 20.1)
	var passed: bool = not _failed and activity_ok and crosscheck_ok and _max_transient <= MAX_TRANSIENT_NODES and _max_inventory <= inventory_capacity and _max_chests <= chest_capacity and memory_growth_mb <= MEMORY_GROWTH_LIMIT_MB
	print("SOAK_CROSSCHECK simulated_minutes=%.2f stage=%d levels=%s gold=%d predicted_stage=%d stage_delta=%d predicted_levels=%s predicted_gold=%d lead_error_percent=%.1f max_level_error_percent=%.1f gold_error_percent=%.1f crosscheck_ok=%s" % [simulated_seconds / 60.0, final_stage, ",".join(final_levels), int(final_state.get("gold", 0)), _predicted_stage, stage_delta, _format_level_map(_predicted_levels), _predicted_gold, lead_error_percent, max_level_error_percent, gold_error_percent, str(crosscheck_ok)])
	print("SOAK_RESULT passed=%s simulated_hours=%.2f real_seconds=%.2f time_scale=%.1f frames=%d monster_kills=%d hero_deaths=%d stages_cleared=%d chests_dropped=%d white_chests=%d blue_chests=%d act_chests=%d items_gained=%d max_nodes=%d max_transient=%d max_inventory=%d/%d max_chests=%d/%d memory_start=%d memory_peak=%d memory_growth_mb=%d white_cooldown=%.1f effective_step=%.3f" % [str(passed), simulated_seconds / 3600.0, real_seconds, TIME_SCALE, _frames, _monster_kills, _hero_deaths, _stages_cleared, _chests_dropped, _white_chests_dropped, _blue_chests_dropped, _act_chests_dropped, _items_gained, _max_nodes, _max_transient, _max_inventory, inventory_capacity, _max_chests, chest_capacity, _start_memory, _max_memory, memory_growth_mb, final_cooldown, effective_step])
	quit(0 if passed else 1)

func _connect_activity_signals() -> void:
	_event_bus.connect("unit_killed", _on_unit_killed)
	_event_bus.connect("stage_cleared", _on_stage_cleared)
	_event_bus.connect("chest_dropped", _on_chest_dropped)
	_event_bus.connect("chest_opened", _on_chest_opened)
	_event_bus.connect("hero_leveled_up", _on_hero_leveled_up)

func _on_unit_killed(_unit_name: String, is_hero: bool) -> void:
	if is_hero:
		_hero_deaths += 1
	else:
		_monster_kills += 1

func _on_stage_cleared(_stage_index: int) -> void:
	_stages_cleared += 1

func _on_chest_dropped(chest_type: String, _item_level: int) -> void:
	_chests_dropped += 1
	if chest_type == "white":
		_white_chests_dropped += 1
	elif chest_type == "blue":
		_blue_chests_dropped += 1
	elif chest_type == "act_boss":
		_act_chests_dropped += 1

func _on_chest_opened(result: Dictionary) -> void:
	var items: Array = result.get("items", [])
	_items_gained += items.size()

func _on_hero_leveled_up(_class_id: String, _level: int) -> void:
	var party: Array = _game_state.call("get_party") as Array
	if party.size() > 1 and party[1] == null:
		_game_state.call("set_party_slot", 1, "priest")
	if party.size() > 2 and party[2] == null and int(_game_state.call("get_lead_level")) >= 15:
		_game_state.call("set_party_slot", 2, "ranger")

func _sample() -> void:
	_max_nodes = maxi(_max_nodes, _count_nodes(root))
	_max_transient = maxi(_max_transient, _count_transient_nodes(root))
	var inventory: Dictionary = _game_state.call("get_inventory") as Dictionary
	var chest_state: Dictionary = _game_state.call("get_chest_state") as Dictionary
	_max_inventory = maxi(_max_inventory, Inventory.count_items(inventory))
	_max_chests = maxi(_max_chests, Chests.get_queue_size(chest_state))
	_max_memory = maxi(_max_memory, _get_memory())

func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count

func _count_transient_nodes(node: Node) -> int:
	var count: int = 0
	if node.is_in_group("transient") or node is BattleProjectile or node is DamageNumber or node is BattleHitEffect or node is ChestDropFeedback or node is SkillEffect or node is FloatingText:
		count += 1
	for child: Node in node.get_children():
		count += _count_transient_nodes(child)
	return count

func _format_level_map(level_map: Dictionary) -> String:
	var parts: Array[String] = []
	for raw_class_id: Variant in level_map.keys():
		parts.append("%s%d" % [str(raw_class_id), int(level_map[raw_class_id])])
	return ",".join(parts)

func _get_memory() -> int:
	return int(OS.get_static_memory_usage())

func _read_env_float(key: String, default_value: float) -> float:
	var value: String = OS.get_environment(key)
	return default_value if value.is_empty() else value.to_float()

func _read_env_int(key: String, default_value: int) -> int:
	var value: String = OS.get_environment(key)
	return default_value if value.is_empty() else value.to_int()
