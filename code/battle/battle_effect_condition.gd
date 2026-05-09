extends Resource
class_name ConditionRule
## Rule for checking if an effect should trigger

enum Operator {
	GREATER_THAN,        # >
	LESS_THAN,           # <
	EQUALS,              # ==
	GREATER_EQUAL,       # >=
	LESS_EQUAL,          # <=
	HAS_STATUS,          # Has specific status
	NOT_HAS_STATUS,      # Does not have status
}

@export var enabled: bool = true
@export var check_stat: String = "hp"  # Stat to check (hp, mp, atk, etc.)
@export var operator: Operator = Operator.GREATER_THAN
@export var threshold_value: float = 0.0
@export var status_to_check: StatusDefinition = null  # For HAS_STATUS checks
@export var invert: bool = false  # Invert the result

func evaluate(entity: Entity, context: Dictionary = {}) -> bool:
	if not enabled:
		return true
	
	var result: bool = false
	var actual_value: float = 0.0
	
	# Special handling for status checks
	if operator == Operator.HAS_STATUS or operator == Operator.NOT_HAS_STATUS:
		if status_to_check:
			result = entity.has_status(status_to_check.id)
			if operator == Operator.NOT_HAS_STATUS:
				result = not result
		else:
			result = false
	else:
		# Get stat value
		match check_stat:
			"hp":
				actual_value = float(entity.hp)
			"hp_percent":
				actual_value = (float(entity.hp) / float(entity.get_max_stat("hp"))) * 100.0
			"mp":
				actual_value = float(entity.mp)
			"mp_percent":
				actual_value = (float(entity.mp) / float(entity.get_max_stat("mp"))) * 100.0
			_:
				actual_value = float(entity.get_base_stat(check_stat))
		
		# Compare against threshold
		match operator:
			Operator.GREATER_THAN:
				result = actual_value > threshold_value
			Operator.LESS_THAN:
				result = actual_value < threshold_value
			Operator.EQUALS:
				result = abs(actual_value - threshold_value) < 0.001
			Operator.GREATER_EQUAL:
				result = actual_value >= threshold_value
			Operator.LESS_EQUAL:
				result = actual_value <= threshold_value
	
	return not result if invert else result

func _get_icon() -> String:
	match operator:
		Operator.GREATER_THAN: return ">"
		Operator.LESS_THAN: return "<"
		Operator.EQUALS: return "=="
		Operator.GREATER_EQUAL: return ">="
		Operator.LESS_EQUAL: return "<="
		Operator.HAS_STATUS: return "HAS"
		Operator.NOT_HAS_STATUS: return "!HAS"
	return "?"
