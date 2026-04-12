@tool
class_name DialogueEffect
extends Resource

## Effect that runs when entering/exiting a dialogue node

enum EffectType {
	SET_VARIABLE,         # Set a game variable
	ADD_ITEM,             # Give item to player
	REMOVE_ITEM,          # Take item from player
	ADD_STATUS,           # Apply status effect
	REMOVE_STATUS,        # Remove status effect
	START_QUEST,          # Begin quest
	COMPLETE_QUEST,       # Finish quest
	TRIGGER_EVENT,        # Fire a signal/event
	WAIT,                 # Pause dialogue briefly
	CUSTOM                # Custom script
}

@export_group("Effect")
@export_enum("Set Variable", "Add Item", "Remove Item", "Add Status", "Remove Status",
             "Start Quest", "Complete Quest", "Trigger Event", "Wait", "Custom")
var effect_type: int = 0

@export var param_string: String = ""      # var_name, item_id, status_id, quest_id, event_name
@export var param_value: float = 0.0       # value, amount
@export var wait_seconds: float = 1.0      # For WAIT type
@export var custom_script: String = ""     # Path to custom effect script


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	
	match effect_type:
		EffectType.SET_VARIABLE:
			props.append({"name": "param_string", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "param_value", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.ADD_ITEM, EffectType.REMOVE_ITEM:
			props.append({"name": "param_string", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT})
			props.append({
				"name": "param_value",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,999,1",
				"usage": PROPERTY_USAGE_DEFAULT
			})
		
		EffectType.ADD_STATUS, EffectType.REMOVE_STATUS, EffectType.START_QUEST, EffectType.COMPLETE_QUEST:
			props.append({"name": "param_string", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.TRIGGER_EVENT:
			props.append({"name": "param_string", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.WAIT:
			props.append({
				"name": "wait_seconds",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.1,10,0.1",
				"usage": PROPERTY_USAGE_DEFAULT
			})
		
		EffectType.CUSTOM:
			props.append({
				"name": "custom_script",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_FILE,
				"hint_string": "*.gd",
				"usage": PROPERTY_USAGE_DEFAULT
			})
	
	return props
