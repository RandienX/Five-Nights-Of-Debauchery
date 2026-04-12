@tool
class_name DialogueNode
extends Resource

## A single dialogue entry with text, branches, and choices

@export_group("Node Identity")
@export var label: String = ""

@export_group("Display")
@export_multiline var text: String = ""
@export var speaker: String = ""
@export var portrait: Texture2D

@export_group("Flow Control")
@export var next_label: String = ""  # Empty = end dialogue

@export_group("Conditional Branches")
@export var branches: Array[DialogueBranch] = []

@export_group("Player Choices")
@export var choices: Array[DialogueChoice] = []

@export_group("Effects")
@export var on_enter_effects: Array[DialogueEffect] = []
@export var on_exit_effects: Array[DialogueEffect] = []


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	
	# Add hint for branches array to show nicely in inspector
	props.append({
		"name": "branches",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%s/1:" % DialogueBranch.class_name
	})
	
	# Add hint for choices array
	props.append({
		"name": "choices",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%s/1:" % DialogueChoice.class_name
	})
	
	# Add hint for effects arrays
	props.append({
		"name": "on_enter_effects",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%s/1:" % DialogueEffect.class_name
	})
	
	props.append({
		"name": "on_exit_effects",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%s/1:" % DialogueEffect.class_name
	})
	
	return props


func has_branches() -> bool:
	return not branches.is_empty()


func has_choices() -> bool:
	return not choices.is_empty()


func is_end_node() -> bool:
	return next_label.is_empty() and branches.is_empty() and choices.is_empty()
