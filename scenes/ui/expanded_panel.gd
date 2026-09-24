class_name ExpandedPanel
extends PanelContainer

signal stage_selected(stage_index: int)
signal difficulty_selected(difficulty_id: String)
signal auto_advance_changed(enabled: bool)

var _tabs: TabContainer
var _party_content: VBoxContainer
var _inventory_grid: GridContainer
var _inventory_detail: VBoxContainer
var _inventory_summary: Label
var _skills_content: VBoxContainer
var _stage_content: VBoxContainer
var _difficulty_selector: OptionButton
var _updating_difficulty: bool = false
var _selected_inventory_slot: int = -1
var _auto_setting_button: CheckButton
var _topmost_setting_button: CheckButton
var _auto_open_buttons: Dictionary = {}
var _auto_sell_buttons: Dictionary = {}
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
	_refresh_inventory_tab()
	_refresh_skills_tab()
	_refresh_stage_tab()
	_refresh_settings_tab()

func select_tab(tab_name: String) -> void:
	if _tabs == null:
		return
	for index: int in range(_tabs.get_tab_count()):
		if _tabs.get_tab_title(index) == tab_name:
			_tabs.current_tab = index
			return

func select_inventory_slot(slot_index: int) -> void:
	_selected_inventory_slot = slot_index
	_refresh_inventory_tab()

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
	var heading: Label = _make_label("隊伍、裝備與關卡", 18, Color(0.78, 0.88, 1.0))
	column.add_child(heading)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 14)
	column.add_child(_tabs)
	_build_party_tab()
	_build_inventory_tab()
	_build_skills_tab()
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
	_party_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_party_content)

func _build_inventory_tab() -> void:
	var root: HBoxContainer = HBoxContainer.new()
	root.name = "背包"
	root.add_theme_constant_override("separation", 12)
	_tabs.add_child(root)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	_inventory_summary = _make_label("背包 0/40", 14, Color(0.82, 0.88, 0.98))
	left.add_child(_inventory_summary)
	var batch_row: HBoxContainer = HBoxContainer.new()
	batch_row.add_theme_constant_override("separation", 3)
	left.add_child(batch_row)
	for rarity_id: String in ItemData.get_rarity_ids():
		var batch_button: Button = Button.new()
		batch_button.text = "販售%s" % ItemData.get_rarity_name(rarity_id)
		batch_button.focus_mode = Control.FOCUS_NONE
		batch_button.add_theme_font_size_override("font_size", 11)
		batch_button.pressed.connect(_on_batch_sell.bind(rarity_id))
		batch_row.add_child(batch_button)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 8
	_inventory_grid.add_theme_constant_override("h_separation", 4)
	_inventory_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_inventory_grid)
	var detail_panel: PanelContainer = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(310.0, 0.0)
	detail_panel.add_theme_stylebox_override("panel", _make_card_style())
	root.add_child(detail_panel)
	var detail_margin: MarginContainer = MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 10)
	detail_margin.add_theme_constant_override("margin_right", 10)
	detail_margin.add_theme_constant_override("margin_top", 8)
	detail_margin.add_theme_constant_override("margin_bottom", 8)
	detail_panel.add_child(detail_margin)
	_inventory_detail = VBoxContainer.new()
	_inventory_detail.add_theme_constant_override("separation", 5)
	detail_margin.add_child(_inventory_detail)

func _build_skills_tab() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "技能"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	_skills_content = VBoxContainer.new()
	_skills_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_skills_content)

func _build_stage_tab() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "關卡"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	_stage_content = VBoxContainer.new()
	_stage_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_content.add_theme_constant_override("separation", 4)
	scroll.add_child(_stage_content)

func _build_placeholder_tab(tab_name: String, message: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = tab_name
	_tabs.add_child(panel)
	var label: Label = _make_label(message, 14, Color(0.60, 0.68, 0.82))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)

func _build_settings_tab() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "設定"
	_tabs.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
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
	column.add_child(_make_label("寶箱自動開啟", 14, Color(0.80, 0.86, 0.96)))
	for chest_type: String in ["white", "blue", "act_boss"]:
		var button: CheckButton = CheckButton.new()
		button.text = _chest_type_name(chest_type)
		button.focus_mode = Control.FOCUS_NONE
		button.toggled.connect(_on_auto_open_toggled.bind(chest_type))
		column.add_child(button)
		_auto_open_buttons[chest_type] = button
	column.add_child(_make_label("掉落在線上自動販售", 14, Color(0.80, 0.86, 0.96)))
	for rarity_id: String in ["common", "uncommon"]:
		var button: CheckButton = CheckButton.new()
		button.text = ItemData.get_rarity_name(rarity_id)
		button.focus_mode = Control.FOCUS_NONE
		button.toggled.connect(_on_auto_sell_toggled.bind(rarity_id))
		column.add_child(button)
		_auto_sell_buttons[rarity_id] = button
	column.add_child(_make_note("設定會自動儲存；視窗拖曳可按住戰場背景。"))

func _refresh_settings_tab() -> void:
	if _auto_setting_button == null or _topmost_setting_button == null:
		return
	_updating_settings = true
	_auto_setting_button.button_pressed = bool(GameState.get_setting("auto_advance", true))
	_topmost_setting_button.button_pressed = bool(GameState.get_setting("always_on_top", true))
	for chest_type: String in ["white", "blue", "act_boss"]:
		var chest_button: CheckButton = _auto_open_buttons[chest_type]
		chest_button.button_pressed = bool(GameState.get_setting("auto_open_%s" % chest_type, false))
	for rarity_id: String in ["common", "uncommon"]:
		var sell_button: CheckButton = _auto_sell_buttons[rarity_id]
		sell_button.button_pressed = bool(GameState.get_setting("auto_sell_%s" % rarity_id, false))
	_updating_settings = false

func _refresh_party_tab() -> void:
	_clear_content(_party_content)
	var party: Array = GameState.get_party()
	for slot_index: int in range(3):
		_party_content.add_child(_make_slot_card(slot_index, party))
	_party_content.add_child(_make_note("隊伍槽位在主將等級 5、15 解鎖；點擊裝備欄可卸下。"))

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
		column.add_child(_make_label("槽位 %d：未解鎖（主將 Lv.%d 解鎖）" % [slot_index + 1, required_level], 14, Color(0.58, 0.66, 0.80)))
		return card
	var hero: Dictionary = hero_value
	var class_id: String = str(hero.get("class_id", "knight"))
	var class_definition: Dictionary = ClassData.get_class_definition(class_id)
	var class_title: String = str(class_definition.get("name", class_id))
	var level: int = int(hero.get("level", 1))
	column.add_child(_make_label("槽位 %d：%s  Lv.%d  ·  %s  ·  戰力 %d" % [slot_index + 1, class_title, level, str(class_definition.get("role", "")), GameState.get_hero_power(class_id)], 14, Color(0.90, 0.94, 1.0)))
	var stats: Dictionary = GameState.get_hero_stats(class_id)
	column.add_child(_make_label("生命 %d   攻擊 %d   攻速 %.2f   暴擊 %.1f%%   防禦 %d" % [int(stats.get("max_hp", 0)), int(stats.get("attack", 0)), float(stats.get("attack_speed", 0.0)), float(stats.get("crit_chance", 0.0)) * 100.0, int(stats.get("defense", 0))], 12, Color(0.72, 0.82, 0.95)))
	column.add_child(_make_label("經驗 %d/%d" % [int(hero.get("xp", 0)), XPCurve.xp_to_next(level)], 11, Color(0.55, 0.72, 0.92)))
	var equipment_grid: GridContainer = GridContainer.new()
	equipment_grid.columns = 7
	equipment_grid.add_theme_constant_override("h_separation", 4)
	equipment_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(equipment_grid)
	var equipment: Dictionary = GameState.get_equipment(class_id)
	for slot_key: String in ItemData.get_slot_ids():
		var item_value: Variant = equipment.get(slot_key, null)
		var item: Dictionary = item_value if item_value is Dictionary else {}
		var slot_button: Button = Button.new()
		slot_button.custom_minimum_size = Vector2(100.0, 48.0)
		slot_button.focus_mode = Control.FOCUS_NONE
		slot_button.text = "%s\n%s" % [ItemData.get_slot_name(slot_key), "未裝備" if item.is_empty() else ItemData.get_rarity_name(str(item.get("rarity", "common")))]
		slot_button.add_theme_font_size_override("font_size", 11)
		slot_button.tooltip_text = _item_tooltip(item) if not item.is_empty() else "點擊卸下裝備"
		if not item.is_empty():
			slot_button.icon = _item_icon_texture(item)
			slot_button.expand_icon = true
		slot_button.add_theme_stylebox_override("normal", _make_rarity_style(item.get("rarity", "common") if not item.is_empty() else "", 0))
		slot_button.pressed.connect(_on_equipment_slot_pressed.bind(class_id, slot_key))
		equipment_grid.add_child(slot_button)
	var class_row: HBoxContainer = HBoxContainer.new()
	class_row.add_theme_constant_override("separation", 4)
	column.add_child(class_row)
	for candidate_id: String in ClassData.get_class_ids():
		var class_button: Button = Button.new()
		class_button.text = str(ClassData.get_class_definition(candidate_id).get("name", candidate_id))
		class_button.focus_mode = Control.FOCUS_NONE
		class_button.add_theme_font_size_override("font_size", 14)
		class_button.disabled = not _can_select_class(slot_index, candidate_id, party)
		if candidate_id == class_id:
			class_button.text = "目前：%s" % class_button.text
		class_button.pressed.connect(_on_class_selected.bind(slot_index, candidate_id))
		class_row.add_child(class_button)
	return card

func _refresh_inventory_tab() -> void:
	_clear_grid(_inventory_grid)
	var inventory: Dictionary = GameState.get_inventory()
	var items: Array = inventory.get("slots", [])
	_inventory_summary.text = "背包 %d/40" % Inventory.count_items(inventory)
	for index: int in range(Inventory.SLOT_COUNT):
		var item_value: Variant = items[index] if index < items.size() else null
		var item: Dictionary = item_value if item_value is Dictionary else {}
		var slot_button: Button = Button.new()
		slot_button.custom_minimum_size = Vector2(78.0, 62.0)
		slot_button.focus_mode = Control.FOCUS_NONE
		slot_button.text = str(index + 1) if item.is_empty() else "%s\nLv.%d" % [ItemData.get_rarity_name(str(item.get("rarity", "common"))), int(item.get("level", 1))]
		slot_button.add_theme_font_size_override("font_size", 11)
		if not item.is_empty():
			slot_button.icon = _item_icon_texture(item)
			slot_button.expand_icon = true
			slot_button.tooltip_text = _item_tooltip(item)
			slot_button.add_theme_stylebox_override("normal", _make_rarity_style(str(item.get("rarity", "common")), 2))
		else:
			slot_button.add_theme_stylebox_override("normal", _make_rarity_style("", 1))
		slot_button.pressed.connect(_on_inventory_slot_pressed.bind(index))
		_inventory_grid.add_child(slot_button)
	_refresh_inventory_detail()

func _refresh_inventory_detail() -> void:
	_clear_content(_inventory_detail)
	var item: Dictionary = GameState.get_inventory_item(_selected_inventory_slot)
	if item.is_empty():
		_inventory_detail.add_child(_make_label("選擇左側物品查看詳情", 14, Color(0.68, 0.75, 0.88)))
		return
	var rarity_id: String = str(item.get("rarity", "common"))
	_inventory_detail.add_child(_make_label(str(item.get("name", "物品")), 16, ItemData.get_rarity_color(rarity_id)))
	_inventory_detail.add_child(_make_label("稀有度：%s   等級：%d" % [ItemData.get_rarity_name(rarity_id), int(item.get("level", 1))], 13, Color(0.80, 0.86, 0.96)))
	_inventory_detail.add_child(_make_label("欄位：%s   主屬性：%s" % [ItemData.get_slot_name(str(item.get("slot", ""))), _stat_text(str(item.get("main_stat", "")), float(item.get("main_value", 0.0)), _is_percent_stat(str(item.get("main_stat", ""))))], 12, Color(0.78, 0.84, 0.94)))
	var affixes: Array = item.get("affixes", [])
	if affixes.is_empty():
		_inventory_detail.add_child(_make_label("詞綴：無", 12, Color(0.65, 0.72, 0.84)))
	else:
		for affix_value: Variant in affixes:
			if affix_value is Dictionary:
				var affix: Dictionary = affix_value
				var affix_percent: bool = bool(affix.get("percent", false)) or _is_percent_stat(str(affix.get("stat", "")))
				_inventory_detail.add_child(_make_label("詞綴：%s" % _stat_text(str(affix.get("stat", "")), float(affix.get("value", 0.0)), affix_percent), 11, Color(0.75, 0.84, 0.96)))
	var sockets: Array = item.get("sockets", [])
	var socket_names: Array[String] = []
	for socket_value: Variant in sockets:
		if socket_value is Dictionary:
			socket_names.append(_socket_name(str(socket_value.get("type", ""))))
	_inventory_detail.add_child(_make_label("鑲嵌格：%s" % ("、".join(socket_names) if not socket_names.is_empty() else "無"), 11, Color(0.72, 0.78, 0.90)))
	var lead_hero: Dictionary = _get_lead_hero()
	if not lead_hero.is_empty():
		var class_id: String = str(lead_hero.get("class_id", "knight"))
		var current_stats: Dictionary = GameState.get_hero_stats(class_id)
		var equipment: Dictionary = GameState.get_equipment(class_id)
		equipment[str(item.get("slot", "weapon"))] = item
		var candidate_stats: Dictionary = Stats.calculate_final_stats(class_id, int(lead_hero.get("level", 1)), equipment, GameState.get_skill_state(class_id))
		var power_diff: int = Power.compare(candidate_stats, current_stats)
		var diff_color: Color = Color(0.35, 0.95, 0.45) if power_diff >= 0 else Color(1.0, 0.38, 0.38)
		_inventory_detail.add_child(_make_label("對比 %s：戰力 %+d" % [str(ClassData.get_class_definition(class_id).get("name", class_id)), power_diff], 13, diff_color))
		var equip_row: HBoxContainer = HBoxContainer.new()
		equip_row.add_theme_constant_override("separation", 4)
		_inventory_detail.add_child(equip_row)
		for hero: Dictionary in GameState.get_active_heroes():
			var hero_class_id: String = str(hero.get("class_id", ""))
			var equip_button: Button = Button.new()
			equip_button.text = "裝備給 %s" % str(ClassData.get_class_definition(hero_class_id).get("name", hero_class_id))
			equip_button.focus_mode = Control.FOCUS_NONE
			equip_button.add_theme_font_size_override("font_size", 11)
			equip_button.disabled = not ItemData.can_equip_item(item, hero_class_id)
			equip_button.pressed.connect(_on_equip_pressed.bind(hero_class_id))
			equip_row.add_child(equip_button)
	var sell_button: Button = Button.new()
	sell_button.text = "販賣"
	sell_button.focus_mode = Control.FOCUS_NONE
	sell_button.pressed.connect(_on_sell_pressed)
	_inventory_detail.add_child(sell_button)

func _get_lead_hero() -> Dictionary:
	var active: Array[Dictionary] = GameState.get_active_heroes()
	return active[0] if not active.is_empty() else {}

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

func _refresh_skills_tab() -> void:
	_clear_content(_skills_content)
	var active_heroes: Array[Dictionary] = GameState.get_active_heroes()
	for hero: Dictionary in active_heroes:
		_skills_content.add_child(_make_skill_hero_card(hero))
	_skills_content.add_child(_make_note("每級獲得 1 技能點；主動技能可裝備兩個，會依戰況自動施放。"))

func _make_skill_hero_card(hero: Dictionary) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_card_style())
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	card.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var class_id: String = str(hero.get("class_id", "knight"))
	var class_title: String = str(ClassData.get_class_definition(class_id).get("name", class_id))
	column.add_child(_make_label("%s  Lv.%d  ·  可用技能點 %d" % [class_title, int(hero.get("level", 1)), GameState.get_skill_points(class_id)], 15, Color(0.88, 0.93, 1.0)))
	var skill_state: Dictionary = GameState.get_skill_state(class_id)
	var equipped: Array[String] = GameState.get_equipped_active_skills(class_id)
	var active_grid: GridContainer = GridContainer.new()
	active_grid.columns = 2
	active_grid.add_theme_constant_override("h_separation", 6)
	active_grid.add_theme_constant_override("v_separation", 5)
	column.add_child(active_grid)
	for definition: Dictionary in SkillData.get_class_skills(class_id, "active"):
		active_grid.add_child(_make_skill_cell(definition, class_id, skill_state, equipped, true))
	var passive_grid: GridContainer = GridContainer.new()
	passive_grid.columns = 2
	passive_grid.add_theme_constant_override("h_separation", 6)
	passive_grid.add_theme_constant_override("v_separation", 5)
	column.add_child(_make_label("被動技能", 13, Color(0.68, 0.78, 0.94)))
	column.add_child(passive_grid)
	for definition: Dictionary in SkillData.get_class_skills(class_id, "passive"):
		passive_grid.add_child(_make_skill_cell(definition, class_id, skill_state, equipped, false))
	return card

func _make_skill_cell(definition: Dictionary, class_id: String, skill_state: Dictionary, equipped: Array[String], active: bool) -> PanelContainer:
	var skill_id: String = str(definition.get("id", ""))
	var cell: PanelContainer = PanelContainer.new()
	cell.custom_minimum_size = Vector2(420.0, 86.0)
	cell.add_theme_stylebox_override("panel", _make_card_style())
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	cell.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	margin.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(38.0, 38.0)
	icon.texture = _skill_icon_texture(skill_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text_column: VBoxContainer = VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_column)
	var level: int = Skills.get_skill_level(skill_state, skill_id)
	var level_text: String = "Lv.%d/%d  ·  花費 %d 點" % [level, int(definition.get("max_level", 5)), int(definition.get("skill_point_cost", 1))]
	if active:
		level_text += "  ·  冷卻 %.1f 秒" % float(definition.get("cooldown", 0.0))
	else:
		level_text += "  ·  %s" % str(definition.get("effect_text", "被動效果"))
	text_column.add_child(_make_label("%s  %s" % [str(definition.get("name", skill_id)), level_text], 12, Color(0.88, 0.92, 1.0)))
	text_column.add_child(_make_label(str(definition.get("description", "")), 10, Color(0.64, 0.72, 0.86)))
	var controls: VBoxContainer = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 2)
	row.add_child(controls)
	var upgrade_button: Button = Button.new()
	upgrade_button.text = "+1 點"
	upgrade_button.focus_mode = Control.FOCUS_NONE
	upgrade_button.add_theme_font_size_override("font_size", 11)
	upgrade_button.disabled = GameState.get_skill_points(class_id) <= 0 or level >= int(definition.get("max_level", 5))
	upgrade_button.pressed.connect(_on_skill_upgrade.bind(class_id, skill_id))
	controls.add_child(upgrade_button)
	if active:
		var equip_row: HBoxContainer = HBoxContainer.new()
		equip_row.add_theme_constant_override("separation", 2)
		controls.add_child(equip_row)
		for slot_index: int in range(2):
			var equip_button: Button = Button.new()
			equip_button.text = "槽%d" % (slot_index + 1)
			equip_button.focus_mode = Control.FOCUS_NONE
			equip_button.add_theme_font_size_override("font_size", 10)
			equip_button.disabled = level <= 0
			if equipped.size() > slot_index and equipped[slot_index] == skill_id:
				equip_button.text = "已裝備"
			equip_button.pressed.connect(_on_skill_equip.bind(class_id, skill_id, slot_index))
			equip_row.add_child(equip_button)
	return cell

func _skill_icon_texture(skill_id: String) -> Texture2D:
	var frames: SpriteFrames = load("res://addons/duelyst_animated_sprites/spriteframes/icons/%s.tres" % SkillData.get_skill_icon(skill_id)) as SpriteFrames
	if frames == null or frames.get_animation_names().is_empty():
		return null
	return frames.get_frame_texture(frames.get_animation_names()[0], 0)

func _refresh_stage_tab() -> void:
	_clear_content(_stage_content)
	_stage_content.add_child(_make_label("難度", 15, Color(0.84, 0.90, 1.0)))
	_updating_difficulty = true
	_difficulty_selector = OptionButton.new()
	_difficulty_selector.focus_mode = Control.FOCUS_NONE
	_difficulty_selector.add_theme_font_size_override("font_size", 14)
	var unlocked_difficulties: Array = GameState.get_unlocked_difficulties()
	for difficulty_id: String in DifficultyData.get_difficulty_ids():
		var unlocked: bool = unlocked_difficulties.has(difficulty_id)
		_difficulty_selector.add_item(DifficultyData.get_difficulty_name(difficulty_id) if unlocked else "%s（未解鎖）" % DifficultyData.get_difficulty_name(difficulty_id))
		var item_index: int = _difficulty_selector.item_count - 1
		_difficulty_selector.set_item_metadata(item_index, difficulty_id)
		_difficulty_selector.set_item_disabled(item_index, not unlocked)
	var current_difficulty: String = GameState.get_current_difficulty()
	for index: int in range(_difficulty_selector.item_count):
		if str(_difficulty_selector.get_item_metadata(index)) == current_difficulty:
			_difficulty_selector.select(index)
			break
	_difficulty_selector.tooltip_text = str(GameState.get_difficulty_definition(current_difficulty).get("description", ""))
	_difficulty_selector.item_selected.connect(_on_difficulty_selected)
	_updating_difficulty = false
	_stage_content.add_child(_difficulty_selector)
	var difficulty_description: String = str(GameState.get_difficulty_definition(current_difficulty).get("description", ""))
	_stage_content.add_child(_make_note("選擇已解鎖的關卡；完成目前難度第 3 幕第 10 關後解鎖下一難度。\n%s" % difficulty_description))
	var table: Array[Dictionary] = StageData.get_stage_table(current_difficulty)
	var current_stage: int = GameState.get_current_stage()
	for stage: Dictionary in table:
		var stage_index: int = int(stage.get("index", 0))
		var button: Button = Button.new()
		var is_current: bool = stage_index == current_stage
		button.text = "%s%s  ·  建議 Lv.%d  ·  %d 波%s" % [str(stage.get("display_name", "普通 1-1")), "（目前）" if is_current else "", int(stage.get("recommended_level", 1)), int(stage.get("wave_count", 5)), "  ·  首領" if bool(stage.get("is_act_boss", false)) else ""]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = stage_index > GameState.get_unlocked_stage()
		button.pressed.connect(_on_stage_pressed.bind(stage_index))
		_stage_content.add_child(button)

func _item_icon_texture(item: Dictionary) -> Texture2D:
	var frames: SpriteFrames = load("res://addons/duelyst_animated_sprites/spriteframes/icons/%s.tres" % ItemData.get_icon_id(item)) as SpriteFrames
	if frames == null:
		return null
	var names: PackedStringArray = frames.get_animation_names()
	if names.is_empty():
		return null
	return frames.get_frame_texture(names[0], 0)

func _item_tooltip(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var affixes: Array = item.get("affixes", [])
	var affix_parts: Array[String] = []
	for affix_value: Variant in affixes:
		if affix_value is Dictionary:
			affix_parts.append(_affix_text(affix_value))
	var affix_text: String = "、".join(affix_parts)
	return "%s\n等級 %d\n%s\n詞綴：%s" % [str(item.get("name", "")), int(item.get("level", 1)), _stat_text(str(item.get("main_stat", "")), float(item.get("main_value", 0.0)), _is_percent_stat(str(item.get("main_stat", "")))), affix_text if not affix_text.is_empty() else "無"]

func _affix_text(affix: Dictionary) -> String:
	var stat_id: String = str(affix.get("stat", ""))
	var percent: bool = bool(affix.get("percent", false)) or _is_percent_stat(stat_id)
	return _stat_text(stat_id, float(affix.get("value", 0.0)), percent)

func _is_percent_stat(stat_id: String) -> bool:
	return stat_id.ends_with("_percent") or stat_id == "crit_chance" or stat_id == "crit_damage" or stat_id.ends_with("_resistance") or stat_id == "life_steal" or stat_id == "gold_gain" or stat_id == "xp_gain" or stat_id == "heal_power"

func _stat_text(stat_id: String, value: float, percent: bool) -> String:
	var label: String = stat_id
	if stat_id == "attack":
		label = "攻擊"
	elif stat_id == "max_hp":
		label = "生命"
	elif stat_id == "defense":
		label = "防禦"
	elif stat_id == "attack_speed":
		label = "攻速"
	elif stat_id == "crit_chance":
		label = "暴擊"
	elif stat_id == "crit_damage":
		label = "暴擊傷害"
	elif stat_id == "fire_resistance":
		label = "火抗"
	elif stat_id == "ice_resistance":
		label = "冰抗"
	elif stat_id == "lightning_resistance":
		label = "電抗"
	elif stat_id == "chaos_resistance":
		label = "混沌抗"
	elif stat_id == "life_steal":
		label = "生命吸取"
	elif stat_id == "attack_percent":
		label = "攻擊"
	elif stat_id == "attack_speed_percent":
		label = "攻速"
	elif stat_id == "gold_gain":
		label = "金幣獲取"
	elif stat_id == "xp_gain":
		label = "經驗獲取"
	elif stat_id == "damage_absorption_percent":
		label = "受到傷害"
	elif stat_id == "heal_power":
		label = "治療效果"
	elif stat_id == "effect_radius_percent":
		label = "技能範圍"
	elif stat_id == "elemental_damage_percent":
		label = "元素傷害"
	return "%s +%.1f%%" % [label, value * 100.0] if percent else "%s +%d" % [label, roundi(value)]

func _socket_name(socket_type: String) -> String:
	if socket_type == "decorative":
		return "裝飾"
	if socket_type == "engraving":
		return "雕刻"
	if socket_type == "rune":
		return "銘文"
	return socket_type

func _chest_type_name(chest_type: String) -> String:
	if chest_type == "blue":
		return "藍箱自動開啟"
	if chest_type == "act_boss":
		return "幕箱自動開啟"
	return "白箱自動開啟"

func _make_rarity_style(rarity_id: String, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.20, 0.98)
	if not rarity_id.is_empty():
		style.border_color = ItemData.get_rarity_color(rarity_id)
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
	return style

func _make_note(text: String) -> Label:
	return _make_label(text, 11, Color(0.57, 0.67, 0.82))

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

func _clear_grid(grid: GridContainer) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

func _on_class_selected(slot_index: int, class_id: String) -> void:
	GameState.set_party_slot(slot_index, class_id)
	refresh()

func _on_stage_pressed(stage_index: int) -> void:
	stage_selected.emit(stage_index)

func _on_difficulty_selected(index: int) -> void:
	if _updating_difficulty or _difficulty_selector == null or index < 0 or index >= _difficulty_selector.item_count:
		return
	var difficulty_id: String = str(_difficulty_selector.get_item_metadata(index))
	if not difficulty_id.is_empty():
		difficulty_selected.emit(difficulty_id)

func _on_skill_upgrade(class_id: String, skill_id: String) -> void:
	GameState.upgrade_skill(class_id, skill_id)
	refresh()

func _on_skill_equip(class_id: String, skill_id: String, slot_index: int) -> void:
	GameState.equip_active_skill(class_id, skill_id, slot_index)
	refresh()

func _on_equipment_slot_pressed(class_id: String, slot_id: String) -> void:
	GameState.unequip_item(class_id, slot_id)
	refresh()

func _on_inventory_slot_pressed(slot_index: int) -> void:
	_selected_inventory_slot = slot_index
	_refresh_inventory_tab()

func _on_equip_pressed(class_id: String) -> void:
	GameState.equip_item(class_id, _selected_inventory_slot)
	refresh()

func _on_sell_pressed() -> void:
	GameState.sell_inventory_item(_selected_inventory_slot)
	_selected_inventory_slot = -1
	refresh()

func _on_batch_sell(rarity_id: String) -> void:
	GameState.sell_items_by_rarity(rarity_id)
	refresh()

func _on_state_changed() -> void:
	refresh()

func _on_setting_changed(_key: String, _value: Variant) -> void:
	_refresh_settings_tab()

func _on_auto_setting_toggled(enabled: bool) -> void:
	if _updating_settings:
		return
	GameState.set_setting("auto_advance", enabled)
	auto_advance_changed.emit(enabled)

func _on_topmost_setting_toggled(enabled: bool) -> void:
	if _updating_settings:
		return
	WindowManager.set_always_on_top(enabled)

func _on_auto_open_toggled(enabled: bool, chest_type: String) -> void:
	if _updating_settings:
		return
	GameState.set_auto_open(chest_type, enabled)

func _on_auto_sell_toggled(enabled: bool, rarity_id: String) -> void:
	if _updating_settings:
		return
	GameState.set_setting("auto_sell_%s" % rarity_id, enabled)

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
