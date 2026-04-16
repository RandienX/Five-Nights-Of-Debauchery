extends RefCounted
class_name BattleConditionAllEnemiesDead

# Checks if all enemies are dead
func check(battle_engine: Node) -> bool:
	if battle_engine.has_method("get_alive_enemies"):
		return battle_engine.get_alive_enemies().size() == 0
	
	# Fallback to old method if new method doesn't exist
	var battle = battle_engine.battle
	for e in range(5):
		var enemy = battle.get('enemy_pos'+str(e+1))
		if enemy and enemy.hp > 0:
			return false
	return true
