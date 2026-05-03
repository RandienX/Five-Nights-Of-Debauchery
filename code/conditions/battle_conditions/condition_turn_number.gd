extends RefCounted
class_name BattleConditionTurnNumber

@export var turn_number: int = 5
@export var comparison: int = 0  # 0: ==, 1: >=, 2: <=, 3: >, 4: <

# Checks if the current battle turn matches the condition
func check(battle_engine: Node) -> bool:
	# We need to track turns - for now we'll use a simple counter on the battle_engine
	if not battle_engine.has_meta("battle_turn"):
		battle_engine.set_meta("battle_turn", 1)
	
	var current_turn = battle_engine.get_meta("battle_turn")
	
	match comparison:
		0: return current_turn == turn_number
		1: return current_turn >= turn_number
		2: return current_turn <= turn_number
		3: return current_turn > turn_number
		4: return current_turn < turn_number
	
	return false
