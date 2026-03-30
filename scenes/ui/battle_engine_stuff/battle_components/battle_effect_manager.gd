extends RefCounted
class_name BattleEffectManager

# Manages status effects in battle - uses Global.effect enum format [level, duration]
const EFFECT_ATLAS_PATH = "res://assets/battleui/status_effects.png"
const EFFECT_TILE_SIZE = 64
const EFFECT_COLS = 4

func get_effect_level(target: Object, effect: Global.effect) -> int:
	if not target or not target.has_key("effects"):
		return 0
	if effect in target.effects and target.effects[effect] is Array and target.effects[effect].size() >= 1:
		return target.effects[effect][0]
	return 0

func get_effect_duration(target: Object, effect: Global.effect) -> int:
	if not target or not target.has_key("effects"):
		return 0
	if effect in target.effects and target.effects[effect] is Array and target.effects[effect].size() >= 2:
		return target.effects[effect][1]
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
			return 1.0 + (level * 0.1)
		Global.effect.Slow:
			return 1.0 / (1.0 + (level * 0.1))
		Global.effect.Tough:
			return 1.0 + (level * 0.25)
		Global.effect.Sick:
			return 1.0 / (1.0 + (level * 0.25))
		Global.effect.Focus:
			return 1.0 + (level * 0.05)
		Global.effect.Blind:
			return 1.0 / (1.0 + (level * 0.2))
	return 1.0

func apply_effect(target: Object, effect: Global.effect, level: int, duration: int) -> void:
	if not target:
		return
	
	if not target.has_key("effects"):
		target.effects = {}
	
	if effect not in target.effects or not target.effects[effect] is Array:
		target.effects[effect] = [0, 0]
	
	target.effects[effect][0] = max(target.effects[effect][0], level)
	target.effects[effect][1] = max(target.effects[effect][1], duration)

func remove_effect(target: Object, effect: Global.effect) -> void:
	if not target or not target.has_key("effects"):
		return
	
	if effect in target.effects:
		target.effects.erase(effect)

func apply_absorption_bonus(target: Object, level: int) -> void:
	if target is Party:
		target.base_stats["def"] += int(target.level_up["def"] * level)
		target.base_stats["mdf"] += int(target.level_up["mdf"] * level)

func remove_absorption_bonus(target: Object, old_level: int) -> void:
	if target is Party and old_level > 0:
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
		Global.effect.Absorb: "Absorb",
		Global.effect.Tough: "Tough",
		Global.effect.Sick: "Sick",
		Global.effect.Focus: "Focus",
		Global.effect.Blind: "Blind"
	}
	
	var name = base_names.get(effect, "Unknown")
	if level > 1:
		name += " " + str(level)
	return name

func update_effects_on_all(initiative: Array[Object]) -> void:
	for actor in initiative:
		if not actor or not actor.has_key("effects"):
			continue
		
		var to_remove: Array[Global.effect] = []
		for effect in actor.effects:
			if actor.effects[effect] is Array and actor.effects[effect].size() >= 2:
				actor.effects[effect][1] -= 1
				if actor.effects[effect][1] <= 0:
					to_remove.append(effect)
		
		for effect in to_remove:
			remove_effect(actor, effect)
