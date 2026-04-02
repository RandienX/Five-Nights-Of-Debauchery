class_name BattleAIManager
extends Node

## Manages enemy AI decision making
## Supports different AI personalities and targeting strategies

signal ai_decision_made(enemy: Node2D, action: Dictionary)

var battle_root: Node2D = null
var logger: BattleLogger = null
var effect_manager: BattleEffectManager = null

# AI Personalities
const AI_PASSIVE = 0.3
const AI_NORMAL = 0.6
const AI_AGGRESSIVE = 1.0

func _ready():
	pass

func init_manager(root: Node2D, log: BattleLogger, effects: BattleEffectManager):
	battle_root = root
	logger = log
	effect_manager = effects

## Determines AI action for an enemy
func decide_action(enemy: Node2D, party: Array, enemies: Array, personality: float = AI_NORMAL) -> Dictionary:
	if not is_instance_valid(enemy) or enemy.is_dead():
		return {}
	
	# Filter valid targets (alive party members)
	var valid_targets: Array[Node2D] = []
	for member in party:
		if is_instance_valid(member) and not member.is_dead():
			valid_targets.append(member)
	
	if valid_targets.is_empty():
		return {}
	
	# Choose target based on personality
	var target = select_target(enemy, valid_targets, personality)
	
	# Decide action type (attack, skill, defend, etc.)
	var action_type = decide_action_type(enemy, target, personality)
	
	# Build action dictionary
	var action = {
		"actor": enemy,
		"type": action_type.type,
		"target": target,
		"data": action_type.data
	}
	
	ai_decision_made.emit(enemy, action)
	return action

## Selects a target based on AI personality
func select_target(enemy: Node2D, targets: Array, personality: float) -> Node2D:
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
		var hp_percent = target.get_hp_percent() if target.has_method("get_hp_percent") else 1.0
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
