class_name BattleInitiativeManager
extends Node

## Manages turn order based on speed stats (RPG Maker style)
## Works with BattleTypes.BattleActor objects
## In RPG Maker style: all party members act first (in their speed order), then all enemies

signal initiative_updated(order: Array[BattleTypes.BattleActor])
signal turn_started(actor: BattleTypes.BattleActor)

var initiative_queue: Array[BattleTypes.BattleActor] = []
var current_actor: BattleTypes.BattleActor = null
var battle_root: Node2D = null

# RPG Maker style: separate queues for party and enemies
var party_queue: Array[BattleTypes.BattleActor] = []
var enemy_queue: Array[BattleTypes.BattleActor] = []
var is_party_phase: bool = true

# Speed-based initiative with randomness (like old engine)
var initiative_order: Array[BattleTypes.BattleActor] = []
var initiative_who: int = -1

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Calculates initiative for all actors (RPG Maker style: party first, then enemies)
## Uses speed with randomness like the old engine: randi_range(ceili(ai * 0.75 * total_mult), floori(ai * 1.25 * total_mult))
func calculate_initiative(actors: Array[BattleTypes.BattleActor]):
	initiative_queue.clear()
	party_queue.clear()
	enemy_queue.clear()
	is_party_phase = true
	initiative_order.clear()
	initiative_who = -1
	
	# Calculate speed values with randomness for each actor
	var speed_dict: Dictionary[int, BattleTypes.BattleActor] = {}
	
	for actor in actors:
		if actor.is_dead:
			continue
		
		var base_speed = actor.speed
		var speed_mult = 1.0
		var slow_mult = 1.0
		
		# Apply status effect modifiers if available
		if battle_root and battle_root.has_node("BattleEffectManager"):
			var effect_mgr = battle_root.get_node("BattleEffectManager")
			if effect_mgr.has_method("get_effect_multiplier"):
				speed_mult = effect_mgr.get_effect_multiplier(actor, Global.effect.Speed)
				slow_mult = effect_mgr.get_effect_multiplier(actor, Global.effect.Slow)
		
		var total_mult = speed_mult * slow_mult
		var rng = randi_range(ceili(base_speed * 0.75 * total_mult), floori(base_speed * 1.25 * total_mult))
		
		# Ensure unique speed values
		while rng in speed_dict:
			rng += 1
		
		speed_dict[rng] = actor
	
	# Sort by speed (descending - higher goes first)
	var keys = speed_dict.keys()
	keys.sort()
	keys.reverse()
	
	for k in keys:
		initiative_order.append(speed_dict[k])
	
	# Separate into party and enemy queues
	for actor in initiative_order:
		if actor.is_enemy:
			enemy_queue.append(actor)
		else:
			party_queue.append(actor)
	
	# Combine: party first, then enemies (RPG Maker style)
	initiative_queue = party_queue.duplicate()
	initiative_queue.append_array(enemy_queue.duplicate())
	
	initiative_updated.emit(initiative_queue)
	
	return initiative_queue

## Gets the next actor in the queue (RPG Maker style)
func get_next_actor() -> BattleTypes.BattleActor:
	if initiative_queue.is_empty():
		return null
	
	current_actor = initiative_queue.pop_front()
	
	# Track phase transitions
	if current_actor:
		is_party_phase = not current_actor.is_enemy
	
	turn_started.emit(current_actor)
	return current_actor

## Removes a dead unit from the queue
func remove_from_queue(actor: BattleTypes.BattleActor):
	initiative_queue.erase(actor)
	party_queue.erase(actor)
	enemy_queue.erase(actor)
	# Also remove from initiative_order
	initiative_order.erase(actor)
	if current_actor == actor:
		current_actor = null

## Checks if it's a party member's turn
func is_player_turn() -> bool:
	if not current_actor:
		return false
	return not current_actor.is_enemy

## Checks if it's an enemy's turn
func is_enemy_turn() -> bool:
	if not current_actor:
		return false
	return current_actor.is_enemy

## Resets the queue for a new round (re-add all living actors)
func reset_round(actors: Array[BattleTypes.BattleActor]):
	# Filter out dead actors
	var living_actors = actors.filter(func(a): return not a.is_dead)
	calculate_initiative(living_actors)

## Advances initiative index (for old engine style execution)
func advance_initiative_index() -> int:
	initiative_who += 1
	if initiative_who >= initiative_order.size():
		initiative_who = -1
		return -1
	return initiative_who

## Gets current initiative index
func get_current_initiative_index() -> int:
	return initiative_who

## Sets initiative index
func set_initiative_index(index: int):
	initiative_who = index

