extends Resource
class_name Quest

## Quest - Main quest resource containing points and rewards
##
## The Quest resource is the primary processing object in the quest system.
## It contains a linear sequence of QuestPoints, each with conditions and logic gates.
## When completed, QuestEffects are executed as rewards.
## 
## Structure:
## - Quest contains multiple QuestPoints (linear progression)
## - Each QuestPoint has multiple QuestPointConditions
## - Conditions use LogicGates (AND, OR, NOT) for evaluation
## - QuestEffects define rewards upon quest completion

@export_group("Quest Definition")
@export var quest_name: String = "New Quest"
@export var quest_id: String = ""  # Unique identifier
@export var description: String = ""
@export var category: String = ""  # Optional categorization

@export_group("Quest Structure")
@export var points: Array[QuestPoint] = []  # Linear progression of points (steps)
@export var effects: Array[QuestEffect] = []  # Rewards on completion

@export_group("Progress Tracking")
@export var current_point_index: int = 0
@export var is_active: bool = false
@export var is_complete: bool = false
@export var is_failed: bool = false

@export_group("Optional")
@export var icon: Texture2D = null
@export var priority: int = 0  # For sorting (higher = more important)
@export var metadata: Dictionary = {}

## Initialize this quest
func initialize() -> void:
	is_active = true
	is_complete = false
	is_failed = false
	current_point_index = 0
	
	# Reset all points
	for point in points:
		point.reset()

## Get the current active point
func get_current_point() -> QuestPoint:
	if points.is_empty():
		return null
	if current_point_index >= points.size():
		current_point_index = points.size() - 1
	return points[current_point_index]

## Evaluate current point and return its state
func evaluate() -> QuestPoint.QuestState:
	var point = get_current_point()
	if not point:
		return QuestPoint.QuestState.YES
	
	return point.evaluate()

## Update progress for a specific condition type/target
func update_progress(type: QuestPointCondition.ConditionType, target_key: String, amount: float = 1.0) -> QuestPoint.QuestState:
	var point = get_current_point()
	if not point:
		return QuestPoint.QuestState.NO
	
	var state = point.update_condition_progress(type, target_key, amount)
	
	# Check if point is complete and advance
	if state == QuestPoint.QuestState.YES and point.auto_advance:
		_advance_to_next_point()
	
	return state

## Advance to next point
func _advance_to_next_point() -> bool:
	if current_point_index < points.size() - 1:
		current_point_index += 1
		return true
	else:
		# All points complete - complete the quest
		complete_quest()
		return false

## Complete this quest and execute effects
func complete_quest() -> void:
	if is_complete:
		return
	
	is_complete = true
	is_active = false
	
	# Execute all reward effects
	for effect in effects:
		effect.execute(self)

## Fail this quest
func fail_quest() -> void:
	if is_failed or is_complete:
		return
	
	is_failed = true
	is_active = false

## Reset quest to initial state
func reset() -> void:
	is_active = false
	is_complete = false
	is_failed = false
	current_point_index = 0
	
	for point in points:
		point.reset()

## Get overall completion percentage (0.0 to 1.0)
func get_completion_percentage() -> float:
	if points.is_empty():
		return 1.0
	
	if is_complete:
		return 1.0
	
	if is_failed:
		return 0.0
	
	var total_progress := 0.0
	for i in range(points.size()):
		var point = points[i]
		if i < current_point_index:
			total_progress += 1.0
		elif i == current_point_index:
			total_progress += point.get_completion_percentage()
	
	return total_progress / points.size()

## Get current objective description
func get_current_objective() -> String:
	var point = get_current_point()
	if not point:
		return "Quest Complete!"
	
	return point.step_name

## Create save data for this quest
func get_save_data() -> Dictionary:
	return {
		"quest_id": quest_id,
		"quest_name": quest_name,
		"is_active": is_active,
		"is_complete": is_complete,
		"is_failed": is_failed,
		"current_point_index": current_point_index,
		"points_data": _serialize_points(),
		"metadata": metadata
	}

func _serialize_points() -> Array:
	var data := []
	for point in points:
		var point_data := {
			"step_name": point.step_name,
			"is_complete": point.is_complete,
			"logic_gate": point.logic_gate,
			"conditions_data": []
		}
		
		for condition in point.conditions:
			point_data["conditions_data"].append({
				"type": condition.type,
				"target_key": condition.target_key,
				"progress_current": condition.progress_current,
				"progress_target": condition.progress_target
			})
		
		data.append(point_data)
	
	return data

## Load quest from save data
func load_save_data(data: Dictionary) -> void:
	if data.has("is_active"):
		is_active = data["is_active"]
	if data.has("is_complete"):
		is_complete = data["is_complete"]
	if data.has("is_failed"):
		is_failed = data["is_failed"]
	if data.has("current_point_index"):
		current_point_index = data["current_point_index"]
	
	if data.has("points_data"):
		_deserialize_points(data["points_data"])

func _deserialize_points(points_data: Array) -> void:
	for i in range(min(points_data.size(), points.size())):
		var point_data = points_data[i]
		var point = points[i]
		
		if point_data.has("is_complete"):
			point.is_complete = point_data["is_complete"]
		
		if point_data.has("conditions_data"):
			_deserialize_conditions(point, point_data["conditions_data"])

func _deserialize_conditions(point: QuestPoint, conditions_data: Array) -> void:
	for i in range(min(conditions_data.size(), point.conditions.size())):
		var cond_data = conditions_data[i]
		var condition = point.conditions[i]
		
		if cond_data.has("progress_current"):
			condition.progress_current = cond_data["progress_current"]
		if cond_data.has("progress_target"):
			condition.progress_target = cond_data["progress_target"]

## Create a copy of this quest
func duplicate() -> Quest:
	var new_quest = Quest.new()
	new_quest.quest_name = quest_name
	new_quest.quest_id = quest_id
	new_quest.description = description
	new_quest.category = category
	new_quest.current_point_index = 0
	new_quest.is_active = false
	new_quest.is_complete = false
	new_quest.is_failed = false
	new_quest.icon = icon
	new_quest.priority = priority
	new_quest.metadata = metadata.duplicate()
	
	for point in points:
		new_quest.points.append(point.duplicate())
	
	for effect in effects:
		new_quest.effects.append(effect.duplicate())
	
	return new_quest
