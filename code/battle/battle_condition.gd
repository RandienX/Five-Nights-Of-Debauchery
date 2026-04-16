@tool
class_name BattleCondition
extends Resource

## Conditional check for battle flow control
## Similar structure to DialogueBranch for consistency

enum ConditionType {
	ALL_ENEMIES_DEFEATED,     # Check if all enemies are defeated
	SPECIFIC_ENEMY_DEFEATED,  # Check if specific enemy is defeated
	ENEMY_HP_BELOW,           # Check if any enemy HP below threshold
	PARTY_HP_BELOW,           # Check if any party member HP below threshold
	PARTY_MEMBER_ALIVE,       # Check if specific party member is alive
	TURN_NUMBER_EQUALS,       # Check if current turn equals value
	TURN_NUMBER_GREATER,      # Check if current turn > value
	VARIABLE_EQUALS,          # var == value
	VARIABLE_LESS,            # var < value
	VARIABLE_GREATER,         # var > value
	HAS_STATUS,               # Check if unit has status effect
	RANDOM_CHANCE,            # Random percent check
	CUSTOM                    # Custom script
}

@export_group("Condition")
@export_enum("All Enemies Defeated", "Specific Enemy Defeated", "Enemy HP Below", 
			 "Party HP Below", "Party Member Alive", "Turn Number Equals", 
			 "Turn Number Greater", "Var Equals", "Var Less", "Var Greater",
			 "Has Status", "Random Chance", "Custom") 
var condition_type: int = 0

@export var param_string: String = ""      # enemy_id, party_member_id, var_name, status_id
@export var param_value: float = 1.0       # HP threshold, turn number, comparison value, percent
@export var custom_script: String = ""     # Path to custom condition script

@export_group("Flow")
@export var comment: String = ""           # Designer note


func get_condition_type_name() -> String:
	return ConditionType.keys()[condition_type]


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	
	# Dynamic params based on condition type
	match condition_type:
		ConditionType.SPECIFIC_ENEMY_DEFEATED, ConditionType.PARTY_MEMBER_ALIVE, ConditionType.HAS_STATUS:
			props.append({
				"name": "param_string",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_NONE,
				"usage": PROPERTY_USAGE_DEFAULT
			})
		
		ConditionType.ENEMY_HP_BELOW, ConditionType.PARTY_HP_BELOW:
			props.append({
				"name": "param_string",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_NONE,
				"usage": PROPERTY_USAGE_DEFAULT
			})
			props.append({
				"name": "param_value",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0,9999,1",
				"usage": PROPERTY_USAGE_DEFAULT
			})
		
		ConditionType.TURN_NUMBER_EQUALS, ConditionType.TURN_NUMBER_GREATER:
			props.append({
				"name": "param_value",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,999,1",
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
