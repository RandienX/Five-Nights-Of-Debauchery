extends RefCounted
class_name BattleConditionCustomScript

@export var custom_check_script: GDScript

# Delegates the check to a custom script
func check(battle_engine: Node) -> bool:
	if custom_check_script:
		var instance = custom_check_script.new()
		if instance.has_method("check"):
			return instance.check(battle_engine)
	return false
