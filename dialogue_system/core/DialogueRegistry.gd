class_name DialogueRegistry
extends RefCounted

## Static registry for dialogue conditions and actions.
## Provides built-in conditions and allows registration of custom ones.
## Thread-safe, singleton-like pattern for global access.


## =====================
## Built-in Condition Handlers
## Signature: func(arguments: Array, context: Dictionary) -> bool
## =====================

## Check if player has an item
## Arguments: [item_id: String, amount: int (default 1)]
static func condition_has_item(arguments: Array, context: Dictionary) -> bool:
	if arguments.is_empty():
		push_error("DialogueRegistry: condition_has_item requires at least item_id argument")
		return false
	
	var item_id: String = str(arguments[0])
	var amount: int = 1
	if arguments.size() > 1:
		amount = int(arguments[1])
	
	# Delegate to game-specific implementation via context
	if context.has("has_item_callback"):
		var callback: Callable = context["has_item_callback"]
		if callback.is_valid():
			return callback.call(item_id, amount)
	
	push_warning("DialogueRegistry: No has_item_callback provided in context - assuming item NOT present")
	return false


## Check if player has a status effect
## Arguments: [effect_id: String]
static func condition_has_status_effect(arguments: Array, context: Dictionary) -> bool:
	if arguments.is_empty():
		push_error("DialogueRegistry: condition_has_status_effect requires effect_id argument")
		return false
	
	var effect_id: String = str(arguments[0])
	
	if context.has("has_status_effect_callback"):
		var callback: Callable = context["has_status_effect_callback"]
		if callback.is_valid():
			return callback.call(effect_id)
	
	push_warning("DialogueRegistry: No has_status_effect_callback provided - assuming effect NOT present")
	return false


## Check a game variable against a value
## Arguments: [var_name: String, operator: String, value: Variant]
## Operators: "==", "!=", "<", ">", "<=", ">="
static func condition_check_variable(arguments: Array, context: Dictionary) -> bool:
	if arguments.size() < 3:
		push_error("DialogueRegistry: condition_check_variable requires var_name, operator, and value")
		return false
	
	var var_name: String = str(arguments[0])
	var operator: String = str(arguments[1])
	var value: Variant = arguments[2]
	
	# Get current variable value from context
	var current_value: Variant = null
	if context.has("get_variable_callback"):
		var callback: Callable = context["get_variable_callback"]
		if callback.is_valid():
			current_value = callback.call(var_name)
	elif context.has("variables") and context["variables"] is Dictionary:
		current_value = context["variables"].get(var_name)
	else:
		push_warning("DialogueRegistry: No variable source available for '%s'" % var_name)
		return false
	
	# Perform comparison
	match operator:
		"==": return current_value == value
		"!=": return current_value != value
		"<": 
			if typeof(current_value) == TYPE_INT or typeof(current_value) == TYPE_FLOAT:
				return float(current_value) < float(value)
			return false
		">": 
			if typeof(current_value) == TYPE_INT or typeof(current_value) == TYPE_FLOAT:
				return float(current_value) > float(value)
			return false
		"<=": 
			if typeof(current_value) == TYPE_INT or typeof(current_value) == TYPE_FLOAT:
				return float(current_value) <= float(value)
			return false
		">=": 
			if typeof(current_value) == TYPE_INT or typeof(current_value) == TYPE_FLOAT:
				return float(current_value) >= float(value)
			return false
		_:
			push_error("DialogueRegistry: Unknown operator '%s' in check_variable" % operator)
			return false
	
	return false


## Random chance check
## Arguments: [percent: float (0-100)]
static func condition_random_chance(arguments: Array, context: Dictionary) -> bool:
	if arguments.is_empty():
		push_error("DialogueRegistry: condition_random_chance requires percent argument")
		return false
	
	var percent: float = float(arguments[0])
	percent = clamp(percent, 0.0, 100.0)
	
	var roll: float = randf_range(0.0, 100.0)
	return roll <= percent


## Always true (useful for testing)
static func condition_always_true(_arguments: Array, _context: Dictionary) -> bool:
	return true


## Always false (useful for testing)
static func condition_always_false(_arguments: Array, _context: Dictionary) -> bool:
	return false


## =====================
## Built-in Action Handlers
## Signature: func(arguments: Array, context: Dictionary) -> void
## =====================

## Set a game variable
## Arguments: [var_name: String, value: Variant]
static func action_set_variable(arguments: Array, context: Dictionary) -> void:
	if arguments.size() < 2:
		push_error("DialogueRegistry: action_set_variable requires var_name and value")
		return
	
	var var_name: String = str(arguments[0])
	var value: Variant = arguments[1]
	
	if context.has("set_variable_callback"):
		var callback: Callable = context["set_variable_callback"]
		if callback.is_valid():
			callback.call(var_name, value)
			return
	
	push_warning("DialogueRegistry: No set_variable_callback provided - variable '%s' not set" % var_name)


## Modify a game variable (add/subtract)
## Arguments: [var_name: String, delta: int/float]
static func action_modify_variable(arguments: Array, context: Dictionary) -> void:
	if arguments.size() < 2:
		push_error("DialogueRegistry: action_modify_variable requires var_name and delta")
		return
	
	var var_name: String = str(arguments[0])
	var delta: Variant = arguments[1]
	
	if context.has("get_variable_callback") and context.has("set_variable_callback"):
		var get_cb: Callable = context["get_variable_callback"]
		var set_cb: Callable = context["set_variable_callback"]
		
		if get_cb.is_valid() and set_cb.is_valid():
			var current: Variant = get_cb.call(var_name)
			if typeof(current) == TYPE_INT or typeof(current) == TYPE_FLOAT:
				set_cb.call(var_name, current + delta)
				return
	
	push_warning("DialogueRegistry: Could not modify variable '%s'" % var_name)


## Give item to player
## Arguments: [item_id: String, amount: int]
static func action_give_item(arguments: Array, context: Dictionary) -> void:
	if arguments.is_empty():
		push_error("DialogueRegistry: action_give_item requires item_id")
		return
	
	var item_id: String = str(arguments[0])
	var amount: int = 1
	if arguments.size() > 1:
		amount = int(arguments[1])
	
	if context.has("give_item_callback"):
		var callback: Callable = context["give_item_callback"]
		if callback.is_valid():
			callback.call(item_id, amount)
			return
	
	push_warning("DialogueRegistry: No give_item_callback provided - item '%s' not given" % item_id)


## Remove item from player
## Arguments: [item_id: String, amount: int]
static func action_remove_item(arguments: Array, context: Dictionary) -> void:
	if arguments.is_empty():
		push_error("DialogueRegistry: action_remove_item requires item_id")
		return
	
	var item_id: String = str(arguments[0])
	var amount: int = 1
	if arguments.size() > 1:
		amount = int(arguments[1])
	
	if context.has("remove_item_callback"):
		var callback: Callable = context["remove_item_callback"]
		if callback.is_valid():
			callback.call(item_id, amount)
			return
	
	push_warning("DialogueRegistry: No remove_item_callback provided - item '%s' not removed" % item_id)


## Add status effect to player
## Arguments: [effect_id: String, duration: float (optional)]
static func action_add_status_effect(arguments: Array, context: Dictionary) -> void:
	if arguments.is_empty():
		push_error("DialogueRegistry: action_add_status_effect requires effect_id")
		return
	
	var effect_id: String = str(arguments[0])
	var duration: float = -1.0  # -1 means permanent
	if arguments.size() > 1:
		duration = float(arguments[1])
	
	if context.has("add_status_effect_callback"):
		var callback: Callable = context["add_status_effect_callback"]
		if callback.is_valid():
			callback.call(effect_id, duration)
			return
	
	push_warning("DialogueRegistry: No add_status_effect_callback provided - effect '%s' not added" % effect_id)


## Remove status effect from player
## Arguments: [effect_id: String]
static func action_remove_status_effect(arguments: Array, context: Dictionary) -> void:
	if arguments.is_empty():
		push_error("DialogueRegistry: action_remove_status_effect requires effect_id")
		return
	
	var effect_id: String = str(arguments[0])
	
	if context.has("remove_status_effect_callback"):
		var callback: Callable = context["remove_status_effect_callback"]
		if callback.is_valid():
			callback.call(effect_id)
			return
	
	push_warning("DialogueRegistry: No remove_status_effect_callback provided - effect '%s' not removed" % effect_id)


## Trigger a custom game event
## Arguments: [event_name: String, ...additional_args]
static func action_trigger_event(arguments: Array, context: Dictionary) -> void:
	if arguments.is_empty():
		push_error("DialogueRegistry: action_trigger_event requires event_name")
		return
	
	var event_name: String = str(arguments[0])
	var extra_args: Array = arguments.slice(1)
	
	if context.has("trigger_event_callback"):
		var callback: Callable = context["trigger_event_callback"]
		if callback.is_valid():
			callback.call(event_name, extra_args)
			return
	
	push_warning("DialogueRegistry: No trigger_event_callback provided - event '%s' not triggered" % event_name)


## Debug print (useful for testing)
static func action_debug_print(arguments: Array, _context: Dictionary) -> void:
	if arguments.is_empty():
		print("DialogueRegistry: [DEBUG]")
		return
	
	var message: String = ""
	for arg in arguments:
		if message != "":
			message += " "
		message += str(arg)
	
	print("DialogueRegistry: [DEBUG] ", message)


## =====================
## Registry Management
## =====================

## Custom conditions registered at runtime
static var _custom_conditions: Dictionary = {}

## Custom actions registered at runtime
static var _custom_actions: Dictionary = {}


## Register a custom condition handler
## @param condition_id: Unique identifier used in dialogue branches
## @param handler: Callable that matches signature (Array, Dictionary) -> bool
static func register_condition(condition_id: String, handler: Callable) -> void:
	if not handler.is_valid():
		push_error("DialogueRegistry: Cannot register invalid callable for condition '%s'" % condition_id)
		return
	
	_custom_conditions[condition_id] = handler
	print("DialogueRegistry: Registered custom condition '%s'" % condition_id)


## Register a custom action handler
## @param action_id: Unique identifier used in dialogue node actions
## @param handler: Callable that matches signature (Array, Dictionary) -> void
static func register_action(action_id: String, handler: Callable) -> void:
	if not handler.is_valid():
		push_error("DialogueRegistry: Cannot register invalid callable for action '%s'" % action_id)
		return
	
	_custom_actions[action_id] = handler
	print("DialogueRegistry: Registered custom action '%s'" % action_id)


## Unregister a custom condition
static func unregister_condition(condition_id: String) -> void:
	_custom_conditions.erase(condition_id)


## Unregister a custom action
static func unregister_action(action_id: String) -> void:
	_custom_actions.erase(action_id)


## Check if a condition is registered (built-in or custom)
static func has_condition(condition_id: String) -> bool:
	if condition_id.begins_with("has_item"):
		return true
	if condition_id.begins_with("has_status_effect"):
		return true
	if condition_id.begins_with("check_variable"):
		return true
	if condition_id.begins_with("random_chance"):
		return true
	if condition_id in ["always_true", "always_false"]:
		return true
	
	return _custom_conditions.has(condition_id)


## Check if an action is registered (built-in or custom)
static func has_action(action_id: String) -> bool:
	if action_id.begins_with("set_variable"):
		return true
	if action_id.begins_with("modify_variable"):
		return true
	if action_id.begins_with("give_item"):
		return true
	if action_id.begins_with("remove_item"):
		return true
	if action_id.begins_with("add_status_effect"):
		return true
	if action_id.begins_with("remove_status_effect"):
		return true
	if action_id.begins_with("trigger_event"):
		return true
	if action_id == "debug_print":
		return true
	
	return _custom_actions.has(action_id)


## Get a condition handler by ID
static func get_condition_handler(condition_id: String) -> Callable:
	# Built-in conditions
	if condition_id.begins_with("has_item"):
		return condition_has_item
	if condition_id.begins_with("has_status_effect"):
		return condition_has_status_effect
	if condition_id.begins_with("check_variable"):
		return condition_check_variable
	if condition_id.begins_with("random_chance"):
		return condition_random_chance
	if condition_id == "always_true":
		return condition_always_true
	if condition_id == "always_false":
		return condition_always_false
	
	# Custom conditions
	if _custom_conditions.has(condition_id):
		return _custom_conditions[condition_id]
	
	return Callable()  # Invalid callable


## Get an action handler by ID
static func get_action_handler(action_id: String) -> Callable:
	# Built-in actions
	if action_id.begins_with("set_variable"):
		return action_set_variable
	if action_id.begins_with("modify_variable"):
		return action_modify_variable
	if action_id.begins_with("give_item"):
		return action_give_item
	if action_id.begins_with("remove_item"):
		return action_remove_item
	if action_id.begins_with("add_status_effect"):
		return action_add_status_effect
	if action_id.begins_with("remove_status_effect"):
		return action_remove_status_effect
	if action_id.begins_with("trigger_event"):
		return action_trigger_event
	if action_id == "debug_print":
		return action_debug_print
	
	# Custom actions
	if _custom_actions.has(action_id):
		return _custom_actions[action_id]
	
	return Callable()  # Invalid callable


## Evaluate a condition by ID with arguments
## @param condition_id: The condition to evaluate
## @param arguments: Arguments to pass to the condition
## @param context: Runtime context (callbacks, variables, etc.)
## @return: Boolean result of condition evaluation
static func evaluate_condition(condition_id: String, arguments: Array, context: Dictionary) -> bool:
	var handler: Callable = get_condition_handler(condition_id)
	
	if not handler.is_valid():
		push_error("DialogueRegistry: Unknown condition '%s'" % condition_id)
		return false
	
	return handler.call(arguments, context)


## Execute an action by ID with arguments
## @param action_id: The action to execute
## @param arguments: Arguments to pass to the action
## @param context: Runtime context (callbacks, variables, etc.)
static func execute_action(action_id: String, arguments: Array, context: Dictionary) -> void:
	var handler: Callable = get_action_handler(action_id)
	
	if not handler.is_valid():
		push_error("DialogueRegistry: Unknown action '%s'" % action_id)
		return
	
	handler.call(arguments, context)


## Clear all custom registrations (useful for testing or hot-reloading)
static func clear_custom_registrations() -> void:
	_custom_conditions.clear()
	_custom_actions.clear()
	print("DialogueRegistry: Cleared all custom registrations")
