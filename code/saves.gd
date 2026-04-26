extends Node
"""
Save System Integration Layer - Bridges old saves.gd with new AutoSaveManager
If sth gets fucked, im blaming this or Global.
"""
const SAVE_PATH = "user://saves/"
const MAX_SLOTS = 10

# Reference to AutoSaveManager if available
var _save_manager: Node = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	# Try to get reference to AutoSaveManager
	if has_node("/root/AutoSaveManager"):
		_save_manager = get_node("/root/AutoSaveManager")

func save_game(slot: int, save_name: String) -> bool:
	# Use AutoSaveManager if available
	if _save_manager:
		return _save_manager.save_game(slot, save_name)
	
	# Fallback to legacy implementation
	if slot < 0 or slot >= MAX_SLOTS: return false
	var data = {
		"slot": slot,
		"save_name": save_name,
		"time_played": Global.time_played,
		"global_data": Global.get_save_data(),
		"scenes_data": Global.get_scenes_data(),
	}
	var file = FileAccess.open(SAVE_PATH + "slot_%d.json" % slot, FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true

func load_game(slot: int) -> bool:
	# Use AutoSaveManager if available
	if _save_manager:
		return _save_manager.load_game(slot)
	
	# Fallback to legacy implementation
	if slot < 0 or slot >= MAX_SLOTS: return false
	var path = SAVE_PATH + "slot_%d.json" % slot
	if not FileAccess.file_exists(path): return false
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	if not json or not json is Dictionary: return false
	
	Global.time_played = json.get("time_played", 0)
	Global.load_save_data(json.get("global_data", {}), json.get("scenes_data", {}))
	return true

func get_slot_info(slot: int) -> Dictionary:
	# Use AutoSaveManager if available
	if _save_manager:
		return _save_manager.get_slot_info(slot)
	
	# Fallback to legacy implementation
	var path = SAVE_PATH + "slot_%d.json" % slot
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	if not json: return {"exists": false}
	return {
		"exists": true,
		"name": json.get("save_name", "Empty"),
		"time": json.get("time_played", 0),
		"global_data": json.get("global_data", Global.get_save_data()),
		"scenes_data": Global.get_scenes_data(),
	}

func format_time(seconds: float) -> String:
	var h = int(seconds) / 3600
	var m = (int(seconds) % 3600) / 60
	var s = int(seconds) % 60
	return "%02d:%02d:%02d" % [h, m, s]

# === New AutoSaveManager Integration Methods ===
## Enable autosave functionality
func enable_autosave(interval_seconds: float = 300.0) -> void:
	if _save_manager:
		_save_manager.set_autosave_enabled(true)
		# Note: interval would need to be set via a separate method on AutoSaveManager

## Disable autosave functionality
func disable_autosave() -> void:
	if _save_manager:
		_save_manager.set_autosave_enabled(false)

## Trigger immediate autosave
func trigger_autosave() -> void:
	if _save_manager:
		_save_manager.trigger_autosave()
	else:
		save_game(0, "Autosave - " + Time.get_datetime_string_from_system(true, true))

## Delete a save slot
func delete_slot(slot: int) -> bool:
	if _save_manager:
		return _save_manager.delete_slot(slot)
	
	var path = SAVE_PATH + "slot_%d.json" % slot
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path) == OK
	return false
