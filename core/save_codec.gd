class_name SaveCodec
extends RefCounted

const VERSION: int = 1

static func make_default_state() -> Dictionary:
	return {
		"version": VERSION,
		"gold": 0,
		"current_stage": 0,
		"unlocked_stage": 0,
		"unlocked_party_slots": 1,
		"party": [_make_hero("knight"), null, null],
		"settings": {
			"auto_advance": true,
			"always_on_top": true,
			"expanded": false
		},
		"last_saved_unix": 0
	}

static func encode_state(state: Dictionary) -> Dictionary:
	var normalized: Dictionary = normalize_state(state)
	normalized["version"] = VERSION
	return normalized

static func normalize_state(state: Dictionary) -> Dictionary:
	var normalized: Dictionary = make_default_state()
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
		elif key == "version":
			continue
		else:
			normalized[key] = state[key]
	normalized["unlocked_stage"] = clampi(int(normalized.get("unlocked_stage", 0)), 0, StageData.get_stage_count() - 1)
	normalized["unlocked_party_slots"] = clampi(int(normalized.get("unlocked_party_slots", 1)), 1, 3)
	normalized["current_stage"] = clampi(int(normalized.get("current_stage", 0)), 0, int(normalized["unlocked_stage"]))
	normalized["gold"] = maxi(0, int(normalized.get("gold", 0)))
	normalized["last_saved_unix"] = maxi(0, int(normalized.get("last_saved_unix", 0)))
	return normalized

static func state_to_json(state: Dictionary) -> String:
	return JSON.stringify(encode_state(state), "\t")

static func state_from_json(json_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return make_default_state()
	return normalize_state(parsed)

static func _make_hero(class_id: String) -> Dictionary:
	return {
		"class_id": class_id,
		"level": 1,
		"xp": 0
	}

static func _normalize_hero(hero: Dictionary) -> Dictionary:
	var class_id: String = str(hero.get("class_id", "knight"))
	if ClassData.get_class_definition(class_id).is_empty():
		class_id = "knight"
	return {
		"class_id": class_id,
		"level": clampi(int(hero.get("level", 1)), 1, Stats.MAX_LEVEL),
		"xp": maxi(0, int(hero.get("xp", 0)))
	}
