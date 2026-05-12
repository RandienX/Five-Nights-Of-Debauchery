extends Node
class_name AchievementSystemClass

signal achievement_unlocked(id: String)
signal achievement_updated(id: String, progress: float)

const SAVE_PATH = "user://achievements.json"
var achievements: Dictionary = {} # ID -> Achievement Instance
var unlocked_ids: Array = []

func _ready():
	load_achievements()

func register_achievement(res: Achievement):
	achievements[res.achievement_id] = res.duplicate()
	# Initialize runtime state if needed

func progress_achievement(id: String, amount: float = 1.0):
	if unlocked_ids.has(id): return
	if not achievements.has(id): return
	
	var ach = achievements[id]
	var stepped = ach.progress_condition(0, amount) # Assuming single condition for simplicity or specific index
	if stepped:
		achievement_updated.emit(id, ach.get_progress())
		if ach.is_complete():
			unlock_achievement(id)
		save_achievements() # Autosave instantly

func unlock_achievement(id: String):
	if unlocked_ids.has(id): return
	unlocked_ids.append(id)
	achievement_unlocked.emit(id)
	# Play sound, show notification
	notification_requested.emit("Achievement Unlocked!", achievements[id].achievement_name)

func save_achievements():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = { "unlocked": unlocked_ids }
		file.store_string(JSON.stringify(data))
		file.close()

func load_achievements():
	if not FileAccess.file_exists(SAVE_PATH): return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var json = JSON.parse_string(text)
		if json and json.has("unlocked"):
			unlocked_ids = json["unlocked"]
		file.close()

func get_progress(id: String) -> float:
	if not achievements.has(id): return 0.0
	return achievements[id].get_progress()

# Helper for notifications (shared pattern)
signal notification_requested(title: String, desc: String)
