class_name DialogueData
extends Resource

enum DialogueCategory { NONE, INTRO, MAIN_STORY, SIDE_QUEST, ENDING, TUTORIAL }
enum DialogueMood { NEUTRAL, HAPPY, SAD, TENSE, MYSTERIOUS, COMEDIC }
enum ConditionType { HAS_ITEM, CHECK_VARIABLE, PARTY_LEVEL, RANDOM_CHANCE, HAS_STATUS }
enum ActionType { SET_VARIABLE, MODIFY_VARIABLE, GIVE_ITEM, TRIGGER_EVENT }

@export_group("Metadata")
@export var dialogue_id: String = ""
@export var dialogue_title: String = ""
@export var author: String = ""
@export var version: String = "1.0"
@export var description: String = ""
@export var tags: Array[String] = []

@export_group("Categorization")
@export var category: DialogueCategory = DialogueCategory.NONE
@export var mood: DialogueMood = DialogueMood.NEUTRAL

@export_group("Node Mapping")
## Maps dialogue categories to specific node IDs
@export var category_nodes: Dictionary = {}
## Maps mood states to portrait file paths
@export var mood_portraits: Dictionary = {}
## Maps condition types to their default argument templates
@export var condition_templates: Dictionary = {}
## Maps action types to their default argument templates
@export var action_templates: Dictionary = {}

@export_group("Nodes")
@export var nodes: Array[DialogueNodeData] = []


func _validate_property(property: Dictionary) -> void:
	if property.name == "category_nodes":
		property.hint_string = "{key_type}/{key_hint}:{key_hint_string};{array_type}:{value_type}/{value_hint}:{value_hint_string}".format({
			key_type = TYPE_INT,
			key_hint = PROPERTY_HINT_ENUM,
			key_hint_string = ",".join(DialogueCategory.keys()),
			array_type = TYPE_ARRAY,
			value_type = TYPE_STRING,
			value_hint = PROPERTY_HINT_NONE,
			value_hint_string = ""
		})
	elif property.name == "mood_portraits":
		property.hint_string = "{key_type}/{key_hint}:{key_hint_string};{array_type}:{value_type}/{value_hint}:{value_hint_string}".format({
			key_type = TYPE_INT,
			key_hint = PROPERTY_HINT_ENUM,
			key_hint_string = ",".join(DialogueMood.keys()),
			array_type = TYPE_ARRAY,
			value_type = TYPE_STRING,
			value_hint = PROPERTY_HINT_FILE,
			value_hint_string = "*.png,*.jpg,*.jpeg,*.webp"
		})
	elif property.name == "condition_templates":
		property.hint_string = "{key_type}/{key_hint}:{key_hint_string};{array_type}:{value_type}/{value_hint}:{value_hint_string}".format({
			key_type = TYPE_INT,
			key_hint = PROPERTY_HINT_ENUM,
			key_hint_string = ",".join(ConditionType.keys()),
			array_type = TYPE_ARRAY,
			value_type = TYPE_VARIANT,
			value_hint = PROPERTY_HINT_NONE,
			value_hint_string = ""
		})
	elif property.name == "action_templates":
		property.hint_string = "{key_type}/{key_hint}:{key_hint_string};{array_type}:{value_type}/{value_hint}:{value_hint_string}".format({
			key_type = TYPE_INT,
			key_hint = PROPERTY_HINT_ENUM,
			key_hint_string = ",".join(ActionType.keys()),
			array_type = TYPE_ARRAY,
			value_type = TYPE_VARIANT,
			value_hint = PROPERTY_HINT_NONE,
			value_hint_string = ""
		})
