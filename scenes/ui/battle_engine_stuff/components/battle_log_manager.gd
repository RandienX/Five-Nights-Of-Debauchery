extends Node
class_name LogManager

var root
var effect_manager

func setup(broot, e_mgr):
	root = broot
	effect_manager = e_mgr

# Each log entry stores the text and its remaining display time
var battle_log: Array[Dictionary] = []
var max_log_entries: int = 6
var log_display_time: float = 8.0

func _process(delta: float) -> void:
	# Update timers for each log entry
	for i in range(battle_log.size() - 1, -1, -1):
		battle_log[i]["time_left"] -= delta
		if battle_log[i]["time_left"] <= 0:
			battle_log.remove_at(i)
	
	# Enforce max entries limit (remove oldest if exceeded)
	while battle_log.size() > max_log_entries:
		battle_log.remove_at(0)
	
	update_battle_log_display()

func add_to_battle_log(text: String) -> void:
	# Split text into lines and add each line as a separate log entry
	var lines = text.split("\n")
	for line in lines:
		if not line.is_empty():
			battle_log.append({
				"text": line,
				"time_left": log_display_time
			})
	
	# Enforce max entries limit immediately after adding
	while battle_log.size() > max_log_entries:
		battle_log.remove_at(0)
	
	update_battle_log_display()

func remove_oldest_log_entry() -> void:
	if not battle_log.is_empty():
		battle_log.remove_at(0)
		update_battle_log_display()

func update_battle_log_display() -> void:
	if battle_log.is_empty():
		root.get_node("Control/enemy_ui/CenterContainer/output").text = ""
	else:
		var display_text = ""
		for i in range(battle_log.size()):
			if i > 0:
				display_text += "\n"
			display_text += battle_log[i]["text"]
		root.get_node("Control/enemy_ui/CenterContainer/output").text = display_text

func print_outcome(atk: Object, targets: Array, attack: Skill, dmg: int, crit: bool, miss: bool, mp_cost: int = 0, effects_applied: Array = []):
	var t = ""
	if targets.size() > 0:
		var attacker_color = "#4CAF50" if atk is Party else "#F44336"
		var target_color = "#FF5722" if targets[0] is Enemy else "#4CAF50"
		
		if atk == targets[0]:
			t = "[color=" + attacker_color + "]" + atk.name + "[/color] used [color=#2196F3]" + attack.name + "[/color] on self"
			if mp_cost > 0: t += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
		elif miss:
			t = "[color=" + attacker_color + "]" + atk.name + "[/color] missed [color=" + target_color + "]" + targets[0].name + "[/color]"
			if mp_cost > 0: t += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
		else:
			t = "[color=" + attacker_color + "]" + atk.name + "[/color] hit [color=" + target_color + "]" + targets[0].name + "[/color] for [color=#FFFFFF]" + str(dmg) + "[/color]"
			if crit: t += " [color=#FFD700]★★CRIT★★[/color]"
			if mp_cost > 0: t += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
			if effects_applied.size() > 0:
				t += " [color=#E91E63]{"
				for i in range(effects_applied.size()):
					if i > 0: t += ", "
					t += effect_manager.get_effect_name_with_level(effects_applied[i][0], effects_applied[i][1])
				t += "}[/color]"
	add_to_battle_log(t)
