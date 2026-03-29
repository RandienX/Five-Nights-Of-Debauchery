extends RefCounted
class_name BattleAttackExecutor

# Handles execution of attacks and damage calculation
var battle_engine: Node

func _init(engine: Node) -> void:
	battle_engine = engine

func execute_attack(attacker: Object, targets: Array, atk: Skill) -> void:
	var alive: Array = []
	for t in targets:
		if t.hp > 0: 
			alive.append(t)
	
	# Handle Check skill
	if atk.name == "Check ":
		await handle_check_skill(attacker, targets)
		return
	
	# Retarget if all targets dead
	if alive.is_empty() and atk.target_type == 0:
		alive = retarget_random_enemy()
		if alive.is_empty():
			return
	
	if alive.is_empty():
		return
	
	# Handle item usage
	if atk.attack_type == 3:
		await handle_item_usage(attacker, alive, atk)
		return
	
	# Handle multi-attack
	if atk.attack_type == 2 and atk.name != "Check ":
		await execute_multi_attack(attacker, alive[0], atk)
		return
	
	# Single target attack
	await execute_single_target_attack(attacker, alive, atk)

func handle_check_skill(attacker: Object, targets: Array) -> void:
	var desc = "[color=#2196F3]━━━ ENEMY INFO ━━━[/color]"
	if targets.size() > 0 and targets[0] is Enemy:
		var target_enemy = targets[0]
		desc += "\n[color=#FF5722]" + target_enemy.name + "[/color]: " + target_enemy.description
		desc += "\n[color=#4CAF50]HP: " + str(target_enemy.hp) + "/" + str(target_enemy.max_hp) + "[/color] [color=#FFC107]ATK: " + str(target_enemy.damage) + "[/color]"
	battle_engine.add_to_battle_log(desc)
	await battle_engine.get_tree().create_timer(1.5).timeout

func retarget_random_enemy() -> Array:
	var enemies: Array = []
	for e in range(5):
		if battle_engine.battle.get('enemy_pos'+str(e+1)) and battle_engine.battle.get('enemy_pos'+str(e+1)).hp > 0:
			enemies.append(battle_engine.battle.get('enemy_pos'+str(e+1)))
	if not enemies.is_empty():
		return [enemies[randi_range(0, enemies.size()-1)]]
	return []

func handle_item_usage(attacker: Object, targets: Array, atk: Skill) -> void:
	var used_item = atk.item_reference
	if used_item and targets.size() > 0:
		var target = targets[0]
		var success = Global.use_item(used_item, target)
		
		if success:
			var item_log = "[color=#FFD700]━━━ ITEM ━━━[/color]"
			item_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.name + "[/color] on [color=#FF5722]" + target.name + "[/color]"
			if used_item.heal_amount > 0: 
				item_log += " [color=#4CAF50](+" + str(used_item.heal_amount) + " HP)[/color]"
			if used_item.mana_amount > 0: 
				item_log += " [color=#2196F3](+" + str(used_item.mana_amount) + " MP)[/color]"
			battle_engine.add_to_battle_log(item_log)
			battle_engine.update_party_ui()
			battle_engine.update_effect_ui(target)
		else:
			battle_engine.add_to_battle_log("[color=#F44336]Item use failed![/color]")
		
		await battle_engine.get_tree().create_timer(0.75).timeout

func execute_multi_attack(attacker: Object, target: Object, atk: Skill) -> void:
	var total_dmg = 0
	var total_crits = 0
	var total_misses = 0
	
	var multi_log = "[color=#FFD700]━━━ MULTI-ATTACK ━━━[/color]"
	multi_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.name + "[/color] on [color=#FF5722]" + target.name + "[/color]"
	
	for i in range(atk.hit_count):
		await battle_engine.get_tree().create_timer(0.15).timeout
		
		var crit = randi_range(1, 10 if attacker is Enemy else 8) == 1
		var base = (attacker.damage if attacker is Enemy else attacker.max_stats['atk']) * atk.attack_multiplier * atk.hit_damage_multiplier
		
		var power_mult = battle_engine.get_effect_multiplier(attacker, Global.effect.Power)
		var weak_mult = battle_engine.get_effect_multiplier(attacker, Global.effect.Weak)
		base *= power_mult * weak_mult
		
		if Global.effect.Power in attacker.effects: 
			base *= 2
		base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
		if crit: 
			base *= 1.5
		base += atk.attack_bonus
		
		if battle_engine.check_instakill(attacker, target):
			target.hp = 0
			multi_log += "\nHit " + str(i+1) + ": ★★★ INSTAKILL ★★★"
			await battle_engine.get_tree().create_timer(0.5).timeout
			if attacker is Party and target is Enemy:
				await battle_engine.animate_enemy_death(target)
			battle_engine.death(target)
			battle_engine.add_to_battle_log(multi_log)
			await battle_engine.get_tree().create_timer(1.0).timeout
			return
		
		var hit_result = calculate_hit_damage(attacker, target, base, crit, atk)
		total_dmg += hit_result[0]
		if hit_result[1]: 
			total_crits += 1
		if hit_result[2]: 
			total_misses += 1
		
		multi_log += hit_result[3]
	
	multi_log += "\n[color=#FFFF00]Total: " + str(total_dmg) + " dmg | Crits: " + str(total_crits) + " | Misses: " + str(total_misses) + "[/color]"
	battle_engine.add_to_battle_log(multi_log)
	
	if total_dmg > 0:
		target.hp -= total_dmg
		if attacker is Party and target is Enemy:
			battle_engine.gain_xp(attacker, target, total_dmg)
		battle_engine.apply_effects(target, atk)
		battle_engine.update_effect_ui(target)
	
	await battle_engine.get_tree().create_timer(0.5).timeout

func execute_single_target_attack(attacker: Object, targets: Array, atk: Skill) -> void:
	var target = targets[0] if targets.size() > 0 else null
	if not target:
		return
	
	var crit = randi_range(1, 10 if attacker is Enemy else 8) == 1
	var base = (attacker.damage if attacker is Enemy else attacker.max_stats['atk']) * atk.attack_multiplier
	var power_mult = battle_engine.get_effect_multiplier(attacker, Global.effect.Power)
	var weak_mult = battle_engine.get_effect_multiplier(attacker, Global.effect.Weak)
	base *= power_mult * weak_mult
	
	if Global.effect.Power in attacker.effects: 
		base *= 2
	base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
	if crit: 
		base *= 1.5
	base += atk.attack_bonus
	
	if battle_engine.check_instakill(attacker, target):
		target.hp = 0
		battle_engine.print_outcome(attacker, targets, atk, 0, crit, false, 0, [])
		await battle_engine.get_tree().create_timer(0.5).timeout
		if attacker is Party and target is Enemy:
			await battle_engine.animate_enemy_death(target)
		battle_engine.death(target)
		battle_engine.add_to_battle_log("[color=#FF0000]★★★ INSTAKILL ★★★[/color]")
		await battle_engine.get_tree().create_timer(1.0).timeout
		return
	
	var miss = randi_range(1, 100) > atk.accuracy
	var dmg = 0 if miss else int(base) - (target.defense if target.has_key("defense") else 0)
	dmg = max(0, dmg)
	
	battle_engine.print_outcome(attacker, targets, atk, dmg, crit, miss, 0, [])
	
	if dmg > 0:
		target.hp -= dmg
		if attacker is Party and target is Enemy:
			battle_engine.gain_xp(attacker, target, dmg)
		battle_engine.apply_effects(target, atk)
		battle_engine.update_effect_ui(target)
	
	await battle_engine.get_tree().create_timer(0.5).timeout

func calculate_hit_damage(attacker: Object, target: Object, base: float, crit: bool, atk: Skill) -> Array:
	var miss = randi_range(1, 100) > atk.accuracy
	if miss:
		return [0, false, true, "\n[color=#F44336]Hit missed![/color]"]
	
	var dmg = int(base) - (target.defense if target.has_key("defense") else 0)
	dmg = max(1, dmg)
	
	var result_str = "\n[color=#4CAF50]Hit!"
	if crit: 
		result_str += " [color=#FFD700]CRIT!"
	result_str += " [-color=" + str(dmg) + " HP][/color]"
	
	return [dmg, crit, false, result_str]
