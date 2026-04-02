class_name BattleEndConditionChecker
extends Node

## Checks for battle end conditions (victory/defeat)

signal victory_achieved()
signal defeat_suffered()
signal custom_condition_met(condition_name: String)

var battle_root: Node2D = null
var logger: BattleLogger = null
var custom_conditions: Dictionary = {} # condition_name -> Callable

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root
	logger = root.logger

## Checks if all enemies are defeated
func check_victory(enemies: Array) -> bool:
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead():
			return false
	
	victory_achieved.emit()
	return true

## Checks if all party members are defeated
func check_defeat(party: Array) -> bool:
	for member in party:
		if is_instance_valid(member) and not member.is_dead():
			return false
	
	defeat_suffered.emit()
	return true

## Registers a custom end condition
func register_custom_condition(name: String, condition_func: Callable):
	custom_conditions[name] = condition_func

## Checks all custom conditions
func check_custom_conditions() -> String:
	for condition_name in custom_conditions:
		var condition_func = custom_conditions[condition_name]
		if condition_func.call():
			custom_condition_met.emit(condition_name)
			return condition_name
	
	return ""

## Performs victory actions (XP distribution, etc.)
func on_victory(party: Array, enemies: Array):
	if logger:
		logger.add_message("[color=#FFD700]Victory![/color]", "#FFD700")
	
	# Distribute XP to party members
	var total_xp = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			total_xp += enemy.get_xp_reward() if enemy.has_method("get_xp_reward") else 10
	
	for member in party:
		if is_instance_valid(member) and not member.is_dead():
			member.gain_xp(total_xp) if member.has_method("gain_xp") else null

## Performs defeat actions (game over screen, etc.)
func on_defeat():
	if logger:
		logger.add_message("[color=#8B0000]Defeat...[/color]", "#8B0000")
	
	# Trigger game over
	if battle_root and battle_root.has_method("show_game_over"):
		battle_root.show_game_over()

## Resets custom conditions
func clear_custom_conditions():
	custom_conditions.clear()
