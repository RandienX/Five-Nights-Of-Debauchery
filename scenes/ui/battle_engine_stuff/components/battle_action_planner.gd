class_name BattleActionPlanner
extends Node

## Manages action planning phase for party members
## Allows queuing actions before execution

signal action_planned(action: BattleTypes.PlannedAction)
signal action_undone(index: int)
signal planning_complete()

var planned_actions: Array[BattleTypes.PlannedAction] = []
var current_plan_index: int = 0
var is_planning: bool = false

func _ready():
	pass

## Starts the planning phase
func start_planning(party: Array[BattleTypes.BattleActor]):
	planned_actions.clear()
	current_plan_index = 0
	is_planning = true
	
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
	
	action_planned.emit(action)
	return action

## Undoes the last planned action
func undo_last_action() -> bool:
	if planned_actions.is_empty():
		return false
	
	planned_actions.remove_at(planned_actions.size() - 1)
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
