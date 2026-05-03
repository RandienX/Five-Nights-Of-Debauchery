@tool
class_name DialogueChoice
extends Resource

## Player choice displayed as a button/option

@export_group("Display")
@export var text: String = "Choice text"
@export var icon: Texture2D

@export_group("Availability")
@export var always_available: bool = true
@export var availability_branch: DialogueBranch  # If set, evaluated for availability

@export_group("Flow")
@export var target_label: String = ""


func is_available(evaluator: DialogueConditionEvaluator) -> bool:
	if always_available:
		return true
	
	if availability_branch:
		return evaluator.evaluate(availability_branch)
	
	return false
