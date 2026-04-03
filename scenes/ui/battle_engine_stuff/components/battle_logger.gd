class_name BattleLogger
extends Node

## Manages battle log messages (matches old engine logic)
## Supports formatted BBCode output with colored messages

signal log_updated(messages: Array)
signal message_added(message: String)

const MAX_MESSAGES = 6  # Matches old engine max_log_entries
const LOG_DISPLAY_TIME = 8.0  # Matches old engine log_display_time

var messages: Array[String] = []
var battle_root: Node2D = null
var log_timer: float = 0.0

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Adds a message to the battle log (matches old engine add_to_battle_log)
func add_message(text: String, color: String = "#FFFFFF"):
	log_timer = 0.0
	
	# Auto-format with colors based on content if not already formatted
	var formatted = text
	if not text.begins_with("[color="):
		formatted = "[color=%s]%s[/color]" % [color, text]
	
	messages.append(formatted)
	
	# Trim old messages if over limit (like old engine)
	if messages.size() > MAX_MESSAGES:
		messages.remove_at(0)
	
	message_added.emit(formatted)
	log_updated.emit(messages)
	
	return formatted

## Removes oldest log entry (matches old engine remove_oldest_log_entry)
func remove_oldest_log_entry():
	if not messages.is_empty():
		messages.remove_at(0)
		log_updated.emit(messages)

## Updates the battle log display
func update_log_display():
	if messages.is_empty():
		return ""
	else:
		return "\n".join(messages)

## Adds a damage message (matches old engine print_outcome format)
func add_damage_message(attacker: String, defender: String, damage: int, is_critical: bool = false, skill_name: String = "", mp_cost: int = 0, effects_applied: Array = []):
	var crit_text = " [color=#FFD700]★★CRIT★★[/color]" if is_critical else ""
	var attack_text = skill_name if skill_name != "" else "hit"
	
	var msg = "[color=#4CAF50]%s[/color] %s [color=#FF5722]%s[/color] for [color=#FFFFFF]%d[/color]%s" % [attacker, attack_text, defender, damage, crit_text]
	
	if mp_cost > 0:
		msg += " [color=#9C27B0](%d MP)[/color]" % mp_cost
	
	if effects_applied.size() > 0:
		msg += " [color=#E91E63]{"
		for i in range(effects_applied.size()):
			if i > 0:
				msg += ", "
			msg += str(effects_applied[i])
		msg += "}[/color]"
	
	return add_message(msg)

## Adds a miss message
func add_miss_message(attacker: String, defender: String, skill_name: String = "", mp_cost: int = 0):
	var attack_text = skill_name if skill_name != "" else "missed"
	var msg = "[color=#4CAF50]%s[/color] %s [color=#FF5722]%s[/color]" % [attacker, attack_text, defender]
	if mp_cost > 0:
		msg += " [color=#9C27B0](%d MP)[/color]" % mp_cost
	return add_message(msg)

## Adds a heal message
func add_heal_message(target: String, amount: int):
	var msg = "%s heals for [color=#90EE90]%d[/color] HP" % [target, amount]
	return add_message(msg)

## Adds a status effect message
func add_status_message(target: String, effect_name: String, applied: bool = true):
	if applied:
		var msg = "%s is afflicted with [color=#DDA0DD]%s[/color]" % [target, effect_name]
		return add_message(msg)
	else:
		var msg = "%s's [color=#DDA0DD]%s[/color] wears off" % [target, effect_name]
		return add_message(msg)

## Adds a death message
func add_death_message(unit: String):
	var msg = "[color=#8B0000]%s[/color] has fallen!" % [unit]
	return add_message(msg, "#8B0000")

## Adds an escape message
func add_escape_message(success: bool):
	if success:
		return add_message("Successfully escaped from battle!", "#90EE90")
	else:
		return add_message("Couldn't escape!", "#FF6B6B")

## Adds a level up message
func add_level_up_message(character: String, new_level: int):
	var msg = "[color=#FFD700]%s[/color] reached level [color=#FFD700]%d[/color]!" % [character, new_level]
	return add_message(msg, "#FFD700")

## Adds XP gain message
func add_xp_gain_message(character: String, xp_amount: int):
	var msg = "[color=#4CAF50]%s[/color] gained [color=#FFD700]%d[/color] XP!" % [character, xp_amount]
	return add_message(msg)

## Adds a buff message (matches old engine buff log format)
func add_buff_message(actor: String, target: String, effects: Array, mp_cost: int = 0):
	var msg = "[color=#FFD700]━━━ BUFF ━━━[/color]\n"
	msg += "[color=#4CAF50]%s[/color] buffed %s" % [actor, target]
	
	for effect in effects:
		msg += " [color=#E91E63]%s[/color]" % str(effect)
	
	if mp_cost > 0:
		msg += " [color=#9C27B0](%d MP)[/color]" % mp_cost
	
	return add_message(msg)

## Adds multi-attack message (for multi-hit skills)
func add_multi_attack_message(attacker: String, defender: String, total_damage: int, hits: int, total_hits: int, crits: int = 0, mp_cost: int = 0):
	var msg = "[color=#FFD700]━━━ MULTI-ATTACK ━━━[/color]\n"
	msg += "[color=#4CAF50]%s[/color] used attack on [color=#FF5722]%s[/color]\n" % [attacker, defender]
	msg += "[color=#03A9F4]Total: %d DMG | %d/%d hits" % [total_damage, hits, total_hits]
	if crits > 0:
		msg += " | %d CRITs" % crits
	if mp_cost > 0:
		msg += " | %d MP" % mp_cost
	msg += "[/color]"
	return add_message(msg)

## Adds enemy info message (for Check skill)
func add_enemy_info_message(enemy_name: String, description: String, hp: int, max_hp: int, atk: int):
	var msg = "[color=#2196F3]━━━ ENEMY INFO ━━━[/color]\n"
	msg += "[color=#FF5722]%s[/color]: %s\n" % [enemy_name, description]
	msg += "[color=#4CAF50]HP: %d/%d[/color] [color=#FFC107]ATK: %d[/color]" % [hp, max_hp, atk]
	return add_message(msg)

## Clears the battle log
func clear_log():
	messages.clear()
	log_updated.emit(messages)

## Gets all messages
func get_messages() -> Array:
	return messages

## Gets the last N messages
func get_last_messages(count: int) -> Array:
	var start = max(0, messages.size() - count)
	return messages.slice(start)

## Process function for log timer
func _process(delta: float):
	if not messages.is_empty():
		log_timer += delta
		if log_timer >= LOG_DISPLAY_TIME:
			log_timer = 0.0
			remove_oldest_log_entry()
