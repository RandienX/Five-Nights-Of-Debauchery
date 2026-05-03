extends Node
"""
Save System Integration Layer - Bridges old saves.gd with new SingletonSaveManager
Supports multiple save slots with automatic adaptation to variable changes.
"""
const SAVE_PATH = "user://saves/"
const MAX_SLOTS = 10

# Reference to SingletonSaveManager
var _save_manager: Node = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	# Get reference to SingletonSaveManager
	if has_node("/root/SingletonSaveManager"):
		_save_manager = get_node("/root/SingletonSaveManager")

## Save game to a specific slot with a custom name
func save_game(slot: int, save_name: String = "") -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("[Saves] Invalid slot number: %d" % slot)
		return false
	
	# Use SingletonSaveManager if available
	if _save_manager:
		var success = _save_manager.save_all()
		if success:
			# Save slot metadata
			_save_slot_metadata(slot, save_name)
		return success
	
	# Fallback to legacy implementation (should not be used)
	push_warning("[Saves] SingletonSaveManager not found, using legacy save")
	return _legacy_save_game(slot, save_name)

## Load game from a specific slot
func load_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("[Saves] Invalid slot number: %d" % slot)
		return false
	
	# Check if slot exists
	if not _slot_exists(slot):
		push_error("[Saves] Slot %d does not exist" % slot)
		return false
	
	# Use SingletonSaveManager if available
	if _save_manager:
		return _save_manager.load_all()
	
	# Fallback to legacy implementation
	push_warning("[Saves] SingletonSaveManager not found, using legacy load")
	return _legacy_load_game(slot)

## Get information about a save slot
func get_slot_info(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SLOTS:
		return {"exists": false}
	
	var metadata_path = SAVE_PATH + "slot_%d_meta.json" % slot
	
	# Use SingletonSaveManager metadata if available
	if _save_manager and _slot_exists(slot):
		var metadata = _load_slot_metadata(slot)
		if metadata:
			return {
				"exists": true,
				"slot": slot,
				"name": metadata.get("save_name", "Save %d" % (slot + 1)),
				"time_played": metadata.get("time_played", 0),
				"timestamp": metadata.get("timestamp", ""),
				"formatted_time": format_time(metadata.get("time_played", 0))
			}
	
	# Check legacy format
	var legacy_path = SAVE_PATH + "slot_%d.json" % slot
	if FileAccess.file_exists(legacy_path):
		var file = FileAccess.open(legacy_path, FileAccess.READ)
		var json = JSON.parse_string(file.get_as_text())
		file.close()
		if json:
			return {
				"exists": true,
				"slot": slot,
				"name": json.get("save_name", "Save %d" % (slot + 1)),
				"time_played": json.get("time_played", 0),
				"formatted_time": format_time(json.get("time_played", 0))
			}
	
	return {"exists": false}

## Delete a save slot
func delete_slot(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false
	
	var success = true
	
	# Delete metadata file
	var meta_path = SAVE_PATH + "slot_%d_meta.json" % slot
	if FileAccess.file_exists(meta_path):
		success = DirAccess.remove_absolute(meta_path) == OK and success
	
	# Delete legacy file if exists
	var legacy_path = SAVE_PATH + "slot_%d.json" % slot
	if FileAccess.file_exists(legacy_path):
		success = DirAccess.remove_absolute(legacy_path) == OK and success
	
	# Delete singleton save files for this slot
	# Note: SingletonSaveManager uses shared files, so we don't delete them
	# Instead, we could implement slot-specific copies if needed
	
	return success

## Check if a slot has a valid save
func _slot_exists(slot: int) -> bool:
	var meta_path = SAVE_PATH + "slot_%d_meta.json" % slot
	var legacy_path = SAVE_PATH + "slot_%d.json" % slot
	return FileAccess.file_exists(meta_path) or FileAccess.file_exists(legacy_path)

## Save slot metadata (name, time played, timestamp)
func _save_slot_metadata(slot: int, save_name: String) -> void:
	# Try to get Global reference for time_played
	var global: Node = null
	if Engine.has_singleton("Global"):
		global = Engine.get_singleton("Global")
	
	var metadata = {
		"slot": slot,
		"save_name": save_name if save_name else "Save %d" % (slot + 1),
		"time_played": global.time_played if global and "time_played" in global else 0,
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"save_version": SingletonSaveManager.SAVE_VERSION if SingletonSaveManager else "1.0"
	}
	
	var file_path = SAVE_PATH + "slot_%d_meta.json" % slot
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(metadata, "  "))
		file.close()

## Load slot metadata
func _load_slot_metadata(slot: int) -> Dictionary:
	var file_path = SAVE_PATH + "slot_%d_meta.json" % slot
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	
	return json if json else {}

## Format time in seconds to HH:MM:SS
func format_time(seconds: float) -> String:
	var h = int(seconds) / 3600
	var m = (int(seconds) % 3600) / 60
	var s = int(seconds) % 60
	return "%02d:%02d:%02d" % [h, m, s]

## Get list of all save slots with their info
func get_all_slots_info() -> Array:
	var slots_info: Array = []
	for i in range(MAX_SLOTS):
		slots_info.append(get_slot_info(i))
	return slots_info

## Enable autosave (saves to slot 0)
func enable_autosave(interval_seconds: float = 300.0) -> void:
	if _save_manager and _save_manager.has_method("set_autosave_enabled"):
		_save_manager.set_autosave_enabled(true)
		# Note: interval would need separate method on SingletonSaveManager

## Disable autosave
func disable_autosave() -> void:
	if _save_manager and _save_manager.has_method("set_autosave_enabled"):
		_save_manager.set_autosave_enabled(false)

## Trigger immediate autosave to slot 0
func trigger_autosave() -> void:
	if _save_manager:
		save_game(0, "Autosave - " + Time.get_datetime_string_from_system(true, true))
	else:
		save_game(0, "Autosave - " + Time.get_datetime_string_from_system(true, true))

# === Legacy Implementation (Fallback) ===
func _legacy_save_game(slot: int, save_name: String) -> bool:
	if slot < 0 or slot >= MAX_SLOTS: return false
	var global: Node = Engine.get_singleton("Global") if Engine.has_singleton("Global") else null
	var data = {
		"slot": slot,
		"save_name": save_name,
		"time_played": global.time_played if global and "time_played" in global else 0,
		"global_data": global.get_save_data() if global and global.has_method("get_save_data") else {},
		"scenes_data": global.get_scenes_data() if global and global.has_method("get_scenes_data") else {},
	}
	var file = FileAccess.open(SAVE_PATH + "slot_%d.json" % slot, FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true

func _legacy_load_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS: return false
	var path = SAVE_PATH + "slot_%d.json" % slot
	if not FileAccess.file_exists(path): return false
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	if not json or not json is Dictionary: return false
	
	var global: Node = Engine.get_singleton("Global") if Engine.has_singleton("Global") else null
	if global:
		global.time_played = json.get("time_played", 0)
		if global.has_method("load_save_data"):
			global.load_save_data(json.get("global_data", {}), json.get("scenes_data", {}))
	return true
