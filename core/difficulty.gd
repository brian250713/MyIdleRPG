class_name Difficulty
extends RefCounted

const FINAL_STAGE_INDEX: int = 29

static func get_difficulty_ids() -> Array[String]:
	return DifficultyData.get_difficulty_ids()

static func get_definition(difficulty_id: String) -> Dictionary:
	return DifficultyData.get_difficulty_definition(DifficultyData.normalize_difficulty_id(difficulty_id))

static func scale_level(base_level: int, difficulty_id: String) -> int:
	return maxi(1, base_level + DifficultyData.get_level_offset(difficulty_id))

static func get_stat_multiplier(difficulty_id: String) -> float:
	return DifficultyData.get_stat_multiplier(difficulty_id)

static func get_next_difficulty(difficulty_id: String) -> String:
	var ids: Array[String] = get_difficulty_ids()
	var index: int = ids.find(DifficultyData.normalize_difficulty_id(difficulty_id))
	if index < 0 or index >= ids.size() - 1:
		return ""
	return ids[index + 1]

static func is_unlocked(difficulty_id: String, unlocked_difficulties: Array) -> bool:
	return unlocked_difficulties.has(difficulty_id) or difficulty_id == "normal"

static func can_unlock_after_stage(difficulty_id: String, stage_index: int) -> bool:
	return stage_index >= FINAL_STAGE_INDEX and not get_next_difficulty(difficulty_id).is_empty()

static func unlock_after_stage(difficulty_id: String, stage_index: int, unlocked_difficulties: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_id: Variant in unlocked_difficulties:
		var id: String = str(raw_id)
		if DifficultyData.get_difficulty_ids().has(id) and not result.has(id):
			result.append(id)
	if not result.has("normal"):
		result.append("normal")
	if can_unlock_after_stage(difficulty_id, stage_index):
		var next_id: String = get_next_difficulty(difficulty_id)
		if not next_id.is_empty() and not result.has(next_id):
			result.append(next_id)
	return result

static func get_stage_table(difficulty_id: String = "normal") -> Array[Dictionary]:
	return StageData.get_stage_table(difficulty_id)

static func get_stage_by_index(stage_index: int, difficulty_id: String = "normal") -> Dictionary:
	return StageData.get_stage_by_index(stage_index, difficulty_id)
