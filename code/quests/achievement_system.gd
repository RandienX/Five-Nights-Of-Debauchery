extends Node
class_name AchievementSystemClass

## AchievementSystem - Manages achievements with separate autosave
##
## Achievements are saved separately from regular saves and autosave
## on every change. Checks one achievement every 6 physics frames.

signal achievement_unlocked(achievement: Achievement)
signal achievement_progress_updated(achievement: Achievement)

# Singleton access
static var instance: AchievementSystemClass = null

const ACHIEVEMENT_SAVE_PATH := "user://achievements.json"

var achievements: Dictionary = {}  # achievement_id -> Achievement
var unlocked_achievements: Array[Achievement] = []
var locked_achievements: Array[Achievement] = []

# Physics frame counter for staggered checking
var _frame_counter: int = 0
var _achievements_to_check: Array[Achievement] = []

func _init():
	instance = self

func _ready() -> void:
	set_physics_process(true)
	_load_achievements()

func _physics_process(_delta: float) -> void:
	_frame_counter += 1
	
	# Check one achievement every 6 physics frames
	if _frame_counter >= 6:
		_frame_counter = 0
		_check_next_achievement()

## Add an achievement to track
func add_achievement(achievement: Achievement) -> bool:
	if not achievement or achievement.achievement_id.is_empty():
		push_error("[AchievementSystem] Cannot add achievement without valid ID")
		return false
	
	if achievements.has(achievement.achievement_id):
		push_warning("[AchievementSystem] Achievement '%s' already exists" % achievement.achievement_id)
		return false
	
	achievements[achievement.achievement_id] = achievement
	
	if achievement.is_unlocked:
		unlocked_achievements.append(achievement)
	else:
		locked_achievements.append(achievement)
		_achievements_to_check.append(achievement)
	
	return true

## Add achievement by resource path
func add_achievement_by_path(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_error("[AchievementSystem] Achievement not found: %s" % path)
		return false
	
	var achievement = load(path) as Achievement
	if not achievement:
		push_error("[AchievementSystem] Failed to load achievement: %s" % path)
		return false
	
	return add_achievement(achievement)

## Add achievement by ID
func add_achievement_by_id(achievement_id: String) -> bool:
	var paths = [
		"res://resources/achievements/%s.tres" % achievement_id,
		"res://resources/achievements/%s.resource" % achievement_id,
		"res://achievements/%s.tres" % achievement_id
	]
	
	for path in paths:
		if ResourceLoader.exists(path):
			return add_achievement_by_path(path)
	
	push_error("[AchievementSystem] Achievement not found: %s" % achievement_id)
	return false

## Unlock an achievement
func unlock_achievement(achievement_id: String) -> bool:
	if not achievement_id in achievements:
		return false
	
	var achievement = achievements[achievement_id]
	if achievement.is_unlocked:
		return false
	
	achievement.unlock()
	locked_achievements.erase(achievement)
	unlocked_achievements.append(achievement)
	_achievements_to_check.erase(achievement)
	
	achievement_unlocked.emit(achievement)
	_save_achievements()  # Autosave on unlock
	
	print("[AchievementSystem] Unlocked: %s" % achievement.achievement_name)
	return true

## Update progress for achievements matching condition type/target
func update_progress(type: QuestPointCondition.ConditionType, target_key: String, amount: float = 1.0) -> void:
	for achievement in _achievements_to_check:
		if achievement.update_progress(type, target_key, amount):
			# Check if complete
			if achievement.is_complete():
				unlock_achievement(achievement.achievement_id)
			else:
				achievement_progress_updated.emit(achievement)
				_save_achievements()  # Autosave on progress

## Check next achievement in rotation (one per 6 physics frames)
func _check_next_achievement() -> void:
	if _achievements_to_check.is_empty():
		return
	
	# Get first achievement to check
	var achievement = _achievements_to_check[0]
	
	# Evaluate its conditions
	if achievement.is_complete():
		unlock_achievement(achievement.achievement_id)
	
	# Move to end of queue for round-robin
	_achievements_to_check.append(_achievements_to_check.pop_front())

## Get achievement by ID
func get_achievement(achievement_id: String) -> Achievement:
	if achievement_id in achievements:
		return achievements[achievement_id]
	return null

## Check if achievement is unlocked
func is_achievement_unlocked(achievement_id: String) -> bool:
	var achievement = get_achievement(achievement_id)
	return achievement != null and achievement.is_unlocked

## Get all unlocked achievements
func get_unlocked_achievements() -> Array:
	return unlocked_achievements

## Get all locked achievements
func get_locked_achievements() -> Array:
	return locked_achievements

## Get all achievements sorted by category and priority
func get_sorted_achievements() -> Array:
	var sorted = achievements.values().duplicate_deep()
	sorted.sort_custom(func(a, b):
		if a.category != b.category:
			return a.category < b.category
		return a.priority > b.priority
	)
	return sorted

## Get completion percentage across all achievements
func get_completion_percentage() -> float:
	if achievements.is_empty():
		return 0.0
	
	return float(unlocked_achievements.size()) / float(achievements.size()) * 100.0

## Save achievements to separate file (autosave)
func _save_achievements() -> void:
	var data := {
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"achievements": []
	}
	
	for achievement in achievements.values():
		data["achievements"].append(achievement.get_save_data())
	
	var file = FileAccess.open(ACHIEVEMENT_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[AchievementSystem] Achievements autosaved")
	else:
		push_error("[AchievementSystem] Failed to save achievements")

## Load achievements from separate file
func _load_achievements() -> void:
	if not FileAccess.file_exists(ACHIEVEMENT_SAVE_PATH):
		print("[AchievementSystem] No achievement save file found")
		return
	
	var file = FileAccess.open(ACHIEVEMENT_SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[AchievementSystem] Failed to open achievement save file")
		return
	
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		push_error("[AchievementSystem] Failed to parse achievement save: %s" % json.get_error_message())
		return
	
	var data = json.get_data()
	if not data is Dictionary or not data.has("achievements"):
		push_error("[AchievementSystem] Invalid achievement save data")
		return
	
	# Apply save data to existing achievements
	for achievement_data in data["achievements"]:
		var achievement_id = achievement_data.get("achievement_id", "")
		if achievement_id in achievements:
			achievements[achievement_id].load_save_data(achievement_data)
	
	# Rebuild lists
	unlocked_achievements.clear()
	locked_achievements.clear()
	_achievements_to_check.clear()
	
	for achievement in achievements.values():
		if achievement.is_unlocked:
			unlocked_achievements.append(achievement)
		else:
			locked_achievements.append(achievement)
			_achievements_to_check.append(achievement)
	
	print("[AchievementSystem] Achievements loaded")

## Reset all achievements
func reset_all_achievements() -> void:
	for achievement in achievements.values():
		achievement.reset()
	
	unlocked_achievements.clear()
	locked_achievements.clear()
	_achievements_to_check.clear()
	
	for achievement in achievements.values():
		locked_achievements.append(achievement)
		_achievements_to_check.append(achievement)
	
	# Clear save file
	var file = FileAccess.open(ACHIEVEMENT_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.close()
