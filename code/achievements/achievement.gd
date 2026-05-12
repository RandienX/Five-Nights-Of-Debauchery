extends Resource
class_name Achievement

## Achievement - Trackable accomplishment based on quest-like logic
##
## Achievements use similar logic to quests but are simpler, tracking
## single objectives with optional multiple conditions.

@export_group("Achievement Definition")
@export var achievement_id: String = ""
@export var achievement_name: String = "New Achievement"
@export var description: String = ""
@export var icon: Texture2D = null

@export_group("Conditions")
@export var conditions: Array[QuestPointCondition] = []
@export var logic_gate: QuestPoint.LogicGate = QuestPoint.LogicGate.AND

@export_group("Progress Tracking")
@export var is_unlocked: bool = false
@export var progress_current: float = 0.0
@export var progress_target: float = 1.0
@export var times_completed: int = 0

@export_group("Optional")
@export var category: String = ""
@export var hidden: bool = false  # Hide until unlocked
@export var priority: int = 0
@export var metadata: Dictionary = {}

## Check if achievement is complete
func is_complete() -> bool:
	if conditions.is_empty():
		return progress_current >= progress_target
	
	match logic_gate:
		QuestPoint.LogicGate.AND:
			for condition in conditions:
				if not condition.is_complete():
					return false
			return true
		QuestPoint.LogicGate.OR:
			for condition in conditions:
				if condition.is_complete():
					return true
			return false
		QuestPoint.LogicGate.NOT:
			for condition in conditions:
				if condition.is_complete():
					return false
			return true
	
	return progress_current >= progress_target

## Update progress for a specific condition
func update_progress(type: QuestPointCondition.ConditionType, target_key: String, amount: float = 1.0) -> bool:
	var updated := false
	
	for condition in conditions:
		if condition.type == type and condition.target_key == target_key:
			condition.add_progress(amount)
			updated = true
			break
	
	if updated:
		_recalculate_progress()
		return is_complete()
	
	return false

## Recalculate overall progress
func _recalculate_progress() -> void:
	if conditions.is_empty():
		return
	
	var total := 0.0
	for condition in conditions:
		total += condition.progress_current / condition.progress_target
	
	progress_current = total / conditions.size()
	progress_target = 1.0

## Unlock this achievement
func unlock() -> void:
	if is_unlocked:
		return
	
	is_unlocked = true
	times_completed += 1

## Reset achievement
func reset() -> void:
	is_unlocked = false
	progress_current = 0.0
	times_completed = 0
	
	for condition in conditions:
		condition.reset()

## Get display description (handles hidden achievements)
func get_display_description() -> String:
	if hidden and not is_unlocked:
		return "???"
	return description

## Get save data
func get_save_data() -> Dictionary:
	return {
		"achievement_id": achievement_id,
		"is_unlocked": is_unlocked,
		"progress_current": progress_current,
		"times_completed": times_completed,
		"conditions_data": _serialize_conditions()
	}

func _serialize_conditions() -> Array:
	var data := []
	for condition in conditions:
		data.append({
			"type": condition.type,
			"target_key": condition.target_key,
			"progress_current": condition.progress_current,
			"progress_target": condition.progress_target
		})
	return data

## Load from save data
func load_save_data(data: Dictionary) -> void:
	if data.has("is_unlocked"):
		is_unlocked = data["is_unlocked"]
	if data.has("progress_current"):
		progress_current = data["progress_current"]
	if data.has("times_completed"):
		times_completed = data["times_completed"]
	
	if data.has("conditions_data"):
		_deserialize_conditions(data["conditions_data"])

func _deserialize_conditions(conditions_data: Array) -> void:
	for i in range(min(conditions_data.size(), conditions.size())):
		var cond_data = conditions_data[i]
		var condition = conditions[i]
		
		if cond_data.has("progress_current"):
			condition.progress_current = cond_data["progress_current"]
		if cond_data.has("progress_target"):
			condition.progress_target = cond_data["progress_target"]

## Create a copy
func duplicate() -> Achievement:
	var new_ach = Achievement.new()
	new_ach.achievement_id = achievement_id
	new_ach.achievement_name = achievement_name
	new_ach.description = description
	new_ach.icon = icon
	new_ach.logic_gate = logic_gate
	new_ach.hidden = hidden
	new_ach.category = category
	new_ach.priority = priority
	new_ach.metadata = metadata.duplicate()
	
	for condition in conditions:
		new_ach.conditions.append(condition.duplicate())
	
	return new_ach
