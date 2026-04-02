class_name BattleAttackExecutor
extends Node

## Handles attack execution, damage calculation, and animations

signal attack_started(attacker: Node2D, target: Node2D)
signal damage_dealt(target: Node2D, damage: int, is_critical: bool)
signal attack_completed()

var battle_root: Node2D = null
var effect_manager: BattleEffectManager = null
var logger: BattleLogger = null

func _ready():
	pass

func init_manager(root: Node2D, effects: BattleEffectManager, log: BattleLogger):
	battle_root = root
	effect_manager = effects
	logger = log

## Executes a basic attack
func execute_attack(attacker: Node2D, target: Node2D, is_multi: bool = false) -> Dictionary:
	attack_started.emit(attacker, target)
	
	var result = calculate_damage(attacker, target)
	
	# Apply damage
	if is_instance_valid(target) and not target.is_dead():
		target.take_damage(result.damage)
		damage_dealt.emit(target, result.damage, result.is_critical)
		
		# Log the attack
		if logger:
			var attacker_name = attacker.get_character_name() if attacker.has_method("get_character_name") else "Unknown"
			var target_name = target.get_character_name() if target.has_method("get_character_name") else "Unknown"
			logger.add_damage_message(attacker_name, target_name, result.damage, result.is_critical)
	
	# Handle instakill (non-boss only)
	if result.is_instakill and not target.is_boss():
		target.take_damage(99999) # Massive damage to ensure death
	
	attack_completed.emit()
	return result

## Executes a skill attack
func execute_skill(attacker: Node2D, target: Node2D, skill_data: Dictionary) -> Dictionary:
	attack_started.emit(attacker, target)
	
	var result = calculate_skill_damage(attacker, target, skill_data)
	
	# Apply damage
	if is_instance_valid(target) and not target.is_dead():
		target.take_damage(result.damage)
		damage_dealt.emit(target, result.damage, result.is_critical)
		
		# Log the attack
		if logger:
			var attacker_name = attacker.get_character_name() if attacker.has_method("get_character_name") else "Unknown"
			var target_name = target.get_character_name() if target.has_method("get_character_name") else "Unknown"
			logger.add_message("%s uses %s on %s for [color=#FF6B6B]%d[/color] damage" % [attacker_name, skill_data.name, target_name, result.damage])
	
	# Apply additional effects from skill
	if skill_data.has("effects") and result.success:
		for effect_data in skill_data.effects:
			apply_skill_effect(target, effect_data)
	
	attack_completed.emit()
	return result

## Calculates basic attack damage
func calculate_damage(attacker: Node2D, defender: Node2D) -> Dictionary:
	var atk = attacker.get_stat("atk") if attacker.has_method("get_stat") else 10
	var def = defender.get_stat("def") if defender.has_method("get_stat") else 5
	
	# Basic damage formula
	var base_damage = max(1, atk - (def * 0.5))
	
	# Critical hit check (10% base chance)
	var crit_chance = attacker.get_stat("crit") if attacker.has_method("get_stat") else 0.1
	var is_critical = randf() < crit_chance
	
	if is_critical:
		base_damage *= 1.5
	
	# Random variance (±10%)
	var variance = randf_range(0.9, 1.1)
	var final_damage = int(base_damage * variance)
	
	# Check for instakill proc (rare chance)
	var is_instakill = randf() < 0.05 # 5% chance
	
	return {
		"damage": final_damage,
		"is_critical": is_critical,
		"is_instakill": is_instakill,
		"success": true
	}

## Calculates skill damage
func calculate_skill_damage(attacker: Node2D, defender: Node2D, skill_data: Dictionary) -> Dictionary:
	var atk = attacker.get_stat("atk") if attacker.has_method("get_stat") else 10
	var def = defender.get_stat("def") if defender.has_method("get_stat") else 5
	var power = skill_data.get("power", 1.0)
	
	# Skill damage formula
	var base_damage = max(1, (atk * power) - (def * 0.3))
	
	# Critical hit check
	var crit_chance = attacker.get_stat("crit") if attacker.has_method("get_stat") else 0.1
	var is_critical = randf() < crit_chance
	
	if is_critical:
		base_damage *= 1.5
	
	# Random variance
	var variance = randf_range(0.9, 1.1)
	var final_damage = int(base_damage * variance)
	
	# Skills don't instakill by default
	var is_instakill = false
	
	return {
		"damage": final_damage,
		"is_critical": is_critical,
		"is_instakill": is_instakill,
		"success": true
	}

## Applies a skill effect to a target
func apply_skill_effect(target: Node2D, effect_data: Dictionary):
	if not effect_manager:
		return
	
	var effect = BattleTypes.StatusEffect.new(
		effect_data.id,
		effect_data.name,
		effect_data.duration
	)
	
	if effect_data.has("stat_modifiers"):
		effect.stat_modifiers = effect_data.stat_modifiers
	
	if effect_data.has("flags"):
		effect.flags = effect_data.flags
	
	effect_manager.apply_effect(target, effect)
