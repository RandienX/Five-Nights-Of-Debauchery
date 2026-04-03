class_name BattleActionPlanner
extends Node

## Manages action planning phase for party members
## Allows queuing actions before execution (like old engine)

signal action_planned(action: BattleTypes.PlannedAction)
signal action_undone(index: int)
signal planning_complete()

var planned_actions: Array[BattleTypes.PlannedAction] = []
var action_history: Array[Object] = []  # For undo functionality (like old engine)
var current_plan_index: int = 0
var is_planning: bool = false
var battle_engine: BattleEngine = null  # Reference to battle engine for actor lookup

# Planning state (matches old engine)
var attack_array: Dictionary = {}  # {actor: [targets, skill]}
var current_party_plan_index: int = 0
var selected_enemy: int = 1
var previous_enemy: int = 1

func _ready():
	pass

## Initialize with reference to battle engine
func init_manager(engine: BattleEngine):
	battle_engine = engine

## Starts the planning phase
func start_planning(party: Array[BattleTypes.BattleActor]):
	planned_actions.clear()
	action_history.clear()
	attack_array.clear()
	current_plan_index = 0
	is_planning = true
	current_party_plan_index = 0
	
	# Pre-create placeholder actions for each party member
	for member in party:
		if member and not member.is_dead:
			var action = BattleTypes.PlannedAction.new(member.id, BattleTypes.ActionType.ATTACK)
			planned_actions.append(action)

## Plans an action for the current party member being planned
func plan_action(actor: BattleTypes.BattleActor, type: BattleTypes.ActionType, target: BattleTypes.BattleActor = null, skill_id: String = "", item_id: String = ""):
	var action = BattleTypes.PlannedAction.new(actor.id, type)
	if target:
		action.target_ids = [target.id]
	action.skill_id = skill_id
	action.item_id = item_id
	
	# Find existing action for this actor or add new
	var found_index = -1
	for i in range(planned_actions.size()):
		if planned_actions[i].source_id == actor.id:
			found_index = i
			break
	
	if found_index >= 0:
		planned_actions[found_index] = action
	else:
		planned_actions.append(action)
	
	# Store in attack_array like old engine
	if type == BattleTypes.ActionType.ATTACK or type == BattleTypes.ActionType.SKILL or type == BattleTypes.ActionType.ITEM:
		var targets = []
		if target:
			targets.append(target)
		attack_array[actor] = [targets, skill_id]
	
	action_planned.emit(action)
	return action

## Undoes the last planned action (matches old engine undo_last_action)
func undo_last_action() -> bool:
	if action_history.is_empty():
		return false
	
	var last = action_history.pop_back()
	if attack_array.has(last):
		var atk_data = attack_array[last]
		if atk_data.size() >= 2:
			var skill_id = atk_data[1]
			# Restore item if it was an item use (attack_type == 3)
			if skill_id and battle_engine and battle_engine.has_method("_get_item_data"):
				var item_data = battle_engine._get_item_data(skill_id)
				if item_data and item_data.has("id"):
					# Restore item to inventory via Global
					Global.add_item_by_id(item_data.id, 1)
		attack_array.erase(last)
	
	# Update current attacker and state
	if battle_engine:
		battle_engine.current_actor = last
		battle_engine.state = BattleTypes.BattleState.PLANNING
	
	current_party_plan_index = max(0, current_party_plan_index - 1)
	
	action_undone.emit(planned_actions.size())
	return true

## Gets the next action to execute
func get_next_action() -> BattleTypes.PlannedAction:
	if current_plan_index >= planned_actions.size():
		return null
	
	var action = planned_actions[current_plan_index]
	current_plan_index += 1
	return action

## Resets the execution index (for re-planning)
func reset_execution():
	current_plan_index = 0

## Checks if all party members have planned actions
func is_planning_complete() -> bool:
	if not is_planning:
		return false
	
	# Count valid party members
	var valid_members = 0
	for action in planned_actions:
		if action.source_id != "" and not _is_actor_dead(action.source_id):
			valid_members += 1
	
	return planned_actions.size() >= valid_members and valid_members > 0

## Ends the planning phase
func end_planning():
	is_planning = false
	planning_complete.emit()

## Clears all planned actions
func clear_plans():
	planned_actions.clear()
	current_plan_index = 0
	attack_array.clear()
	action_history.clear()

## Helper to check if an actor is dead
func _is_actor_dead(actor_id: String) -> bool:
	if battle_engine:
		var actor = battle_engine._get_actor_by_id(actor_id)
		if actor:
			return actor.is_dead
	return false

## Adds an attack to the attack array (matches old engine add_attack)
func add_attack(attacker: BattleTypes.BattleActor, attacked: Array[BattleTypes.BattleActor], skill_id: String):
	attack_array[attacker] = [attacked, skill_id]
