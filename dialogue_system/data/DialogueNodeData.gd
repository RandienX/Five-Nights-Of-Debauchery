class_name DialogueNodeData
extends Resource

## Defines a single step/branch in the dialogue tree.
## Each node can contain text, choices, conditions, and flow control.

@export_group("Node Identity")
@export var label: String = ""  ## Optional identifier for jump targets
@export var node_id: int = -1   ## Auto-assigned or manual ID

@export_group("Content")
@export_multiline var text: String = ""  ## The dialogue text to display
@export var speaker: String = ""         ## Optional speaker name
@export var portrait: Texture2D = null   ## Optional portrait image

@export_group("Flow Control")
enum NodeType { STANDARD, CHOICE, CONDITIONAL_BRANCH, JUMP, END }
@export var node_type: NodeType = NodeType.STANDARD

## For CONDITIONAL_BRANCH type: List of conditional branches
@export var branches: Array[DialogueBranch] = []

## For JUMP type: Target index or label to jump to
@export var jump_target: String = ""  ## Can be numeric index or label string

## For CHOICE type: Available player choices
@export var choices: Array[DialogueChoice] = []

@export_group("Actions")
## Actions to trigger when this node is entered (before displaying)
@export var on_enter_actions: Array[String] = []
## Actions to trigger when leaving this node
@export var on_exit_actions: Array[String] = []

@export_group("Metadata")
@export var tags: Array[String] = []  ## For filtering/categorization
@export var metadata: Dictionary = {}  ## Custom data for game-specific logic


## Returns a string representation for debugging
func _to_string() -> String:
	return "DialogueNodeData(id=%d, label=%s, type=%s)" % [
		node_id, label if not label.is_empty() else str(node_id), NodeType.keys()[node_type]
	]
