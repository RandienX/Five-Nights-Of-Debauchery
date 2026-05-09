extends Node
class_name AttackExecutor

var root
var root_nodepath
var death_manager
var effect_manager
var log_manager
var battle

var attack_array: Dictionary = {}

func setup(broot, d_mgr, e_mgr, l_mgr, batt):
	root = broot
	root_nodepath = root.get_path()
	death_manager = d_mgr
	effect_manager = e_mgr
	log_manager = l_mgr
	battle = batt

func do_attacks() -> void:
	if death_manager.game_over_active: return
	for actor in root.initiative:
		if attack_array.has(actor) and root:
			root.current_attacker = actor
			await execute_single_attack(actor)
			await death_manager.check_enemy_death_and_xp()
	root.start_round()

# ──────────────────────────────────────────────────────────────────────────────
# Main Entry Point
# ──────────────────────────────────────────────────────────────────────────────

func execute_single_attack(attacker: Object) -> void:
	print("battle_attack_executor.gd: execute_single_attack: START - attacker=%s" % (attacker.name if attacker else "null"))
	if death_manager.game_over_active: 
		print("battle_attack_executor.gd: execute_single_attack: game over active, returning")
		return
	var targets: Array = attack_array[attacker][0]
	var atk: Skill = attack_array[attacker][1]
	
	print("battle_attack_executor.gd: execute_single_attack: target_count=%d, skill=%s" % [targets.size(), atk.skill_name])
	
	# Step 1: Filter alive targets
	var alive: Array = _get_alive_targets(targets)
	print("battle_attack_executor.gd: execute_single_attack: alive_targets=%d" % alive.size())
	
	# Step 2: Handle Check skill (special case)
	if atk.skill_name == "Check ":
		print("battle_attack_executor.gd: execute_single_attack: handling Check skill")
		await _handle_check_skill(attacker, targets)
		return
	
	# Step 3: Ensure valid target for single-target attacks
	if alive.is_empty() and atk.target_type == 0:
		print("battle_attack_executor.gd: execute_single_attack: no alive targets for single-target, assigning random")
		if not _assign_random_target(attacker, atk):
			print("battle_attack_executor.gd: execute_single_attack: failed to assign random target, returning")
			return
		alive = _get_alive_targets(attack_array[attacker][0])
		print("battle_attack_executor.gd: execute_single_attack: new alive count=%d" % alive.size())
		if alive.is_empty():
			print("battle_attack_executor.gd: execute_single_attack: still no alive targets, returning")
			return
	
	# Step 4: Route to appropriate handler based on attack type
	print("battle_attack_executor.gd: execute_single_attack: routing to attack execution")
	await _route_attack_execution(attacker, alive, atk)
	print("battle_attack_executor.gd: execute_single_attack: END")


# ──────────────────────────────────────────────────────────────────────────────
# Attack Routing Logic
# ──────────────────────────────────────────────────────────────────────────────

func _route_attack_execution(attacker: Object, alive: Array, atk: Skill) -> void:
	"""Unified skill execution with comprehensive customization support."""
	print("battle_attack_executor.gd: _route_attack_execution: START - attacker=%s, alive_count=%d, skill=%s" % [attacker.name if attacker else "null", alive.size(), atk.skill_name])
	if death_manager.game_over_active: 
		print("battle_attack_executor.gd: _route_attack_execution: game over active, returning")
		return
	
	# Step 1: Apply on_use effects
	print("battle_attack_executor.gd: _route_attack_execution: applying on_use effects")
	await _apply_on_use_effects(attacker, alive, atk)
	
	# Step 2: Check if this is an item-based skill
	if atk.is_item_skill:
		print("battle_attack_executor.gd: _route_attack_execution: handling item skill")
		await _handle_item_usage(attacker, alive, atk)
	
	# Step 3: Handle non-damaging skills (buffs/debuffs without targeting enemies)
	if atk.target_type in [1, 2]:  # Self or Party
		print("battle_attack_executor.gd: _route_attack_execution: handling support skill, target_type=%d" % atk.target_type)
		await _handle_support_skill(attacker, alive, atk)
		print("battle_attack_executor.gd: _route_attack_execution: support skill complete, returning")
		return
	
	# Step 4: Execute attack logic (single or multi-hit)
	print("battle_attack_executor.gd: _route_attack_execution: executing attack sequence")
	await _execute_attack_sequence(attacker, alive, atk)
	print("battle_attack_executor.gd: _route_attack_execution: END")


# ──────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ──────────────────────────────────────────────────────────────────────────────

func _get_alive_targets(targets: Array) -> Array:
	var alive: Array = []
	for t in targets:
		if t is Entity:
			if t.hp > 0:
				alive.append(t)
	return alive


func _handle_check_skill(attacker: Entity, targets: Array) -> void:
	if death_manager.game_over_active: return
	var desc = "[color=#2196F3]━━━ ENEMY INFO ━━━[/color]"
	if targets.size() > 0 and targets[0].role == Entity.Role.ENEMY:
		var target_enemy = targets[0]
		desc += "\n[color=#FF5722]" + target_enemy.name + "[/color]: " + target_enemy.description
		desc += "\n[color=#4CAF50]HP: " + str(target_enemy.hp) + "/" + str(target_enemy.max_stats["hp"]) + "[/color] [color=#FFC107]ATK: " + str(target_enemy.base_stats["atk"]) + "[/color]"
	log_manager.add_to_battle_log(desc)
	await root.get_tree().create_timer(2.5).timeout


func _assign_random_target(attacker: Entity, atk: Skill) -> bool:
	# For enemies, target party members; for party members, target enemies
	var valid_targets: Array = []
	if attacker.role == Entity.Role.ENEMY:
		valid_targets = root.party.filter(func(p): return p and p.hp > 0)
	else:
		valid_targets = root.get_alive_enemies()
	
	if not valid_targets.is_empty():
		var new_target = [valid_targets[randi_range(0, valid_targets.size()-1)]]
		attack_array[attacker][0] = new_target
		return true
	return false


func _handle_item_usage(attacker: Entity, targets: Array, atk: Skill) -> void:
	if death_manager.game_over_active: return
	var used_item = root.item_manager.item_ref
	print("e")
	if used_item and targets.size() > 0:
		var success = PlayerStats.use_item(used_item, targets)
		
		if success:
			var item_log = "[color=#FFD700]━━━ ITEM ━━━[/color]"
			var targetnames := ""
			for t in range(len(targets)): 
				targetnames += targets[t].name + "\n"
			item_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.skill_name + "[/color] on [color=#FF5722]" + targetnames + "[/color]"
			if used_item.heal_amount > 0:
				item_log += " [color=#4CAF50](+" + str(used_item.heal_amount) + " HP)[/color]"
			if used_item.mana_amount > 0:
				item_log += " [color=#2196F3](+" + str(used_item.mana_amount) + " MP)[/color]"
			log_manager.add_to_battle_log(item_log)
			root.update_party_ui()
			for t in targets:
				effect_manager.status_applied.emit(t, "", 0)
		else:
			log_manager.add_to_battle_log("[color=#F44336]Item use failed![/color]")
		
		await root.get_tree().create_timer(1.25 / Settings.battle_speed).timeout


# ──────────────────────────────────────────────────────────────────────────────
# New Unified Attack Execution System
# ──────────────────────────────────────────────────────────────────────────────

func _apply_on_use_effects(attacker: Object, targets: Array, atk: Skill) -> void:
	"""Apply effects that trigger on skill use (before attack lands) via BattleEffectManager."""
	print("battle_attack_executor.gd: _apply_on_use_effects: START - attacker=%s, skill=%s, on_use_effect_count=%d" % [attacker.name if attacker else "null", atk.skill_name, atk.on_use_effects.size()])
	if not atk.on_use_effects.is_empty():
		for effect in atk.on_use_effects:
			print("battle_attack_executor.gd: _apply_on_use_effects: executing effect=%s" % (effect.effect_name if effect else "null"))
			effect_manager.execute_effect(effect, attacker, {"selected_enemy": targets[0] if targets.size() > 0 else null})
	print("battle_attack_executor.gd: _apply_on_use_effects: END")


func _handle_support_skill(attacker: Entity, alive: Array, atk: Skill) -> void:
	if death_manager.game_over_active: 
		print("battle_attack_executor.gd: _handle_support_skill: game over active, returning")
		return
	print("battle_attack_executor.gd: _handle_support_skill: START - attacker=%s, skill=%s" % [attacker.name, atk.skill_name])
	"""Handle buffs/debuffs and other non-damaging skills via BattleEffectManager."""
	var support_log = "[color=#FFD700]━━━ SKILL ━━━[/color]"

	if atk.target_type == 1:  # Self
		print("battle_attack_executor.gd: _handle_support_skill: target type SELF")
		# Execute on_use effects already handled, now apply on_hit effects for self-buffs
		for effect in atk.on_hit_effects:
			print("battle_attack_executor.gd: _handle_support_skill: applying on_hit effect=%s to self" % (effect.effect_name if effect else "null"))
			effect_manager.execute_effect(effect, attacker, {})
			effect_manager.tick_all_statuses()  # Tick statuses after application
		support_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.skill_name + "[/color] on self"
	elif atk.target_type == 2:  # Party
		print("battle_attack_executor.gd: _handle_support_skill: target type PARTY")
		support_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.skill_name + "[/color] on party"
		for p in root.party:
			if p.hp > 0:
				for effect in atk.on_hit_effects:
					print("battle_attack_executor.gd: _handle_support_skill: applying on_hit effect=%s to party member=%s" % [effect.effect_name if effect else "null", p.name])
					effect_manager.execute_effect(effect, p, {})
					effect_manager.tick_all_statuses()
	
	if atk.mana_cost > 0:
		support_log += " [color=#9C27B0](" + str(atk.mana_cost) + " MP)[/color]"
		print("battle_attack_executor.gd: _handle_support_skill: mana cost=%d" % atk.mana_cost)
	
	log_manager.add_to_battle_log(support_log)
	attacker.mp = max(0, attacker.mp - atk.mana_cost)
	if root:
		await root.get_tree().create_timer(1.0 / Settings.battle_speed).timeout
	print("battle_attack_executor.gd: _handle_support_skill: END")


func _execute_attack_sequence(attacker: Entity, alive: Array, atk: Skill) -> void:
	if death_manager.game_over_active: return
	"""Unified attack execution handling both single and multi-hit attacks."""
	if alive.is_empty():
		return
		
	var attack_log = "[color=#FFD700]━━━ ATTACK ━━━[/color]"

	for e in range(len(alive)):
		var target: Entity = alive[e]
		var total_dmg = 0
		var total_crits = 0
		var total_misses = 0
		var hit_count = max(1, atk.hit_count)
		attack_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.skill_name + "[/color] on [color=#FF5722]" + target.name + "[/color]"
		
		for i in range(hit_count):
			await root.get_tree().create_timer(0.15 / Settings.battle_speed).timeout
			
			# Step 1: Calculate accuracy and determine hit/miss
			var hit_result = _calculate_hit(attacker, target, atk)
			var dmg = hit_result.dmg
			var crit = hit_result.crit
			var hit = hit_result.hit
			
			# Step 2: Check for instakill
			if target.has_status("instakill"):
				target.hp = 0
				attack_log += "\n[color=#FF0000]Hit " + str(i+1) + ": ★★★ INSTAKILL ★★★[/color]"
				await root.get_tree().create_timer(0.25 / Settings.battle_speed).timeout
				if target.role == Entity.Role.ENEMY:
					await death_manager.animate_enemy_death(target)
					death_manager.death(target)
				log_manager.add_to_battle_log(attack_log)
				await root.get_tree().create_timer(0.5 / Settings.battle_speed).timeout
				return
			
			# Step 3: Process hit or miss
			if hit:
				await _process_hit(attacker, target, atk, dmg, crit, attack_log)
				total_dmg += dmg
				if crit:
					total_crits += 1
			else:
				await _process_miss(attacker, target, atk, attack_log, i)
				total_misses += 1
			
			# Deduct mana cost per hit (optional design choice)
			if i == 0:
				attacker.mp = max(0, attacker.mp - atk.mana_cost)
		
		# Step 4: Log final results
		attack_log += "\n[color=#03A9F4]Total: " + str(total_dmg) + " DMG | "
		attack_log += str(hit_count - total_misses) + "/" + str(hit_count) + " hits"
		if total_crits > 0:
			attack_log += " | " + str(total_crits) + " CRITs"
		if atk.mana_cost > 0:
			attack_log += " | " + str(atk.mana_cost) + " MP"
		attack_log += "[/color]"
		
		log_manager.add_to_battle_log(attack_log)
		await root.get_tree().create_timer(1.0 / Settings.battle_speed).timeout
		
		# Step 5: Check for death (enemy)
		if target.hp <= 0:
			if target.role == Entity.Role.ENEMY:
				await root.death_manager.animate_enemy_death(target)
				
	# Step 6: Die
	_cleanup_deaths(attacker, alive)
		

func _process_hit(attacker: Entity, target: Entity, atk: Skill, dmg: int, crit: bool, attack_log: String) -> void:
	if death_manager.game_over_active: return
	"""Process a successful hit: apply damage, effects, and wake from sleep via BattleEffectManager."""

	if root.get_node("AnimationPlayer"):
		root.get_node("AnimationPlayer").play("move_around_screen")
		await root.get_node("AnimationPlayer").animation_finished
	target.hp -= dmg

	# Apply on-hit effects via BattleEffectManager
	for effect in atk.on_hit_effects:
		effect_manager.execute_effect(effect, attacker, {"selected_enemy": target})

	# Check for sleep wake using new status API
	var sleep_stacks = target.get_status_stacks("sleep_debuff")
	if sleep_stacks > 0:
		if sleep_stacks < 1: sleep_stacks = 1
		if randf() < (1.0 - (0.1 * float(sleep_stacks))):
			target.remove_status("sleep_debuff")
			attack_log += "\n[color=#FFD700]" + target.name + " woke up![/color]"
	
	# Update enemy UI
	for i in range(5):
		var e = root.enemies_by_slot[i]
		if e and e.hp > 0:
			var node = get_node_or_null("Control/enemy_ui/enemies/enemy"+str(i+1))
			if node:
				node.hp = max(0, e.hp)


func _process_miss(attacker: Entity, target: Entity, atk: Skill, attack_log: String, hit_index: int) -> void:
	if death_manager.game_over_active: return
	"""Process a missed attack: apply on-miss effects via BattleEffectManager."""
	# Apply on-miss effects if any
	if not atk.on_miss_effects.is_empty():
		for effect in atk.on_miss_effects:
			effect_manager.execute_effect(effect, attacker, {"selected_enemy": target})


func _cleanup_deaths(attacker: Entity, alive: Array) -> void:
	if death_manager.game_over_active: return
	for t in alive:
		if t.hp <= 0:
			death_manager.death(t)
			await root.get_tree().create_timer(0.15 / Settings.battle_speed).timeout


# ──────────────────────────────────────────────────────────────────────────────
# Combat Calculation Helpers
# ──────────────────────────────────────────────────────────────────────────────

func _calculate_hit(attacker: Entity, target: Entity, atk: Skill) -> Dictionary:
	var crit = randi_range(1, 10 if attacker.role == Entity.Role.ENEMY else 8) == 1
	var base = (attacker.get_base_stat(&"atk") if attacker.role == Entity.Role.ENEMY else attacker.get_max_stat(&"atk")) * atk.attack_multiplier * atk.hit_damage_multiplier

	# Get multipliers from status effects using new API
	var power_mult = _get_status_multiplier(attacker, "power", 0.25)
	var weak_mult = _get_status_multiplier(attacker, "weak", -0.25)
	base *= power_mult * weak_mult

	# Check for Power status duration
	if attacker.has_status("power_buff"):
		base *= 2

	base *= randf_range(0.86 if attacker.role == Entity.Role.ENEMY else 0.9, 1.16 if attacker.role == Entity.Role.ENEMY else 1.2)
	if crit:
		base *= 1.5
	base += atk.attack_bonus

	# Defense multipliers from statuses
	var tough_mult = _get_status_multiplier(target, "tough", 0.2)
	var sick_mult = _get_status_multiplier(target, "sick", -0.2)
	var def_stat = target.get_max_stat(&"def") if attacker.role == Entity.Role.ENEMY else target.get_base_stat(&"def") * 2

	# Check for Defend status
	var defend_mult = 1.5 if target.has_status("defend") else 1.0
	var def_mult = clampf(1.0 - (float(def_stat) / (100.0 / (tough_mult * sick_mult))), 0.0, 1.0)
	def_mult /= defend_mult
	def_mult = clampf(def_mult, 0.0, 1.0)

	var dmg = max(0, floor(base * def_mult))

	# Accuracy multipliers from statuses
	var focus_mult = _get_status_multiplier(attacker, "focus", 0.15)
	var blind_mult = _get_status_multiplier(target, "blind", -0.5, true)
	var hit = randf() <= (atk.accuracy * focus_mult * blind_mult)

	return {
			"dmg": dmg,
			"crit": crit,
			"hit": hit
	}

func _get_status_multiplier(entity: Entity, status_id: String, per_stack_value: float, flat: bool = false) -> float:
	"""Get multiplier from a status effect. If flat=true, returns additive value instead."""
	if not entity.has_status(status_id):
		return 1.0 if not flat else 0.0
	var stacks = entity.get_status_stacks(status_id)
	if flat:
		return per_stack_value * stacks
	else:
		return 1.0 + (float(stacks) * per_stack_value)
