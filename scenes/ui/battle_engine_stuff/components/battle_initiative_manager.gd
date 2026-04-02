class_name BattleInitiativeManager
extends Node

## Manages turn order based on speed stats
## Works with BattleTypes.BattleActor objects

signal initiative_updated(order: Array[BattleTypes.BattleActor])
signal turn_started(actor: BattleTypes.BattleActor)

var initiative_queue: Array[BattleTypes.BattleActor] = []
var current_actor: BattleTypes.BattleActor = null
var battle_root: Node2D = null

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Calculates initiative for all actors and sorts the queue
func calculate_initiative(actors: Array[BattleTypes.BattleActor]):
	initiative_queue.clear()
	
	# Add all actors to queue
	for actor in actors:
		if not actor.is_dead:
			initiative_queue.append(actor)
	
	# Sort by speed (descending) - higher speed goes first
	initiative_queue.sort_custom(func(a, b):
		return a.speed > b.speed
	)
	
	initiative_updated.emit(initiative_queue)
	
	return initiative_queue

## Gets the next actor in the queue
func get_next_actor() -> BattleTypes.BattleActor:
	if initiative_queue.is_empty():
		return null
	
	current_actor = initiative_queue.pop_front()
	turn_started.emit(current_actor)
	return current_actor

## Removes a dead unit from the queue
func remove_from_queue(actor: BattleTypes.BattleActor):
	initiative_queue.erase(actor)
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
