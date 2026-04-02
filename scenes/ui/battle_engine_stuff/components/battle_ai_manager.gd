class_name BattleAIManager
extends Node

## Manages enemy AI decision making
## Works with BattleTypes.BattleActor objects and Enemy resources

signal ai_decision_made(enemy: BattleTypes.BattleActor, action: Dictionary)

var battle_root: Node2D = null
var logger: BattleLogger = null
var effect_manager: BattleEffectManager = null

# AI Personalities (mapped from Global.AI enum)
const AI_PASSIVE = 0.3
const AI_NORMAL = 0.6
const AI_AGGRESSIVE = 1.0

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Determines AI action for an enemy actor
func decide_action(enemy: BattleTypes.BattleActor, party: Array[BattleTypes.BattleActor], 
				   enemies: Array[BattleTypes.BattleActor], personality: float = AI_NORMAL) -> Dictionary:
	if not enemy or enemy.is_dead:
		return {}
	
	# Filter valid targets (alive party members)
	var valid_targets: Array[BattleTypes.BattleActor] = []
	for member in party:
		if member and not member.is_dead:
			valid_targets.append(member)
	
	if valid_targets.is_empty():
		return {}
	
	# Choose target based on personality
	var target = select_target(enemy, valid_targets, personality)
	
	# Decide action type (attack, skill, defend, etc.)
	var action_type = decide_action_type(enemy, target, personality)
	
	# Build action dictionary using BattleTypes.PlannedAction
	var action = {
		"actor": enemy,
		"type": action_type.type,
		"target": target,
		"data": action_type.data
	}
	
	ai_decision_made.emit(enemy, action)
	return action

## Selects a target based on AI personality
func select_target(enemy: BattleTypes.BattleActor, targets: Array[BattleTypes.BattleActor], personality: float) -> BattleTypes.BattleActor:
	if targets.is_empty():
		return null
	
	if targets.size() == 1:
		return targets[0]
	
	# Aggressive AI: target lowest HP (focus fire)
	if personality >= AI_AGGRESSIVE:
		return get_lowest_hp_target(targets)
	
	# Passive AI: random target
	if personality <= AI_PASSIVE:
		return targets[randi() % targets.size()]
	
	# Normal AI: weighted random (slight preference for low HP)
	var weights: Array[float] = []
	var total_weight = 0.0
	
	for target in targets:
		var hp_percent = float(target.current_hp) / float(target.max_hp) if target.max_hp > 0 else 1.0
		# Higher weight for lower HP
		var weight = 2.0 - hp_percent
		weights.append(weight)
		total_weight += weight
	
	# Weighted random selection
	var roll = randf() * total_weight
	var cumulative = 0.0
	
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return targets[i]
	
	return targets[targets.size() - 1]

## Gets target with lowest HP percentage
func get_lowest_hp_target(targets: Array[BattleTypes.BattleActor]) -> BattleTypes.BattleActor:
	var lowest = targets[0]
	var lowest_percent = float(lowest.current_hp) / float(lowest.max_hp) if lowest.max_hp > 0 else 1.0
	
	for target in targets:
		var percent = float(target.current_hp) / float(target.max_hp) if target.max_hp > 0 else 1.0
		if percent < lowest_percent:
			lowest = target
			lowest_percent = percent
	
	return lowest

## Decides what action to take
func decide_action_type(enemy: BattleTypes.BattleActor, target: BattleTypes.BattleActor, personality: float) -> Dictionary:
	# Check if enemy has skills/attacks available
	var enemy_resource = enemy.resource as Enemy
	var has_skills = enemy_resource and enemy_resource.attacks and enemy_resource.attacks.size() > 0
	
	# Aggressive AI: always attack or use offensive skills
	if personality >= AI_AGGRESSIVE:
		if has_skills and should_use_skill(enemy, personality):
			var skill = select_offensive_skill(enemy_resource)
			if skill:
				return {"type": BattleTypes.ActionType.SKILL, "data": {"skill": skill}}
		return {"type": BattleTypes.ActionType.ATTACK, "data": {}}
	
	# Passive AI: more likely to defend when low HP
	if personality <= AI_PASSIVE:
		if enemy.current_hp < enemy.max_hp * 0.3:
			return {"type": BattleTypes.ActionType.DEFEND, "data": {}}
		return {"type": BattleTypes.ActionType.ATTACK, "data": {}}
	
	# Normal AI: balanced approach
	if has_skills and randf() < 0.4:
		var skill = select_skill(enemy_resource)
		if skill:
			return {"type": BattleTypes.ActionType.SKILL, "data": {"skill": skill}}
	
	# Default to attack
	return {"type": BattleTypes.ActionType.ATTACK, "data": {}}

## Checks if enemy should use a skill
func should_use_skill(enemy: BattleTypes.BattleActor, personality: float) -> bool:
	# Aggressive AI uses skills more often
	var chance = 0.5 if personality >= AI_AGGRESSIVE else 0.3
	return randf() < chance

## Selects an offensive skill
func select_offensive_skill(enemy_res: Enemy) -> Resource:
	if not enemy_res or not enemy_res.attacks:
		return null
	
	# Prefer damaging skills
	for attack in enemy_res.attacks:
		if attack and attack.damage > 0:
			return attack
	
	# Fallback to any skill
	return enemy_res.attacks[randi() % enemy_res.attacks.size()] if enemy_res.attacks else null

## Selects any available skill
func select_skill(enemy_res: Enemy) -> Resource:
	if not enemy_res or not enemy_res.attacks:
		return null
	return enemy_res.attacks[randi() % enemy_res.attacks.size()]

## Converts Global.AI enum to personality float
func get_personality_from_global(global_ai: int) -> float:
	match global_ai:
		Global.AI.Dumb, Global.AI.Defensive:
			return AI_PASSIVE
		Global.AI.Casual, Global.AI.Intelligent:
			return AI_NORMAL
		Global.AI.Violent:
			return AI_AGGRESSIVE
		_:
			return AI_NORMAL
		weights.append(weight)
		total_weight += weight
	
	# Weighted random selection
	var roll = randf() * total_weight
	var cumulative = 0.0
	
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return targets[i]
	
	return targets[targets.size() - 1]

## Decides what action type to use
func decide_action_type(enemy: Node2D, target: Node2D, personality: float) -> Dictionary:
	# Check if enemy has skills
	var skills = enemy.get_skills() if enemy.has_method("get_skills") else []
	
	# Aggressive AI: always attack or use offensive skills
	if personality >= AI_AGGRESSIVE:
		if not skills.is_empty() and should_use_skill(enemy, skills, true):
			var skill = select_skill(skills, true)
			return {"type": BattleTypes.ActionType.SKILL, "data": skill}
		return {"type": BattleTypes.ActionType.ATTACK, "data": {}}
	
	# Passive AI: might defend or use healing skills
	if personality <= AI_PASSIVE:
		if enemy.get_hp_percent() < 0.3 and has_healing_skill(skills):
			var heal_skill = select_skill(skills, false)
			return {"type": BattleTypes.ActionType.SKILL, "data": heal_skill}
		
		if randf() < 0.3:
			return {"type": BattleTypes.ActionType.DEFEND, "data": {}}
		
		return {"type": BattleTypes.ActionType.ATTACK, "data": {}}
	
	# Normal AI: balanced approach
	if not skills.is_empty():
		if should_use_skill(enemy, skills, false):
			var skill = select_skill(skills, false)
			return {"type": BattleTypes.ActionType.SKILL, "data": skill}
	
	return {"type": BattleTypes.ActionType.ATTACK, "data": {}}

## Gets the target with lowest HP percentage
func get_lowest_hp_target(targets: Array) -> Node2D:
	var lowest_hp = 1.0
	var lowest_target = null
	
	for target in targets:
		var hp_percent = target.get_hp_percent() if target.has_method("get_hp_percent") else 1.0
		if hp_percent < lowest_hp:
			lowest_hp = hp_percent
			lowest_target = target
	
	return lowest_target

## Checks if enemy should use a skill
func should_use_skill(enemy: Node2D, skills: Array, aggressive: bool) -> bool:
	var mp = enemy.get_mp() if enemy.has_method("get_mp") else 0
	var mp_percent = enemy.get_mp_percent() if enemy.has_method("get_mp_percent") else 1.0
	
	# Not enough MP
	if mp <= 0:
		return false
	
	# Aggressive: use skills more often
	if aggressive:
		return mp_percent > 0.2
	
	# Conservative: save MP for emergencies
	return mp_percent > 0.5 or enemy.get_hp_percent() < 0.4

## Checks if enemy has any healing skills
func has_healing_skill(skills: Array) -> bool:
	for skill in skills:
		if skill.get("type") == "heal" or skill.get("target") == "self":
			return true
	return false

## Selects a skill to use
func select_skill(skills: Array, aggressive: bool) -> Dictionary:
	if skills.is_empty():
		return {}
	
	# Filter usable skills (enough MP)
	var usable_skills: Array = []
	for skill in skills:
		if skill.get("cost", 0) <= 999: # Assume we checked MP already
			usable_skills.append(skill)
	
	if usable_skills.is_empty():
		return {}
	
	# Aggressive: pick highest damage skill
	if aggressive:
		var max_power = 0
		var best_skill = usable_skills[0]
		
		for skill in usable_skills:
			var power = skill.get("power", 1.0)
			if power > max_power:
				max_power = power
				best_skill = skill
		
		return best_skill
	
	# Conservative: pick random usable skill
	return usable_skills[randi() % usable_skills.size()]

## Gets AI personality from string name
func get_personality_from_name(name: String) -> float:
	match name.to_lower():
		"passive":
			return AI_PASSIVE
		"aggressive":
			return AI_AGGRESSIVE
		_:
			return AI_NORMAL
