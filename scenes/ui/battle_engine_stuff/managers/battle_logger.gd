class_name BattleLogger
extends Node

## Manages battle log display and history
## Based on tech_demo1_engine.gd logging logic

signal log_updated()

var battle_log: Array[String] = []
var max_log_entries: int = 6
var log_display_time: float = 8.0
var log_timer: float = 0.0
var battle_root: Node2D = null

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Processes the log timer (call from _process)
func process_log(delta: float):
	if not battle_log.is_empty():
		log_timer += delta
		if log_timer >= log_display_time:
			log_timer = 0.0
			remove_oldest_log_entry()

## Adds text to the battle log
func add_to_battle_log(text: String):
	log_timer = 0.0
	battle_log.append(text)
	if battle_log.size() > max_log_entries:
		battle_log.remove_at(0)
	update_battle_log_display()

## Removes the oldest log entry
func remove_oldest_log_entry():
	if not battle_log.is_empty():
		battle_log.remove_at(0)
		update_battle_log_display()

## Updates the battle log display
func update_battle_log_display():
	var label = battle_root.get_node_or_null("Control/enemy_ui/CenterContainer/output")
	if label is RichTextLabel:
		if battle_log.is_empty():
			label.text = ""
		else:
			label.text = "\n".join(battle_log)

## Prints attack outcome to log
func print_outcome(atk: Object, targets: Array, attack: Skill, dmg: int, crit: bool, miss: bool, mp_cost: int = 0, effects_applied: Array = []):
	var t = ""
	if targets.size() > 0:
		var attacker_color = "#4CAF50" if atk is Party or ("max_stats" in atk) else "#F44336"
		var target_color = "#FF5722" if targets[0] is Enemy or not ("max_stats" in targets[0]) else "#4CAF50"
		
		if atk == targets[0]:
			t = "[color=" + attacker_color + "]" + atk.name + "[/color] used [color=#2196F3]" + attack.name + "[/color] on self"
			if mp_cost > 0:
				t += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
		elif miss:
			t = "[color=" + attacker_color + "]" + atk.name + "[/color] missed [color=" + target_color + "]" + targets[0].name + "[/color]"
			if mp_cost > 0:
				t += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
		else:
			t = "[color=" + attacker_color + "]" + atk.name + "[/color] hit [color=" + target_color + "]" + targets[0].name + "[/color] for [color=#FFFFFF]" + str(dmg) + "[/color]"
			if crit:
				t += " [color=#FFD700]★★CRIT★★[/color]"
			if mp_cost > 0:
				t += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
			if effects_applied.size() > 0:
				t += " [color=#E91E63]{"
				for i in range(effects_applied.size()):
					if i > 0:
						t += ", "
					t += get_effect_name_with_level(effects_applied[i][0], effects_applied[i][1])
				t += "}[/color]"
	
	add_to_battle_log(t)

## Gets effect name with level
func get_effect_name_with_level(effect: Global.effect, level: int) -> String:
	match effect:
		Global.effect.Power: return "Power+" + str(level)
		Global.effect.Tough: return "Tough+" + str(level)
		Global.effect.Focus: return "Focus+" + str(level)
		Global.effect.Speed: return "Speed+" + str(level)
		Global.effect.Blind: return "Blind+" + str(level)
		Global.effect.Absorption: return "Absorption+" + str(level)
		Global.effect.Weak: return "Weak+" + str(level)
		Global.effect.Sick: return "Sick+" + str(level)
		Global.effect.Slow: return "Slow+" + str(level)
		Global.effect.Sleep: return "Sleep+" + str(level)
		Global.effect.Poison: return "Poison+" + str(level)
		Global.effect.Bleed: return "Bleed+" + str(level)
		Global.effect.Defend: return "Defend"
		Global.effect.Concentrate: return "Concentrate"
		_: return "Effect" + str(effect)

## Clears the log
func clear_log():
	battle_log.clear()
	log_timer = 0.0
	update_battle_log_display()
