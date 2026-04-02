class_name BattleInitiativeManager
extends Node

## Manages turn order based on speed stats
## Uses a simple initiative queue system

signal initiative_updated(order: Array)
signal turn_started(actor: Node2D)

var initiative_queue: Array[Node2D] = []
var current_actor: Node2D = null
var battle_root: Node2D = null

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Calculates initiative for all units and sorts the queue
func calculate_initiative(party: Array, enemies: Array):
	initiative_queue.clear()
	
	# Combine all units
	var all_units = party + enemies
	
	# Sort by speed (descending) - higher speed goes first
	all_units.sort_custom(func(a, b):
		var speed_a = a.get_stat("spd") if a.has_method("get_stat") else 10
		var speed_b = b.get_stat("spd") if b.has_method("get_stat") else 10
		return speed_a > speed_b
	)
	
	initiative_queue = all_units
	initiative_updated.emit(initiative_queue)
	
	return initiative_queue

## Gets the next actor in the queue
func get_next_actor() -> Node2D:
	if initiative_queue.is_empty():
		return null
	
	current_actor = initiative_queue.pop_front()
	turn_started.emit(current_actor)
	return current_actor

## Re-adds a unit to the queue (for multi-turn effects or re-ordering)
func add_to_queue(unit: Node2D, position: int = -1):
	if position == -1:
		initiative_queue.append(unit)
	else:
		initiative_queue.insert(position, unit)

## Removes a unit from the queue (e.g., on death)
func remove_from_queue(unit: Node2D):
	initiative_queue.erase(unit)
	if current_actor == unit:
		current_actor = null

## Checks if it's a party member's turn
func is_player_turn() -> bool:
	if not current_actor:
		return false
	return current_actor.is_in_group("party")

## Checks if it's an enemy's turn
func is_enemy_turn() -> bool:
	if not current_actor:
		return false
	return current_actor.is_in_group("enemy")

## Resets the queue for a new round
func reset_round(party: Array, enemies: Array):
	calculate_initiative(party, enemies)
