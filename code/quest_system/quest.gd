class_name Quest
extends Resource

enum QuestState { NO, PROGRESS, DONE, FAIL, YES }

@export var quest_id: String = ""
@export var quest_name: String = ""
@export var steps: Array[QuestStep] = []
@export var completion_effects: Array[QuestEffect] = []

# Runtime State
var current_step_index: int = 0
var state: QuestState = QuestState.NO
var _is_completed: bool = false

func initialize():
	current_step_index = 0
	state = QuestState.NO
	_is_completed = false
	for step in steps:
		step.initialize_runtime()

func get_current_step() -> QuestStep:
	if current_step_index < 0 or current_step_index >= steps.size():
		return null
	return steps[current_step_index]

func progress_condition(condition_index: int, amount: float = 1.0) -> bool:
	var step = get_current_step()
	if not step: return false
	
	var old_state = step.evaluate()
	step.update_condition_progress(condition_index, amount)
	var new_state = step.evaluate()
	
	if new_state["complete"] != old_state["complete"]:
		if new_state["complete"]:
			state = QuestState.DONE # Flash green/yellow
		else:
			state = QuestState.PROGRESS # Update bars
		return true
	elif new_state["progress_ratio"] > old_state["progress_ratio"]:
		state = QuestState.PROGRESS
		return true
		
	return false

func advance_step() -> bool:
	if _is_completed: return false
	
	current_step_index += 1
	if current_step_index >= steps.size():
		complete_quest()
		return true
	
	state = QuestState.YES # Trigger effects for previous step if needed, now moving to next
	return false

func complete_quest():
	_is_completed = true
	state = QuestState.YES
	for effect in completion_effects:
		effect.execute(null) # Pass appropriate owner if needed

func get_save_data() -> Dictionary:
	var steps_data = []
	for step in steps:
		var conds_data = []
		for cond in step._condition_states:
			conds_data.append({
				"key": cond.target_key,
				"current": cond.progress_current,
				"target": cond.progress_target
			})
		steps_data.append(conds_data)
	
	return {
		"id": quest_id,
		"step_index": current_step_index,
		"completed": _is_completed,
		"steps": steps_data
	}

func load_save_data(data: Dictionary):
	if data.get("id") != quest_id: return
	current_step_index = data.get("step_index", 0)
	_is_completed = data.get("completed", false)
	
	var saved_steps = data.get("steps", [])
	for i in range(min(saved_steps.size(), steps.size())):
		var saved_conds = saved_steps[i]
		var step = steps[i]
		step.initialize_runtime() # Reset runtime
		for j in range(min(saved_conds.size(), step._condition_states.size())):
			var s_cond = saved_conds[j]
			var r_cond = step._condition_states[j]
			r_cond.progress_current = s_cond.get("current", 0)
	
	if _is_completed:
		state = QuestState.YES
	elif current_step_index >= steps.size():
		complete_quest()
	else:
		state = QuestState.NO
