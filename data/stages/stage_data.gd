class_name StageData
extends RefCounted

const ACT_COUNT: int = 3
const STAGES_PER_ACT: int = 10
const TOTAL_STAGES: int = ACT_COUNT * STAGES_PER_ACT
const NORMAL_DIFFICULTY: String = "普通"
const WAVE_HEAL_RATIO: float = 0.30
const STAGE_START_HEAL_RATIO: float = 1.0
const PROGRESSION_LEVEL_MARGIN: int = 1

static func get_stage_table(difficulty_id: String = "normal") -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	var normalized_difficulty_id: String = DifficultyData.normalize_difficulty_id(difficulty_id)
	var difficulty: Dictionary = DifficultyData.get_difficulty_definition(normalized_difficulty_id)
	var difficulty_name: String = str(difficulty.get("name", NORMAL_DIFFICULTY))
	var level_offset: int = int(difficulty.get("level_offset", 0))
	var is_elemental_difficulty: bool = normalized_difficulty_id != "normal"
	var pools: Array[Array] = [
		["neutral_gnasher", "neutral_ghostlynx"],
		["neutral_mercpirate", "neutral_monsterdragonhawk"],
		["neutral_giantcrab", "neutral_mercmelee1"],
		["neutral_monsterlightningbeetle", "neutral_prongbok"],
		["neutral_golemstone", "neutral_monstercrystalwisp"]
	]
	var bosses: Array[String] = ["boss_andromeda", "boss_chaosknight", "boss_legion"]
	var elemental_pool: Array[String] = ["fire_drake", "chaos_reaver"]

	for act: int in range(1, ACT_COUNT + 1):
		for stage: int in range(1, STAGES_PER_ACT + 1):
			var base_level: int = (act - 1) * STAGES_PER_ACT + stage
			var is_boss: bool = stage == STAGES_PER_ACT
			var pool: Array = []
			# 每個關卡都有五波後的關卡首領；第 10 關沿用同一首領並標記為幕首領。
			var boss_id: String = bosses[act - 1]
			var first_pool: Array = pools[(stage - 1 + (act - 1) * 2) % pools.size()]
			var second_pool: Array = pools[(stage + (act - 1) * 2) % pools.size()]
			for monster_id: String in first_pool:
				if not pool.has(monster_id):
					pool.append(monster_id)
			for monster_id: String in second_pool:
				if not pool.has(monster_id):
					pool.append(monster_id)
			if is_elemental_difficulty:
				for monster_id: String in elemental_pool:
					if not pool.has(monster_id):
						pool.append(monster_id)
			table.append({
				"index": table.size(),
				"difficulty": difficulty_name,
				"difficulty_id": normalized_difficulty_id,
				"act": act,
				"stage": stage,
				"recommended_level": base_level + level_offset,
				"required_level": base_level + level_offset + PROGRESSION_LEVEL_MARGIN,
				"base_level": base_level,
				"wave_count": 5,
				"wave_heal_ratio": WAVE_HEAL_RATIO,
				"stage_start_heal_ratio": STAGE_START_HEAL_RATIO,
				"monster_pool": pool,
				"boss": boss_id,
				"is_act_boss": is_boss,
				"display_name": "%s %d-%d" % [difficulty_name, act, stage]
			})
	return table

static func get_stage_by_index(stage_index: int, difficulty_id: String = "normal") -> Dictionary:
	var table: Array[Dictionary] = get_stage_table(difficulty_id)
	var safe_index: int = clampi(stage_index, 0, table.size() - 1)
	return table[safe_index].duplicate(true)

static func get_stage_count() -> int:
	return TOTAL_STAGES

static func get_required_level(stage_index: int, difficulty_id: String = "normal") -> int:
	var stage: Dictionary = get_stage_by_index(stage_index, difficulty_id)
	return maxi(1, int(stage.get("required_level", int(stage.get("recommended_level", 1)) + PROGRESSION_LEVEL_MARGIN)))

static func get_display_name(stage_index: int, difficulty_id: String = "normal") -> String:
	var stage: Dictionary = get_stage_by_index(stage_index, difficulty_id)
	return str(stage.get("display_name", "%s 1-1" % NORMAL_DIFFICULTY))
