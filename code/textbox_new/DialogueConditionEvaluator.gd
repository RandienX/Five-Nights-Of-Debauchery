class_name DialogueConditionEvaluator
extends RefCounted

## Evaluates dialogue branch conditions
## Connect this to your game's data systems

# Signals for custom condition evaluation
signal custom_condition_requested(branch: DialogueBranch, result_callback: Callable)

# Game state hooks - connect these to your actual game systems
var has_item_func: Callable      # func(item_id: String, amount: int) -> bool
var has_status_func: Callable    # func(effect_id: String) -> bool
var get_variable_func: Callable  # func(var_name: String) -> float
var is_quest_complete_func: Callable  # func(quest_id: String) -> bool
var is_quest_active_func: Callable    # func(quest_id: String) -> bool


func evaluate(branch: DialogueBranch) -> bool:
	if not branch:
		return false
	
	match branch.condition_type:
		DialogueBranch.HAS_ITEM:
			return _eval_has_item(branch.param_string, int(branch.param_value))
		
		DialogueBranch.HAS_STATUS:
			return _eval_has_status(branch.param_string)
		
		DialogueBranch.VARIABLE_EQUALS:
			return _eval_var_equals(branch.param_string, branch.param_value)
		
		DialogueBranch.VARIABLE_LESS:
			return _eval_var_less(branch.param_string, branch.param_value)
		
		DialogueBranch.VARIABLE_GREATER:
			return _eval_var_greater(branch.param_string, branch.param_value)
		
		DialogueBranch.RANDOM_CHANCE:
			return _eval_random(branch.param_value)
		
		DialogueBranch.QUEST_COMPLETE:
			return _eval_quest_complete(branch.param_string)
		
		DialogueBranch.QUEST_ACTIVE:
			return _eval_quest_active(branch.param_string)
		
		DialogueBranch.CUSTOM:
			return _eval_custom(branch)
		
		_:
			push_warning("Unknown condition type: %s" % branch.condition_type)
			return false


func _eval_has_item(item_id: String, amount: int) -> bool:
	if has_item_func.is_valid():
		return has_item_func.call(item_id, amount)
	push_warning("Dialogue: has_item_func not set, cannot check for '%s'" % item_id)
	return false


func _eval_has_status(effect_id: String) -> bool:
	if has_status_func.is_valid():
		return has_status_func.call(effect_id)
	push_warning("Dialogue: has_status_func not set, cannot check for '%s'" % effect_id)
	return false


func _eval_var_equals(var_name: String, value: float) -> bool:
	if get_variable_func.is_valid():
		return get_variable_func.call(var_name) == value
	push_warning("Dialogue: get_variable_func not set, cannot check '%s'" % var_name)
	return false


func _eval_var_less(var_name: String, value: float) -> bool:
	if get_variable_func.is_valid():
		return get_variable_func.call(var_name) < value
	push_warning("Dialogue: get_variable_func not set, cannot check '%s'" % var_name)
	return false


func _eval_var_greater(var_name: String, value: float) -> bool:
	if get_variable_func.is_valid():
		return get_variable_func.call(var_name) > value
	push_warning("Dialogue: get_variable_func not set, cannot check '%s'" % var_name)
	return false


func _eval_random(percent: float) -> bool:
	return randf_range(0, 100) < percent


func _eval_quest_complete(quest_id: String) -> bool:
	if is_quest_complete_func.is_valid():
		return is_quest_complete_func.call(quest_id)
	push_warning("Dialogue: is_quest_complete_func not set, cannot check '%s'" % quest_id)
	return false


func _eval_quest_active(quest_id: String) -> bool:
	if is_quest_active_func.is_valid():
		return is_quest_active_func.call(quest_id)
	push_warning("Dialogue: is_quest_active_func not set, cannot check '%s'" % quest_id)
	return false


func _eval_custom(branch: DialogueBranch) -> bool:
	if branch.custom_script.is_empty():
		push_error("Dialogue: Custom branch has no script path")
		return false
	
	# Load and execute custom script
	var script = load(branch.custom_script)
	if not script:
		push_error("Dialogue: Failed to load custom script: %s" % branch.custom_script)
		return false
	
	# Expect a static function: static func evaluate(branch: DialogueBranch, evaluator: DialogueConditionEvaluator) -> bool
	if script.has_static_method("evaluate"):
		return script.evaluate(branch, self)
	
	push_error("Dialogue: Custom script missing static evaluate() function: %s" % branch.custom_script)
	return false
