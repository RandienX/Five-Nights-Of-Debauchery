extends RefCounted
class_name BattleConditionEnemyDefeated

@export var enemy_index: int = 1  # 1-5 for enemy_pos1 to enemy_pos5

# Checks if a specific enemy is dead
func check(battle_engine: Node) -> bool:
	# Try new method first
	if battle_engine.has_method("get_enemy"):
		var enemy = battle_engine.get_enemy(enemy_index - 1)
		if enemy:
			return enemy.hp <= 0
		return true  # Enemy doesn't exist, consider defeated
	
	# Fallback to old method
	var battle = battle_engine.battle
	var enemy = battle.get('enemy_pos'+str(enemy_index))
	if enemy:
		return enemy.hp <= 0
	return false
