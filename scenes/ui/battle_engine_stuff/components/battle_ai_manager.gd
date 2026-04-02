class_name BattleAIManager
extends Node

## Manages enemy AI decision making with 6 personality types
## Works with BattleTypes.BattleActor objects and Enemy resources

signal ai_decision_made(enemy: BattleTypes.BattleActor, action: Dictionary)

var battle_root: Node2D = null
var logger: BattleLogger = null
var effect_manager: BattleEffectManager = null

# AI Personality thresholds
const AI_DUMB = 0.2
const AI_CASUAL = 0.4
const AI_VIOLENT = 0.9
const AI_DEFENSIVE = 0.3
const AI_INTELLIGENT = 0.7
const AI_FLEXIBLE = 1.0

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root
	logger = root.get_node_or_null("BattleLogger")
	effect_manager = root.get_node_or_null("BattleEffectManager")

## Determines AI action for an enemy actor based on personality
func decide_action(enemy: BattleTypes.BattleActor, party: Array[BattleTypes.BattleActor], 
				   enemies: Array[BattleTypes.BattleActor], personality: int = BattleTypes.AIPersonality.CASUAL) -> Dictionary:
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
	var action_type = decide_action_type(enemy, target, personality, party, enemies)
	
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
func select_target(enemy: BattleTypes.BattleActor, targets: Array[BattleTypes.BattleActor], personality: int) -> BattleTypes.BattleActor:
	if targets.is_empty():
		return null
	
	if targets.size() == 1:
		return targets[0]
	
	match personality:
		BattleTypes.AIPersonality.DUMB:
			# Random target, no strategy
			return targets[randi() % targets.size()]
		
		BattleTypes.AIPersonality.CASUAL:
			# Slight preference for low HP
			return select_weighted_by_hp(targets, 0.3)
		
		BattleTypes.AIPersonality.VIOLENT:
			# Always focus lowest HP (kill order)
			return get_lowest_hp_target(targets)
		
		BattleTypes.AIPersonality.DEFENSIVE:
			# Target highest HP (threat removal) or random
			if randf() < 0.6:
				return get_highest_hp_target(targets)
			else:
				return targets[randi() % targets.size()]
		
		BattleTypes.AIPersonality.INTELLIGENT:
			# Smart targeting: low HP + status effects + class priority
			return select_smart_target(enemy, targets)
		
		BattleTypes.AIPersonality.FLEXIBLE:
			# Adapts based on battle state
			return select_adaptive_target(enemy, targets)
	
	# Default: casual
	return select_weighted_by_hp(targets, 0.3)

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

## Gets target with highest HP percentage
func get_highest_hp_target(targets: Array[BattleTypes.BattleActor]) -> BattleTypes.BattleActor:
	var highest = targets[0]
	var highest_percent = float(highest.current_hp) / float(highest.max_hp) if highest.max_hp > 0 else 0.0
	
	for target in targets:
		var percent = float(target.current_hp) / float(target.max_hp) if target.max_hp > 0 else 0.0
		if percent > highest_percent:
			highest = target
			highest_percent = percent
	
	return highest

## Weighted selection by HP (higher weight = lower HP)
func select_weighted_by_hp(targets: Array[BattleTypes.BattleActor], intensity: float) -> BattleTypes.BattleActor:
	var weights: Array[float] = []
	var total_weight = 0.0
	
	for target in targets:
		var hp_percent = float(target.current_hp) / float(target.max_hp) if target.max_hp > 0 else 1.0
		var weight = 1.0 + ((1.0 - hp_percent) * intensity * 5.0)
		weights.append(weight)
		total_weight += weight
	
	var roll = randf() * total_weight
	var cumulative = 0.0
	
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return targets[i]
	
	return targets[targets.size() - 1]

## Smart targeting (Intelligent AI)
func select_smart_target(enemy: BattleTypes.BattleActor, targets: Array[BattleTypes.BattleActor]) -> BattleTypes.BattleActor:
	var best_target = targets[0]
	var best_score = 0.0
	
	for target in targets:
		var score = 0.0
		
		# HP factor (lower HP = higher priority)
		var hp_percent = float(target.current_hp) / float(target.max_hp) if target.max_hp > 0 else 1.0
		score += (1.0 - hp_percent) * 40.0
		
		# Status effect factor (more debuffs = easier kill)
		var debuff_count = 0
		for effect in target.status_effects:
			if not effect.is_positive:
				debuff_count += 1
		score += debuff_count * 10.0
		
		# Speed factor (faster targets = threat)
		score += target.speed * 0.1
		
		if score > best_score:
			best_score = score
			best_target = target
	
	return best_target

## Adaptive targeting (Flexible AI - adapts to battle state)
func select_adaptive_target(enemy: BattleTypes.BattleActor, targets: Array[BattleTypes.BattleActor]) -> BattleTypes.BattleActor:
	var enemy_res = enemy.resource as Enemy
	if not enemy_res:
		return targets[randi() % targets.size()]
	
	# Adapt based on enemy's current HP
	var enemy_hp_percent = float(enemy.current_hp) / float(enemy.max_hp) if enemy.max_hp > 0 else 1.0
	
	if enemy_hp_percent < 0.3:
		# Desperate: go for kill on weakest
		return get_lowest_hp_target(targets)
	elif enemy_hp_percent > 0.7:
		# Confident: target strongest
		return get_highest_hp_target(targets)
	else:
		# Normal: smart targeting
		return select_smart_target(enemy, targets)

## Decides what action to take based on personality and ALL stats
func decide_action_type(enemy: BattleTypes.BattleActor, target: BattleTypes.BattleActor, 
						personality: int, party: Array[BattleTypes.BattleActor], 
						enemies: Array[BattleTypes.BattleActor]) -> Dictionary:
	var enemy_res = enemy.resource as Enemy
	if not enemy_res:
		return {"type": BattleTypes.ActionType.ATTACK, "data": {}}
	
	var has_skills = enemy_res.attacks and enemy_res.attacks.size() > 0
	var hp_percent = float(enemy.current_hp) / float(enemy.max_hp) if enemy.max_hp > 0 else 1.0
	var mp_percent = float(enemy.current_mp) / float(enemy.max_mp) if enemy.max_mp > 0 else 0.0
	
	match personality:
		BattleTypes.AIPersonality.DUMB:
			# Always attack, rarely uses skills
			if has_skills and randf() < 0.1 and mp_percent > 0.5:
				var skill = select_random_skill(enemy_res)
				if skill:
					return {"type": BattleTypes.ActionType.SKILL, "data": skill}
			return {"type": BattleTypes.ActionType.ATTACK, "data": {}}
		
		BattleTypes.AIPersonality.CASUAL:
			# Balanced but conservative
			if hp_percent < 0.3:
				return {"type": BattleTypes.ActionType.DEFEND, "data": {}}
			if has_skills and randf() < 0.3 and mp_percent > 0.4:
				var skill = select_random_skill(enemy_res)
				if skill:
					return {"type": BattleTypes.ActionType.SKILL, "data": skill}
			return {"type": BattleTypes.ActionType.ATTACK, "data": {}}
		
		BattleTypes.AIPersonality.VIOLENT:
			# Always aggressive, use strongest skills
			if has_skills and mp_percent > 0.2:
				var skill = select_best_offensive_skill(enemy_res)
				if skill:
					return {"type": BattleTypes.ActionType.SKILL, "data": skill}
			return {"type": BattleTypes.ActionType.ATTACK, "data": {}}
		
		BattleTypes.AIPersonality.DEFENSIVE:
			# Defend when low HP, use healing/support skills
			if hp_percent < 0.4:
				return {"type": BattleTypes.ActionType.DEFEND, "data": {}}
			if has_skills:
				var heal_skill = select_healing_skill(enemy_res)
				if heal_skill and hp_percent < 0.6:
					return {"type": BattleTypes.ActionType.SKILL, "data": heal_skill}
			return {"type": BattleTypes.ActionType.ATTACK, "data": {}}
		
		BattleTypes.AIPersonality.INTELLIGENT:
			# Smart decision making based on full stat analysis
			return make_intelligent_decision(enemy, enemy_res, target, party, hp_percent, mp_percent)
		
		BattleTypes.AIPersonality.FLEXIBLE:
			# Adapts strategy based on entire battle state
			return make_flexible_decision(enemy, enemy_res, target, party, enemies, hp_percent, mp_percent)
	
	# Default
	return {"type": BattleTypes.ActionType.ATTACK, "data": {}}

## Intelligent decision making
func make_intelligent_decision(enemy: BattleTypes.BattleActor, enemy_res: Enemy, 
							   target: BattleTypes.BattleActor, party: Array[BattleTypes.BattleActor],
							   hp_percent: float, mp_percent: float) -> Dictionary:
	var has_skills = enemy_res.attacks and enemy_res.attacks.size() > 0
	
	# Check if we should heal
	if hp_percent < 0.5 and has_skills:
		var heal_skill = select_healing_skill(enemy_res)
		if heal_skill and mp_percent > 0.3:
			return {"type": BattleTypes.ActionType.SKILL, "data": heal_skill}
	
	# Check if target is vulnerable (finish off)
	var target_hp_percent = float(target.current_hp) / float(target.max_hp) if target.max_hp > 0 else 1.0
	if target_hp_percent < 0.3 and has_skills and mp_percent > 0.2:
		var skill = select_best_offensive_skill(enemy_res)
		if skill:
			return {"type": BattleTypes.ActionType.SKILL, "data": skill}
	
	# Use offensive skills strategically
	if has_skills and mp_percent > 0.4 and randf() < 0.5:
		var skill = select_best_offensive_skill(enemy_res)
		if skill:
			return {"type": BattleTypes.ActionType.SKILL, "data": skill}
	
	return {"type": BattleTypes.ActionType.ATTACK, "data": {}}

## Flexible decision making (adapts to full battle state)
func make_flexible_decision(enemy: BattleTypes.BattleActor, enemy_res: Enemy,
							target: BattleTypes.BattleActor, party: Array[BattleTypes.BattleActor],
							enemies: Array[BattleTypes.BattleActor], hp_percent: float, mp_percent: float) -> Dictionary:
	var has_skills = enemy_res.attacks and enemy_res.attacks.size() > 0
	
	# Count alive allies
	var alive_allies = 0
	for ally in enemies:
		if ally and not ally.is_dead:
			alive_allies += 1
	
	# Count alive enemies (party)
	var alive_enemies = 0
	for p in party:
		if p and not p.is_dead:
			alive_enemies += 1
	
	# Outnumbered: play defensively
	if alive_allies < alive_enemies:
		if hp_percent < 0.5:
			return {"type": BattleTypes.ActionType.DEFEND, "data": {}}
		if has_skills:
			var heal_skill = select_healing_skill(enemy_res)
			if heal_skill and mp_percent > 0.4:
				return {"type": BattleTypes.ActionType.SKILL, "data": heal_skill}
	
	# Outnumbering: be aggressive
	if alive_allies > alive_enemies:
		if has_skills and mp_percent > 0.3:
			var skill = select_best_offensive_skill(enemy_res)
			if skill:
				return {"type": BattleTypes.ActionType.SKILL, "data": skill}
		return {"type": BattleTypes.ActionType.ATTACK, "data": {}}
	
	# Even match: smart play
	return make_intelligent_decision(enemy, enemy_res, target, party, hp_percent, mp_percent)

## Selects random skill
func select_random_skill(enemy_res: Enemy) -> Resource:
	if not enemy_res or not enemy_res.attacks or enemy_res.attacks.is_empty():
		return null
	return enemy_res.attacks[randi() % enemy_res.attacks.size()]

## Selects best offensive skill
func select_best_offensive_skill(enemy_res: Enemy) -> Resource:
	if not enemy_res or not enemy_res.attacks or enemy_res.attacks.is_empty():
		return null
	
	var best_skill = null
	var best_power = 0
	
	for attack in enemy_res.attacks:
		if attack and attack.damage > best_power:
			best_power = attack.damage
			best_skill = attack
	
	return best_skill if best_skill else enemy_res.attacks[0]

## Selects healing skill
func select_healing_skill(enemy_res: Enemy) -> Resource:
	if not enemy_res or not enemy_res.attacks or enemy_res.attacks.is_empty():
		return null
	
	for attack in enemy_res.attacks:
		# Check if skill has healing properties
		if attack and attack.has_method("get_type"):
			if attack.call("get_type") == "heal":
				return attack
		# Alternative: check property
		if attack and attack.get("type") == "heal":
			return attack
		# Check by name
		if attack and "heal" in str(attack).to_lower():
			return attack
	
	return null

## Converts Global.AI enum to BattleTypes.AIPersonality
func get_personality_from_global(global_ai: int) -> int:
	match global_ai:
		Global.AI.Dumb:
			return BattleTypes.AIPersonality.DUMB
		Global.AI.Casual:
			return BattleTypes.AIPersonality.CASUAL
		Global.AI.Violent:
			return BattleTypes.AIPersonality.VIOLENT
		Global.AI.Defensive:
			return BattleTypes.AIPersonality.DEFENSIVE
		Global.AI.Intelligent:
			return BattleTypes.AIPersonality.INTELLIGENT
		Global.AI.Flexible:
			return BattleTypes.AIPersonality.FLEXIBLE
		_:
			return BattleTypes.AIPersonality.CASUAL

