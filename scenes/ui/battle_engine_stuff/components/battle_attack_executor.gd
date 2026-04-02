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

## Calculates basic attack damage
func calculate_damage(attacker: BattleTypes.BattleActor, defender: BattleTypes.BattleActor) -> Dictionary:
	var base_damage = attacker.attack
	var defense = defender.defense
	
	# Apply status effect modifiers
	if effect_manager:
		base_damage = effect_manager.apply_stat_modifiers(attacker, base_damage, Global.effect.Power)
		defense = effect_manager.apply_stat_modifiers(defender, defense, Global.effect.Tough)
	
	# Calculate final damage (minimum 1)
	var actual_damage = max(1, base_damage - defense)
	
	# Critical hit chance (simple 10% for now)
	var is_critical = randf() < 0.1
	if is_critical:
		actual_damage = int(actual_damage * 1.5)
	
	# Instakill check (very rare)
	var is_instakill = randf() < 0.01
	
	return {
		"damage": actual_damage,
		"is_critical": is_critical,
		"is_instakill": is_instakill
	}

## Calculates skill damage
func calculate_skill_damage(attacker: BattleTypes.BattleActor, defender: BattleTypes.BattleActor, skill: Resource) -> Dictionary:
	if not skill:
		return calculate_damage(attacker, defender)
	
	var base_damage = skill.damage if skill.has_method("get_damage") or "damage" in skill else attacker.attack
	var defense = defender.defense
	
	# Apply skill multiplier if exists
	var multiplier = skill.damage_multiplier if "damage_multiplier" in skill else 1.0
	base_damage = int(base_damage * multiplier)
	
	# Apply status effects
	if effect_manager:
		base_damage = effect_manager.apply_stat_modifiers(attacker, base_damage, Global.effect.Power)
		defense = effect_manager.apply_stat_modifiers(defender, defense, Global.effect.Tough)
	
	var actual_damage = max(1, base_damage - defense)
	
	# Skills can crit too
	var is_critical = randf() < (skill.crit_rate if "crit_rate" in skill else 0.1)
	if is_critical:
		actual_damage = int(actual_damage * 1.5)
	
	return {
		"damage": actual_damage,
		"is_critical": is_critical,
		"is_instakill": false,
		"skill_effects": skill.effects if "effects" in skill else []
	}
