extends Control

@onready var _expanded_panel: ExpandedPanel = $Layout/ExpandedPanel
@onready var _bottom_bar: HBoxContainer = $Layout/BottomBar
@onready var _battlefield: Battlefield = $Layout/BottomBar/Battlefield
@onready var _hud: BattleHUD = $Layout/BottomBar/HUD

var _offline_dialog: AcceptDialog

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_layout_for_window(WindowManager.is_expanded())
	WindowManager.window_mode_changed.connect(_on_window_mode_changed)
	WindowManager.always_on_top_changed.connect(_on_always_on_top_changed)
	_hud.set_battlefield(_battlefield)
	_hud.expand_requested.connect(_on_expand_requested)
	_hud.auto_advance_changed.connect(_on_auto_advance_changed)
	_hud.always_on_top_changed.connect(_on_always_on_top_changed)
	_hud.open_chests_requested.connect(_on_open_chests_requested)
	_expanded_panel.stage_selected.connect(_on_stage_selected)
	_expanded_panel.difficulty_selected.connect(_on_difficulty_selected)
	_expanded_panel.auto_advance_changed.connect(_on_auto_advance_changed)
	_battlefield.start_campaign()
	_expanded_panel.refresh()
	var offline_summary: Dictionary = GameState.get_offline_summary()
	if int(offline_summary.get("raw_seconds", 0)) >= 60 and bool(offline_summary.get("ok", false)):
		call_deferred("show_offline_summary", offline_summary)

func show_offline_summary(summary: Dictionary) -> void:
	if summary.is_empty() or int(summary.get("raw_seconds", 0)) < 60 or not bool(summary.get("ok", false)):
		return
	if not is_instance_valid(_offline_dialog):
		_offline_dialog = AcceptDialog.new()
		_offline_dialog.title = "離線收益"
		_offline_dialog.ok_button_text = "確定"
		add_child(_offline_dialog)
		var content: VBoxContainer = VBoxContainer.new()
		content.name = "OfflineSummary"
		_offline_dialog.add_child(content)
		var away_label: Label = Label.new()
		away_label.name = "AwayLabel"
		content.add_child(away_label)
		var reward_label: Label = Label.new()
		reward_label.name = "RewardLabel"
		content.add_child(reward_label)
		var chest_label: Label = Label.new()
		chest_label.name = "ChestLabel"
		content.add_child(chest_label)
		var away_text: String = _format_offline_seconds(float(summary.get("away_seconds", 0.0)))
		(_offline_dialog.get_node("OfflineSummary/AwayLabel") as Label).text = "離線時間：%s" % away_text
		(_offline_dialog.get_node("OfflineSummary/RewardLabel") as Label).text = "金幣 +%d　經驗 +%d" % [int(summary.get("gold", 0)), int(summary.get("xp", 0))]
		(_offline_dialog.get_node("OfflineSummary/ChestLabel") as Label).text = "白箱 +%d" % int(summary.get("white_chests", 0))
	_offline_dialog.popup_centered(Vector2(360.0, 190.0))

func _format_offline_seconds(seconds: float) -> String:
	var total_minutes: int = int(seconds / 60.0)
	var hours: int = total_minutes / 60
	var minutes: int = total_minutes % 60
	if hours > 0:
		return "%d 小時 %d 分鐘" % [hours, minutes]
	return "%d 分鐘" % minutes

func _layout_for_window(expanded: bool) -> void:
	_expanded_panel.visible = expanded
	_bottom_bar.custom_minimum_size = Vector2(0.0, WindowManager.STRIP_HEIGHT)
	_bottom_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var layout: VBoxContainer = $Layout
	layout.queue_sort()

func _on_window_mode_changed(expanded: bool) -> void:
	_layout_for_window(expanded)
	_hud.refresh()
	_expanded_panel.refresh()

func _on_expand_requested() -> void:
	WindowManager.toggle_expanded()

func _on_auto_advance_changed(enabled: bool) -> void:
	GameState.set_setting("auto_advance", enabled)
	_battlefield.set_auto_advance(enabled)

func _on_always_on_top_changed(_enabled: bool) -> void:
	_hud.refresh()

func _on_stage_selected(stage_index: int) -> void:
	_battlefield.select_stage(stage_index)

func _on_difficulty_selected(difficulty_id: String) -> void:
	_battlefield.select_difficulty(difficulty_id)

func _on_open_chests_requested() -> void:
	GameState.open_next_chest()
