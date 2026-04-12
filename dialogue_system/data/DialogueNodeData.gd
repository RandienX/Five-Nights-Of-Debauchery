class_name DialogueNodeData
extends Resource

@export_group("Content")
@export_multiline var text: String = "Dialogue text here..."
@export var speaker_name: String = ""

@export_group("Flow")
@export var next_index: int = -1  # -1 means end of dialogue

@export_group("Optional Condition")
## If empty, node always shows. If set, must be true to proceed.
@export var condition_id: String = ""
@export var condition_args: Array = []
@export var jump_if_false_index: int = -1  # Where to go if condition fails

@export_group("Optional Action")
## Executed when this node is displayed
@export var action_id: String = ""
@export var action_args: Array = []
