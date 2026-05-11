@icon("res://icon.svg")
class_name Achievement
extends Resource
## Achievement resource - similar to Quest but with independent tracking

@export_group("Achievement Definition")
@export var achievement_name: String = "New Achievement"
@export var description: String = ""  ## Displayed in UI
@export var category: String = "General"  ## Category for filtering

@export_group("Content")
@export var steps: Array[QuestStep] = []  ## Reuse QuestStep for achievement conditions
@export var icon: Texture2D = null  ## Icon displayed in UI
@export var hidden: bool = false  ## Hide description until unlocked

@export_group("Rewards - Optional")
@export var rewards: Array[QuestEffect] = []  ## Optional rewards when unlocked

@export_group("Metadata")
@export var priority: int = 0  ## Sort order in UI
@export var is_secret: bool = false  ## Secret achievements show ??? until unlocked

@export_group("Tracking")
var unique_id: String = ""
var is_unlocked: bool = false
var unlock_time: float = 0.0

## Initialize achievement
func initialize() -> void:
	if unique_id.is_empty():
		unique_id = _generate_unique_id()

## Evaluate achievement progress
func evaluate() -> bool:
	if is_unlocked:
		return true
	
	if steps.is_empty():
		is_unlocked = true
		unlock_time = Time.get_unix_time_from_system()
		return true
	
	for step in steps:
		if not step.evaluate():
			return false
	
	# All steps complete
	is_unlocked = true
	unlock_time = Time.get_unix_time_from_system()
	
	# Execute rewards if any
	for effect in rewards:
		effect.execute()
	
	return true

## Get overall progress (0.0 to 1.0)
func get_progress_ratio() -> float:
	if steps.is_empty():
		return 1.0 if is_unlocked else 0.0
	
	var total_progress = 0.0
	for step in steps:
		total_progress += step.get_progress_ratio()
	
	return total_progress / float(steps.size())

## Get display info (handles hidden/secret achievements)
func get_display_info() -> Dictionary:
	if hidden and not is_unlocked:
		return {
			"name": "???",
			"description": "???",
			"category": category,
			"progress": 0.0,
			"is_unlocked": false,
			"is_hidden": true
		}
	
	if is_secret and not is_unlocked:
		return {
			"name": "Secret Achievement",
			"description": "???",
			"category": category,
			"progress": get_progress_ratio() * 100,
			"is_unlocked": false,
			"is_secret": true
		}
	
	return {
		"name": achievement_name,
		"description": description,
		"category": category,
		"progress": get_progress_ratio() * 100,
		"is_unlocked": is_unlocked,
		"unlock_time": unlock_time,
		"icon": icon
	}

## Generate unique ID
func _generate_unique_id() -> String:
	var hash = achievement_name.hash()
	return "achievement_%d" % hash

## Reset achievement progress
func reset() -> void:
	is_unlocked = false
	unlock_time = 0.0
	
	for step in steps:
		step.reset()

## Serialize for save (minimal - state stored in AchievementSystem)
func to_dict() -> Dictionary:
	return {
		"unique_id": unique_id,
		"is_unlocked": is_unlocked,
		"unlock_time": unlock_time
	}
