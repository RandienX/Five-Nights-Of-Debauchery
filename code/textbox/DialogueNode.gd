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

func has_branches() -> bool:
	return not branches.is_empty()

func has_choices() -> bool:
	return not choices.is_empty()

func is_end_node() -> bool:
	return next_label.is_empty() and branches.is_empty() and choices.is_empty()
