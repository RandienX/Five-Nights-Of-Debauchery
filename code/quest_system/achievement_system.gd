@icon("res://icon.svg")
extends Node
## AchievementSystem - Independent achievement tracking with separate persistence
##
## Features:
## - Reuses Quest condition/evaluation logic
## - Separate autosave to user://achievements.json
## - Instant save on state change
## - Independent lifecycle from quest system

signal achievement_unlocked(achievement: Achievement)
signal achievement_progress_updated(achievement: Achievement, progress: float)
signal achievement_ui_notification(achievement: Achievement, message: String)

const SAVE_PATH := "user://achievements.json"
const EVALUATION_INTERVAL := 1.0

var achievements: Array[Achievement] = []
var unlocked_achievements: Array[String] = []  ## Store unique IDs of unlocked

var _evaluation_running := false
var _auto_save_enabled := true
var _debug_mode := false

## Reference to achievement UI (set by game_menu)
var achievement_ui: Control = null

func _ready() -> void:
	_start_evaluation_loop()
	_load_achievements()
	_print_debug("AchievementSystem initialized")

func _start_evaluation_loop() -> void:
	_evaluation_running = true
	_evaluate_achievements_loop()

func _evaluate_achievements_loop() -> void:
	while _evaluation_running:
		await get_tree().create_timer(EVALUATION_INTERVAL).timeout
		_evaluate_all_achievements()

func _evaluate_all_achievements() -> void:
	for achievement in achievements:
		if not achievement or achievement.is_unlocked:
			continue
		
		var was_progress = achievement.get_progress_ratio()
		var is_complete = achievement.evaluate()
		
		if achievement.get_progress_ratio() > was_progress:
			achievement_progress_updated.emit(achievement, achievement.get_progress_ratio())
		
		if is_complete and not achievement.is_unlocked:
			_unlock_achievement(achievement)

func _unlock_achievement(achievement: Achievement) -> void:
	achievement.is_unlocked = true
	achievement.unlock_time = Time.get_unix_time_from_system()
	unlocked_achievements.append(achievement.unique_id)
	
	_print_debug("Achievement unlocked: %s" % achievement.achievement_name)
	achievement_unlocked.emit(achievement)
	_show_notification(achievement, "Achievement Unlocked!")
	
	if _auto_save_enabled:
		_save_achievements()

func _show_notification(achievement: Achievement, message: String) -> void:
	achievement_ui_notification.emit(achievement, message)
	
	if achievement_ui and achievement_ui.has_method("show_notification"):
		achievement_ui.show_notification(achievement, message)

## Load all achievement definitions from resources
func _load_achievements() -> void:
	achievements.clear()
	
	# Load from standard path
	var dir = DirAccess.open("res://resources/achievements/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".resource"):
				var path = "res://resources/achievements/" + file_name
				var res = load(path)
				if res is Achievement:
					var achievement = res.duplicate()
					achievement.initialize()
					achievements.append(achievement)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	# Restore unlock states
	_load_unlock_states()
	_print_debug("Loaded %d achievements" % achievements.size())

func _load_unlock_states() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[AchievementSystem] Failed to parse achievements.json")
		return
	
	var data = json.data
	if data is Dictionary:
		unlocked_achievements = data.get("unlocked_ids", [])
		
		# Mark achievements as unlocked
		for achievement in achievements:
			if achievement.unique_id in unlocked_achievements:
				achievement.is_unlocked = true
				achievement.unlock_time = data.get("unlock_times", {}).get(achievement.unique_id, 0.0)

## Save achievements to isolated file
func _save_achievements() -> void:
	var unlock_times: Dictionary = {}
	for achievement in achievements:
		if achievement.is_unlocked:
			unlock_times[achievement.unique_id] = achievement.unlock_time
	
	var data = {
		"version": 1,
		"saved_at": Time.get_datetime_string_from_system(true, true),
		"unlocked_ids": unlocked_achievements,
		"unlock_times": unlock_times
	}
	
	var json_string = JSON.stringify(data, "\t")
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[AchievementSystem] Failed to open achievements.json for writing")
		return
	
	file.store_string(json_string)
	file.close()
	
	_print_debug("Achievements saved")

## Progress an achievement condition - scene-agnostic
func progress_achievement(achievement_id: String, condition_type: QuestPointCondition.ConditionType, 
	key: String, amount: float = 1.0) -> void:
	var achievement = _get_achievement_by_id(achievement_id)
	if not achievement or achievement.is_unlocked:
		return
	
	for step in achievement.steps:
		var point = step.get_current_point()
		if not point:
			continue
		
		for condition in point.conditions:
			if condition.type == condition_type and condition.target_key == key:
				var old_ratio = condition.get_progress_ratio()
				condition.progress_current += amount
				var new_ratio = condition.get_progress_ratio()
				
				if new_ratio > old_ratio:
					_print_debug("Achievement progress: %s [%s] %.1f -> %.1f" % [
						achievement.achievement_name, key, old_ratio * 100, new_ratio * 100
					])

func _get_achievement_by_id(unique_id: String) -> Achievement:
	for achievement in achievements:
		if achievement.unique_id == unique_id:
			return achievement
	return null

## Get achievement by unique ID
func get_achievement(unique_id: String) -> Achievement:
	return _get_achievement_by_id(unique_id)

## Get all achievements
func get_all_achievements() -> Array[Achievement]:
	return achievements

## Get unlocked achievements
func get_unlocked_achievements() -> Array[Achievement]:
	var unlocked: Array[Achievement] = []
	for achievement in achievements:
		if achievement.is_unlocked:
			unlocked.append(achievement)
	return unlocked

## Get locked achievements
func get_locked_achievements() -> Array[Achievement]:
	var locked: Array[Achievement] = []
	for achievement in achievements:
		if not achievement.is_unlocked:
			locked.append(achievement)
	return locked

## Get progress summary
func get_progress_summary() -> Dictionary:
	var total = achievements.size()
	var unlocked_count = unlocked_achievements.size()
	
	return {
		"total": total,
		"unlocked": unlocked_count,
		"locked": total - unlocked_count,
		"percentage": (float(unlocked_count) / float(total) * 100) if total > 0 else 0.0
	}

## Manual unlock (for debug/special cases)
func force_unlock(achievement_id: String) -> bool:
	var achievement = _get_achievement_by_id(achievement_id)
	if not achievement:
		return false
	
	if not achievement.is_unlocked:
		_unlock_achievement(achievement)
	return true

## Reset achievement (for testing)
func reset_achievement(achievement_id: String) -> bool:
	var achievement = _get_achievement_by_id(achievement_id)
	if not achievement:
		return false
	
	achievement.is_unlocked = false
	achievement.unlock_time = 0.0
	
	if achievement_id in unlocked_achievements:
		unlocked_achievements.erase(achievement_id)
	
	# Reset progress
	for step in achievement.steps:
		step.reset()
	
	_print_debug("Reset achievement: %s" % achievement.achievement_name)
	return true

## Reset all achievements (dangerous!)
func reset_all_achievements() -> void:
	for achievement in achievements:
		achievement.is_unlocked = false
		achievement.unlock_time = 0.0
		
		for step in achievement.steps:
			step.reset()
	
	unlocked_achievements.clear()
	
	if _auto_save_enabled:
		_save_achievements()
	
	_print_debug("All achievements reset")

## Debug utilities
func set_debug_mode(enabled: bool) -> void:
	_debug_mode = enabled

func _print_debug(message: String) -> void:
	if _debug_mode:
		print("[AchievementSystem] %s" % message)

func get_debug_info() -> Dictionary:
	return {
		"total_achievements": achievements.size(),
		"unlocked_count": unlocked_achievements.size(),
		"evaluation_running": _evaluation_running,
		"auto_save_enabled": _auto_save_enabled
	}

## Cleanup
func _exit_tree() -> void:
	_evaluation_running = false
	if _auto_save_enabled:
		_save_achievements()
