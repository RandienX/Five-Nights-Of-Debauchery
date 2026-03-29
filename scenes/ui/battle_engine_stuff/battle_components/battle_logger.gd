extends RefCounted
class_name BattleLogger

# Manages battle log display
var battle_log: Array[String] = []
var max_log_entries: int = 6
var log_display_time: float = 8.0
var log_timer: float = 0.0

func add_to_battle_log(text: String) -> void:
	battle_log.append(text)
	if battle_log.size() > max_log_entries:
		remove_oldest_log_entry()
	log_timer = 0.0

func remove_oldest_log_entry() -> void:
	if not battle_log.is_empty():
		battle_log.pop_front()

func get_formatted_log() -> String:
	var result = ""
	for entry in battle_log:
		result += entry + "\n"
	return result.rstrip("\n")

func update_timer(delta: float) -> bool:
	# Returns true if a log entry should be removed
	log_timer += delta
	if log_timer >= log_display_time and not battle_log.is_empty():
		log_timer = 0.0
		remove_oldest_log_entry()
		return true
	return false

func clear_log() -> void:
	battle_log.clear()
	log_timer = 0.0
