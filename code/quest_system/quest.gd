@icon("res://icon.svg")
class_name Quest
extends Resource
## Main Quest resource containing steps and rewards

@export_group("Quest Definition")
@export var quest_name: String = "New Quest"
@export var description: String = ""  ## Full quest description for UI
@export var quest giver: String = ""  ## NPC or source of the quest
@export var category: String = "Main"  ## Quest category (Main, Side, Hidden, etc.)

@export_group("Content")
@export var steps: Array[QuestStep] = []  ## Sequential steps to complete
@export var rewards: Array[QuestEffect] = []  ## Effects applied on completion

@export_group("Metadata")
@export var icon: Texture2D = null  ## Optional icon for UI
@export var is_repeatable: bool = false  ## Can be completed multiple times
@export var is_optional: bool = false  ## Side quest vs main quest
@export var priority: int = 0  ## Higher priority quests show first in UI

@export_group("Tracking")
var state: QuestPoint.QuestState = QuestPoint.QuestState.NO
var current_step_index: int = 0
var is_active: bool = false
var is_completed: bool = false
var times_completed: int = 0
var unique_id: String = ""  ## For save/load tracking

## Initialize quest with unique ID if not set
func initialize() -> void:
	if unique_id.is_empty():
		unique_id = _generate_unique_id()
	is_active = true
	state = QuestPoint.QuestState.NO
	
	# Execute immediate effects
	for effect in rewards:
		if effect.execute_immediately:
			effect.execute()

## Get current active step
func get_current_step() -> QuestStep:
	if current_step_index < 0 or current_step_index >= steps.size():
		return null
	return steps[current_step_index]

## Evaluate quest progress - returns true if quest is complete
func evaluate() -> bool:
	if not is_active:
		return is_completed
	
	if steps.is_empty():
		is_completed = true
		state = QuestPoint.QuestState.YES
		return true
	
	var current_step = get_current_step()
	if not current_step:
		# All steps complete
		is_completed = true
		state = QuestPoint.QuestState.YES
		_execute_rewards()
		return true
	
	# Evaluate current step
	current_step.evaluate()
	
	# Update quest state based on step state
	state = current_step.get_state()
	
	# If step complete, advance
	if current_step.is_complete():
		current_step_index += 1
		# Recursively evaluate to check next step
		return evaluate()
	
	return false

## Get overall quest progress (0.0 to 1.0)
func get_progress_ratio() -> float:
	if steps.is_empty():
		return 1.0 if is_completed else 0.0
	
	var completed_steps = current_step_index
	var current_step_progress = 0.0
	
	if current_step_index < steps.size():
		current_step_progress = steps[current_step_index].get_progress_ratio()
	
	return (float(completed_steps) + current_step_progress) / float(steps.size())

## Complete the quest and execute rewards
func complete() -> void:
	if is_completed:
		return
	
	is_completed = true
	is_active = false
	times_completed += 1
	state = QuestPoint.QuestState.YES
	
	_execute_rewards()
	
	if QuestSystem:
		QuestSystem.emit_signal("quest_completed", self)

## Execute all reward effects
func _execute_rewards() -> void:
	for effect in rewards:
		if not effect.execute_immediately:  # Skip already-executed
			effect.execute()

## Reset quest for repeat
func reset() -> void:
	current_step_index = 0
	is_completed = false
	is_active = true
	state = QuestPoint.QuestState.NO
	
	for step in steps:
		step.reset()

## Fail the quest
func fail() -> void:
	is_active = false
	state = QuestPoint.QuestState.FAIL
	
	if QuestSystem:
		QuestSystem.emit_signal("quest_failed", self)

## Generate unique ID based on quest name and timestamp
func _generate_unique_id() -> String:
	var hash = quest_name.hash()
	return "quest_%d_%d" % [hash, Time.get_unix_time_from_system()]

## Serialize quest state for save data
func to_dict() -> Dictionary:
	return {
		"quest_name": quest_name,
		"unique_id": unique_id,
		"is_active": is_active,
		"is_completed": is_completed,
		"current_step_index": current_step_index,
		"times_completed": times_completed,
		"state": state,
		"steps_data": _serialize_steps()
	}

## Serialize step data
func _serialize_steps() -> Array:
	var data: Array = []
	for i in range(steps.size()):
		var step = steps[i]
		var step_data = {
			"step_name": step.step_name,
			"current_point_index": step.current_point_index,
			"points_data": _serialize_points(step)
		}
		data.append(step_data)
	return data

## Serialize point data within a step
func _serialize_points(step: QuestStep) -> Array:
	var data: Array = []
	for point in step.points:
		var point_data = {
			"point_name": point.point_name,
			"state": point.state,
			"conditions_data": _serialize_conditions(point)
		}
		data.append(point_data)
	return data

## Serialize condition data within a point
func _serialize_conditions(point: QuestPoint) -> Array:
	var data: Array = []
	for condition in point.conditions:
		var cond_data = {
			"type": condition.type,
			"target_key": condition.target_key,
			"progress_current": condition.progress_current,
			"progress_target": condition.progress_target
		}
		data.append(cond_data)
	return data

## Deserialize quest state from save data
static func from_dict(data: Dictionary) -> Quest:
	var quest = Quest.new()
	quest.quest_name = data.get("quest_name", "Unknown Quest")
	quest.unique_id = data.get("unique_id", "")
	quest.is_active = data.get("is_active", false)
	quest.is_completed = data.get("is_completed", false)
	quest.current_step_index = data.get("current_step_index", 0)
	quest.times_completed = data.get("times_completed", 0)
	quest.state = data.get("state", QuestPoint.QuestState.NO)
	
	# Note: Steps and conditions need to be populated from the original resource
	# This is handled by QuestSystem when loading
	return quest

## Get display-ready information
func get_display_info() -> Dictionary:
	return {
		"name": quest_name,
		"description": description,
		"category": category,
		"progress": get_progress_ratio() * 100,
		"current_step": get_current_step().step_name if get_current_step() else "Complete!",
		"is_completed": is_completed,
		"is_active": is_active
	}
