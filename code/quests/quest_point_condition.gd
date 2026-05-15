extends Resource
class_name QuestPointCondition

## QuestPointCondition - Individual condition within a QuestPoint
##
## Represents a single condition that must be met for a quest point to progress.
## Supports multiple condition types and tracks progress toward completion.
## Each condition can have logic gates that reference OTHER connected conditions.

enum ConditionType {
HAS_ITEM,           # Player must have specific item(s)
HAS_STATUS,         # Player/party must have a status effect
DONE_THING,         # Generic action completed
DONE_DIALOGUE,      # Specific dialogue completed
TALKED_TO_NPC,      # Talked to specific NPC
KILLED_ENEMY,       # Defeated specific enemy type
BATTLE_WON,         # Won a specific battle
VISITED_LOCATION,   # Visited a specific location
CUSTOM              # Custom condition logic
}

enum LogicGate {
AND,  # This condition AND all connected conditions must be met
OR,   # This condition OR any connected condition must be met
NOT   # Connected condition must NOT be met
}

@export_group("Condition Definition")
@export var type: ConditionType = ConditionType.HAS_ITEM
@export var target_key: String = ""  # Item ID, NPC name, dialogue ID, etc.
@export var description: String = ""  # Optional custom description
@export var progress_target: float = 1.0  # Required amount/steps
@export var progress_current: float = 0.0  # Current progress
@export var custom_script: String = ""  # Path to custom condition script (for CUSTOM type)

@export_group("Logic Gate Connections")
@export var logic_gate: LogicGate = LogicGate.AND  # How this condition combines with connected conditions
@export var connected_condition_indices: Array[int] = []  # Indices of other conditions in the same point this connects to

@export_group("Optional Data")
@export var metadata: Dictionary = {}  # Additional data for custom conditions
@export var icon_override: Texture2D = null  # Optional icon override

# Internal tracking for conditions that track progress delta (e.g., KILLED_ENEMY, BATTLE_WON)
# Stores the baseline value when the quest/point started, so we only count progress after quest start
var _initial_value_count: Variant = 0  # Keep as Variant for future flexibility (int, float, etc.)

## Check if this condition is currently met
func is_complete() -> bool:
	return progress_current >= progress_target

## Check if this condition is met considering connected conditions and logic gates
func is_complete_with_connections(point: QuestPoint, evaluator: QuestConditionEvaluator = null) -> bool:
	# First check if this base condition is complete
	var base_complete = is_complete()
	
	# If no connections, just return base result
	if connected_condition_indices.is_empty():
		return base_complete
	
	# Get connected conditions
	var connected_conditions: Array[QuestPointCondition] = []
	for idx in connected_condition_indices:
		if idx >= 0 and idx < point.conditions.size():
			connected_conditions.append(point.conditions[idx])
	
	if connected_conditions.is_empty():
		return base_complete
	
	# Evaluate based on logic gate
	match logic_gate:
		LogicGate.AND:
			# This condition AND all connected must be complete
			if not base_complete:
				return false
			for cond in connected_conditions:
				if not cond.is_complete():
					return false
			return true
		
		LogicGate.OR:
			# This condition OR any connected must be complete
			if base_complete:
				return true
			for cond in connected_conditions:
				if cond.is_complete():
					return true
			return false
		
		LogicGate.NOT:
			# This condition is complete only if connected conditions are NOT complete
			if not base_complete:
				return true  # Base not complete, so NOT is satisfied
			# Check if any connected condition is complete (violation)
			for cond in connected_conditions:
				if cond.is_complete():
					return false  # Violation - connected condition is done when it shouldn't be
			return true
	
	return base_complete

## Reset condition progress
func reset() -> void:
	progress_current = 0.0

## Add progress to this condition
func add_progress(amount: float = 1.0) -> void:
	progress_current = min(progress_current + amount, progress_target)

## Get condition description (uses custom or auto-generated)
func get_description() -> String:
	if not description.is_empty():
		return description

	match type:
		ConditionType.HAS_ITEM:
			return "Collect %d %s" % [progress_target, target_key]
		ConditionType.KILLED_ENEMY:
			return "Defeat %d %s" % [progress_target, target_key]
		ConditionType.DONE_DIALOGUE:
			return "Complete dialogue: %s" % target_key
		ConditionType.TALKED_TO_NPC:
			return "Talk to %s" % target_key
		ConditionType.BATTLE_WON:
			return "Win battle: %s" % target_key
		ConditionType.HAS_STATUS:
			return "Have status: %s" % target_key
		ConditionType.VISITED_LOCATION:
			return "Visit: %s" % target_key
		ConditionType.DONE_THING:
			return "Complete: %s" % target_key
		ConditionType.CUSTOM:
			return "Custom: %s" % target_key

	return target_key

## Initialize kill count baseline when quest starts (for KILLED_ENEMY conditions)
func initialize_kill_baseline(global_enemies_killed: Dictionary) -> void:
	if type == ConditionType.KILLED_ENEMY:
		_initial_value_count = global_enemies_killed.get(target_key, 0)
		# Set current progress to 0 initially, will be updated on evaluation
		progress_current = 0.0

## Get current progress for KILLED_ENEMY conditions based on global counter delta
func get_kill_progress(global_enemies_killed: Dictionary) -> float:
	if type != ConditionType.KILLED_ENEMY:
		return progress_current

	var current_total = global_enemies_killed.get(target_key, 0)
	var kills_since_start = current_total - _initial_value_count
	return max(0.0, kills_since_start as float)
