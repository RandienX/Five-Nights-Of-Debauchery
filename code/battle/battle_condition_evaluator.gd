class_name BattleConditionEvaluator
extends RefCounted

## Evaluates battle condition checks
## Connect this to your game's data systems

# Signals for custom condition evaluation
signal custom_condition_requested(condition: BattleCondition, result_callback: Callable)

# Game state hooks - connect these to your actual game systems
var get_party_member_func: Callable        # func(member_id: String) -> Node (party member instance)
var get_enemy_func: Callable               # func(enemy_id: String) -> Node (enemy instance)
var get_all_enemies_func: Callable         # func() -> Array (all enemy instances)
var is_enemy_defeated_func: Callable       # func(enemy_id: String) -> bool
var are_all_enemies_defeated_func: Callable # func() -> bool
var get_variable_func: Callable            # func(var_name: String) -> float
var has_status_func: Callable              # func(unit: Node, status_id: String) -> bool
var get_current_turn_func: Callable        # func() -> int


func evaluate(condition: BattleCondition) -> bool:
	if not condition:
		return false
	
	match condition.condition_type:
		BattleCondition.ConditionType.ALL_ENEMIES_DEFEATED:
			return _eval_all_enemies_defeated()
		
		BattleCondition.ConditionType.SPECIFIC_ENEMY_DEFEATED:
			return _eval_specific_enemy_defeated(condition.param_string)
		
		BattleCondition.ConditionType.ENEMY_HP_BELOW:
			return _eval_enemy_hp_below(condition.param_string, int(condition.param_value))
		
		BattleCondition.ConditionType.PARTY_HP_BELOW:
			return _eval_party_hp_below(condition.param_string, int(condition.param_value))
		
		BattleCondition.ConditionType.PARTY_MEMBER_ALIVE:
			return _eval_party_member_alive(condition.param_string)
		
		BattleCondition.ConditionType.TURN_NUMBER_EQUALS:
			return _eval_turn_equals(int(condition.param_value))
		
		BattleCondition.ConditionType.TURN_NUMBER_GREATER:
			return _eval_turn_greater(int(condition.param_value))
		
		BattleCondition.ConditionType.VARIABLE_EQUALS:
			return _eval_var_equals(condition.param_string, condition.param_value)
		
		BattleCondition.ConditionType.VARIABLE_LESS:
			return _eval_var_less(condition.param_string, condition.param_value)
		
		BattleCondition.ConditionType.VARIABLE_GREATER:
			return _eval_var_greater(condition.param_string, condition.param_value)
		
		BattleCondition.ConditionType.HAS_STATUS:
			return _eval_has_status(condition.param_string)
		
		BattleCondition.ConditionType.RANDOM_CHANCE:
			return _eval_random(condition.param_value)
		
		BattleCondition.ConditionType.CUSTOM:
			return _eval_custom(condition)
		
		_:
			push_warning("Unknown battle condition type: %s" % condition.condition_type)
			return false


func _eval_all_enemies_defeated() -> bool:
	if are_all_enemies_defeated_func.is_valid():
		return are_all_enemies_defeated_func.call()
	push_warning("Battle: are_all_enemies_defeated_func not set")
	return false


func _eval_specific_enemy_defeated(enemy_id: String) -> bool:
	if is_enemy_defeated_func.is_valid():
		return is_enemy_defeated_func.call(enemy_id)
	push_warning("Battle: is_enemy_defeated_func not set, cannot check for '%s'" % enemy_id)
	return false


func _eval_enemy_hp_below(enemy_id: String, hp_threshold: int) -> bool:
	if get_enemy_func.is_valid():
		var enemy = get_enemy_func.call(enemy_id)
		if enemy and enemy.has_method("get_hp"):
			return enemy.get_hp() < hp_threshold
	push_warning("Battle: Cannot check HP for enemy '%s'" % enemy_id)
	return false


func _eval_party_hp_below(member_id: String, hp_threshold: int) -> bool:
	if get_party_member_func.is_valid():
		var member = get_party_member_func.call(member_id)
		if member and member.has_method("get_hp"):
			return member.get_hp() < hp_threshold
	push_warning("Battle: Cannot check HP for party member '%s'" % member_id)
	return false


func _eval_party_member_alive(member_id: String) -> bool:
	if get_party_member_func.is_valid():
		var member = get_party_member_func.call(member_id)
		if member and member.has_method("is_alive"):
			return member.is_alive()
		elif member:
			# Fallback: check if HP > 0
			return member.has_method("get_hp") and member.get_hp() > 0
	push_warning("Battle: Cannot check alive status for party member '%s'" % member_id)
	return false


func _eval_turn_equals(turn_number: int) -> bool:
	if get_current_turn_func.is_valid():
		return get_current_turn_func.call() == turn_number
	push_warning("Battle: get_current_turn_func not set, cannot check turn number")
	return false


func _eval_turn_greater(turn_number: int) -> bool:
	if get_current_turn_func.is_valid():
		return get_current_turn_func.call() > turn_number
	push_warning("Battle: get_current_turn_func not set, cannot check turn number")
	return false


func _eval_var_equals(var_name: String, value: float) -> bool:
	if get_variable_func.is_valid():
		return get_variable_func.call(var_name) == value
	push_warning("Battle: get_variable_func not set, cannot check '%s'" % var_name)
	return false


func _eval_var_less(var_name: String, value: float) -> bool:
	if get_variable_func.is_valid():
		return get_variable_func.call(var_name) < value
	push_warning("Battle: get_variable_func not set, cannot check '%s'" % var_name)
	return false


func _eval_var_greater(var_name: String, value: float) -> bool:
	if get_variable_func.is_valid():
		return get_variable_func.call(var_name) > value
	push_warning("Battle: get_variable_func not set, cannot check '%s'" % var_name)
	return false


func _eval_has_status(status_id: String) -> bool:
	# This requires a specific unit context - should be set by caller
	if has_status_func.is_valid():
		return has_status_func.call(status_id)
	push_warning("Battle: has_status_func not set, cannot check for '%s'" % status_id)
	return false


func _eval_random(percent: float) -> bool:
	return randf_range(0, 100) < percent


func _eval_custom(condition: BattleCondition) -> bool:
	if condition.custom_script.is_empty():
		push_error("Battle: Custom condition has no script path")
		return false
	
	# Load and execute custom script
	var script = load(condition.custom_script)
	if not script:
		push_error("Battle: Failed to load custom script: %s" % condition.custom_script)
		return false
	
	# Expect a static function: static func evaluate(condition: BattleCondition, evaluator: BattleConditionEvaluator) -> bool
	if script.has_static_method("evaluate"):
		return script.evaluate(condition, self)
	
	push_error("Battle: Custom script missing static evaluate() function: %s" % condition.custom_script)
	return false
