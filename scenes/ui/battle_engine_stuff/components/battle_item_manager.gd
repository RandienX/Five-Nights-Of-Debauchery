class_name BattleItemManager
extends Node

## Manages item usage in battle
## Handles item selection, validation, and effects

signal item_used(user: Node2D, item: Dictionary, target: Node2D)
signal item_menu_opened()
signal item_menu_closed()

var battle_root: Node2D = null
var logger: BattleLogger = null
var effect_manager: BattleEffectManager = null

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root
	logger = root.logger
	effect_manager = root.effect_manager

## Uses an item
func use_item(user: Node2D, item: Dictionary, target: Node2D = null) -> bool:
	if not is_instance_valid(user):
		return false
	
	# Validate item
	if not validate_item(item):
		return false
	
	# Determine target if not specified
	if not target:
		target = determine_item_target(user, item)
	
	# Apply item effect
	var success = apply_item_effect(user, target, item)
	
	if success:
		item_used.emit(user, item, target)
		
		# Log the usage
		if logger:
			var user_name = user.get_character_name() if user.has_method("get_character_name") else "Unknown"
			logger.add_message("%s used [color=#90EE90]%s[/color]" % [user_name, item.name])
	
	return success

## Validates if an item can be used
func validate_item(item: Dictionary) -> bool:
	if not item.has("id"):
		return false
	
	# Check if item exists in inventory
	if battle_root and battle_root.has_method("has_item"):
		if not battle_root.has_item(item.id):
			return false
	
	# Check item count
	if battle_root and battle_root.has_method("get_item_count"):
		if battle_root.get_item_count(item.id) <= 0:
			return false
	
	return true

## Determines the appropriate target for an item
func determine_item_target(user: Node2D, item: Dictionary) -> Node2D:
	var target_type = item.get("target_type", "single_ally")
	
	match target_type:
		"self":
			return user
		"single_ally":
			return get_lowest_hp_ally(user)
		"all_allies":
			return user # Special case, handled in apply_item_effect
		"single_enemy":
			return get_random_enemy(user)
		"all_enemies":
			return user # Special case, handled in apply_item_effect
		_:
			return user

## Gets the ally with lowest HP percentage
func get_lowest_hp_ally(user: Node2D) -> Node2D:
	if not battle_root or not battle_root.has_method("get_party_members"):
		return user
	
	var party = battle_root.get_party_members()
	var lowest_hp = 1.0
	var lowest_target = user
	
	for member in party:
		if is_instance_valid(member) and not member.is_dead():
			var hp_percent = member.get_hp_percent() if member.has_method("get_hp_percent") else 1.0
			if hp_percent < lowest_hp:
				lowest_hp = hp_percent
				lowest_target = member
	
	return lowest_target

## Gets a random enemy
func get_random_enemy(user: Node2D) -> Node2D:
	if not battle_root or not battle_root.has_method("get_enemy_members"):
		return null
	
	var enemies = battle_root.get_enemy_members()
	var valid_enemies: Array[Node2D] = []
	
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead():
			valid_enemies.append(enemy)
	
	if valid_enemies.is_empty():
		return null
	
	return valid_enemies[randi() % valid_enemies.size()]

## Applies the item's effect
func apply_item_effect(user: Node2D, target: Node2D, item: Dictionary) -> bool:
	var effect_type = item.get("effect_type", "heal")
	var value = item.get("value", 0)
	
	match effect_type:
		"heal":
			return apply_heal(target, value)
		"revive":
			return apply_revive(target, value)
		"status_cure":
			return apply_status_cure(target, item.get("cure_effects", []))
		"damage":
			return apply_item_damage(user, target, value)
		"buff":
			return apply_buff(target, item.get("stat_modifiers", {}), item.get("duration", 3))
		_:
			return false

## Applies healing from an item
func apply_heal(target: Node2D, amount: int) -> bool:
	if not is_instance_valid(target) or target.is_dead():
		return false
	
	if target.has_method("heal"):
		target.heal(amount)
		
		if logger:
			var target_name = target.get_character_name() if target.has_method("get_character_name") else "Unknown"
			logger.add_heal_message(target_name, amount)
		
		return true
	
	return false

## Applies revival from an item
func apply_revive(target: Node2D, amount: int) -> bool:
	if not is_instance_valid(target):
		return false
	
	if not target.is_dead():
		return false # Can't revive someone who's not dead
	
	if target.has_method("revive"):
		target.revive(amount)
		
		if logger:
			var target_name = target.get_character_name() if target.has_method("get_character_name") else "Unknown"
			logger.add_message("%s was revived!" % [target_name], "#90EE90")
		
		return true
	
	return false

## Applies status cure from an item
func apply_status_cure(target: Node2D, effects_to_cure: Array) -> bool:
	if not is_instance_valid(target) or not effect_manager:
		return false
	
	var cured = false
	
	for effect_id in effects_to_cure:
		if effect_manager.has_effect(target, effect_id):
			effect_manager.remove_effect(target, effect_id)
			cured = true
	
	if cured and logger:
		var target_name = target.get_character_name() if target.has_method("get_character_name") else "Unknown"
		logger.add_message("%s's status ailments were cured!" % [target_name], "#90EE90")
	
	return cured

## Applies damage from an item (e.g., bomb)
func apply_item_damage(user: Node2D, target: Node2D, amount: int) -> bool:
	if not is_instance_valid(target) or target.is_dead():
		return false
	
	if target.has_method("take_damage"):
		target.take_damage(amount)
		
		if logger:
			var target_name = target.get_character_name() if target.has_method("get_character_name") else "Unknown"
			logger.add_message("%s took [color=#FF6B6B]%d[/color] damage from item!" % [target_name, amount])
		
		return true
	
	return false

## Applies buff from an item
func apply_buff(target: Node2D, stat_modifiers: Dictionary, duration: int) -> bool:
	if not is_instance_valid(target) or not effect_manager:
		return false
	
	var effect = BattleTypes.StatusEffect.new(
		"item_buff",
		"Item Buff",
		duration
	)
	effect.stat_modifiers = stat_modifiers
	
	effect_manager.apply_effect(target, effect)
	
	if logger:
		var target_name = target.get_character_name() if target.has_method("get_character_name") else "Unknown"
		logger.add_message("%s received a buff!" % [target_name], "#90EE90")
	
	return true

## Opens the item menu (emits signal for UI)
func open_item_menu():
	item_menu_opened.emit()

## Closes the item menu (emits signal for UI)
func close_item_menu():
	item_menu_closed.emit()
