extends RefCounted
class_name BattleConditionEnemyDefeated

@export var enemy_index: int = 1  # 1-5 for enemy_pos1 to enemy_pos5

# Checks if a specific enemy is dead
func check(battle_engine: Node) -> bool:
	var battle = battle_engine.battle
	var enemy = battle.get('enemy_pos'+str(enemy_index))
	if enemy:
		return enemy.hp <= 0
	return false
