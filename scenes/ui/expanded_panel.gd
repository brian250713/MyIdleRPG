class_name ExpandedPanel
extends PanelContainer

signal stage_selected(stage_index: int)
signal auto_advance_changed(enabled: bool)

var _tabs: TabContainer
var _party_content: VBoxContainer
var _stage_content: VBoxContainer
var _auto_setting_button: CheckButton
var _topmost_setting_button: CheckButton
var _updating_settings: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 440.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _make_panel_style())
	_build_interface()
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.setting_changed.connect(_on_setting_changed)
	EventBus.stage_changed.connect(_on_stage_changed)
	refresh()

func refresh() -> void:
	_refresh_party_tab()
	_refresh_stage_tab()
	_refresh_settings_tab()

func _build_interface() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var heading: Label = Label.new()
	heading.text = "隊伍與關卡管理"
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	column.add_child(heading)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 14)
	column.add_child(_tabs)
	_build_party_tab()
	_build_placeholder_tab("背包", "背包將在 Phase 2 開放。")
	_build_placeholder_tab("技能", "技能將在 Phase 3 開放。")
	_build_placeholder_tab("方塊", "方塊將在 Phase 4 開放。")
	_build_placeholder_tab("符文", "符文將在 Phase 4 開放。")
	_build_stage_tab()
	_build_settings_tab()

func _build_party_tab() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "小隊"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	_party_content = VBoxContainer.new()
	_party_content.name = "PartyContent"
	_party_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_party_content)

func _build_stage_tab() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "關卡"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	_stage_content = VBoxContainer.new()
	_stage_content.name = "StageContent"
	_stage_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_content.add_theme_constant_override("separation", 4)
	scroll.add_child(_stage_content)

func _build_placeholder_tab(tab_name: String, message: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = tab_name
	_tabs.add_child(panel)
	var label: Label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.60, 0.68, 0.82))
	panel.add_child(label)

func _build_settings_tab() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "設定"
	_tabs.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_auto_setting_button = CheckButton.new()
	_auto_setting_button.text = "自動推進"
	_auto_setting_button.focus_mode = Control.FOCUS_NONE
	_auto_setting_button.toggled.connect(_on_auto_setting_toggled)
	column.add_child(_auto_setting_button)
	_topmost_setting_button = CheckButton.new()
	_topmost_setting_button.text = "視窗置頂"
	_topmost_setting_button.focus_mode = Control.FOCUS_NONE
	_topmost_setting_button.toggled.connect(_on_topmost_setting_toggled)
	column.add_child(_topmost_setting_button)
	column.add_child(_make_note("設定會自動儲存；視窗拖曳可按住戰場背景。"))

func _refresh_settings_tab() -> void:
	if _auto_setting_button == null or _topmost_setting_button == null:
		return
	_updating_settings = true
	_auto_setting_button.button_pressed = bool(GameState.get_setting("auto_advance", true))
	_topmost_setting_button.button_pressed = bool(GameState.get_setting("always_on_top", true))
	_updating_settings = false

func _refresh_party_tab() -> void:
	_clear_content(_party_content)
	var party: Array = GameState.get_party()
	for slot_index: int in range(3):
		_party_content.add_child(_make_slot_card(slot_index, party))
	_party_content.add_child(_make_note("隊伍槽位在主將等級 5、15 解鎖；各職業等級與經驗獨立計算。"))

func _make_slot_card(slot_index: int, party: Array) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_card_style())
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	card.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var hero_value: Variant = party[slot_index] if slot_index < party.size() else null
	if not (hero_value is Dictionary):
		var required_level: int = 5 if slot_index == 1 else 15
		var locked_label: Label = _make_label("槽位 %d：未解鎖（主將 Lv.%d 解鎖）" % [slot_index + 1, required_level], 13, Color(0.58, 0.66, 0.80))
		column.add_child(locked_label)
		return card
	var hero: Dictionary = hero_value
	var class_id: String = str(hero.get("class_id", "knight"))
	var class_definition: Dictionary = ClassData.get_class_definition(class_id)
	var class_title: String = str(class_definition.get("name", class_id))
	var level: int = int(hero.get("level", 1))
	var header: Label = _make_label("槽位 %d：%s  Lv.%d  ·  %s" % [slot_index + 1, class_title, level, str(class_definition.get("role", ""))], 14, Color(0.90, 0.94, 1.0))
	column.add_child(header)
	var stats: Dictionary = Stats.calculate_class_stats(class_id, level)
	var stats_text: String = "生命 %d   攻擊 %d   攻速 %.2f   暴擊 %.1f%%   防禦 %d" % [int(stats.get("max_hp", 0)), int(stats.get("attack", 0)), float(stats.get("attack_speed", 0.0)), float(stats.get("crit_chance", 0.0)) * 100.0, int(stats.get("defense", 0))]
	column.add_child(_make_label(stats_text, 11, Color(0.72, 0.82, 0.95)))
	var xp_text: String = "經驗 %d/%d" % [int(hero.get("xp", 0)), XPCurve.xp_to_next(level)]
	if level >= XPCurve.MAX_LEVEL:
		xp_text = "經驗 MAX"
	column.add_child(_make_label(xp_text, 10, Color(0.55, 0.72, 0.92)))
	var class_row: HBoxContainer = HBoxContainer.new()
	class_row.add_theme_constant_override("separation", 4)
	column.add_child(class_row)
	for candidate_id: String in ClassData.get_class_ids():
		var button: Button = Button.new()
		button.text = str(ClassData.get_class_definition(candidate_id).get("name", candidate_id))
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 14)
		button.disabled = not _can_select_class(slot_index, candidate_id, party)
		if candidate_id == class_id:
			button.text = "目前：%s" % button.text
		button.pressed.connect(_on_class_selected.bind(slot_index, candidate_id))
		class_row.add_child(button)
	return card

func _can_select_class(slot_index: int, candidate_id: String, party: Array) -> bool:
	if not GameState.is_party_slot_unlocked(slot_index):
		return false
	for index: int in range(party.size()):
		if index == slot_index:
			continue
		var hero_value: Variant = party[index]
		if hero_value is Dictionary and str(hero_value.get("class_id", "")) == candidate_id:
			return false
	return true

func _refresh_stage_tab() -> void:
	_clear_content(_stage_content)
	_stage_content.add_child(_make_note("選擇已解鎖的普通關卡；目前進度會在關閉遊戲後保留。"))
	var table: Array[Dictionary] = StageData.get_stage_table()
	var current_stage: int = GameState.get_current_stage()
	for stage: Dictionary in table:
		var stage_index: int = int(stage.get("index", 0))
		var button: Button = Button.new()
		var is_current: bool = stage_index == current_stage
		button.text = "%s%s  ·  建議 Lv.%d  ·  %d 波%s" % [
			str(stage.get("display_name", "普通 1-1")),
			"（目前）" if is_current else "",
			int(stage.get("recommended_level", 1)),
			int(stage.get("wave_count", 5)),
			"  ·  首領" if bool(stage.get("is_act_boss", false)) else ""
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = stage_index > GameState.get_unlocked_stage()
		button.pressed.connect(_on_stage_pressed.bind(stage_index))
		_stage_content.add_child(button)

func _make_note(text: String) -> Label:
	return _make_label(text, 10, Color(0.57, 0.67, 0.82))

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(14, font_size))
	label.add_theme_color_override("font_color", color)
	return label

func _clear_content(content: VBoxContainer) -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _on_auto_setting_toggled(enabled: bool) -> void:
	if _updating_settings:
		return
	GameState.set_setting("auto_advance", enabled)
	auto_advance_changed.emit(enabled)

func _on_topmost_setting_toggled(enabled: bool) -> void:
	if _updating_settings:
		return
	WindowManager.set_always_on_top(enabled)

func _on_setting_changed(_key: String, _value: Variant) -> void:
	_refresh_settings_tab()

func _on_class_selected(slot_index: int, class_id: String) -> void:
	GameState.set_party_slot(slot_index, class_id)
	refresh()

func _on_stage_pressed(stage_index: int) -> void:
	stage_selected.emit(stage_index)

func _on_state_changed() -> void:
	refresh()

func _on_stage_changed(_stage_index: int, _display_name: String) -> void:
	_refresh_stage_tab()

func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.05, 0.095, 1.0)
	style.border_color = Color(0.18, 0.28, 0.45, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	return style

func _make_card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.11, 0.18, 0.96)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
