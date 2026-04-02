class_name BattleLogger
extends Node

## Manages battle log messages
## Supports formatted BBCode output

signal log_updated(messages: Array)
signal message_added(message: String)

const MAX_MESSAGES = 50

var messages: Array[String] = []
var battle_root: Node2D = null

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Adds a message to the battle log
func add_message(text: String, color: String = "#FFFFFF"):
	var formatted = "[color=%s]%s[/color]" % [color, text]
	messages.append(formatted)
	
	# Trim old messages if over limit
	if messages.size() > MAX_MESSAGES:
		messages.remove_at(0)
	
	message_added.emit(formatted)
	log_updated.emit(messages)
	
	return formatted

## Adds a damage message
func add_damage_message(attacker: String, defender: String, damage: int, is_critical: bool = false, skill_name: String = ""):
	var crit_text = " [color=#FFD700](CRITICAL!)[/color]" if is_critical else ""
	var attack_text = skill_name if skill_name != "" else "attacks"
	var msg = "%s %s %s for [color=#FF6B6B]%d[/color] damage%s" % [attacker, attack_text, defender, damage, crit_text]
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
		return add_message("Failed to escape!", "#FF6B6B")

## Adds a level up message
func add_level_up_message(character: String, new_level: int):
	var msg = "[color=#FFD700]%s[/color] reached level [color=#FFD700]%d[/color]!" % [character, new_level]
	return add_message(msg, "#FFD700")

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
