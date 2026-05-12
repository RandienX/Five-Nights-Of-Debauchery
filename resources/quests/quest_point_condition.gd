extends Resource
class_name QuestPointCondition

## QuestPointCondition - Individual condition within a QuestPoint
##
## Represents a single condition that must be met for a quest point to progress.
## Supports multiple condition types and tracks progress toward completion.

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

@export_group("Condition Definition")
@export var type: ConditionType = ConditionType.HAS_ITEM
@export var target_key: String = ""  # Item ID, NPC name, dialogue ID, etc.
@export var description: String = ""  # Optional custom description
@export var progress_target: float = 1.0  # Required amount/steps
@export var progress_current: float = 0.0  # Current progress

@export_group("Optional Data")
@export var metadata: Dictionary = {}  # Additional data for custom conditions
@export var icon_override: Texture2D = null  # Optional icon override

## Check if this condition is currently met
func is_complete() -> bool:
	return progress_current >= progress_target

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

## Create a copy of this condition
func duplicate() -> QuestPointCondition:
	var new_cond = QuestPointCondition.new()
	new_cond.type = type
	new_cond.target_key = target_key
	new_cond.description = description
	new_cond.progress_target = progress_target
	new_cond.progress_current = progress_current
	new_cond.metadata = metadata.duplicate()
	new_cond.icon_override = icon_override
	return new_cond
