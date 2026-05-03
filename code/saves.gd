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
	if has_node("/root/SaveManager"):
		_save_manager = get_node("/root/SaveManager")

func save_game(slot: int, save_name: String):
	# Use AutoSaveManager if available
	_save_manager.save_game(slot, save_name)

func load_game(slot: int):
	# Use AutoSaveManager if available
	_save_manager.load_game(slot)
	

func get_slot_info(slot: int) -> Dictionary:
	# Use AutoSaveManager if available
	return _save_manager.get_slot_info(slot)

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
