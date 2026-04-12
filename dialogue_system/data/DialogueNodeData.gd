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

## For CONDITIONAL_BRANCH: List of conditions with jump targets
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


## Represents a conditional branch in the dialogue
class DialogueBranch:
	## Condition ID to check (registered in DialogueRegistry)
	var condition_id: String = ""
	## Arguments for the condition
	var arguments: Array = []
	## Target to jump to if condition is true (index or label)
	var jump_target: String = ""
	## What to do if false: NEXT (proceed to next index) or JUMP (to specific target)
	var on_false_behavior: String = "NEXT"
	var on_false_target: String = ""
	
	func _init(
		p_condition_id: String = "",
		p_arguments: Array = [],
		p_jump_target: String = "",
		p_on_false_behavior: String = "NEXT",
		p_on_false_target: String = ""
	):
		condition_id = p_condition_id
		arguments = p_arguments
		jump_target = p_jump_target
		on_false_behavior = p_on_false_behavior
		on_false_target = p_on_false_target


## Represents a player choice in a CHOICE node
class DialogueChoice:
	var text: String = ""
	var target: String = ""  ## Index or label to jump to when selected
	var is_visible_condition: String = ""  ## Optional condition to show/hide choice
	var is_visible_args: Array = []
	
	func _init(
		p_text: String = "",
		p_target: String = "",
		p_is_visible_condition: String = "",
		p_is_visible_args: Array = []
	):
		text = p_text
		target = p_target
		is_visible_condition = p_is_visible_condition
		is_visible_args = p_is_visible_args
