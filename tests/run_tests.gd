extends SceneTree

## 每個案例在獨立程序執行；即使案例陷入無限迴圈，主測試器仍能在逾時後繼續。
const TEST_TIMEOUT_MSEC: int = 10000
const PROCESS_POLL_MSEC: int = 10

var _failures: int = 0
var _cases_run: int = 0

func _init() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	var test_files: PackedStringArray = DirAccess.get_files_at("res://tests")
	test_files.sort()
	for file_name: String in test_files:
		if not file_name.begins_with("test_") or not file_name.ends_with(".gd"):
			continue
		if file_name == "test_worker.gd":
			continue
		var path: String = "res://tests/%s" % file_name
		var script: Script = load(path) as Script
		if script == null:
			_failures += 1
			print("FAIL %s：無法載入測試腳本" % path)
			continue
		var method_names: Array[String] = []
		for method_info: Dictionary in script.get_script_method_list():
			var method_name: String = str(method_info.get("name", ""))
			if method_name.begins_with("test_") and not method_names.has(method_name):
				method_names.append(method_name)
		method_names.sort()
		for method_name: String in method_names:
			_cases_run += 1
			_run_isolated_case(file_name, method_name)
	print("測試完成：%d 個案例，%d 個失敗" % [_cases_run, _failures])
	quit(1 if _failures > 0 else 0)

func _run_isolated_case(file_name: String, method_name: String) -> void:
	var executable: String = OS.get_executable_path()
	var project_path: String = ProjectSettings.globalize_path("res://")
	var arguments: PackedStringArray = PackedStringArray([
		"--headless",
		"--path", project_path,
		"-s", "res://tests/test_worker.gd",
		"--", "--file", "res://tests/%s" % file_name, "--method", method_name
	])
	var process_id: int = OS.create_process(executable, arguments, false)
	if process_id <= 0:
		_failures += 1
		print("FAIL %s::%s：無法啟動隔離測試程序" % [file_name, method_name])
		return
	var start_msec: int = Time.get_ticks_msec()
	var timed_out: bool = false
	while OS.is_process_running(process_id):
		if Time.get_ticks_msec() - start_msec >= TEST_TIMEOUT_MSEC:
			timed_out = true
			OS.kill(process_id)
			break
		OS.delay_msec(PROCESS_POLL_MSEC)
	if timed_out:
		_failures += 1
		print("FAIL %s::%s：超過單一案例時間上限 %d ms" % [file_name, method_name, TEST_TIMEOUT_MSEC])
		return
	var exit_code: int = OS.get_process_exit_code(process_id)
	if exit_code == 0:
		print("PASS %s::%s" % [file_name, method_name])
	else:
		_failures += 1
		print("FAIL %s::%s：測試程序結束碼 %d" % [file_name, method_name, exit_code])
