class_name StageData
extends RefCounted

const ACT_COUNT: int = 3
const STAGES_PER_ACT: int = 10
const TOTAL_STAGES: int = ACT_COUNT * STAGES_PER_ACT
const NORMAL_DIFFICULTY: String = "普通"

static func get_stage_table() -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	var pools: Array[Array] = [
		["neutral_gnasher", "neutral_ghostlynx"],
		["neutral_mercpirate", "neutral_monsterdragonhawk"],
		["neutral_giantcrab", "neutral_mercmelee1"],
		["neutral_monsterlightningbeetle", "neutral_prongbok"],
		["neutral_golemstone", "neutral_monstercrystalwisp"]
	]
	var bosses: Array[String] = ["boss_andromeda", "boss_chaosknight", "boss_legion"]

	for act: int in range(1, ACT_COUNT + 1):
		for stage: int in range(1, STAGES_PER_ACT + 1):
			var recommended_level: int = (act - 1) * STAGES_PER_ACT + stage
			var is_boss: bool = stage == STAGES_PER_ACT
			var pool: Array = []
			var boss_id: String = ""
			if is_boss:
				boss_id = bosses[act - 1]
				pool.append(boss_id)
			else:
				var first_pool: Array = pools[(stage - 1 + (act - 1) * 2) % pools.size()]
				var second_pool: Array = pools[(stage + (act - 1) * 2) % pools.size()]
				for monster_id: String in first_pool:
					if not pool.has(monster_id):
						pool.append(monster_id)
				for monster_id: String in second_pool:
					if not pool.has(monster_id):
						pool.append(monster_id)
			table.append({
				"index": table.size(),
				"difficulty": NORMAL_DIFFICULTY,
				"difficulty_id": "normal",
				"act": act,
				"stage": stage,
				"recommended_level": recommended_level,
				"wave_count": 5,
				"monster_pool": pool,
				"boss": boss_id,
				"is_act_boss": is_boss,
				"display_name": "%s %d-%d" % [NORMAL_DIFFICULTY, act, stage]
			})
	return table

static func get_stage_by_index(stage_index: int) -> Dictionary:
	var table: Array[Dictionary] = get_stage_table()
	var safe_index: int = clampi(stage_index, 0, table.size() - 1)
	return table[safe_index].duplicate(true)

static func get_stage_count() -> int:
	return TOTAL_STAGES

static func get_display_name(stage_index: int) -> String:
	var stage: Dictionary = get_stage_by_index(stage_index)
	return str(stage.get("display_name", "%s 1-1" % NORMAL_DIFFICULTY))
