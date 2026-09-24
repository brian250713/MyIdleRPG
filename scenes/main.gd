extends Control

@onready var _expanded_panel: ExpandedPanel = $Layout/ExpandedPanel
@onready var _bottom_bar: HBoxContainer = $Layout/BottomBar
@onready var _battlefield: Battlefield = $Layout/BottomBar/Battlefield
@onready var _hud: BattleHUD = $Layout/BottomBar/HUD

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_layout_for_window(WindowManager.is_expanded())
	WindowManager.window_mode_changed.connect(_on_window_mode_changed)
	WindowManager.always_on_top_changed.connect(_on_always_on_top_changed)
	_hud.set_battlefield(_battlefield)
	_hud.expand_requested.connect(_on_expand_requested)
	_hud.auto_advance_changed.connect(_on_auto_advance_changed)
	_hud.always_on_top_changed.connect(_on_always_on_top_changed)
	_expanded_panel.stage_selected.connect(_on_stage_selected)
	_expanded_panel.auto_advance_changed.connect(_on_auto_advance_changed)
	_battlefield.start_campaign()
	_expanded_panel.refresh()

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
