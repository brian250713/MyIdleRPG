extends SceneTree

const DEFAULT_WAIT_SECONDS: float = 10.0

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	var wait_seconds: float = _get_wait_seconds()
	var output_path: String = OS.get_environment("CAP_OUT")
	if output_path.is_empty():
		output_path = "user://capture.png"
	var expanded: bool = OS.get_environment("CAP_EXPANDED") == "1"
	var game_state: Node = root.get_node("GameState")
	var window_manager: Node = root.get_node("WindowManager")
	game_state.call("set_setting", "expanded", expanded)
	window_manager.call("set_expanded", expanded)
	window_manager.call("apply_window_mode")

	var packed_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if packed_scene == null:
		print("CAPTURE_ERROR=missing_main_scene")
		quit(1)
		return
	var main_scene: Node = packed_scene.instantiate()
	root.add_child(main_scene)
	if OS.get_environment("CAP_DEBUG_LOOT") == "1":
		game_state.call("seed_debug_loot")
	var selected_tab: String = OS.get_environment("CAP_TAB")
	if not selected_tab.is_empty():
		var expanded_panel: Node = main_scene.get_node("Layout/ExpandedPanel")
		expanded_panel.call("select_tab", selected_tab)
		var selected_item_text: String = OS.get_environment("CAP_SELECT_ITEM")
		if not selected_item_text.is_empty():
			expanded_panel.call("select_inventory_slot", selected_item_text.to_int())
	await process_frame
	await _wait_for_seconds(wait_seconds)
	await process_frame

	var viewport_texture: ViewportTexture = root.get_texture()
	var image: Image = viewport_texture.get_image()
	if image == null:
		print("CAPTURE_ERROR=no_viewport_image")
		quit(1)
		return
	var absolute_path: String = ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		print("CAPTURE_ERROR=save_failed:%s" % error_string(save_error))
		quit(1)
		return
	print("CAPTURE_PATH=", absolute_path)
	print("CAPTURE_SIZE=", root.size)
	quit(0)

func _get_wait_seconds() -> float:
	var value: String = OS.get_environment("CAP_SECONDS")
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if value.is_empty() and not user_args.is_empty():
		value = user_args[0]
	if value.is_empty():
		var all_args: PackedStringArray = OS.get_cmdline_args()
		for argument: String in all_args:
			if argument.is_valid_float():
				value = argument
				break
	if value.is_empty():
		return DEFAULT_WAIT_SECONDS
	return maxf(0.0, value.to_float())

func _wait_for_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var start_msec: int = Time.get_ticks_msec()
	var duration_msec: int = int(seconds * 1000.0)
	while Time.get_ticks_msec() - start_msec < duration_msec:
		await process_frame
