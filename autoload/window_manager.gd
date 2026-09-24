extends Node

signal window_mode_changed(expanded: bool)
signal always_on_top_changed(enabled: bool)

const STRIP_HEIGHT: int = 180
const EXPANDED_HEIGHT: int = 620
const PANEL_HEIGHT: int = 440
const FALLBACK_SCREEN_SIZE: Vector2i = Vector2i(1152, 648)

var _expanded: bool = false
var _dragging: bool = false
var _drag_offset: Vector2i = Vector2i.ZERO
var _last_screen: int = -1

func _ready() -> void:
	_expanded = bool(GameState.get_setting("expanded", false))
	call_deferred("apply_window_mode")

func is_expanded() -> bool:
	return _expanded

func is_dragging() -> bool:
	return _dragging

func toggle_expanded() -> void:
	set_expanded(not _expanded)

func set_expanded(expanded: bool) -> void:
	if _expanded == expanded:
		return
	_expanded = expanded
	GameState.set_setting("expanded", _expanded)
	apply_window_mode()
	window_mode_changed.emit(_expanded)

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
	window.borderless = true
	window.always_on_top = bool(GameState.get_setting("always_on_top", true))
	var screen_id: int = _get_current_screen(window)
	var usable_rect: Rect2i = _get_usable_rect(screen_id)
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
