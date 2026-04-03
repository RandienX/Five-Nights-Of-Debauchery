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

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Calculates initiative for all actors (RPG Maker style: party first, then enemies)
func calculate_initiative(actors: Array[BattleTypes.BattleActor]):
	initiative_queue.clear()
	party_queue.clear()
	enemy_queue.clear()
	is_party_phase = true
	
	# Separate party and enemies
	for actor in actors:
		if not actor.is_dead:
			if actor.is_enemy:
				enemy_queue.append(actor)
			else:
				party_queue.append(actor)
	
	# Sort each group by speed (descending) - higher speed goes first
	party_queue.sort_custom(func(a, b):
		return a.speed > b.speed
	)
	
	enemy_queue.sort_custom(func(a, b):
		return a.speed > b.speed
	)
	
	# Combine into main queue: party first, then enemies
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
