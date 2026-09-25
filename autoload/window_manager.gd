extends Node

signal window_mode_changed(expanded: bool)
signal normal_mode_changed(enabled: bool)
signal always_on_top_changed(enabled: bool)

const STRIP_HEIGHT: int = 180
const EXPANDED_HEIGHT: int = 620
const PANEL_HEIGHT: int = 440
const FALLBACK_SCREEN_SIZE: Vector2i = Vector2i(1152, 648)
const NORMAL_MIN_SIZE: Vector2i = Vector2i(800, 480)
const NORMAL_DEFAULT_SIZE: Vector2i = Vector2i(1100, 680)

var _expanded: bool = false
var _normal_mode: bool = false
var _dragging: bool = false
var _drag_offset: Vector2i = Vector2i.ZERO
var _last_screen: int = -1

func _ready() -> void:
	_expanded = bool(GameState.get_setting("expanded", false))
	_normal_mode = bool(GameState.get_setting("normal_window_mode", false))
	call_deferred("apply_window_mode")

func is_expanded() -> bool:
	return _expanded

func is_normal_mode() -> bool:
	return _normal_mode

func is_dragging() -> bool:
	return _dragging

func reload_settings() -> void:
	_expanded = bool(GameState.get_setting("expanded", false))
	_normal_mode = bool(GameState.get_setting("normal_window_mode", false))
	apply_window_mode()
	window_mode_changed.emit(_expanded)
	normal_mode_changed.emit(_normal_mode)

func toggle_expanded() -> void:
	set_expanded(not _expanded)

func set_expanded(expanded: bool) -> void:
	if _expanded == expanded:
		return
	_expanded = expanded
	GameState.set_setting("expanded", _expanded)
	apply_window_mode()
	window_mode_changed.emit(_expanded)

func toggle_normal_mode() -> void:
	set_normal_mode(not _normal_mode)

func set_normal_mode(enabled: bool) -> void:
	if _normal_mode == enabled:
		return
	_normal_mode = enabled
	GameState.set_setting("normal_window_mode", _normal_mode)
	apply_window_mode()
	normal_mode_changed.emit(_normal_mode)

func toggle_always_on_top() -> void:
	set_always_on_top(not bool(GameState.get_setting("always_on_top", true)))

func set_always_on_top(enabled: bool) -> void:
	GameState.set_setting("always_on_top", enabled)
	var window: Window = get_window()
	if window != null:
		window.always_on_top = enabled
	always_on_top_changed.emit(enabled)

func apply_window_mode() -> void:
	if Engine.is_embedded_in_editor():
		return
	var window: Window = get_window()
	if window == null:
		return
	window.always_on_top = bool(GameState.get_setting("always_on_top", true))
	var screen_id: int = _get_current_screen(window)
	var usable_rect: Rect2i = _get_usable_rect(screen_id)
	if _normal_mode:
		window.borderless = false
		window.unresizable = false
		window.min_size = NORMAL_MIN_SIZE
		var target_size: Vector2i = _get_saved_normal_size(usable_rect.size)
		window.size = target_size
		var saved_position: Vector2i = _get_saved_position()
		if saved_position.x == -1 and saved_position.y == -1:
			saved_position = usable_rect.position + (usable_rect.size - target_size) / 2
		window.position = _clamp_position(saved_position, target_size, usable_rect)
		_last_screen = screen_id
		return
	window.borderless = true
	window.unresizable = true
	window.min_size = Vector2i.ZERO
	var target_height: int = EXPANDED_HEIGHT if _expanded else STRIP_HEIGHT
	window.size = Vector2i(usable_rect.size.x, target_height)
	window.position = Vector2i(usable_rect.position.x, usable_rect.position.y + usable_rect.size.y - target_height)
	_last_screen = screen_id

func begin_drag() -> void:
	var window: Window = get_window()
	if window == null:
		return
	var mouse_position: Vector2i = DisplayServer.mouse_get_position()
	_drag_offset = mouse_position - window.position
	_dragging = true

func drag_window(relative: Vector2) -> void:
	if not _dragging:
		return
	var window: Window = get_window()
	if window == null:
		return
	window.position += Vector2i(roundi(relative.x), roundi(relative.y))

func end_drag() -> void:
	_dragging = false
	var window: Window = get_window()
	if window == null:
		return
	GameState.set_setting("window_x", window.position.x)
	GameState.set_setting("window_y", window.position.y)
	GameState.set_setting("window_width", window.size.x)
	GameState.set_setting("window_height", window.size.y)

func _get_current_screen(window: Window) -> int:
	var screen_id: int = 0
	if DisplayServer.get_name() == "headless":
		return 0
	screen_id = DisplayServer.window_get_current_screen(window.get_window_id())
	if screen_id < 0:
		screen_id = 0
	return screen_id

func _get_usable_rect(screen_id: int) -> Rect2i:
	if DisplayServer.get_name() == "headless":
		return Rect2i(Vector2i.ZERO, FALLBACK_SCREEN_SIZE)
	var rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_id)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return Rect2i(Vector2i.ZERO, FALLBACK_SCREEN_SIZE)
	return rect

func _get_saved_position() -> Vector2i:
	var x_value: int = int(GameState.get_setting("window_x", -1))
	var y_value: int = int(GameState.get_setting("window_y", -1))
	if x_value < -1 or y_value < -1:
		return Vector2i(-1, -1)
	return Vector2i(x_value, y_value)

func _get_saved_normal_size(screen_size: Vector2i) -> Vector2i:
	var width: int = clampi(int(GameState.get_setting("window_width", NORMAL_DEFAULT_SIZE.x)), NORMAL_MIN_SIZE.x, screen_size.x)
	var height: int = clampi(int(GameState.get_setting("window_height", NORMAL_DEFAULT_SIZE.y)), NORMAL_MIN_SIZE.y, screen_size.y)
	return Vector2i(width, height)

func _clamp_position(position: Vector2i, window_size: Vector2i, usable_rect: Rect2i) -> Vector2i:
	var max_x: int = usable_rect.position.x + usable_rect.size.x - window_size.x
	var max_y: int = usable_rect.position.y + usable_rect.size.y - window_size.y
	return Vector2i(clampi(position.x, usable_rect.position.x, maxi(usable_rect.position.x, max_x)), clampi(position.y, usable_rect.position.y, maxi(usable_rect.position.y, max_y)))
