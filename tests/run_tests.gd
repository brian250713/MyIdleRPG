extends SceneTree

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
		var path: String = "res://tests/%s" % file_name
		var script: Script = load(path) as Script
		if script == null:
			_failures += 1
			print("FAIL %s：無法載入測試腳本" % path)
			continue
		var instance: Object = script.new()
		for method_info: Dictionary in instance.get_method_list():
			var method_name: String = str(method_info.get("name", ""))
			if not method_name.begins_with("test_"):
				continue
			_cases_run += 1
			var result: Variant = instance.call(method_name)
			if bool(result):
				print("PASS %s::%s" % [file_name, method_name])
			else:
				_failures += 1
				print("FAIL %s::%s" % [file_name, method_name])
	print("測試完成：%d 個案例，%d 個失敗" % [_cases_run, _failures])
	quit(1 if _failures > 0 else 0)
