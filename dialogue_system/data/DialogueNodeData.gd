class_name DialogueNodeData
extends Resource

enum NodeType { DIALOGUE, QUESTION, ACTION, CONDITION, JUMP, END }
enum TextEffect { NONE, TYPEWRITER, FADE, SCROLL, WAVE }
enum ChoiceLayout { VERTICAL, HORIZONTAL, GRID }
enum ConditionType { HAS_ITEM, CHECK_VARIABLE, PARTY_LEVEL, RANDOM_CHANCE, HAS_STATUS }
enum ActionType { SET_VARIABLE, MODIFY_VARIABLE, GIVE_ITEM, TRIGGER_EVENT }

@export_group("Content")
@export var node_id: String = ""
@export var node_type: NodeType = NodeType.DIALOGUE
@export_multiline var text: String = "Dialogue text here..."
@export var speaker_name: String = ""

@export_group("Text Effects")
@export var text_effect: TextEffect = TextEffect.NONE
@export var text_effect_speed: float = 0.03

@export_group("Flow")
@export var next_index: int = -1  # -1 means end of dialogue
## Maps choice text to the node index it jumps to
@export var branching_choices: Dictionary = {}

@export_group("Optional Condition")
## If empty, node always shows. If set, must be true to proceed.
@export var condition_type: ConditionType = ConditionType.HAS_ITEM
@export var condition_args: Array = []
@export var jump_if_false_index: int = -1  # Where to go if condition fails

@export_group("Optional Action")
## Executed when this node is displayed
@export var action_type: ActionType = ActionType.SET_VARIABLE
@export var action_args: Array = []

@export_group("Visuals")
@export var background_color: Color = Color.TRANSPARENT
@export var portrait_texture_path: String = ""
@export var emotion: String = ""
@export var sound_effect_path: String = ""
@export var choice_layout: ChoiceLayout = ChoiceLayout.VERTICAL

@export_group("Debug Info")
@export var notes: String = ""
@export var created_date: String = ""
@export var last_modified: String = ""


func _validate_property(property: Dictionary) -> void:
	if property.name == "branching_choices":
		property.hint_string = "{key_type}/{key_hint}:{key_hint_string};{array_type}:{value_type}/{value_hint}:{value_hint_string}".format({
			key_type = TYPE_STRING,
			key_hint = PROPERTY_HINT_NONE,
			key_hint_string = "",
			array_type = TYPE_ARRAY,
			value_type = TYPE_INT,
			value_hint = PROPERTY_HINT_NONE,
			value_hint_string = ""
		})
