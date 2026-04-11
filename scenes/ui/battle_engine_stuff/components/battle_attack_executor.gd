extends Node
class_name AttackExecutor

var root
var death_manager
var effect_manager
var log_manager
var battle

var attack_array: Dictionary = {}

func setup(broot, d_mgr, e_mgr, l_mgr, batt):
	root = broot
	death_manager = d_mgr
	effect_manager = e_mgr
	log_manager = l_mgr
	battle = batt

func do_attacks() -> void:
	for actor in root.initiative:
		if attack_array.has(actor):
			if actor is Party:
				root.current_attacker = actor
			await execute_single_attack(actor)
	await death_manager.check_enemy_death_and_xp()
	await root.get_tree().create_timer(0.5).timeout
	root.start_round()

func execute_single_attack(attacker: Object) -> void:
	var targets = attack_array[attacker][0]
	var atk: Skill = attack_array[attacker][1]
	var alive: Array = []
	for t in targets:
		if t.hp > 0: alive.append(t)
	
	if atk.name == "Check ":
		var desc = "[color=#2196F3]━━━ ENEMY INFO ━━━[/color]"
		if targets.size() > 0 and targets[0] is Enemy:
			var target_enemy = targets[0]
			desc += "\n[color=#FF5722]" + target_enemy.name + "[/color]: " + target_enemy.description
			desc += "\n[color=#4CAF50]HP: " + str(target_enemy.hp) + "/" + str(target_enemy.max_hp) + "[/color] [color=#FFC107]ATK: " + str(target_enemy.damage) + "[/color]"
		log_manager.add_to_battle_log(desc)
		await root.get_tree().create_timer(1.5).timeout
		return

	if alive.is_empty() and atk.target_type == 0:  
		var enemies: Array = []
		for e in range(5):
			if battle.get('enemy_pos'+str(e+1)) and battle.get('enemy_pos'+str(e+1)).hp > 0:
				enemies.append(battle.get('enemy_pos'+str(e+1)))
		if not enemies.is_empty():
			alive = [enemies[randi_range(0, enemies.size()-1)]]
			attack_array[attacker][0] = alive
		else : return
	if alive.is_empty(): return

	if atk.attack_type == 3:
		var used_item = atk.item_reference
		
		if used_item and targets.size() > 0:
			var target = targets[0]
			var success = Global.use_item(used_item, target)
			
			if success:
				var item_log = "[color=#FFD700]━━━ ITEM ━━━[/color]"
				item_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.name + "[/color] on [color=#FF5722]" + target.name + "[/color]"
				if used_item.heal_amount > 0: item_log += " [color=#4CAF50](+" + str(used_item.heal_amount) + " HP)[/color]"
				if used_item.mana_amount > 0: item_log += " [color=#2196F3](+" + str(used_item.mana_amount) + " MP)[/color]"
				log_manager.add_to_battle_log(item_log)
				root.update_party_ui()
				effect_manager.update_effect_ui(target)
			else:
				log_manager.add_to_battle_log("[color=#F44336]Item use failed![/color]")
			
			await root.get_tree().create_timer(0.75).timeout
			return

	if alive.is_empty() and atk.target_type == 0:
		var enemies: Array = []
		for e in range(5):
			if battle.get('enemy_pos'+str(e+1)) and battle.get('enemy_pos'+str(e+1)).hp > 0:
				enemies.append(battle.get('enemy_pos'+str(e+1)))
		if not enemies.is_empty():
			alive = [enemies[randi_range(0, enemies.size()-1)]]
			attack_array[attacker][0] = alive
		else : return
	if alive.is_empty(): return

	if atk.attack_type == 2 and atk.name != "Check ":
		var total_dmg = 0
		var total_crits = 0
		var total_misses = 0
		var target = alive[0] if alive.size() > 0 else null
		if not target: return
		
		var multi_log = "[color=#FFD700]━━━ MULTI-ATTACK ━━━[/color]"
		multi_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.name + "[/color] on [color=#FF5722]" + target.name + "[/color]"
		
		for i in range(atk.hit_count):
			await root.get_tree().create_timer(0.15).timeout
			
			var crit = randi_range(1, 10 if attacker is Enemy else 8) == 1
			var base = (attacker.damage if attacker is Enemy else attacker.max_stats['atk']) * atk.attack_multiplier * atk.hit_damage_multiplier
			
			var power_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Power)
			var weak_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Weak)
			base *= power_mult * weak_mult
			
			if Global.effect.Power in attacker.effects: base *= 2
			base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
			if crit: base *= 1.5
			base += atk.attack_bonus
			
			if effect_manager.check_instakill(attacker, target):
				target.hp = 0
				multi_log += "\n[color=#FF0000]Hit " + str(i+1) + ": ★★★ INSTAKILL ★★★[/color]"
				await root.get_tree().create_timer(0.5).timeout
				if attacker is Party and target is Enemy:
					await death_manager.animate_enemy_death(target)
				death_manager.death(target)
				log_manager.add_to_battle_log(multi_log)
				await root.get_tree().create_timer(1.0).timeout
				return
			
			var tough_mult = effect_manager.get_effect_multiplier(target, Global.effect.Tough)
			var sick_mult = effect_manager.get_effect_multiplier(target, Global.effect.Sick)
			var def_stat = target.max_stats["def"] if attacker is Enemy else target.defense * 2
			var defend_mult = 1.5 if Global.effect.Defend in target.effects else 1.0
			var def_mult = clampf(1.0 - (float(def_stat) / (100.0 / (tough_mult * sick_mult))), 0.0, 1.0)
			def_mult /= defend_mult
			def_mult = clampf(def_mult, 0.0, 1.0)
			
			var dmg = max(0, floor(base * def_mult))
			
			var focus_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Focus)
			var blind_mult = effect_manager.get_effect_multiplier(target, Global.effect.Blind)
			var hit = randf() <= (atk.accuracy * focus_mult * blind_mult)
			
			if hit:
				root.get_node("AnimationPlayer").play("move_around_screen")
				await root.get_node("AnimationPlayer").animation_finished
				target.hp -= dmg
				total_dmg += dmg
				if crit: total_crits += 1
				
				var hit_color = "#FF0000" if crit else "#FFFFFF"
				multi_log += "\n[color=" + hit_color + "]Hit " + str(i+1) + ": " + str(dmg) + " DMG"
				if crit: multi_log += " ★CRIT★"
				multi_log += "[/color]"
				
				if target.effects.has(Global.effect.Sleep):
					var sleep_level = target.effects[Global.effect.Sleep][0]
					if randf() < (1.0 - (0.1 * sleep_level)):
						effect_manager.remove_effect(target, Global.effect.Sleep)
						multi_log += "\n[color=#FFD700]" + target.name + " woke up![/color]"
				
				for e in range(5):
					var node = get_node_or_null("Control/enemy_ui/enemies/enemy"+str(e+1))
					if node and battle.get('enemy_pos'+str(e+1)):
						node.hp = max(0, battle.get('enemy_pos'+str(e+1)).hp)
			else:
				total_misses += 1
				multi_log += "\n[color=#FF9800]Hit " + str(i+1) + ": MISSED[/color]"
		
		attacker.mp = max(0, attacker.mp - atk.mana_cost)
		
		multi_log += "\n[color=#03A9F4]Total: " + str(total_dmg) + " DMG | "
		multi_log += str(atk.hit_count - total_misses) + "/" + str(atk.hit_count) + " hits"
		if total_crits > 0: multi_log += " | " + str(total_crits) + " CRITs"
		if atk.mana_cost > 0: multi_log += " | " + str(atk.mana_cost) + " MP"
		multi_log += "[/color]"
		
		log_manager.add_to_battle_log(multi_log)
		await root.get_tree().create_timer(1.5).timeout
		
		if target.hp <= 0:
			if attacker is Party and target is Enemy:
				await death_manager.animate_enemy_death(target)
			death_manager.death(target)
		return

	if atk.attack_type == 0 and atk.target_type == 0:
		var target = alive[0]
		var crit = randi_range(1, 10 if attacker is Enemy else 8) == 1
		var base = (attacker.damage if attacker is Enemy else attacker.max_stats['atk']) * atk.attack_multiplier
		
		var power_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Power)
		var weak_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Weak)
		base *= power_mult * weak_mult
		
		if Global.effect.Power in attacker.effects: base *= 2
		base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
		if crit: base *= 1.5
		base += atk.attack_bonus
		
		var was_instakill = false
		if effect_manager.check_instakill(attacker, target):
			target.hp = 0
			attacker.mp = max(0, attacker.mp - atk.mana_cost)
			was_instakill = true
			if attacker is Party and target is Enemy:
				await death_manager.animate_enemy_death(target)
			death_manager.death(target)
		
		var tough_mult = effect_manager.get_effect_multiplier(target, Global.effect.Tough)
		var sick_mult = effect_manager.get_effect_multiplier(target, Global.effect.Sick)
		var def_stat = target.max_stats["def"] if attacker is Enemy else target.defense * 2
		var defend_mult = 1.5 if Global.effect.Defend in target.effects else 1.0
		var def_mult = clampf(1.0 - (float(def_stat) / (100.0 / (tough_mult * sick_mult))), 0.0, 1.0)
		def_mult /= defend_mult
		def_mult = clampf(def_mult, 0.0, 1.0)
		
		var dmg = max(0, floor(base * def_mult))
		
		var focus_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Focus)
		var blind_mult = effect_manager.get_effect_multiplier(target, Global.effect.Blind)
		var hit = randf() <= (atk.accuracy * focus_mult * blind_mult)
		
		var effects_applied: Array = []
		if hit and not was_instakill:
			root.get_node("AnimationPlayer").play("move_around_screen")
			target.hp -= dmg
			effect_manager.apply_effects(target, atk)
			
			if atk.effects:
				for effect in atk.effects.keys():
					var level = atk.effects[effect][0]
					var duration = atk.effects[effect][1]
					effects_applied.append([effect, level])
			
			if target.effects.has(Global.effect.Sleep):
				var sleep_level = target.effects[Global.effect.Sleep][0]
				if randf() < (1.0 - (0.1 * sleep_level)):
					effect_manager.remove_effect(target, Global.effect.Sleep)
			
			if attacker is Party and target is Enemy and target.hp <= 0:
				await death_manager.animate_enemy_death(target)
		
		attacker.mp = max(0, attacker.mp - atk.mana_cost)
		if not was_instakill:
			log_manager.print_outcome(attacker, [target], atk, dmg, crit, not hit, atk.mana_cost, effects_applied)
		else:
			log_manager.add_to_battle_log("[color=#FF0000]" + attacker.name + " used " + atk.name + ": ★★★ INSTAKILL ★★★[/color]")

	elif atk.attack_type == 1:
		var buff_log = "[color=#FFD700]━━━ BUFF ━━━[/color]"
		var effects_applied: Array = []
		
		if atk.target_type == 1:
			effect_manager.apply_effects(attacker, atk)
			effect_manager.update_effect_ui(attacker)
			buff_log += "\n[color=#4CAF50]" + attacker.name + "[/color] buffed self"
			if atk.effects:
				for effect in atk.effects.keys():
					var level = atk.effects[effect][0]
					var duration = atk.effects[effect][1]
					effects_applied.append([effect, level])
					buff_log += " [color=#E91E63]" + effect_manager.get_effect_name_with_level(effect, level) + " (" + str(duration) + "t)[/color]"
			if atk.mana_cost > 0: buff_log += " [color=#9C27B0](" + str(atk.mana_cost) + " MP)[/color]"
			log_manager.add_to_battle_log(buff_log)
			
		elif atk.target_type == 2:
			buff_log += "\n[color=#4CAF50]" + attacker.name + "[/color] buffed party"
			for p in root.party:
				if p.hp > 0:
					effect_manager.apply_effects(p, atk)
					effect_manager.update_effect_ui(p)
			if atk.effects:
				for effect in atk.effects.keys():
					var level = atk.effects[effect][0]
					var duration = atk.effects[effect][1]
					if not effects_applied.any(func(e): return e[0] == effect):
						effects_applied.append([effect, level])
					buff_log += " [color=#E91E63]" + effect_manager.get_effect_name_with_level(effect, level) + " (" + str(duration) + "t)[/color]"
			if atk.mana_cost > 0: buff_log += " [color=#9C27B0](" + str(atk.mana_cost) + " MP)[/color]"
			log_manager.add_to_battle_log(buff_log)

	for t in alive:
		if t.hp <= 0:
			death_manager.death(t)
	await root.get_tree().create_timer(0.5).timeout
