class_name BattleHUD
extends PanelContainer

signal expand_requested
signal auto_advance_changed(enabled: bool)
signal always_on_top_changed(enabled: bool)
signal open_chests_requested

var _battlefield: Battlefield
var _gold_label: Label
var _stage_label: Label
var _auto_button: CheckButton
var _topmost_button: Button
var _expand_button: Button
var _chest_label: Label
var _soul_label: Label
var _open_chests_button: Button
var _party_rows: VBoxContainer
var _updating_controls: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(380.0, 180.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _make_panel_style())
	_build_interface()
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.setting_changed.connect(_on_setting_changed)
	refresh()

func set_battlefield(battlefield: Battlefield) -> void:
	_battlefield = battlefield
	refresh()

func refresh() -> void:
	_update_top_controls()
	_update_stage_text()
	_update_party_rows()

func _process(_delta: float) -> void:
	_update_stage_text()

func _build_interface() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.custom_minimum_size = Vector2(0.0, 28.0)
	top_row.add_theme_constant_override("separation", 4)
	column.add_child(top_row)

	_gold_label = _make_label("金幣 0", 11, Color(1.0, 0.84, 0.32))
	_gold_label.custom_minimum_size = Vector2(78.0, 0.0)
	top_row.add_child(_gold_label)
	_stage_label = _make_label("普通 1-1", 10, Color(0.83, 0.91, 1.0))
	_stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_stage_label)

	_auto_button = CheckButton.new()
	_auto_button.text = "自動"
	_auto_button.tooltip_text = "自動推進"
	_auto_button.focus_mode = Control.FOCUS_NONE
	_auto_button.add_theme_font_size_override("font_size", 14)
	top_row.add_child(_auto_button)
	_auto_button.toggled.connect(_on_auto_toggled)

	_topmost_button = Button.new()
	_topmost_button.text = "置頂"
	_topmost_button.tooltip_text = "切換置頂"
	_topmost_button.focus_mode = Control.FOCUS_NONE
	_topmost_button.add_theme_font_size_override("font_size", 14)
	_topmost_button.pressed.connect(_on_topmost_pressed)
	top_row.add_child(_topmost_button)

	_expand_button = Button.new()
	_expand_button.text = "展開"
	_expand_button.focus_mode = Control.FOCUS_NONE
	_expand_button.add_theme_font_size_override("font_size", 14)
	_expand_button.pressed.connect(_on_expand_pressed)
	top_row.add_child(_expand_button)

	var chest_row: HBoxContainer = HBoxContainer.new()
	chest_row.name = "ChestRow"
	chest_row.custom_minimum_size = Vector2(0.0, 24.0)
	chest_row.add_theme_constant_override("separation", 5)
	column.add_child(chest_row)
	_chest_label = _make_label("箱 白0 藍0 幕0", 11, Color(0.82, 0.88, 0.98))
	_chest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest_row.add_child(_chest_label)
	_soul_label = _make_label("靈魂石 0", 10, Color(0.72, 0.76, 1.0))
	chest_row.add_child(_soul_label)
	_open_chests_button = Button.new()
	_open_chests_button.text = "開箱"
	_open_chests_button.focus_mode = Control.FOCUS_NONE
	_open_chests_button.add_theme_font_size_override("font_size", 14)
	_open_chests_button.pressed.connect(_on_open_chests_pressed)
	chest_row.add_child(_open_chests_button)

	var separator: HSeparator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0.0, 2.0)
	column.add_child(separator)

	_party_rows = VBoxContainer.new()
	_party_rows.name = "PartyRows"
	_party_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_party_rows.add_theme_constant_override("separation", 3)
	column.add_child(_party_rows)

func _update_top_controls() -> void:
	_updating_controls = true
	_gold_label.text = "金幣 %d" % GameState.get_gold()
	_auto_button.button_pressed = bool(GameState.get_setting("auto_advance", true))
	_topmost_button.text = "置頂：開" if bool(GameState.get_setting("always_on_top", true)) else "置頂：關"
	_expand_button.text = "收合" if WindowManager.is_expanded() else "展開"
	var chest_counts: Dictionary = GameState.get_chest_counts()
	_chest_label.text = "箱 白%d 藍%d 幕%d" % [int(chest_counts.get("white", 0)), int(chest_counts.get("blue", 0)), int(chest_counts.get("act_boss", 0))]
	_soul_label.text = "靈魂石 %d" % GameState.get_soul_stones()
	_open_chests_button.disabled = Chests.get_queue_size(GameState.get_chest_state()) == 0
	_updating_controls = false

func _update_stage_text() -> void:
	if _stage_label == null:
		return
	if _battlefield == null:
		_stage_label.text = StageData.get_display_name(GameState.get_current_stage())
		return
	var snapshot: Dictionary = _battlefield.get_snapshot()
	var wave_text: String = "首領" if bool(snapshot.get("boss_active", false)) else "第 %d/%d 波" % [int(snapshot.get("wave_number", 1)), int(snapshot.get("wave_count", 5))]
	_stage_label.text = "%s · %s" % [str(snapshot.get("stage_name", "普通 1-1")), wave_text]
	_stage_label.tooltip_text = str(snapshot.get("status", ""))

func _update_party_rows() -> void:
	if _party_rows == null:
		return
	for child: Node in _party_rows.get_children():
		_party_rows.remove_child(child)
		child.queue_free()
	var active_heroes: Array[Dictionary] = GameState.get_active_heroes()
	for hero: Dictionary in active_heroes:
		var row: PanelContainer = PanelContainer.new()
		row.custom_minimum_size = Vector2(0.0, 34.0)
		row.add_theme_stylebox_override("panel", _make_row_style())
		_party_rows.add_child(row)
		var row_margin: MarginContainer = MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 6)
		row_margin.add_theme_constant_override("margin_right", 6)
		row_margin.add_theme_constant_override("margin_top", 2)
		row_margin.add_theme_constant_override("margin_bottom", 2)
		row.add_child(row_margin)
		var row_column: VBoxContainer = VBoxContainer.new()
		row_column.add_theme_constant_override("separation", 1)
		row_margin.add_child(row_column)
		var name_row: HBoxContainer = HBoxContainer.new()
		row_column.add_child(name_row)
		var class_definition: Dictionary = ClassData.get_class_definition(str(hero.get("class_id", "knight")))
		var class_title: String = str(class_definition.get("name", "英雄"))
		var level: int = int(hero.get("level", 1))
		var name_label: Label = _make_label("%s  Lv.%d" % [class_title, level], 10, Color(0.88, 0.93, 1.0))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(name_label)
		var xp_label: Label = _make_label(_xp_text(level, int(hero.get("xp", 0))), 9, Color(0.65, 0.75, 0.9))
		xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_row.add_child(xp_label)
		var bar: ProgressBar = ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = maxf(1.0, float(XPCurve.xp_to_next(level)))
		bar.value = minf(float(hero.get("xp", 0)), bar.max_value)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0.0, 5.0)
		row_column.add_child(bar)
	if active_heroes.is_empty():
		var empty_label: Label = _make_label("等待小隊成員", 10, Color(0.65, 0.72, 0.85))
		_party_rows.add_child(empty_label)

func _xp_text(level: int, xp: int) -> String:
	if level >= XPCurve.MAX_LEVEL:
		return "MAX"
	return "%d/%d" % [xp, XPCurve.xp_to_next(level)]

func _on_state_changed() -> void:
	refresh()

func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "auto_advance" or key == "always_on_top" or key == "expanded":
		refresh()

func _on_auto_toggled(enabled: bool) -> void:
	if _updating_controls:
		return
	auto_advance_changed.emit(enabled)

func _on_topmost_pressed() -> void:
	always_on_top_changed.emit(not bool(GameState.get_setting("always_on_top", true)))

func _on_expand_pressed() -> void:
	expand_requested.emit()

func _on_open_chests_pressed() -> void:
	open_chests_requested.emit()

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(14, font_size))
	label.add_theme_color_override("font_color", color)
	return label

func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.06, 0.11, 0.98)
	style.border_color = Color(0.18, 0.28, 0.42, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	return style

func _make_row_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.20, 0.92)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style
