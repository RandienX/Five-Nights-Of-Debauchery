class_name BattleAttackExecutor
extends Node

## Executes all battle attacks and damage calculations
## Based on tech_demo1_engine.gd do_attacks() and execute_single_attack() logic

signal attack_started(attacker: Object, attack: Skill)
signal attack_completed(attacker: Object, results: Dictionary)
signal all_attacks_complete()

var battle_root: Node2D = null
var attack_array: Dictionary = {}  # {attacker: [targets, attack]}

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Executes all planned attacks
func do_attacks():
	if not battle_root:
		return
	
	for actor in battle_root.initiative:
		if battle_root.attack_array.has(actor):
			if actor is Party or ("max_stats" in actor):
				battle_root.current_attacker = actor
			await execute_single_attack(actor)
	
	await check_enemy_death_and_xp()
	await get_tree().create_timer(0.5).timeout
	
	if battle_root and battle_root.has_method("start_round"):
		battle_root.start_round()
	
	all_attacks_complete.emit()

## Executes a single attack
func execute_single_attack(attacker: Object):
	var targets = battle_root.attack_array[attacker][0]
	var atk: Skill = battle_root.attack_array[attacker][1]
	
	var alive: Array = []
	for t in targets:
		if t.hp > 0:
			alive.append(t)
	
	attack_started.emit(attacker, atk)
	
	# Handle "Check" skill (enemy info)
	if atk.name == "Check ":
		var desc = "[color=#2196F3]━━━ ENEMY INFO ━━━[/color]"
		if targets.size() > 0 and targets[0] is Enemy:
			var target_enemy = targets[0]
			desc += "\n[color=#FF5722]" + target_enemy.name + "[/color]: " + target_enemy.description
			desc += "\n[color=#4CAF50]HP: " + str(target_enemy.hp) + "/" + str(target_enemy.max_hp) + "[/color] [color=#FFC107]ATK: " + str(target_enemy.damage) + "[/color]"
		add_to_battle_log(desc)
		await get_tree().create_timer(1.5).timeout
		return
	
	# Handle dead targets for single-target attacks
	if alive.is_empty() and atk.target_type == 0:
		var enemies: Array = []
		for e in range(5):
			if battle_root.battle.get('enemy_pos' + str(e + 1)) and battle_root.battle.get('enemy_pos' + str(e + 1)).hp > 0:
				enemies.append(battle_root.battle.get('enemy_pos' + str(e + 1)))
		if not enemies.is_empty():
			alive = [enemies[randi_range(0, enemies.size() - 1)]]
			battle_root.attack_array[attacker][0] = alive
		else:
			return
	
	if alive.is_empty():
		return
	
	# Handle item usage
	if atk.attack_type == 3:
		await execute_item_use(attacker, targets, atk)
		return
	
	# Handle multi-attack skills
	if atk.attack_type == 2 and atk.name != "Check ":
		await execute_multi_attack(attacker, alive, atk)
		return
	
	# Handle single attack
	await execute_standard_attack(attacker, alive, atk)

## Executes item usage
func execute_item_use(attacker: Object, targets: Array, atk: Skill):
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
			add_to_battle_log(item_log)
			update_party_ui()
			update_effect_ui(target)
		else:
			add_to_battle_log("[color=#F44336]Item use failed![/color]")
		
		await get_tree().create_timer(0.75).timeout

## Executes multi-attack skill
func execute_multi_attack(attacker: Object, alive: Array, atk: Skill):
	var total_dmg = 0
	var total_crits = 0
	var total_misses = 0
	var target = alive[0] if alive.size() > 0 else null
	
	if not target:
		return
	
	var multi_log = "[color=#FFD700]━━━ MULTI-ATTACK ━━━[/color]"
	multi_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.name + "[/color] on [color=#FF5722]" + target.name + "[/color]"
	
	for i in range(atk.hit_count):
		await get_tree().create_timer(0.15).timeout
		
		var crit = randi_range(1, 10 if attacker is Enemy else 8) == 1
		var base = (attacker.damage if attacker is Enemy else attacker.max_stats['atk']) * atk.attack_multiplier * atk.hit_damage_multiplier
		
		var power_mult = get_effect_multiplier(attacker, Global.effect.Power)
		var weak_mult = get_effect_multiplier(attacker, Global.effect.Weak)
		base *= power_mult * weak_mult
		
		if Global.effect.Power in attacker.effects:
			base *= 2
		base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
		if crit:
			base *= 1.5
		base += atk.attack_bonus
		
		if check_instakill(attacker, target):
			target.hp = 0
			multi_log += "\n[color=#FF0000]Hit " + str(i + 1) + ": ★★★ INSTAKILL ★★★[/color]"
			await get_tree().create_timer(0.5).timeout
			if (attacker is Party or ("max_stats" in attacker)) and target is Enemy:
				await animate_enemy_death(target)
			death(target)
			add_to_battle_log(multi_log)
			await get_tree().create_timer(1.0).timeout
			return
		
		var miss = randi_range(1, 100) > get_accuracy(attacker, target)
		if miss:
			total_misses += 1
			multi_log += "\n[color=#F44336]Hit " + str(i + 1) + ": Missed[/color]"
		else:
			var dmg = calculate_final_damage(attacker, target, base, atk)
			target.hp = max(0, target.hp - dmg)
			total_dmg += dmg
			if crit:
				total_crits += 1
				multi_log += "\n[color=#FFD700]Hit " + str(i + 1) + ": " + str(dmg) + " CRIT![/color]"
			else:
				multi_log += "\nHit " + str(i + 1) + ": " + str(dmg)
		
		update_effect_ui(target)
	
	multi_log += "\n[color=#FFFFFF]Total: " + str(total_dmg) + " damage[/color]"
	if total_crits > 0:
		multi_log += " [color=#FFD700](" + str(total_crits) + " crits)[/color]"
	if total_misses > 0:
		multi_log += " [color=#F44336](" + str(total_misses) + " misses)[/color]"
	
	add_to_battle_log(multi_log)
	await get_tree().create_timer(0.75).timeout

## Executes standard single attack
func execute_standard_attack(attacker: Object, alive: Array, atk: Skill):
	var target = alive[0] if alive.size() > 0 else null
	if not target:
		return
	
	var crit = randi_range(1, 10 if attacker is Enemy else 8) == 1
	var base = (attacker.damage if attacker is Enemy else attacker.max_stats['atk']) * atk.attack_multiplier
	
	var power_mult = get_effect_multiplier(attacker, Global.effect.Power)
	var weak_mult = get_effect_multiplier(attacker, Global.effect.Weak)
	base *= power_mult * weak_mult
	
	if Global.effect.Power in attacker.effects:
		base *= 2
	base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
	if crit:
		base *= 1.5
	base += atk.attack_bonus
	
	var miss = randi_range(1, 100) > get_accuracy(attacker, target)
	
	var effects_applied: Array = []
	if not miss:
		var dmg = calculate_final_damage(attacker, target, base, atk)
		target.hp = max(0, target.hp - dmg)
		
		if check_instakill(attacker, target):
			target.hp = 0
			await animate_enemy_death(target) if (attacker is Party or ("max_stats" in attacker)) and target is Enemy else null
			death(target)
		
		apply_effects(target, atk)
		for effect in atk.effects.keys():
			effects_applied.append([effect, atk.effects[effect][0]])
		
		update_effect_ui(target)
		print_outcome(attacker, [target], atk, dmg, crit, miss, 0, effects_applied)
	else:
		print_outcome(attacker, [target], atk, 0, false, true, 0, [])
	
	await get_tree().create_timer(0.75).timeout

## Calculates final damage
func calculate_final_damage(attacker: Object, defender: Object, base_dmg: float, atk: Skill) -> int:
	var def_mult = get_effect_multiplier(defender, Global.effect.Tough)
	var sick_mult = get_effect_multiplier(defender, Global.effect.Sick)
	
	var defense = (defender.toughness if defender is Enemy else defender.max_stats['def']) * def_mult * sick_mult
	
	if Global.effect.Tough in defender.effects:
		defense *= 2
	
	var dmg = base_dmg - defense
	dmg = max(1, floor(dmg))
	
	return dmg

## Gets accuracy for an attack
func get_accuracy(attacker: Object, defender: Object) -> int:
	var base_acc = 85
	var blind_mult = get_effect_multiplier(attacker, Global.effect.Blind)
	base_acc = floor(base_acc * blind_mult)
	return base_acc

## Checks for instakill
func check_instakill(attacker: Object, target: Object) -> bool:
	if attacker is Party or ("max_stats" in attacker):
		if Global.effect.Focus in attacker.effects:
			return randi_range(1, 100) <= 30
	return false

## Applies effects from attack
func apply_effects(target: Object, atk: Skill):
	if battle_root and battle_root.has_method("apply_effects"):
		battle_root.apply_effects(target, atk)

## Animates enemy death
func animate_enemy_death(e: Enemy):
	if battle_root and battle_root.has_method("animate_enemy_death"):
		await battle_root.animate_enemy_death(e)

## Handles death
func death(obj):
	if battle_root and battle_root.has_method("death"):
		battle_root.death(obj)

## Checks enemy death and XP
func check_enemy_death_and_xp():
	if not battle_root:
		return
	
	var all_dead = true
	for e in range(5):
		if battle_root.battle.get('enemy_pos' + str(e + 1)) and battle_root.battle.get('enemy_pos' + str(e + 1)).hp > 0:
			all_dead = false
			break
	
	if all_dead:
		var total_xp = 0
		for e in range(5):
			if battle_root.battle.get('enemy_pos' + str(e + 1)):
				total_xp += battle_root.battle.get('enemy_pos' + str(e + 1)).xp_reward
		
		for actor in battle_root.initiative:
			if actor is Party or ("max_stats" in actor):
				actor.xp += total_xp
				var output = battle_root.get_node_or_null("Control/enemy_ui/CenterContainer/output")
				if output:
					output.text = actor.name + " gained " + str(total_xp) + " XP! "
				
				while actor.xp >= actor.xp_to_level_up:
					actor.xp -= actor.xp_to_level_up
					actor.level += 1
					actor.xp_to_level_up = ceil(actor.xp_to_level_up * actor.level_up_xp_multilpier)
					for stat in ["hp", "mp", "atk", "def", "ai"]:
						actor.max_stats[stat] += int(actor.level_up[stat] * actor.level)
						actor.base_stats[stat] += int(actor.level_up[stat] * actor.level)
					actor.hp = actor.max_stats["hp"]
					actor.mp = actor.max_stats["mp"]
					
					if output:
						output.text = actor.name + " leveled up to " + str(actor.level) + "! "
					await get_tree().create_timer(1.0).timeout
		
		if battle_root.has_method("end_battle_victory"):
			await battle_root.end_battle_victory()

## Helper functions
func add_to_battle_log(text: String):
	if battle_root and battle_root.has_method("add_to_battle_log"):
		battle_root.add_to_battle_log(text)

func get_effect_multiplier(target: Object, effect: Global.effect) -> float:
	if battle_root and battle_root.has_method("get_effect_multiplier"):
		return battle_root.get_effect_multiplier(target, effect)
	return 1.0

func update_effect_ui(target: Object):
	if battle_root and battle_root.has_method("update_effect_ui"):
		battle_root.update_effect_ui(target)

func update_party_ui():
	if battle_root and battle_root.has_method("update_party_ui"):
		battle_root.update_party_ui()

func print_outcome(atk: Object, targets: Array, attack: Skill, dmg: int, crit: bool, miss: bool, mp_cost: int = 0, effects_applied: Array = []):
	if battle_root and battle_root.has_method("print_outcome"):
		battle_root.print_outcome(atk, targets, attack, dmg, crit, miss, mp_cost, effects_applied)
