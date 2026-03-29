extends RefCounted
class_name BattleEndConditionChecker

# Checks and executes battle end conditions
func check_conditions(battle: Resource, battle_engine: Node) -> bool:
	if not battle or not battle.end_conditions or battle.end_conditions.is_empty():
		return false
	
	for condition in battle.end_conditions:
		if condition.check(battle_engine):
			condition.execute(battle_engine)
			return true
	
	return false

# Built-in condition: All enemies defeated
func check_all_enemies_defeated(battle: Resource) -> bool:
	for e in range(5):
		if battle.get('enemy_pos'+str(e+1)) and battle.get('enemy_pos'+str(e+1)).hp > 0:
			return false
	return true

# Built-in condition: Specific enemy defeated
func check_enemy_defeated(battle: Resource, enemy_index: int) -> bool:
	if enemy_index < 1 or enemy_index > 5:
		return false
	if not battle.get('enemy_pos'+str(enemy_index)):
		return true  # Enemy doesn't exist, consider defeated
	return battle.get('enemy_pos'+str(enemy_index)).hp <= 0

# Built-in condition: Party member low HP
func check_party_member_low_hp(party: Array, threshold_percent: float = 0.25) -> bool:
	for p in party:
		if p.hp > 0 and float(p.hp) / p.max_stats["hp"] <= threshold_percent:
			return true
	return false

# Built-in condition: Turn number reached
func check_turn_number(turn: int, target_turn: int) -> bool:
	return turn >= target_turn

# Custom condition using script
func check_custom_condition(condition_script: GDScript, battle_engine: Node) -> bool:
	if condition_script:
		var instance = condition_script.new()
		if instance.has_method("check"):
			return instance.check(battle_engine)
	return false
