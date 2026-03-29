extends Node
"""
If sth gets fucked, im blaming this or Global.
"""
const SAVE_PATH = "user://saves/"
const MAX_SLOTS = 10

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)

func save_game(slot: int, save_name: String) -> bool:
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
