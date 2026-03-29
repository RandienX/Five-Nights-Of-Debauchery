extends RefCounted
class_name BattleConditionAllEnemiesDead

# Checks if all enemies are dead
func check(battle_engine: Node) -> bool:
	var battle = battle_engine.battle
	for e in range(5):
		var enemy = battle.get('enemy_pos'+str(e+1))
		if enemy and enemy.hp > 0:
			return false
	return true
