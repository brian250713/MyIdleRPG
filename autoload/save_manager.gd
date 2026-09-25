extends Node

const SAVE_PATH: String = "user://save.json"
const CAPTURE_SAVE_PATH: String = "user://capture_save.json"
const TEST_SAVE_PATH: String = "user://test_runner_save.json"
const AUTOSAVE_SECONDS: float = 30.0

var _autosave_timer: Timer
var _loaded: bool = false
var _closing: bool = false
var _capture_mode: bool = false
var _test_mode: bool = false
var _save_path: String = SAVE_PATH

static func get_save_path_for_mode(capture_mode: bool = false, override_path: String = "") -> String:
	if not override_path.is_empty():
		return override_path
	return CAPTURE_SAVE_PATH if capture_mode else SAVE_PATH

func _ready() -> void:
	_test_mode = _detect_test_mode()
	_capture_mode = _detect_capture_mode()
	_save_path = _resolve_save_path()
	if _test_mode or _capture_mode:
		_reset_isolated_save(_save_path)
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveTimer"
	_autosave_timer.wait_time = AUTOSAVE_SECONDS
	_autosave_timer.one_shot = false
	if not _test_mode and not _capture_mode:
		_autosave_timer.autostart = true
		_autosave_timer.timeout.connect(save_game)
	add_child(_autosave_timer)
	var root_window: Window = get_tree().root
	if root_window != null:
		root_window.close_requested.connect(_on_window_close_requested)
	load_game()

func load_game() -> bool:
	if _test_mode or _capture_mode:
		GameState.apply_loaded_state(SaveCodec.make_default_state())
		_loaded = true
		return false
	if not FileAccess.file_exists(_save_path):
		return false
	var text: String = FileAccess.get_file_as_string(_save_path)
	if text.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("存檔格式不正確，已使用新存檔。")
		return false
	GameState.apply_loaded_state(SaveCodec.normalize_state(parsed))
	var offline_summary: Dictionary = Offline.calculate(GameState.get_save_state(), int(Time.get_unix_time_from_system()))
	if int(offline_summary.get("raw_seconds", 0)) > 0:
		GameState.apply_offline_progress(offline_summary)
		save_game()
	_loaded = true
	return true

func save_game() -> bool:
	if _test_mode:
		return false
	GameState.set_last_saved_unix(int(Time.get_unix_time_from_system()))
	var text: String = SaveCodec.state_to_json(GameState.get_save_state())
	var file: FileAccess = FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("無法寫入存檔：%s" % _save_path)
		return false
	file.store_string(text)
	file.close()
	_loaded = true
	return true

func is_loaded() -> bool:
	return _loaded

func is_capture_mode() -> bool:
	return _capture_mode

func is_test_mode() -> bool:
	return _test_mode

func get_active_save_path() -> String:
	return _save_path

func _on_window_close_requested() -> void:
	if _closing:
		return
	_closing = true
	save_game()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_window_close_requested()

func _resolve_save_path() -> String:
	return get_save_path_for_mode(_capture_mode, _get_override_path())

func _get_override_path() -> String:
	var environment_path: String = OS.get_environment("MYIDLE_SAVE_PATH")
	if not environment_path.is_empty():
		return environment_path
	var arguments: Array[String] = []
	arguments.append_array(OS.get_cmdline_args())
	arguments.append_array(OS.get_cmdline_user_args())
	for index: int in range(arguments.size()):
		var argument: String = arguments[index]
		if argument.begins_with("--save-path="):
			return argument.trim_prefix("--save-path=")
		if argument == "--save-path" and index + 1 < arguments.size():
			return arguments[index + 1]
	return ""

func _detect_capture_mode() -> bool:
	if OS.get_environment("CAPTURE_MODE") == "1":
		return true
	for argument: String in _all_command_arguments():
		if argument.ends_with("tools/capture_screenshot.gd") or argument.ends_with("capture_screenshot.gd"):
			return true
	return false

func _detect_test_mode() -> bool:
	if OS.get_environment("MYIDLE_TEST_MODE") == "1":
		return true
	# Any explicit save-path/tool invocation is isolated; fail closed if a
	# script launches before its environment setup has completed.
	if not OS.get_environment("MYIDLE_SAVE_PATH").is_empty():
		return true
	for argument: String in _all_command_arguments():
		if argument.begins_with("--save-path") or argument == "--save-path":
			return true
		if argument.ends_with("tests/run_tests.gd") or argument.ends_with("tests/test_worker.gd") or (argument.contains("tools/") and argument.ends_with(".gd")):
			return true
	return false

func _all_command_arguments() -> Array[String]:
	var arguments: Array[String] = []
	arguments.append_array(OS.get_cmdline_args())
	arguments.append_array(OS.get_cmdline_user_args())
	return arguments

func _reset_isolated_save(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
