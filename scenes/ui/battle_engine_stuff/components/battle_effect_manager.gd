class_name BattleEffectManager
extends Node

## Manages status effects on battle units
## Handles application, removal, and tick processing

signal effect_applied(unit: Node2D, effect: BattleTypes.StatusEffect)
signal effect_removed(unit: Node2D, effect_id: String)
signal effect_ticked(unit: Node2D, effect: BattleTypes.StatusEffect)

var active_effects: Dictionary = {} # unit_instance_id -> Array of StatusEffect

func _ready():
	pass

## Applies a status effect to a unit
func apply_effect(unit: Node2D, effect: BattleTypes.StatusEffect) -> bool:
	if not is_instance_valid(unit):
		return false
	
	var unit_id = unit.get_instance_id()
	
	if not active_effects.has(unit_id):
		active_effects[unit_id] = []
	
	# Check if effect already exists (stack or refresh)
	var existing_index = -1
	for i in range(active_effects[unit_id].size()):
		if active_effects[unit_id][i].id == effect.id:
			existing_index = i
			break
	
	if existing_index >= 0:
		# Refresh duration
		active_effects[unit_id][existing_index].duration = effect.duration
	else:
		# Add new effect
		active_effects[unit_id].append(effect)
	
	# Apply stat modifiers to unit
	_apply_stat_modifiers(unit, effect)
	
	effect_applied.emit(unit, effect)
	return true

## Removes a status effect from a unit
func remove_effect(unit: Node2D, effect_id: String) -> bool:
	if not is_instance_valid(unit):
		return false
	
	var unit_id = unit.get_instance_id()
	
	if not active_effects.has(unit_id):
		return false
	
	for i in range(active_effects[unit_id].size()):
		if active_effects[unit_id][i].id == effect_id:
			var effect = active_effects[unit_id][i]
			_remove_stat_modifiers(unit, effect)
			active_effects[unit_id].remove_at(i)
			effect_removed.emit(unit, effect_id)
			return true
	
	return false

## Removes all effects from a unit
func remove_all_effects(unit: Node2D):
	if not is_instance_valid(unit):
		return
	
	var unit_id = unit.get_instance_id()
	
	if active_effects.has(unit_id):
		for effect in active_effects[unit_id]:
			_remove_stat_modifiers(unit, effect)
		active_effects.erase(unit_id)

## Ticks down all effect durations and processes effects
func tick_effects():
	for unit_id in active_effects.keys():
		var unit = instance_from_id(unit_id)
		
		if not is_instance_valid(unit):
			active_effects.erase(unit_id)
			continue
		
		if unit.is_dead():
			active_effects.erase(unit_id)
			continue
		
		var effects_to_remove: Array[int] = []
		
		for i in range(active_effects[unit_id].size()):
			var effect = active_effects[unit_id][i]
			effect.duration -= 1
			
			effect_ticked.emit(unit, effect)
			
			if effect.duration <= 0:
				effects_to_remove.append(i)
		
		# Remove expired effects (reverse order to maintain indices)
		for i in range(effects_to_remove.size() - 1, -1, -1):
			var idx = effects_to_remove[i]
			var effect = active_effects[unit_id][idx]
			_remove_stat_modifiers(unit, effect)
			active_effects[unit_id].remove_at(idx)
			effect_removed.emit(unit, effect.id)

## Gets all effects on a unit
func get_effects(unit: Node2D) -> Array:
	if not is_instance_valid(unit):
		return []
	
	var unit_id = unit.get_instance_id()
	
	if active_effects.has(unit_id):
		return active_effects[unit_id]
	
	return []

## Checks if a unit has a specific effect
func has_effect(unit: Node2D, effect_id: String) -> bool:
	var effects = get_effects(unit)
	for effect in effects:
		if effect.id == effect_id:
			return true
	return false

## Applies stat modifiers from an effect to a unit
func _apply_stat_modifiers(unit: Node2D, effect: BattleTypes.StatusEffect):
	for stat in effect.stat_modifiers:
		if unit.has_method("modify_stat"):
			unit.modify_stat(stat, effect.stat_modifiers[stat])

## Removes stat modifiers from a unit
func _remove_stat_modifiers(unit: Node2D, effect: BattleTypes.StatusEffect):
	for stat in effect.stat_modifiers:
		if unit.has_method("modify_stat"):
			unit.modify_stat(stat, 1.0) # Reset to base

## Clears all effects
func clear_all():
	active_effects.clear()

## Gets effect level from a target (for compatibility with old engine)
func get_effect_level(target: Object, effect: Global.effect) -> int:
	if not is_instance_valid(target):
		return 0
	
	var unit_id = target.get_instance_id()
	if active_effects.has(unit_id):
		for e in active_effects[unit_id]:
			if e.id == str(effect):
				return e.level if e.has_method("get_level") or "level" in e else 1
	return 0

## Gets effect duration from a target
func get_effect_duration(target: Object, effect: Global.effect) -> int:
	if not is_instance_valid(target):
		return 0
	
	var unit_id = target.get_instance_id()
	if active_effects.has(unit_id):
		for e in active_effects[unit_id]:
			if e.id == str(effect):
				return e.duration
	return 0

## Gets effect multiplier for stat calculations (like old engine)
func get_effect_multiplier(target: Object, effect: Global.effect) -> float:
	var level = get_effect_level(target, effect)
	if level <= 0:
		return 1.0
	
	match effect:
		Global.effect.Power:
			return 1.0 + (level * 0.25)
		Global.effect.Tough:
			return 1.0 + (level * 0.25)
		Global.effect.Focus:
			return 1.0 + (level * 0.05)
		Global.effect.Speed:
			return 1.0 + (level * 0.1)
		Global.effect.Blind:
			return 1.0 - (level * 0.2)
		Global.effect.Absorption:
			return 1.0 + (level * 0.2)
		Global.effect.Weak:
			return 1.0 - (level * 0.2)
		Global.effect.Sick:
			return 1.0 - (level * 0.2)
		Global.effect.Slow:
			return 1.0 - (level * 0.1)
	return 1.0
