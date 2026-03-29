extends RefCounted
class_name BattleEffectManager

# Manages status effects in battle
const EFFECT_ATLAS_PATH = "res://assets/battleui/status_effects.png"
const EFFECT_TILE_SIZE = 64
const EFFECT_COLS = 4

func get_effect_level(target: Object, effect: Global.effect) -> int:
	if not target or not target.has_key("effects"):
		return 0
	if effect in target.effects:
		return target.effects[effect]
	return 0

func get_effect_duration(target: Object, effect: Global.effect) -> int:
	if not target or not target.has_key("effect_durations"):
		return 0
	if effect in target.effect_durations:
		return target.effect_durations[effect]
	return 0

func get_effect_multiplier(target: Object, effect: Global.effect) -> float:
	var level = get_effect_level(target, effect)
	if level == 0:
		return 1.0
	
	match effect:
		Global.effect.Power:
			return 1.0 + (level * 0.25)
		Global.effect.Weak:
			return 1.0 / (1.0 + (level * 0.25))
		Global.effect.Speed:
			return 1.0 + (level * 0.25)
		Global.effect.Slow:
			return 1.0 / (1.0 + (level * 0.25))
		Global.effect.Absorb:
			return 1.0 + (level * 0.15)
	return 1.0

func apply_effect(target: Object, effect: Global.effect, level: int, duration: int) -> void:
	if not target:
		return
	
	if not target.has_key("effects"):
		target.effects = {}
	if not target.has_key("effect_durations"):
		target.effect_durations = {}
	
	target.effects[effect] = level
	target.effect_durations[effect] = duration
	
	# Apply special effect bonuses
	if effect == Global.effect.Absorb:
		apply_absorption_bonus(target, level)

func remove_effect(target: Object, effect: Global.effect) -> void:
	if not target or not target.has_key("effects"):
		return
	
	if effect in target.effects:
		target.effects.erase(effect)
	if target.has_key("effect_durations") and effect in target.effect_durations:
		target.effect_durations.erase(effect)
	
	# Remove special effect bonuses
	if effect == Global.effect.Absorb:
		remove_absorption_bonus(target)

func apply_absorption_bonus(target: Object, level: int) -> void:
	if target is Party:
		target.base_stats["def"] += int(target.level_up["def"] * level)
		target.base_stats["mdf"] += int(target.level_up["mdf"] * level)

func remove_absorption_bonus(target: Object) -> void:
	if target is Party and target.has_key("effects"):
		var old_level = target.effects.get(Global.effect.Absorb, 0)
		if old_level > 0:
			target.base_stats["def"] -= int(target.level_up["def"] * old_level)
			target.base_stats["mdf"] -= int(target.level_up["mdf"] * old_level)

func get_effect_name_with_level(effect: Global.effect, level: int) -> String:
	var base_names = {
		Global.effect.Burn: "Burn",
		Global.effect.Freeze: "Freeze",
		Global.effect.Shock: "Shock",
		Global.effect.Sleep: "Sleep",
		Global.effect.Poison: "Poison",
		Global.effect.Confuse: "Confuse",
		Global.effect.Power: "Power Up",
		Global.effect.Weak: "Weak",
		Global.effect.Speed: "Haste",
		Global.effect.Slow: "Slow",
		Global.effect.Absorb: "Absorb"
	}
	
	var name = base_names.get(effect, "Unknown")
	if level > 1:
		name += " " + str(level)
	return name

func update_effects_on_all(initiative: Array[Object]) -> void:
	for actor in initiative:
		if not actor or not actor.has_key("effect_durations"):
			continue
		
		var to_remove: Array[Global.effect] = []
		for effect in actor.effect_durations:
			actor.effect_durations[effect] -= 1
			if actor.effect_durations[effect] <= 0:
				to_remove.append(effect)
		
		for effect in to_remove:
			remove_effect(actor, effect)
