class_name BattleInitiativeManager
extends Node

## Manages initiative order and turn progression
## Based on tech_demo1_engine.gd setup_initiative() logic

signal initiative_calculated(initiative_order: Array)
signal turn_started(actor: Object, actor_index: int)
signal round_complete()

var initiative: Array[Object] = []
var initiative_who: int = -1
var battle_root: Node2D = null

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Calculates initiative order based on speed/AI stats with effects
func calculate_initiative(party: Array, enemies: Array) -> Array[Object]:
	initiative.clear()
	var speed_dict: Dictionary[int, Object] = {}
	
	# Add enemies to initiative
	for e in range(5):
		var enemy_key = 'enemy_pos' + str(e + 1)
		if battle_root and battle_root.battle and battle_root.battle.get(enemy_key):
			var enemy = battle_root.battle.get(enemy_key)
			var ai_stat = enemy.ai
			var speed_mult = get_effect_multiplier(enemy, Global.effect.Speed)
			var slow_mult = get_effect_multiplier(enemy, Global.effect.Slow)
			var total_mult = speed_mult * slow_mult
			var rng = randi_range(ceili(ai_stat * 0.75 * total_mult), floori(ai_stat * 1.25 * total_mult))
			while rng in speed_dict:
				rng += 1
			speed_dict[rng] = enemy
	
	# Add party members to initiative
	for p in party:
		var ai_stat = p.max_stats["ai"]
		var speed_mult = get_effect_multiplier(p, Global.effect.Speed)
		var slow_mult = get_effect_multiplier(p, Global.effect.Slow)
		var total_mult = speed_mult * slow_mult
		var rng = randi_range(ceili(ai_stat * 0.75 * total_mult), floori(ai_stat * 1.25 * total_mult))
		while rng in speed_dict:
			rng += 1
		speed_dict[rng] = p
	
	# Sort by speed value (descending)
	var keys = speed_dict.keys()
	keys.sort()
	var rev: Array[Object] = []
	for k in range(keys.size() - 1, -1, -1):
		rev.append(speed_dict[keys[k]])
	
	initiative = rev
	initiative_calculated.emit(initiative)
	return initiative

## Gets the effect multiplier for a target
func get_effect_multiplier(target: Object, effect: Global.effect) -> float:
	if battle_root and battle_root.has_method("get_effect_multiplier"):
		return battle_root.get_effect_multiplier(target, effect)
	
	# Default fallback
	match effect:
		Global.effect.Speed:
			return 1.0
		Global.effect.Slow:
			return 0.5
		_:
			return 1.0

## Advances to the next actor in initiative
func advance_initiative() -> Object:
	if initiative.is_empty():
		return null
	
	initiative_who += 1
	if initiative_who >= initiative.size():
		initiative_who = -1
		round_complete.emit()
		return null
	
	var current = initiative[initiative_who]
	turn_started.emit(current, initiative_who)
	return current

## Gets the current actor
func get_current_actor() -> Object:
	if initiative_who < 0 or initiative_who >= initiative.size():
		return null
	return initiative[initiative_who]

## Gets the current actor index
func get_current_index() -> int:
	return initiative_who

## Resets initiative for a new round
func reset_round(party: Array, enemies: Array):
	initiative_who = -1
	calculate_initiative(party, enemies)

## Checks if current actor is a party member
func is_player_turn() -> bool:
	var current = get_current_actor()
	return current != null and "max_stats" in current  # Party has max_stats

## Gets all party members from initiative
func get_party_members_from_initiative() -> Array[Object]:
	var party_members: Array[Object] = []
	for actor in initiative:
		if actor != null and "max_stats" in actor:  # Party check
			party_members.append(actor)
	return party_members

## Gets all enemies from initiative
func get_enemy_members_from_initiative() -> Array[Object]:
	var enemy_members: Array[Object] = []
	for actor in initiative:
		if actor != null and not ("max_stats" in actor):  # Enemy check
			enemy_members.append(actor)
	return enemy_members
