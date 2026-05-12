extends Resource
class_name QuestPoint

## QuestPoint - A step within a quest that contains conditions and logic gates
##
## A QuestPoint represents a single objective or milestone within a quest.
## It contains multiple conditions that are evaluated based on the logic gate.
## Progress moves linearly through points within a quest step.

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

## Evaluate all conditions and return the current state
func evaluate() -> QuestState:
	if conditions.is_empty():
		return QuestState.YES
	
	var completed_count := 0
	var has_not_violation := false
	
	for condition in conditions:
		var is_met = condition.is_complete()
		
		match logic_gate:
			LogicGate.AND:
				if is_met:
					completed_count += 1
				else:
					# Check if making progress
					if condition.progress_current > 0:
						pass  # PROGRESS state will be returned below
			
			LogicGate.OR:
				if is_met:
					return QuestState.YES  # Early exit for OR
			
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
				return QuestState.YES
			elif completed_count > 0 or _has_any_progress():
				return QuestState.PROGRESS
			else:
				return QuestState.NO
		
		LogicGate.OR:
			if _has_any_progress():
				return QuestState.PROGRESS
			return QuestState.NO
		
		LogicGate.NOT:
			return QuestState.NO  # If we get here, NOT condition is not violated
	
	return QuestState.NO

## Check if any condition has partial progress
func _has_any_progress() -> bool:
	for condition in conditions:
		if condition.progress_current > 0 and condition.progress_current < condition.progress_target:
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
func get_completion_percentage() -> float:
	if conditions.is_empty():
		return 1.0
	
	var total_progress := 0.0
	for condition in conditions:
		total_progress += condition.progress_current / condition.progress_target
	
	return total_progress / conditions.size()

## Create a copy of this quest point
func duplicate() -> QuestPoint:
	var new_point = QuestPoint.new()
	new_point.step_name = step_name
	new_point.logic_gate = logic_gate
	new_point.is_complete = false
	new_point.current_condition_index = current_condition_index
	new_point.auto_advance = auto_advance
	new_point.metadata = metadata.duplicate()
	
	for condition in conditions:
		new_point.conditions.append(condition.duplicate())
	
	return new_point
