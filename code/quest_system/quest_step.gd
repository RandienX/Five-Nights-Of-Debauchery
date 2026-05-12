class_name QuestStep
extends Resource

enum LogicGate {
	AND, # All conditions must be met
	OR,  # At least one condition must be met
	CUSTOM # Handled by custom logic in Quest resource
}

@export var step_name: String = "New Step"
@export var conditions: Array[QuestCondition] = []
@export var logic_gate: LogicGate = LogicGate.AND

# Runtime state (not saved directly in resource, managed by Quest instance)
var _condition_states: Array[QuestCondition] = []

func initialize_runtime():
	_condition_states.clear()
	for cond in conditions:
		_condition_states.append(cond.duplicate_state())

func get_condition_state(index: int) -> QuestCondition:
	if index < 0 or index >= _condition_states.size(): return null
	return _condition_states[index]

func update_condition_progress(index: int, amount: float):
	if index < 0 or index >= _condition_states.size(): return
	var cond = _condition_states[index]
	cond.progress_current = min(cond.progress_current + amount, cond.progress_target)

func evaluate() -> Dictionary:
	# Returns: { state: Enum, completed_indices: Array, failed_indices: Array }
	# We map internal logic to the global State Machine enums loosely here for the step
	var completed_count = 0
	var failed_count = 0
	var completed_indices = []
	
	for i in range(_condition_states.size()):
		var cond = _condition_states[i]
		if cond.is_complete():
			completed_count += 1
			completed_indices.append(i)
		else:
			failed_count += 1

	var all_met = (completed_count == _condition_states.size())
	var any_met = (completed_count > 0)
	var none_met = (completed_count == 0)

	var step_complete = false
	match logic_gate:
		LogicGate.AND: step_complete = all_met
		LogicGate.OR: step_complete = any_met
		LogicGate.CUSTOM: step_complete = all_met # Fallback

	return {
		"complete": step_complete,
		"completed_indices": completed_indices,
		"progress_ratio": float(completed_count) / max(1, _condition_states.size())
	}
