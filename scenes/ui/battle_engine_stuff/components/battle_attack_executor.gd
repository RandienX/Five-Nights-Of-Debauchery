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
	for actor in root.initiative:
		if attack_array.has(actor):
			root.current_attacker = actor
			await execute_single_attack(actor)
			await death_manager.check_enemy_death_and_xp()
	root.start_round()

# ──────────────────────────────────────────────────────────────────────────────
# Main Entry Point
# ──────────────────────────────────────────────────────────────────────────────

func execute_single_attack(attacker: Object) -> void:
	var targets: Array = attack_array[attacker][0]
	var atk: Skill = attack_array[attacker][1]
	
	# Step 1: Filter alive targets
	var alive: Array = _get_alive_targets(targets)
	
	# Step 2: Handle Check skill (special case)
	if atk.skill_name == "Check ":
		await _handle_check_skill(attacker, targets)
		return
	
	# Step 3: Ensure valid target for single-target attacks
	if alive.is_empty() and atk.target_type == 0:
		if not _assign_random_target(attacker, atk):
			return
		alive = _get_alive_targets(attack_array[attacker][0])
		if alive.is_empty():
			return
	
	# Step 4: Route to appropriate handler based on attack type
	await _route_attack_execution(attacker, alive, atk)


# ──────────────────────────────────────────────────────────────────────────────
# Attack Routing Logic
# ──────────────────────────────────────────────────────────────────────────────

func _route_attack_execution(attacker: Object, alive: Array, atk: Skill) -> void:
	"""Unified skill execution with comprehensive customization support."""
	
	# Step 1: Apply on_use effects
	await _apply_on_use_effects(attacker, alive, atk)
	
	# Step 2: Check if this is an item-based skill
	if atk.is_item_skill:
		await _handle_item_usage(attacker, alive, atk)
	
	# Step 3: Handle non-damaging skills (buffs/debuffs without targeting enemies)
	if atk.target_type in [1, 2]:  # Self or Party
		await _handle_support_skill(attacker, alive, atk)
		return
	
	# Step 4: Execute attack logic (single or multi-hit)
	await _execute_attack_sequence(attacker, alive, atk)


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
	var desc = "[color=#2196F3]━━━ ENEMY INFO ━━━[/color]"
	if targets.size() > 0 and targets[0].role == Entity.Role.ENEMY:
		var target_enemy = targets[0]
		desc += "\n[color=#FF5722]" + target_enemy.name + "[/color]: " + target_enemy.description
		desc += "\n[color=#4CAF50]HP: " + str(target_enemy.hp) + "/" + str(target_enemy.max_stats["hp"]) + "[/color] [color=#FFC107]ATK: " + str(target_enemy.base_stats["atk"]) + "[/color]"
	log_manager.add_to_battle_log(desc)
	await root.get_tree().create_timer(2.5).timeout


func _assign_random_target(attacker: Entity, atk: Skill) -> bool:
	var enemies: Array = root.get_alive_enemies()
	if not enemies.is_empty():
		var new_target = [enemies[randi_range(0, enemies.size()-1)]]
		attack_array[attacker][0] = new_target
		return true
	return false


func _handle_item_usage(attacker: Entity, targets: Array, atk: Skill) -> void:
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
				effect_manager.update_effect_ui(t)
		else:
			log_manager.add_to_battle_log("[color=#F44336]Item use failed![/color]")
		
		await root.get_tree().create_timer(0.75).timeout


# ──────────────────────────────────────────────────────────────────────────────
# New Unified Attack Execution System
# ──────────────────────────────────────────────────────────────────────────────

func _apply_on_use_effects(attacker: Object, targets: Array, atk: Skill) -> void:
	"""Apply effects that trigger on skill use (before attack lands)."""
	if not atk.on_use_effects.is_empty():
		for effect in atk.on_use_effects:
			effect.execute(attacker, targets, root.enemy_instances, {"battle_root": root})


func _handle_support_skill(attacker: Entity, alive: Array, atk: Skill) -> void:
	"""Handle buffs/debuffs and other non-damaging skills."""
	var support_log = "[color=#FFD700]━━━ SKILL ━━━[/color]"
	
	if atk.target_type == 1:  # Self
		effect_manager.apply_effects(attacker, atk)
		effect_manager.update_effect_ui(attacker)
		support_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.skill_name + "[/color] on self"
	elif atk.target_type == 2:  # Party
		support_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.skill_name + "[/color] on party"
		for p in root.party:
			if p.hp > 0:
				effect_manager.apply_effects(p, atk)
				effect_manager.update_effect_ui(p)
	
	if atk.mana_cost > 0:
		support_log += " [color=#9C27B0](" + str(atk.mana_cost) + " MP)[/color]"
	
	log_manager.add_to_battle_log(support_log)
	attacker.mp = max(0, attacker.mp - atk.mana_cost)
	await root.get_tree().create_timer(1.0).timeout


func _execute_attack_sequence(attacker: Entity, alive: Array, atk: Skill) -> void:
	"""Unified attack execution handling both single and multi-hit attacks."""
	if alive.is_empty():
		return
		
	var attack_log = "[color=#FFD700]━━━ ATTACK ━━━[/color]"

	for e in range(len(alive)):
		var target = alive[e]
		var total_dmg = 0
		var total_crits = 0
		var total_misses = 0
		var hit_count = max(1, atk.hit_count)
		attack_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.skill_name + "[/color] on [color=#FF5722]" + target.name + "[/color]"
		
		for i in range(hit_count):
			await root.get_tree().create_timer(0.15).timeout
			
			# Step 1: Calculate accuracy and determine hit/miss
			var hit_result = _calculate_hit(attacker, target, atk)
			var dmg = hit_result.dmg
			var crit = hit_result.crit
			var hit = hit_result.hit
			
			# Step 2: Check for instakill
			if effect_manager.check_instakill(attacker, target):
				target.hp = 0
				attack_log += "\n[color=#FF0000]Hit " + str(i+1) + ": ★★★ INSTAKILL ★★★[/color]"
				await root.get_tree().create_timer(0.5).timeout
				if target.role == Entity.Role.ENEMY:
					await death_manager.animate_enemy_death(target)
					death_manager.death(target)
				log_manager.add_to_battle_log(attack_log)
				await root.get_tree().create_timer(1.0).timeout
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
		await root.get_tree().create_timer(0.5).timeout
		
		# Step 5: Check for death (enemy)
		if target.hp <= 0:
			if target.role == Entity.Role.ENEMY:
				await root.death_manager.animate_enemy_death(target)
				
	# Step 6: Die
	_cleanup_deaths(attacker, alive)
		

func _process_hit(attacker: Entity, target: Entity, atk: Skill, dmg: int, crit: bool, attack_log: String) -> void:
	"""Process a successful hit: apply damage, effects, and wake from sleep."""
	
	if root.get_node("AnimationPlayer"):
		root.get_node("AnimationPlayer").play("move_around_screen")
		await root.get_node("AnimationPlayer").animation_finished
	target.hp -= dmg
	
	# Apply on-hit effects
	effect_manager.apply_effects(target, atk)
	
	# Check for sleep wake
	if target.effects.has(BattleEffect.StatusEffect.Sleep):
		var sleep_level = target.effects[BattleEffect.StatusEffect.Sleep][0]
		if randf() < (1.0 - (0.1 * sleep_level)):
			effect_manager.remove_effect(target, BattleEffect.StatusEffect.Sleep)
			attack_log += "\n[color=#FFD700]" + target.name + " woke up![/color]"
	
	# Update enemy UI
	for i in range(5):
		var e = root.enemies_by_slot[i]
		if e and e.hp > 0:
			var node = get_node_or_null("Control/enemy_ui/enemies/enemy"+str(i+1))
			if node:
				node.hp = max(0, e.hp)


func _process_miss(attacker: Entity, target: Entity, atk: Skill, attack_log: String, hit_index: int) -> void:
	"""Process a missed attack: apply on-miss effects."""
	# Apply on-miss effects if any
	if not atk.on_miss_effects.is_empty():
		for effect in atk.on_miss_effects:
			effect.execute(attacker, [target], root.enemy_instances, {"battle_root": root})

func _cleanup_deaths(attacker: Entity, alive: Array) -> void:
	for t in alive:
		if t.hp <= 0:
			death_manager.death(t)
			await root.get_tree().create_timer(0.5).timeout


# ──────────────────────────────────────────────────────────────────────────────
# Combat Calculation Helpers
# ──────────────────────────────────────────────────────────────────────────────

func _calculate_hit(attacker: Entity, target: Entity, atk: Skill) -> Dictionary:
	var crit = randi_range(1, 10 if attacker.role == Entity.Role.ENEMY else 8) == 1
	var base = (attacker.base_stats["atk"] if attacker.role == Entity.Role.ENEMY else attacker.max_stats["atk"]) * atk.attack_multiplier * atk.hit_damage_multiplier
	
	var power_mult = effect_manager.get_effect_multiplier(attacker, BattleEffect.StatusEffect.Power)
	var weak_mult = effect_manager.get_effect_multiplier(attacker, BattleEffect.StatusEffect.Weak)
	base *= power_mult * weak_mult
	
	if BattleEffect.StatusEffect.Power in attacker.effects:
		base *= 2
	base *= randf_range(0.86 if attacker.role == Entity.Role.ENEMY else 0.9, 1.16 if attacker.role == Entity.Role.ENEMY else 1.2)
	if crit:
		base *= 1.5
	base += atk.attack_bonus
	
	var tough_mult = effect_manager.get_effect_multiplier(target, BattleEffect.StatusEffect.Tough)
	var sick_mult = effect_manager.get_effect_multiplier(target, BattleEffect.StatusEffect.Sick)
	var def_stat = target.max_stats["def"] if attacker.role == Entity.Role.ENEMY else target.base_stats["def"] * 2
	var defend_mult = 1.5 if BattleEffect.StatusEffect.Defend in target.effects else 1.0
	var def_mult = clampf(1.0 - (float(def_stat) / (100.0 / (tough_mult * sick_mult))), 0.0, 1.0)
	def_mult /= defend_mult
	def_mult = clampf(def_mult, 0.0, 1.0)
	
	var dmg = max(0, floor(base * def_mult))
	
	var focus_mult = effect_manager.get_effect_multiplier(attacker, BattleEffect.StatusEffect.Focus)
	var blind_mult = effect_manager.get_effect_multiplier(target, BattleEffect.StatusEffect.Blind)
	var hit = randf() <= (atk.accuracy * focus_mult * blind_mult)
	
	return {
		"dmg": dmg,
		"crit": crit,
		"hit": hit
	}
