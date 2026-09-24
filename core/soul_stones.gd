class_name SoulStones
extends RefCounted

const REQUIRED_PER_ACT_BOSS: int = 1

static func is_act_boss_stage(stage_index: int) -> bool:
	return stage_index >= 0 and stage_index % StageData.STAGES_PER_ACT == StageData.STAGES_PER_ACT - 1

static func get_requirement_key(difficulty_id: String, stage_index: int) -> String:
	return "%s:%d" % [difficulty_id, stage_index]

static func is_paid(state: Dictionary, difficulty_id: String, stage_index: int) -> bool:
	var paid: Dictionary = state.get("paid_act_bosses", {})
	return bool(paid.get(get_requirement_key(difficulty_id, stage_index), false))

static func can_pay(state: Dictionary, difficulty_id: String, stage_index: int) -> bool:
	if not is_act_boss_stage(stage_index):
		return true
	return is_paid(state, difficulty_id, stage_index) or int(state.get("soul_stones", 0)) >= REQUIRED_PER_ACT_BOSS

static func pay_for_stage(state: Dictionary, difficulty_id: String, stage_index: int) -> Dictionary:
	if not is_act_boss_stage(stage_index):
		return {"ok": true, "paid": false, "already_paid": false, "state": state.duplicate(true), "reason": "not_act_boss"}
	var key: String = get_requirement_key(difficulty_id, stage_index)
	var paid: Dictionary = state.get("paid_act_bosses", {})
	if bool(paid.get(key, false)):
		return {"ok": true, "paid": false, "already_paid": true, "state": state.duplicate(true), "reason": "already_paid"}
	if int(state.get("soul_stones", 0)) < REQUIRED_PER_ACT_BOSS:
		return {"ok": false, "paid": false, "already_paid": false, "state": state.duplicate(true), "reason": "needs_soul_stone", "required": REQUIRED_PER_ACT_BOSS}
	var next_state: Dictionary = state.duplicate(true)
	next_state["soul_stones"] = int(next_state.get("soul_stones", 0)) - REQUIRED_PER_ACT_BOSS
	paid[key] = true
	next_state["paid_act_bosses"] = paid
	return {"ok": true, "paid": true, "already_paid": false, "state": next_state, "reason": "paid", "required": REQUIRED_PER_ACT_BOSS}

static func clear_paid(state: Dictionary, difficulty_id: String, stage_index: int) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var paid: Dictionary = next_state.get("paid_act_bosses", {})
	paid.erase(get_requirement_key(difficulty_id, stage_index))
	next_state["paid_act_bosses"] = paid
	return next_state

static func get_fallback_stage(stage_index: int) -> int:
	if not is_act_boss_stage(stage_index):
		return stage_index
	return maxi(0, stage_index - 1)

static func get_requirement_text(state: Dictionary, difficulty_id: String, stage_index: int) -> String:
	if not is_act_boss_stage(stage_index):
		return ""
	if is_paid(state, difficulty_id, stage_index):
		return "已支付靈魂石"
	if int(state.get("soul_stones", 0)) < REQUIRED_PER_ACT_BOSS:
		return "需要靈魂石"
	return "可挑戰幕首領"
