class_name BattleUnit
extends Node2D

signal died(unit: BattleUnit)
signal damaged(unit: BattleUnit, amount: int, is_crit: bool, damage_element: String)

@onready var _sprite: AnimatedSprite2D = $Sprite

var display_name: String = "單位"
var level: int = 1
var is_hero: bool = false
var is_boss: bool = false
var attack_type: String = "melee"
var attack_range: float = 70.0
var attack_speed: float = 1.0
var move_speed: float = 34.0
var stats: Dictionary = {}
var sprite_frames: SpriteFrames
var current_hp: float = 1.0
var max_hp: float = 1.0
var attack_cooldown: float = 0.0
var base_attack_speed: float = 1.0
var facing: int = 1
var class_id: String = ""
var element: String = "physical"
var skill_levels: Dictionary = {}
var equipped_active_skills: Array[String] = []
var skill_cooldowns: Dictionary = {}
var skill_burst_multiplier: float = 1.0
var skill_burst_time: float = 0.0
var attack_bonus_percent: float = 0.0
var attack_speed_bonus_percent: float = 0.0
var damage_absorption: float = 0.0
var stun_time: float = 0.0
var slow_time: float = 0.0
var slow_multiplier: float = 1.0
var taunt_time: float = 0.0
var taunt_target_id: int = 0
var party_buff_time: float = 0.0
var party_buff_attack: float = 0.0
var party_buff_attack_speed: float = 0.0

var _death_cleanup_timer: SceneTreeTimer
var _dead: bool = false
var _attacking: bool = false
var _attack_timer: float = 0.0
var _hit_timer: float = 0.0
var _death_timer: float = 0.0
var _frame_content_cache: Dictionary = {}
var _sprite_scale_factor: float = 1.0
var _hp_bar_width: float = 62.0
var _hp_bar_height: float = 5.0
var _bar_y: float = -54.0

func _ready() -> void:
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)

func setup(
	unit_name: String,
	hero: bool,
	boss: bool,
	unit_level: int,
	unit_stats: Dictionary,
	unit_attack_type: String,
	unit_range: float,
	unit_facing: int,
	frames: SpriteFrames,
	visual_scale: float = 0.90
) -> void:
	display_name = unit_name
	is_hero = hero
	is_boss = boss
	level = maxi(1, unit_level)
	stats = unit_stats.duplicate(true)
	attack_type = unit_attack_type
	attack_range = maxf(12.0, unit_range)
	base_attack_speed = maxf(0.1, float(stats.get("attack_speed", 1.0)))
	attack_speed = base_attack_speed
	move_speed = 150.0 + attack_speed * 25.0
	facing = -1 if unit_facing < 0 else 1
	sprite_frames = frames
	max_hp = maxf(1.0, float(stats.get("max_hp", 1.0)))
	current_hp = max_hp
	_sprite.sprite_frames = frames
	_sprite.centered = true
	_sprite.flip_h = facing < 0
	_frame_content_cache = _build_frame_content_cache()
	var frame_info: Dictionary = _get_frame_info("idle", 0)
	var default_size: Vector2 = frame_info.get("size", Vector2.ONE * 100.0)
	var content_height: float = float(frame_info.get("content_height", default_size.y))
	var desired_height: float = 90.0 * maxf(0.55, visual_scale)
	_sprite_scale_factor = desired_height / maxf(1.0, content_height)
	_sprite.scale = Vector2.ONE * _sprite_scale_factor
	_update_sprite_ground_offset()
	_bar_y = -desired_height - 9.0
	queue_redraw()
	play_animation("idle")

func set_ground_y(ground_y: float) -> void:
	position.y = ground_y

func tick(delta: float) -> void:
	if _dead:
		_death_timer = maxf(0.0, _death_timer - delta)
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	stun_time = maxf(0.0, stun_time - delta)
	slow_time = maxf(0.0, slow_time - delta)
	if slow_time <= 0.0:
		slow_multiplier = 1.0
	taunt_time = maxf(0.0, taunt_time - delta)
	party_buff_time = maxf(0.0, party_buff_time - delta)
	if party_buff_time <= 0.0:
		attack_bonus_percent = 0.0
		attack_speed_bonus_percent = 0.0
	if skill_burst_time > 0.0:
		skill_burst_time = maxf(0.0, skill_burst_time - delta)
		if skill_burst_time <= 0.0:
			skill_burst_multiplier = 1.0
	attack_speed = maxf(0.1, base_attack_speed * (1.0 + attack_speed_bonus_percent) * skill_burst_multiplier)
	move_speed = (150.0 + attack_speed * 25.0) * (slow_multiplier if slow_time > 0.0 else 1.0)
	if _hit_timer > 0.0:
		_hit_timer = maxf(0.0, _hit_timer - delta)
		if _hit_timer <= 0.0 and not _attacking:
			play_animation("idle")
	if _attacking:
		_attack_timer = maxf(0.0, _attack_timer - delta)
		if _attack_timer <= 0.0 or not _sprite.is_playing():
			_attacking = false
			play_animation("idle")

func can_attack() -> bool:
	return not _dead and current_hp > 0.0 and attack_cooldown <= 0.0 and stun_time <= 0.0

func begin_attack() -> bool:
	if not can_attack():
		return false
	attack_cooldown = 1.0 / maxf(0.1, attack_speed)
	_attacking = true
	_attack_timer = maxf(0.18, minf(0.45, 0.80 / maxf(0.1, attack_speed)))
	play_animation("attack")
	return true

func take_damage(amount: int, is_crit: bool, damage_element: String = "physical") -> void:
	if _dead or amount <= 0:
		return
	var final_amount: int = maxi(0, amount)
	if damage_absorption > 0.0:
		var absorbed: float = minf(damage_absorption, float(final_amount))
		damage_absorption -= absorbed
		final_amount = maxi(0, final_amount - int(round(absorbed)))
	var passive_reduction: float = clampf(float(stats.get("damage_absorption_percent", 0.0)), 0.0, 0.75)
	final_amount = maxi(0, int(round(float(final_amount) * (1.0 - passive_reduction))))
	if final_amount <= 0:
		return
	current_hp = maxf(0.0, current_hp - float(final_amount))
	queue_redraw()
	_hit_timer = 0.16
	_attacking = false
	_attack_timer = 0.0
	play_animation("hit")
	damaged.emit(self, final_amount, is_crit, CombatMath.normalize_element(damage_element))
	if current_hp <= 0.0:
		_dead = true
		_hit_timer = 0.0
		play_animation("death")
		died.emit(self)
		_death_cleanup_timer = get_tree().create_timer(1.20)
		_death_cleanup_timer.timeout.connect(_on_death_cleanup_timeout)

func heal(amount: int) -> int:
	if _dead or amount <= 0 or current_hp <= 0.0:
		return 0
	var previous: float = current_hp
	current_hp = minf(max_hp, current_hp + float(amount))
	queue_redraw()
	return maxi(0, int(round(current_hp - previous)))

func apply_skill_effect(effect_type: String, value: float, duration: float = 0.0, _element: String = "physical") -> void:
	match effect_type:
		"stun":
			stun_time = maxf(stun_time, duration)
		"slow":
			slow_time = maxf(slow_time, duration)
			slow_multiplier = clampf(1.0 - value, 0.10, 1.0)
		"attack_speed_burst":
			skill_burst_multiplier = maxf(1.0, value)
			skill_burst_time = maxf(skill_burst_time, duration)
		"damage_absorption":
			damage_absorption = maxf(damage_absorption, value)
		"taunt":
			taunt_time = maxf(taunt_time, duration)
		"heal":
			heal(int(round(value)))
		_:
			pass

func configure_skills(hero_class_id: String, hero_element: String, levels: Dictionary, equipped: Array[String]) -> void:
	class_id = hero_class_id
	element = CombatMath.normalize_element(hero_element)
	skill_levels = levels.duplicate(true)
	equipped_active_skills = equipped.duplicate()
	skill_cooldowns.clear()

func get_attack_value() -> float:
	return maxf(0.0, float(stats.get("attack", 0.0)) * (1.0 + attack_bonus_percent))

func revive(hp_ratio: float = 0.5) -> bool:
	if not _dead or current_hp > 0.0:
		return false
	_dead = false
	current_hp = maxf(1.0, max_hp * clampf(hp_ratio, 0.1, 1.0))
	_hit_timer = 0.0
	_attacking = false
	_attack_timer = 0.0
	stun_time = 0.0
	slow_time = 0.0
	slow_multiplier = 1.0
	damage_absorption = 0.0
	play_animation("idle")
	queue_redraw()
	return true

func is_stunned() -> bool:
	return stun_time > 0.0

func is_alive() -> bool:
	return not _dead and current_hp > 0.0 and is_instance_valid(self)

func has_animation(animation_name: String) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(animation_name)

func has_projectile_animation() -> bool:
	return has_animation("projectile")

func get_hp_ratio() -> float:
	return clampf(current_hp / maxf(1.0, max_hp), 0.0, 1.0)

func get_sprite() -> AnimatedSprite2D:
	return _sprite

func play_animation(animation_name: String) -> void:
	if _dead and animation_name != "death":
		return
	if _attacking and animation_name != "attack":
		return
	if _hit_timer > 0.0 and animation_name != "hit":
		return
	if not has_animation(animation_name):
		return
	if _sprite.animation != animation_name or not _sprite.is_playing():
		_sprite.animation = animation_name
		_sprite.play()

func _build_frame_content_cache() -> Dictionary:
	var cache: Dictionary = {}
	if sprite_frames == null:
		return cache
	for animation_name: String in sprite_frames.get_animation_names():
		var frame_count: int = sprite_frames.get_frame_count(animation_name)
		for frame_index: int in range(frame_count):
			var texture: Texture2D = sprite_frames.get_frame_texture(animation_name, frame_index)
			if texture == null:
				continue
			cache["%s:%d" % [animation_name, frame_index]] = _measure_texture(texture)
	return cache

func _get_frame_info(animation_name: String, frame_index: int) -> Dictionary:
	var key: String = "%s:%d" % [animation_name, frame_index]
	if _frame_content_cache.has(key):
		var cached_info: Dictionary = _frame_content_cache[key]
		return cached_info
	if sprite_frames != null and sprite_frames.has_animation(animation_name) and frame_index < sprite_frames.get_frame_count(animation_name):
		var texture: Texture2D = sprite_frames.get_frame_texture(animation_name, frame_index)
		if texture != null:
			var measured_info: Dictionary = _measure_texture(texture)
			_frame_content_cache[key] = measured_info
			return measured_info
	var fallback_size: Vector2 = Vector2.ONE * 100.0
	return {"size": fallback_size, "content_bottom": fallback_size.y, "content_height": fallback_size.y}

func _measure_texture(texture: Texture2D) -> Dictionary:
	var frame_size: Vector2 = texture.get_size()
	var content_bottom: float = frame_size.y
	var content_height: float = frame_size.y
	var image: Image = texture.get_image()
	if image != null and image.get_width() > 0 and image.get_height() > 0:
		var used_rect: Rect2i = image.get_used_rect()
		if used_rect.size.y > 0:
			content_bottom = float(used_rect.position.y + used_rect.size.y)
			content_height = float(used_rect.size.y)
	return {"size": frame_size, "content_bottom": content_bottom, "content_height": content_height}

func _update_sprite_ground_offset() -> void:
	var frame_info: Dictionary = _get_frame_info(_sprite.animation, _sprite.frame)
	var frame_size: Vector2 = frame_info.get("size", Vector2.ONE * 100.0)
	var content_bottom: float = float(frame_info.get("content_bottom", frame_size.y))
	_sprite.position.y = -(content_bottom - frame_size.y * 0.5) * _sprite_scale_factor

func _on_frame_changed() -> void:
	_update_sprite_ground_offset()

func _on_death_cleanup_timeout() -> void:
	if _dead:
		queue_free()

func _on_animation_finished() -> void:
	if _dead:
		return
	if _sprite.animation == "attack":
		_attacking = false
		_attack_timer = 0.0
		play_animation("idle")
	elif _sprite.animation == "hit":
		play_animation("idle")

func _draw() -> void:
	if _dead:
		return
	var bar_position: Vector2 = Vector2(-_hp_bar_width * 0.5, _bar_y)
	draw_rect(Rect2(bar_position, Vector2(_hp_bar_width, _hp_bar_height)), Color(0.03, 0.04, 0.07, 0.90))
	var fill_color: Color = Color(0.30, 0.78, 1.0, 0.95) if is_hero else Color(1.0, 0.30, 0.28, 0.95)
	if is_boss:
		fill_color = Color(1.0, 0.66, 0.18, 0.98)
	draw_rect(Rect2(bar_position + Vector2(1.0, 1.0), Vector2((_hp_bar_width - 2.0) * get_hp_ratio(), _hp_bar_height - 2.0)), fill_color)
