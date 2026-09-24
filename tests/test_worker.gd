extends SceneTree

## 在獨立 Godot 程序執行單一測試，讓主測試器可以安全地逾時中止它。
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var file_path: String = _argument_value(arguments, "--file")
	var method_name: String = _argument_value(arguments, "--method")
	if file_path.is_empty() or method_name.is_empty():
		print("TEST_WORKER_ERROR=missing_arguments")
		quit(2)
		return
	var script: Script = load(file_path) as Script
	if script == null:
		print("TEST_WORKER_ERROR=load_failed:%s" % file_path)
		quit(2)
		return
	var instance: Object = script.new()
	if not instance.has_method(method_name):
		print("TEST_WORKER_ERROR=method_not_found:%s" % method_name)
		quit(2)
		return
	var result: Variant = instance.call(method_name)
	if result is Object:
		var async_state: Object = result
		if async_state.has_signal("completed"):
			result = await async_state.completed
	if bool(result):
		print("TEST_WORKER_PASS=%s::%s" % [file_path, method_name])
		quit(0)
		return
	print("TEST_WORKER_FAIL=%s::%s" % [file_path, method_name])
	quit(1)

func _argument_value(arguments: PackedStringArray, key: String) -> String:
	var key_index: int = arguments.find(key)
	if key_index < 0 or key_index + 1 >= arguments.size():
		return ""
	return str(arguments[key_index + 1])
