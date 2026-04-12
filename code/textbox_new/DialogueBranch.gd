@tool
class_name DialogueBranch
extends Resource

## Conditional branch - evaluates condition and jumps to target if true

enum ConditionType {
	HAS_ITEM,           # Check if player has item
	HAS_STATUS,         # Check if player has status effect
	VARIABLE_EQUALS,    # var == value
	VARIABLE_LESS,      # var < value
	VARIABLE_GREATER,   # var > value
	RANDOM_CHANCE,      # Random percent check
	QUEST_COMPLETE,     # Quest is finished
	QUEST_ACTIVE,       # Quest is in progress
	CUSTOM              # Custom script
}

@export_group("Condition")
@export_enum("Has Item", "Has Status", "Var Equals", "Var Less", "Var Greater", 
             "Random Chance", "Quest Complete", "Quest Active", "Custom") 
var condition_type: int = 0

@export var param_string: String = ""      # item_id, status_id, var_name, quest_id
@export var param_value: float = 1.0       # amount, comparison value, percent
@export var custom_script: String = ""     # Path to custom condition script

@export_group("Flow")
@export var target_label: String = ""      # Jump here if condition is true
@export var comment: String = ""           # Designer note


func get_condition_type_name() -> String:
	return ConditionType.keys()[condition_type]


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	
	# Dynamic params based on condition type
	match condition_type:
		ConditionType.HAS_ITEM, ConditionType.HAS_STATUS, ConditionType.QUEST_COMPLETE, ConditionType.QUEST_ACTIVE:
			props.append({
				"name": "param_string",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_NONE,
				"usage": PROPERTY_USAGE_DEFAULT
			})
			if condition_type == ConditionType.HAS_ITEM:
				props.append({
					"name": "param_value",
					"type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE,
					"hint_string": "0,999,1",
					"usage": PROPERTY_USAGE_DEFAULT
				})
		
		ConditionType.VARIABLE_EQUALS, ConditionType.VARIABLE_LESS, ConditionType.VARIABLE_GREATER:
			props.append({
				"name": "param_string",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_NONE,
				"usage": PROPERTY_USAGE_DEFAULT
			})
			props.append({
				"name": "param_value",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_NONE,
				"usage": PROPERTY_USAGE_DEFAULT
			})
		
		ConditionType.RANDOM_CHANCE:
			props.append({
				"name": "param_value",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0,100,0.1",
				"usage": PROPERTY_USAGE_DEFAULT
			})
		
		ConditionType.CUSTOM:
			props.append({
				"name": "custom_script",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_FILE,
				"hint_string": "*.gd",
				"usage": PROPERTY_USAGE_DEFAULT
			})
	
	return props
