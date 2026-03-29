extends RefCounted
class_name BattleActionPlanner

# Manages action planning phase for party members
var attack_array: Dictionary = {}
var action_history: Array[Object] = []
var current_party_plan_index: int = 0
var planning_phase: bool = true

func add_attack(attacker: Object, attacked: Array, attack: Skill) -> void:
	attack_array[attacker] = [attacked, attack]

func undo_last_action() -> Object:
	if action_history.is_empty():
		return null
	
	var last = action_history.pop_back()
	if attack_array.has(last):
		var atk = attack_array[last][1]
		if atk.attack_type == 3 and atk.item_reference:
			var used_item = atk.item_reference
			Global.add_item(used_item, 1)  # Restore item
		attack_array.erase(last)
	
	current_party_plan_index = max(0, current_party_plan_index - 1)
	return last

func has_planned_action(actor: Object) -> bool:
	return attack_array.has(actor)

func clear_planning() -> void:
	attack_array.clear()
	action_history.clear()
	planning_phase = true
	current_party_plan_index = 0

func get_actor_action(actor: Object) -> Array:
	if attack_array.has(actor):
		return attack_array[actor]
	return []
