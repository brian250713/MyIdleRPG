extends Node

const SAVE_PATH: String = "user://save.json"
const AUTOSAVE_SECONDS: float = 30.0

var _autosave_timer: Timer
var _loaded: bool = false
var _closing: bool = false

func _ready() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveTimer"
	_autosave_timer.wait_time = AUTOSAVE_SECONDS
	_autosave_timer.one_shot = false
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(save_game)
	add_child(_autosave_timer)
	var root_window: Window = get_tree().root
	if root_window != null:
		root_window.close_requested.connect(_on_window_close_requested)
	load_game()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	if text.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("存檔格式不正確，已使用新存檔。")
		return false
	GameState.apply_loaded_state(SaveCodec.normalize_state(parsed))
	_loaded = true
	return true

func save_game() -> bool:
	GameState.set_last_saved_unix(int(Time.get_unix_time_from_system()))
	var text: String = SaveCodec.state_to_json(GameState.get_save_state())
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("無法寫入存檔：%s" % SAVE_PATH)
		return false
	file.store_string(text)
	file.close()
	_loaded = true
	return true

func is_loaded() -> bool:
	return _loaded

func _on_window_close_requested() -> void:
	if _closing:
		return
	_closing = true
	save_game()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_window_close_requested()
