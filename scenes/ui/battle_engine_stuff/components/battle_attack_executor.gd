class_name BattleAttackExecutor
extends Node

## Handles attack execution, damage calculation for BattleActor objects

signal attack_started(attacker: BattleTypes.BattleActor, target: BattleTypes.BattleActor)
signal damage_dealt(target: BattleTypes.BattleActor, damage: int, is_critical: bool)
signal attack_completed()

var battle_root: Node2D = null
var effect_manager: BattleEffectManager = null
var logger: BattleLogger = null

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root
	# Get references from parent
	effect_manager = root.effect_manager if root.has_node("BattleEffectManager") else null
	logger = root.logger if root.has_node("BattleLogger") else null

## Executes a basic attack
func execute_attack(attacker: BattleTypes.BattleActor, target: BattleTypes.BattleActor, is_multi: bool = false) -> Dictionary:
	attack_started.emit(attacker, target)
	
	var result = calculate_damage(attacker, target)
	
	# Apply damage to target's resource
	if target and not target.is_dead:
		target.take_damage(result.damage)
		damage_dealt.emit(target, result.damage, result.is_critical)
		
		# Log the attack
		if logger:
			logger.add_damage_message(attacker.name, target.name, result.damage, result.is_critical)
	
	# Handle instakill (non-boss only - check via resource if Enemy)
	if result.is_instakill:
		var enemy_res = target.resource as Enemy
		if not enemy_res or not enemy_res.has_meta("is_boss"): # Simple boss check
			target.take_damage(99999) # Massive damage to ensure death
	
	attack_completed.emit()
	return result

## Executes a skill attack
func execute_skill(attacker: BattleTypes.BattleActor, target: BattleTypes.BattleActor, skill: Resource) -> Dictionary:
	attack_started.emit(attacker, target)
	
	var result = calculate_skill_damage(attacker, target, skill)
	
	# Apply damage
	if target and not target.is_dead:
		target.take_damage(result.damage)
		damage_dealt.emit(target, result.damage, result.is_critical)
		
		# Log the attack
		if logger:
			var skill_name = ""
			if skill and skill.has_method("get_skill_name"):
				skill_name = skill.call("get_skill_name")
			elif skill and "skill_name" in skill:
				skill_name = skill.skill_name
			
			if skill_name != "":
				logger.add_damage_message(attacker.name, target.name, result.damage, result.is_critical, skill_name)
			else:
				logger.add_damage_message(attacker.name, target.name, result.damage, result.is_critical)
	
	attack_completed.emit()
	return result

## Calculates basic attack damage (matches old engine logic)
func calculate_damage(attacker: BattleTypes.BattleActor, defender: BattleTypes.BattleActor) -> Dictionary:
	var base_damage = attacker.attack
	
	# Apply status effect modifiers
	if effect_manager:
		var power_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Power)
		var weak_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Weak)
		base_damage *= power_mult * weak_mult
		
		# Double damage if Power effect is active
		if effect_manager.has_effect(attacker, str(Global.effect.Power)):
			base_damage *= 2
	
	# Random variance (like old engine: 0.86-1.16 for enemies, 0.9-1.2 for party)
	var variance_min = 0.86 if attacker.is_enemy else 0.9
	var variance_max = 1.16 if attacker.is_enemy else 1.2
	base_damage *= randf_range(variance_min, variance_max)
	
	# Critical hit chance (1 in 10 for enemies, 1 in 8 for party)
	var crit_chance = 10 if attacker.is_enemy else 8
	var is_critical = randi_range(1, crit_chance) == 1
	if is_critical:
		base_damage *= 1.5
	
	# Instakill check (Kill effect)
	var is_instakill = false
	if effect_manager:
		var kill_level = effect_manager.get_effect_level(attacker, Global.effect.Kill)
		if kill_level > 0:
			# Bosses immune to instakill
			var enemy_res = defender.resource as Enemy
			if not enemy_res or not ("is_boss" in enemy_res and enemy_res.is_boss):
				var kill_chance = 0.01 * kill_level
				if randf() < kill_chance:
					is_instakill = true
	
	# Calculate defense reduction
	var defense = defender.defense
	if effect_manager:
		var tough_mult = effect_manager.get_effect_multiplier(defender, Global.effect.Tough)
		var sick_mult = effect_manager.get_effect_multiplier(defender, Global.effect.Sick)
		defense *= tough_mult * sick_mult
	
	# Defend multiplier
	var defend_mult = 1.5 if effect_manager.has_effect(defender, str(Global.effect.Defend)) else 1.0
	
	# Defense formula from old engine
	var def_mult = clampf(1.0 - (float(defense) / (100.0)), 0.0, 1.0)
	def_mult /= defend_mult
	def_mult = clampf(def_mult, 0.0, 1.0)
	
	var actual_damage = max(0, floor(base_damage * def_mult))
	
	# Accuracy check
	var accuracy = 1.0
	if effect_manager:
		var focus_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Focus)
		var blind_mult = effect_manager.get_effect_multiplier(defender, Global.effect.Blind)
		accuracy = focus_mult * blind_mult
	
	var hit = randf() <= accuracy
	
	return {
		"damage": actual_damage if hit else 0,
		"is_critical": is_critical,
		"is_instakill": is_instakill,
		"hit": hit
	}

## Calculates skill damage (matches old engine logic)
func calculate_skill_damage(attacker: BattleTypes.BattleActor, defender: BattleTypes.BattleActor, skill: Resource) -> Dictionary:
	if not skill:
		return calculate_damage(attacker, defender)
	
	var base_damage = attacker.attack
	
	# Get skill properties
	var attack_multiplier = skill.attack_multiplier if "attack_multiplier" in skill else 1.0
	var attack_bonus = skill.attack_bonus if "attack_bonus" in skill else 0
	var hit_count = skill.hit_count if "hit_count" in skill else 1
	var hit_damage_multiplier = skill.hit_damage_multiplier if "hit_damage_multiplier" in skill else 1.0
	var accuracy = skill.accuracy if "accuracy" in skill else 1.0
	var mana_cost = skill.mana_cost if "mana_cost" in skill else 0
	
	base_damage *= attack_multiplier
	
	# Apply status effect modifiers
	if effect_manager:
		var power_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Power)
		var weak_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Weak)
		base_damage *= power_mult * weak_mult
		
		# Double damage if Power effect is active
		if effect_manager.has_effect(attacker, str(Global.effect.Power)):
			base_damage *= 2
	
	# Random variance
	var variance_min = 0.86 if attacker.is_enemy else 0.9
	var variance_max = 1.16 if attacker.is_enemy else 1.2
	base_damage *= randf_range(variance_min, variance_max)
	
	# Critical hit chance
	var crit_chance = 10 if attacker.is_enemy else 8
	var is_critical = randi_range(1, crit_chance) == 1
	if is_critical:
		base_damage *= 1.5
	
	base_damage += attack_bonus
	
	# Instakill check
	var is_instakill = false
	if effect_manager:
		var kill_level = effect_manager.get_effect_level(attacker, Global.effect.Kill)
		if kill_level > 0:
			var enemy_res = defender.resource as Enemy
			if not enemy_res or not ("is_boss" in enemy_res and enemy_res.is_boss):
				var kill_chance = 0.01 * kill_level
				if randf() < kill_chance:
					is_instakill = true
	
	# Calculate defense reduction
	var defense = defender.defense
	if effect_manager:
		var tough_mult = effect_manager.get_effect_multiplier(defender, Global.effect.Tough)
		var sick_mult = effect_manager.get_effect_multiplier(defender, Global.effect.Sick)
		defense *= tough_mult * sick_mult
	
	# Defend multiplier
	var defend_mult = 1.5 if effect_manager.has_effect(defender, str(Global.effect.Defend)) else 1.0
	
	# Defense formula from old engine
	var def_mult = clampf(1.0 - (float(defense) / (100.0)), 0.0, 1.0)
	def_mult /= defend_mult
	def_mult = clampf(def_mult, 0.0, 1.0)
	
	var actual_damage = max(0, floor(base_damage * def_mult))
	
	# Accuracy check with Focus/Blind modifiers
	var final_accuracy = accuracy
	if effect_manager:
		var focus_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Focus)
		var blind_mult = effect_manager.get_effect_multiplier(defender, Global.effect.Blind)
		final_accuracy *= focus_mult * blind_mult
	
	var hit = randf() <= final_accuracy
	
	return {
		"damage": actual_damage if hit else 0,
		"is_critical": is_critical,
		"is_instakill": is_instakill,
		"hit": hit,
		"hit_count": hit_count,
		"hit_damage_multiplier": hit_damage_multiplier,
		"skill_effects": skill.effects if "effects" in skill else []
	}
