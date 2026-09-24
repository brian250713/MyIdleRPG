class_name Battlefield
extends Control

@warning_ignore("unused_signal")
signal battle_message(message: String)
@warning_ignore("unused_signal")
signal stage_progress_changed
@warning_ignore("unused_signal")
signal stage_cleared(stage_index: int)
@warning_ignore("unused_signal")
signal party_defeated

const UnitScene: PackedScene = preload("res://scenes/battle/unit.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/battle/projectile.tscn")
const DamageNumberScene: PackedScene = preload("res://scenes/battle/damage_number.tscn")
const HitEffectScene: PackedScene = preload("res://scenes/battle/hit_effect.tscn")

var _world_layer: Node2D
var _heroes: Array[BattleUnit] = []
var _monsters: Array[BattleUnit] = []
var _progression: StageProgression
var _stage_data: Dictionary = {}
var _stage_index: int = 0
var _wave_spawn_timer: float = 0.0
var _wave_spawned: bool = false
var _stage_active: bool = false
var _boss_pending: bool = false
var _wipe_handled: bool = false
var _stage_clear_timer: float = 0.0
var _retreat_timer: float = 0.0
var _scroll_offset: float = 0.0
var _rng: RandomNumberGenerator
var _last_status: String = "準備出發"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng = GameState.get_rng()
	_world_layer = Node2D.new()
	_world_layer.name = "WorldLayer"
	add_child(_world_layer)
	set_process(true)

func start_campaign() -> void:
	if _progression != null:
		return
	var save_state: Dictionary = GameState.get_save_state()
	var settings: Dictionary = save_state.get("settings", {})
	var saved_stage: Dictionary = StageData.get_stage_by_index(int(save_state.get("current_stage", 0)))
	var initial_state: Dictionary = {
		"current_stage": int(save_state.get("current_stage", 0)),
		"unlocked_stage": int(save_state.get("unlocked_stage", 0)),
		"wave_count": maxi(1, int(saved_stage.get("wave_count", 5))),
		"wave_index": 0,
		"boss_active": false,
		"phase": StageProgression.Phase.WAVES,
		"auto_advance": bool(settings.get("auto_advance", true)),
		"stage_attempts": 0
	}
	_progression = StageProgression.new(initial_state)
	_progression.set_auto_advance(bool(settings.get("auto_advance", true)))
	_begin_stage(_progression.get_current_stage())

func select_stage(stage_index: int) -> void:
	if _progression == null:
		start_campaign()
		return
	var result: String = _progression.select_stage(stage_index)
	if result == "locked":
		_last_status = "尚未解鎖此關卡"
		return
	_stage_clear_timer = 0.0
	_retreat_timer = 0.0
	GameState.set_current_stage(stage_index)
	_begin_stage(stage_index)

func set_auto_advance(enabled: bool) -> void:
	if _progression != null:
		_progression.set_auto_advance(enabled)
	_last_status = "自動推進已開啟" if enabled else "自動推進已關閉"

func get_status_text() -> String:
	return _last_status

func get_stage_index() -> int:
	return _stage_index

func get_snapshot() -> Dictionary:
	var wave_number: int = 1
	var wave_count: int = maxi(1, int(_stage_data.get("wave_count", 5)))
	var boss_active: bool = false
	if _progression != null:
		wave_count = _progression.get_wave_count()
		wave_number = mini(wave_count, _progression.get_wave_index() + 1)
		boss_active = _progression.is_boss_active() or _boss_pending
	return {
		"stage_index": _stage_index,
		"stage_name": StageData.get_display_name(_stage_index),
		"wave_number": wave_number,
		"wave_count": wave_count,
		"boss_active": boss_active,
		"status": _last_status,
		"phase": _progression.get_phase_name() if _progression != null else "idle"
	}

func _process(delta: float) -> void:
	_scroll_offset = fmod(_scroll_offset + delta * 18.0, 160.0)
	queue_redraw()
	if _progression == null:
		return
	if _stage_active:
		_update_units(delta)
		_update_spawning(delta)
		_check_stage_completion()
	if _stage_clear_timer > 0.0:
		_stage_clear_timer -= delta
		if _stage_clear_timer <= 0.0:
			_stage_clear_timer = 0.0
			_advance_after_clear()
	if _retreat_timer > 0.0:
		_retreat_timer -= delta
		if _retreat_timer <= 0.0:
			_retreat_timer = 0.0
			_begin_stage(_progression.get_current_stage())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			WindowManager.begin_drag()
			accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and WindowManager.is_dragging():
		var motion_event: InputEventMouseMotion = event
		WindowManager.drag_window(motion_event.relative)
	elif event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.button_index == MOUSE_BUTTON_LEFT and not button_event.pressed:
			WindowManager.end_drag()

func _begin_stage(stage_index: int) -> void:
	_clear_units()
	_stage_index = clampi(stage_index, 0, StageData.get_stage_count() - 1)
	_stage_data = StageData.get_stage_by_index(_stage_index)
	var wave_count: int = maxi(1, int(_stage_data.get("wave_count", 5)))
	_progression.start_stage(_stage_index, wave_count)
	_wave_spawn_timer = 0.65
	_wave_spawned = false
	_stage_active = true
	_boss_pending = false
	_wipe_handled = false
	_stage_clear_timer = 0.0
	_retreat_timer = 0.0
	_last_status = "%s 出發" % StageData.get_display_name(_stage_index)
	GameState.set_current_stage(_stage_index)
	_spawn_heroes()
	EventBus.stage_changed.emit(_stage_index, StageData.get_display_name(_stage_index))
	EventBus.wave_changed.emit(1, wave_count, false)
	stage_progress_changed.emit()

func _spawn_heroes() -> void:
	var active_heroes: Array[Dictionary] = GameState.get_active_heroes()
	if active_heroes.is_empty():
		active_heroes = [{"class_id": "knight", "level": 1, "xp": 0}]
	for index: int in range(active_heroes.size()):
		var hero_state: Dictionary = active_heroes[index]
		var class_id: String = str(hero_state.get("class_id", "knight"))
		var class_definition: Dictionary = ClassData.get_class_definition(class_id)
		if class_definition.is_empty():
			continue
		var unit_stats: Dictionary = Stats.calculate_class_stats(class_id, int(hero_state.get("level", 1)))
		var spawn_position: Vector2 = Vector2(_hero_formation_x(index), _ground_y())
		var unit: BattleUnit = _create_unit(
			str(class_definition.get("sprite", "f1_general")),
			str(class_definition.get("name", "英雄")),
			true,
			false,
			int(hero_state.get("level", 1)),
			unit_stats,
			str(class_definition.get("attack_type", "melee")),
			float(class_definition.get("range", 80.0)),
			1,
			float(class_definition.get("visual_scale", 0.90)),
			spawn_position
		)
		if unit != null:
			_heroes.append(unit)

func _spawn_wave() -> void:
	var pool_value: Variant = _stage_data.get("monster_pool", [])
	if not (pool_value is Array):
		return
	var pool: Array = pool_value
	if pool.is_empty():
		_spawn_boss()
		return
	var level: int = maxi(1, int(_stage_data.get("recommended_level", 1)))
	var count: int = 2 + (1 if _progression.get_wave_index() >= 3 else 0)
	for index: int in range(count):
		var monster_id: String = str(pool[(index + _progression.get_wave_index()) % pool.size()])
		var definition: Dictionary = MonsterScaling.scale_monster(monster_id, level)
		if definition.is_empty():
			continue
		var spawn_position: Vector2 = Vector2(size.x + 70.0 + float(index) * 78.0, _ground_y())
		var unit: BattleUnit = _create_unit(
			monster_id,
			str(definition.get("name", "怪物")),
			false,
			bool(definition.get("is_boss", false)),
			level,
			definition.get("stats", {}),
			str(definition.get("attack_type", "melee")),
			float(definition.get("range", 55.0)),
			-1,
			float(definition.get("visual_scale", 0.90)),
			spawn_position
		)
		if unit != null:
			_monsters.append(unit)
	_wave_spawned = true
	EventBus.wave_changed.emit(_progression.get_wave_index() + 1, _progression.get_wave_count(), false)
	_last_status = "第 %d 波怪物出現" % (_progression.get_wave_index() + 1)

func _spawn_boss() -> void:
	var boss_id: String = str(_stage_data.get("boss", "boss_andromeda"))
	var definition: Dictionary = MonsterScaling.scale_monster(boss_id, int(_stage_data.get("recommended_level", 10)))
	if definition.is_empty():
		return
	var unit: BattleUnit = _create_unit(
		boss_id,
		str(definition.get("name", "關卡首領")),
		false,
		true,
		int(_stage_data.get("recommended_level", 10)),
		definition.get("stats", {}),
		str(definition.get("attack_type", "melee")),
		float(definition.get("range", 65.0)),
		-1,
		float(definition.get("visual_scale", 1.18)),
		Vector2(size.x + 80.0, _ground_y())
	)
	if unit != null:
		_monsters.append(unit)
	_boss_pending = true
	_wave_spawned = true
	EventBus.wave_changed.emit(_progression.get_wave_count(), _progression.get_wave_count(), true)
	_last_status = "關卡首領出現"

func _create_unit(
	sprite_id: String,
	unit_name: String,
	hero: bool,
	boss: bool,
	level: int,
	unit_stats: Variant,
	unit_attack_type: String,
	unit_range: float,
	facing: int,
	visual_scale: float,
	spawn_position: Vector2
) -> BattleUnit:
	var unit: BattleUnit = UnitScene.instantiate() as BattleUnit
	if unit == null:
		return null
	_world_layer.add_child(unit)
	var frames: SpriteFrames = load("res://addons/duelyst_animated_sprites/spriteframes/units/%s.tres" % sprite_id) as SpriteFrames
	if frames == null:
		frames = _make_fallback_frames()
	var stats_dictionary: Dictionary = unit_stats as Dictionary
	unit.setup(unit_name, hero, boss, level, stats_dictionary, unit_attack_type, unit_range, facing, frames, visual_scale)
	unit.position = Vector2(spawn_position.x, _ground_y())
	unit.set_ground_y(_ground_y())
	unit.died.connect(_on_unit_died)
	unit.damaged.connect(_on_unit_damaged)
	return unit

func _update_units(delta: float) -> void:
	for hero_index: int in range(_heroes.size()):
		var unit: BattleUnit = _heroes[hero_index]
		if not is_instance_valid(unit) or not unit.is_alive():
			continue
		unit.tick(delta)
		var target: BattleUnit = _find_nearest_enemy(unit, _monsters)
		if target == null:
			_move_unit_toward_x(unit, _hero_formation_x(hero_index), delta)
			unit.play_animation("idle")
			continue
		var direction: int = 1 if target.position.x >= unit.position.x else -1
		var distance: float = absf(target.position.x - unit.position.x)
		if distance > unit.attack_range:
			unit.play_animation("run")
			unit.position.x += float(direction) * unit.move_speed * delta
			_clamp_unit_position(unit)
		else:
			unit.play_animation("idle")
			if unit.begin_attack():
				_perform_attack(unit, target)
	for unit: BattleUnit in _monsters:
		if not is_instance_valid(unit) or not unit.is_alive():
			continue
		unit.tick(delta)
		var target: BattleUnit = _find_nearest_enemy(unit, _heroes)
		if target == null:
			unit.play_animation("idle")
			continue
		var direction: int = 1 if target.position.x >= unit.position.x else -1
		var distance: float = absf(target.position.x - unit.position.x)
		if distance > unit.attack_range:
			unit.play_animation("run")
			unit.position.x += float(direction) * unit.move_speed * delta
			_clamp_unit_position(unit)
		else:
			unit.play_animation("idle")
			if unit.begin_attack():
				_perform_attack(unit, target)

func _perform_attack(attacker: BattleUnit, target: BattleUnit) -> void:
	var result: Dictionary = CombatMath.calculate_damage(
		float(attacker.stats.get("attack", 1.0)),
		float(target.stats.get("defense", 0.0)),
		float(attacker.stats.get("crit_chance", 0.0)),
		float(attacker.stats.get("crit_damage", 1.5)),
		_rng
	)
	var amount: int = int(result["amount"])
	var is_crit: bool = bool(result["is_crit"])
	if attacker.attack_type == "ranged":
		var projectile: BattleProjectile = ProjectileScene.instantiate() as BattleProjectile
		if projectile == null:
			return
		_world_layer.add_child(projectile)
		projectile.position = attacker.position + Vector2(float(attacker.facing) * 22.0, -8.0)
		projectile.setup(target, amount, is_crit, attacker.sprite_frames, attacker.has_projectile_animation(), 300.0 + float(attacker.attack_speed) * 35.0)
	else:
		target.take_damage(amount, is_crit)

func _update_spawning(delta: float) -> void:
	if _boss_pending or not _stage_active:
		return
	_wave_spawn_timer -= delta
	if _wave_spawn_timer <= 0.0 and not _has_alive_monsters() and not _wave_spawned:
		_spawn_wave()
		_wave_spawn_timer = 0.85

func _check_stage_completion() -> void:
	if not _stage_active:
		return
	if not _has_alive_heroes() and not _wipe_handled:
		_wipe_handled = true
		_stage_active = false
		var result: String = _progression.on_party_wiped()
		_last_status = "全滅，退回上一關" if result == "retreated" else "全滅，重新挑戰"
		party_defeated.emit()
		if result == "retreated":
			_retreat_timer = 1.25
		else:
			_retreat_timer = 1.25
		return
	if _wave_spawned and not _has_alive_monsters():
		if _progression.get_phase() == StageProgression.Phase.WAVES:
			var result: String = _progression.on_wave_cleared()
			if result == "boss_started":
				_spawn_boss()
			else:
				_wave_spawned = false
				_wave_spawn_timer = 0.70
				EventBus.wave_changed.emit(_progression.get_wave_index() + 1, _progression.get_wave_count(), false)
		elif _progression.get_phase() == StageProgression.Phase.BOSS and _boss_pending:
			_boss_pending = false
			_progression.on_boss_defeated()
			GameState.unlock_stage(mini(StageData.get_stage_count() - 1, _stage_index + 1))
			_last_status = "%s 已通關" % StageData.get_display_name(_stage_index)
			stage_cleared.emit(_stage_index)
			EventBus.stage_cleared.emit(_stage_index)
			_stage_clear_timer = 2.2
			if not _progression.is_auto_advance():
				_last_status = "%s 已通關，自動推進已關閉" % StageData.get_display_name(_stage_index)

func _advance_after_clear() -> void:
	var result: String = _progression.advance_to_next_stage()
	if result == "next_stage_started":
		_begin_stage(_progression.get_current_stage())
	elif result == "all_stages_unlocked":
		_last_status = "普通難度已全部通關，重新挑戰最後一關"
		_begin_stage(_stage_index)
	elif result == "waiting_for_manual_advance":
		_last_status = "自動推進已關閉，重複目前關卡"
		_begin_stage(_stage_index)
	else:
		_last_status = "關卡已通關，準備重新挑戰"

func _on_unit_damaged(unit: BattleUnit, amount: int, is_crit: bool) -> void:
	if not is_instance_valid(unit):
		return
	var hit_effect: BattleHitEffect = HitEffectScene.instantiate() as BattleHitEffect
	if hit_effect != null:
		_world_layer.add_child(hit_effect)
		hit_effect.position = unit.position + Vector2(0.0, -18.0)
		var hit_frames: SpriteFrames = load("res://addons/duelyst_animated_sprites/spriteframes/fx/%s.tres" % ("fx_impactred" if is_crit else "fx_impact")) as SpriteFrames
		hit_effect.setup(hit_frames, is_crit)
	var damage_number: DamageNumber = DamageNumberScene.instantiate() as DamageNumber
	if damage_number == null:
		return
	_world_layer.add_child(damage_number)
	damage_number.position = unit.position + Vector2(0.0, -52.0)
	damage_number.setup(amount, is_crit)
	EventBus.damage_dealt.emit(amount, is_crit, unit.position)

func _on_unit_died(unit: BattleUnit) -> void:
	if not is_instance_valid(unit):
		return
	EventBus.unit_killed.emit(unit.display_name, unit.is_hero)
	if not unit.is_hero:
		GameState.grant_monster_rewards(unit.level, unit.is_boss)
	_last_status = "%s 被擊敗" % unit.display_name

func _find_nearest_enemy(unit: BattleUnit, candidates: Array[BattleUnit]) -> BattleUnit:
	var nearest: BattleUnit = null
	var nearest_distance: float = INF
	for candidate: BattleUnit in candidates:
		if not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var distance: float = absf(candidate.position.x - unit.position.x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest

func _has_alive_monsters() -> bool:
	for unit: BattleUnit in _monsters:
		if is_instance_valid(unit) and unit.is_alive():
			return true
	return false

func _has_alive_heroes() -> bool:
	for unit: BattleUnit in _heroes:
		if is_instance_valid(unit) and unit.is_alive():
			return true
	return false

func _move_unit_toward_x(unit: BattleUnit, target_x: float, delta: float) -> void:
	var distance: float = target_x - unit.position.x
	var max_step: float = unit.move_speed * delta
	if absf(distance) <= max_step:
		unit.position.x = target_x
	elif distance > 0.0:
		unit.position.x += max_step
	else:
		unit.position.x -= max_step

func _clamp_unit_position(unit: BattleUnit) -> void:
	if unit.is_hero:
		unit.position.x = clampf(unit.position.x, 45.0, maxf(50.0, size.x - 25.0))
	else:
		unit.position.x = clampf(unit.position.x, 20.0, maxf(25.0, size.x + 80.0))

func _clear_units() -> void:
	_heroes.clear()
	_monsters.clear()
	if _world_layer == null:
		return
	for child: Node in _world_layer.get_children():
		child.queue_free()

func _ground_y() -> float:
	return size.y * 0.79

func _hero_formation_x(index: int) -> float:
	return 90.0 + float(index) * 72.0

func _make_fallback_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.38, 0.62, 0.92, 1.0))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	for animation_name: String in ["idle", "breathing", "run", "attack", "hit", "death", "projectile"]:
		frames.add_animation(animation_name)
		frames.add_frame(animation_name, texture)
	return frames

func _draw() -> void:
	var viewport_width: float = maxf(1.0, size.x)
	var viewport_height: float = maxf(1.0, size.y)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.075, 0.14, 1.0))
	var band_count: int = maxi(1, int(viewport_height / 24.0))
	for index: int in range(band_count + 1):
		var ratio: float = float(index) / float(band_count)
		var color: Color = Color(0.07 + ratio * 0.04, 0.10 + ratio * 0.07, 0.18 + ratio * 0.10, 1.0)
		draw_rect(Rect2(0.0, ratio * viewport_height, viewport_width, viewport_height / float(band_count) + 1.0), color)
	var ground_y: float = viewport_height * 0.79
	draw_rect(Rect2(0.0, ground_y, viewport_width, viewport_height - ground_y), Color(0.10, 0.16, 0.18, 1.0))
	draw_rect(Rect2(0.0, ground_y, viewport_width, 2.0), Color(0.25, 0.47, 0.42, 0.75))
	for index: int in range(0, int(viewport_width / 160.0) + 3):
		var x: float = fmod(float(index) * 160.0 - _scroll_offset, viewport_width + 160.0) - 80.0
		var hill: PackedVector2Array = PackedVector2Array([
			Vector2(x, ground_y + 2.0),
			Vector2(x + 75.0, ground_y - 28.0 - float((index % 3) * 7)),
			Vector2(x + 155.0, ground_y + 2.0)
		])
		draw_colored_polygon(hill, Color(0.09, 0.25, 0.25, 0.72))
		draw_circle(Vector2(x + 75.0, ground_y - 25.0), 3.0, Color(0.45, 0.78, 0.55, 0.45))
	for index: int in range(0, int(viewport_width / 220.0) + 2):
		var star_x: float = fmod(float(index) * 220.0 - _scroll_offset * 0.35, viewport_width + 220.0) - 110.0
		draw_circle(Vector2(star_x, 28.0 + float((index % 2) * 18)), 1.2, Color(0.55, 0.70, 0.90, 0.35))
