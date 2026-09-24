class_name SaveCodec
extends RefCounted

const VERSION: int = 3

static func make_default_state() -> Dictionary:
	return {
		"version": VERSION,
		"gold": 0,
		"current_stage": 0,
		"unlocked_stage": 0,
		"unlocked_party_slots": 1,
		"difficulty": "normal",
		"unlocked_difficulties": ["normal"],
		"difficulty_progress": _default_difficulty_progress(),
		"cleared_difficulties": [],
		"party": [_make_hero("knight"), null, null],
		"inventory": Inventory.create_inventory(),
		"chests": Chests.create_state(),
		"soul_stones": 0,
		"settings": _default_settings(),
		"last_saved_unix": 0
	}

static func encode_state(state: Dictionary) -> Dictionary:
	var normalized: Dictionary = normalize_state(state)
	normalized["version"] = VERSION
	return normalized

static func normalize_state(state: Dictionary) -> Dictionary:
	var normalized: Dictionary = make_default_state()
	var source_version: int = int(state.get("version", 1))
	for raw_key: Variant in state.keys():
		var key: String = str(raw_key)
		if key == "party":
			var source_party_value: Variant = state.get("party", [])
			if source_party_value is Array:
				var source_party: Array = source_party_value
				var normalized_party: Array = normalized["party"]
				for index: int in range(mini(3, source_party.size())):
					var hero_value: Variant = source_party[index]
					if hero_value is Dictionary:
						normalized_party[index] = _normalize_hero(hero_value)
		elif key == "settings":
			var source_settings_value: Variant = state.get("settings", {})
			if source_settings_value is Dictionary:
				var source_settings: Dictionary = source_settings_value
				var normalized_settings: Dictionary = normalized["settings"]
				for setting_key: Variant in source_settings.keys():
					normalized_settings[str(setting_key)] = source_settings[setting_key]
		elif key == "inventory":
			var source_inventory_value: Variant = state.get("inventory", {})
			if source_inventory_value is Dictionary:
				normalized["inventory"] = Inventory.normalize_inventory(source_inventory_value as Dictionary)
		elif key == "chests":
			var source_chests_value: Variant = state.get("chests", {})
			if source_chests_value is Dictionary:
				normalized["chests"] = Chests.normalize_state(source_chests_value as Dictionary)
		elif key == "unlocked_difficulties":
			var source_difficulties: Variant = state.get("unlocked_difficulties", [])
			if source_difficulties is Array:
				normalized["unlocked_difficulties"] = _normalize_difficulty_list(source_difficulties)
		elif key == "difficulty_progress":
			var source_progress: Variant = state.get("difficulty_progress", {})
			if source_progress is Dictionary:
				normalized["difficulty_progress"] = _normalize_difficulty_progress(source_progress)
		elif key == "cleared_difficulties":
			var source_cleared: Variant = state.get("cleared_difficulties", [])
			if source_cleared is Array:
				normalized["cleared_difficulties"] = _normalize_difficulty_list(source_cleared)
		elif key == "version":
			continue
		else:
			normalized[key] = state[key]
	normalized["version"] = VERSION
	var normalized_settings: Dictionary = normalized["settings"]
	var normalized_chests: Dictionary = normalized["chests"]
	var source_settings_value: Variant = state.get("settings", {})
	for chest_type: String in ["white", "blue", "act_boss"]:
		var setting_key: String = "auto_open_%s" % chest_type
		if source_settings_value is Dictionary and (source_settings_value as Dictionary).has(setting_key):
			normalized_chests["auto_open"][chest_type] = bool(normalized_settings.get(setting_key, false))
		else:
			normalized_settings[setting_key] = bool(normalized_chests.get("auto_open", {}).get(chest_type, false))
	var difficulty_ids: Array[String] = DifficultyData.get_difficulty_ids()
	var current_difficulty: String = str(normalized.get("difficulty", "normal"))
	if not difficulty_ids.has(current_difficulty):
		current_difficulty = "normal"
	var unlocked_difficulties: Array = _normalize_difficulty_list(normalized.get("unlocked_difficulties", ["normal"]))
	if not unlocked_difficulties.has("normal"):
		unlocked_difficulties.append("normal")
	if not unlocked_difficulties.has(current_difficulty):
		current_difficulty = "normal"
	var progress: Dictionary = _normalize_difficulty_progress(normalized.get("difficulty_progress", {}))
	var legacy_unlocked_stage: int = clampi(int(normalized.get("unlocked_stage", 0)), 0, StageData.get_stage_count() - 1)
	if int(progress.get(current_difficulty, 0)) == 0 and legacy_unlocked_stage > 0:
		progress[current_difficulty] = legacy_unlocked_stage
	if source_version < 3:
		current_difficulty = "normal"
		unlocked_difficulties = ["normal"]
		progress = _default_difficulty_progress()
		progress["normal"] = clampi(int(normalized.get("unlocked_stage", 0)), 0, StageData.get_stage_count() - 1)
	normalized["difficulty"] = current_difficulty
	normalized["unlocked_difficulties"] = unlocked_difficulties
	normalized["difficulty_progress"] = progress
	normalized["unlocked_party_slots"] = clampi(int(normalized.get("unlocked_party_slots", 1)), 1, 3)
	var current_unlocked_stage: int = int(progress.get(current_difficulty, 0))
	normalized["unlocked_stage"] = current_unlocked_stage
	normalized["current_stage"] = clampi(int(normalized.get("current_stage", 0)), 0, current_unlocked_stage)
	normalized["gold"] = maxi(0, int(normalized.get("gold", 0)))
	normalized["soul_stones"] = maxi(0, int(normalized.get("soul_stones", 0)))
	normalized["last_saved_unix"] = maxi(0, int(normalized.get("last_saved_unix", 0)))
	if source_version < 2:
		normalized["inventory"] = Inventory.create_inventory() if not state.has("inventory") else normalized["inventory"]
		normalized["chests"] = Chests.create_state() if not state.has("chests") else normalized["chests"]
		normalized["soul_stones"] = int(normalized.get("soul_stones", 0))
	return normalized

static func state_to_json(state: Dictionary) -> String:
	return JSON.stringify(encode_state(state), "\t")

static func state_from_json(json_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return make_default_state()
	return normalize_state(parsed)

static func _default_settings() -> Dictionary:
	return {
		"auto_advance": true,
		"always_on_top": true,
		"expanded": false,
		"auto_open_white": false,
		"auto_open_blue": false,
		"auto_open_act_boss": false,
		"auto_sell_common": false,
		"auto_sell_uncommon": false
	}

static func _make_hero(class_id: String) -> Dictionary:
	return {
		"class_id": class_id,
		"level": 1,
		"xp": 0,
		"equipment": _empty_equipment(),
		"skills": Skills.make_skill_state(class_id)
	}

static func _normalize_hero(hero: Dictionary) -> Dictionary:
	var class_id: String = str(hero.get("class_id", "knight"))
	if ClassData.get_class_definition(class_id).is_empty():
		class_id = "knight"
	var equipment_value: Variant = hero.get("equipment", {})
	var equipment: Dictionary = _empty_equipment()
	if equipment_value is Dictionary:
		equipment = _normalize_equipment(equipment_value)
	var skills_value: Variant = hero.get("skills", {})
	var source_skills: Dictionary = skills_value if skills_value is Dictionary else {}
	var skills: Dictionary = Skills.normalize_skill_state(source_skills, class_id)
	return {
		"class_id": class_id,
		"level": clampi(int(hero.get("level", 1)), 1, Stats.MAX_LEVEL),
		"xp": maxi(0, int(hero.get("xp", 0))),
		"equipment": equipment,
		"skills": skills
	}

static func _default_difficulty_progress() -> Dictionary:
	var progress: Dictionary = {}
	for difficulty_id: String in DifficultyData.get_difficulty_ids():
		progress[difficulty_id] = 0
	return progress

static func _normalize_difficulty_list(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return ["normal"]
	for raw_id: Variant in source:
		var difficulty_id: String = str(raw_id)
		if DifficultyData.get_difficulty_ids().has(difficulty_id) and not result.has(difficulty_id):
			result.append(difficulty_id)
	if not result.has("normal"):
		result.append("normal")
	return result

static func _normalize_difficulty_progress(source: Variant) -> Dictionary:
	var result: Dictionary = _default_difficulty_progress()
	if source is Dictionary:
		for raw_id: Variant in (source as Dictionary).keys():
			var difficulty_id: String = str(raw_id)
			if DifficultyData.get_difficulty_ids().has(difficulty_id):
				result[difficulty_id] = clampi(int((source as Dictionary).get(raw_id, 0)), 0, StageData.get_stage_count() - 1)
	return result

static func _normalize_equipment(source: Dictionary) -> Dictionary:
	var equipment: Dictionary = _empty_equipment()
	for slot_id: String in ItemData.get_slot_ids():
		var item_value: Variant = source.get(slot_id, null)
		if item_value is Dictionary:
			equipment[slot_id] = (item_value as Dictionary).duplicate(true)
	return equipment

static func _empty_equipment() -> Dictionary:
	var equipment: Dictionary = {}
	for slot_id: String in ItemData.get_slot_ids():
		equipment[slot_id] = null
	return equipment
