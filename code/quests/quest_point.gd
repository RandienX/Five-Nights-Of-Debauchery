extends Resource
class_name QuestPoint

## QuestPoint - A step within a quest that contains conditions and logic gates
##
## A QuestPoint represents a single objective or milestone within a quest.
## It contains multiple conditions that are evaluated based on the logic gate.
## Progress moves linearly through points within a quest.

enum LogicGate {
AND,  # All conditions must be met
OR,   # At least one condition must be met
NOT   # Condition must NOT be met (used for failure conditions)
}

enum QuestState {
NO,        # Nothing happened, no progress
PROGRESS,  # Progress made on one or more conditions
DONE,      # All conditions completed (flash green/yellow)
FAIL,      # Quest failed (flash red, often from NOT condition)
YES        # Point complete, progressing to next stage
}

@export_group("Quest Point Definition")
@export var step_name: String = "Step"  # Name/description of this point
@export var conditions: Array[QuestPointCondition] = []  # Conditions to evaluate
@export var logic_gate: LogicGate = LogicGate.AND  # How to combine conditions

@export_group("Progress Tracking")
@export var is_complete: bool = false  # Cached completion state
@export var current_condition_index: int = 0  # For sequential condition tracking

@export_group("Optional")
@export var auto_advance: bool = true  # Auto-advance when complete
@export var metadata: Dictionary = {}  # Additional data

## Evaluate all conditions and return the current state using QuestConditionEvaluator
func evaluate(evaluator: QuestConditionEvaluator = null) -> QuestState:
	if conditions.is_empty():
		return QuestState.YES

	var completed_count := 0
	var has_not_violation := false
	var any_done_state := false

	# Use provided evaluator or create temporary one
	var eval = evaluator if evaluator else QuestConditionEvaluator.new()

	for condition in conditions:
		# Update progress from evaluator
		eval.get_progress(condition)

		# Use is_complete_with_connections to check condition with logic gates
		var is_met = condition.is_complete_with_connections(self, eval)

		match logic_gate:
			LogicGate.AND:
				if is_met:
					completed_count += 1
			LogicGate.OR:
				if is_met:
					return QuestState.DONE  # Early exit for OR - at least one complete
			LogicGate.NOT:
				if is_met:
					has_not_violation = true
				# Check for NOT violation first (highest priority)
				if has_not_violation:
					return QuestState.FAIL

	# Evaluate based on logic gate
	match logic_gate:
		LogicGate.AND:
			if completed_count >= conditions.size():
				return QuestState.DONE
			elif completed_count > 0 or _has_any_progress(eval):
				return QuestState.PROGRESS
			else:
				return QuestState.NO

		LogicGate.OR:
			if _has_any_progress(eval):
				return QuestState.PROGRESS
			return QuestState.NO

		LogicGate.NOT:
			return QuestState.NO  # If we get here, NOT condition is not violated

	return QuestState.NO

## Check if any condition has partial progress
func _has_any_progress(evaluator: QuestConditionEvaluator) -> bool:
	for condition in conditions:
		var progress = evaluator.get_progress(condition) if evaluator else condition.progress_current
		if progress > 0 and progress < condition.progress_target:
			return true
	return false

## Get the current condition being tracked (for UI display)
func get_current_condition() -> QuestPointCondition:
	if conditions.is_empty():
		return null
	if current_condition_index >= conditions.size():
		current_condition_index = 0
	return conditions[current_condition_index]

## Update progress for a specific condition type/target
func update_condition_progress(type: QuestPointCondition.ConditionType, target_key: String, amount: float = 1.0) -> QuestState:
	var updated := false

	for condition in conditions:
		if condition.type == type and condition.target_key == target_key:
			condition.add_progress(amount)
			updated = true
			break

	if updated:
		return evaluate()
	return QuestState.NO

## Reset all conditions in this point
func reset() -> void:
	is_complete = false
	current_condition_index = 0
	for condition in conditions:
		condition.reset()

## Get completion percentage (0.0 to 1.0)
func get_completion_percentage(evaluator: QuestConditionEvaluator = null) -> float:
	if conditions.is_empty():
		return 1.0

	var eval = evaluator if evaluator else QuestConditionEvaluator.new()
	var total_progress := 0.0

	for condition in conditions:
		var progress = eval.get_progress(condition)
		total_progress += progress / condition.progress_target

	return total_progress / conditions.size()
