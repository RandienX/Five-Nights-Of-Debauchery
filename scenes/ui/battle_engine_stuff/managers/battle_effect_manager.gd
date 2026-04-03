class_name BattleEffectManager
extends Node

## Manages all status effects in battle
## Based on tech_demo1_engine.gd effect system logic

signal effect_applied(target: Object, effect: Global.effect, level: int)
signal effect_removed(target: Object, effect: Global.effect)
signal effects_updated()

var effect_durations: Dictionary = {}  # {target: {effect: [level, duration]}}
var battle_root: Node2D = null

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Gets the effect level for a target
func get_effect_level(target: Object, effect: Global.effect) -> int:
	if target.effects.has(effect) and target.effects[effect].size() >= 1:
		return target.effects[effect][0]
	return 0

## Gets the effect duration for a target
func get_effect_duration(target: Object, effect: Global.effect) -> int:
	if target.effects.has(effect) and target.effects[effect].size() >= 2:
		return target.effects[effect][1]
	return 0

## Gets the multiplier for an effect
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

## Removes an effect from a target
func remove_effect(target: Object, effect: Global.effect):
	if target.effects.has(effect):
		target.effects.erase(effect)
	
	if effect_durations.has(target) and effect_durations[target].has(effect):
		effect_durations[target].erase(effect)
	
	# Update UI
	update_effect_ui(target)

## Applies effects from a skill to a target
func apply_effects(target: Object, atk: Skill):
	if atk.effects:
		for effect in atk.effects.keys():
			var level = atk.effects[effect][0]
			var duration = atk.effects[effect][1]
			apply_effect(target, effect, level, duration)

## Applies a single effect to a target
func apply_effect(target: Object, effect: Global.effect, level: int, duration: int):
	if not target.effects.has(effect):
		target.effects[effect] = [0, 0]
	
	target.effects[effect][0] = max(target.effects[effect][0], level)
	target.effects[effect][1] = max(target.effects[effect][1], duration)
	
	if not effect_durations.has(target):
		effect_durations[target] = {}
	if not effect_durations[target].has(effect):
		effect_durations[target][effect] = [level, duration]
	else:
		effect_durations[target][effect][0] = max(effect_durations[target][effect][0], level)
		effect_durations[target][effect][1] = max(effect_durations[target][effect][1], duration)
	
	if effect == Global.effect.Absorption:
		apply_absorption_bonus(target, level)
	
	update_effect_ui(target)
	effect_applied.emit(target, effect, level)

## Applies effect with duration tracking
func apply_effect_duration(target: Object, effect: int, level: int, duration: int):
	if not target.effects.has(effect):
		target.effects[effect] = [0, 0]
	target.effects[effect][0] = max(target.effects[effect][0], level)
	target.effects[effect][1] = max(target.effects[effect][1], duration)
	
	if not effect_durations.has(target):
		effect_durations[target] = {}
	if not effect_durations[target].has(effect):
		effect_durations[target][effect] = [level, duration]
	else:
		effect_durations[target][effect][0] = max(effect_durations[target][effect][0], level)
		effect_durations[target][effect][1] = max(effect_durations[target][effect][1], duration)
	
	if effect == Global.effect.Absorption:
		apply_absorption_bonus(target, level)
	
	update_effect_ui(target)

## Applies absorption HP bonus
func apply_absorption_bonus(target: Object, level: int):
	var bonus = floor(target.max_stats["hp"] * 0.1 * level)
	target.max_stats["hp"] += bonus
	target.hp = min(target.hp + bonus, target.max_stats["hp"])

## Removes absorption HP bonus
func remove_absorption_bonus(target: Object, level: int):
	var bonus = floor(target.max_stats["hp"] * 0.1 * level)
	target.max_stats["hp"] -= bonus
	target.hp = min(target.hp, target.max_stats["hp"])

## Ticks all effects (reduces duration, removes expired)
func update_effects():
	var targets_to_clean = []
	
	for target in effect_durations.keys():
		if not is_instance_valid(target):
			targets_to_clean.append(target)
			continue
		
		var effects_to_remove = []
		for effect in effect_durations[target].keys():
			effect_durations[target][effect][1] -= 1
			if effect_durations[target][effect][1] <= 0:
				effects_to_remove.append(effect)
				
				# Handle absorption removal
				if effect == Global.effect.Absorption:
					remove_absorption_bonus(target, effect_durations[target][effect][0])
		
		for effect in effects_to_remove:
			remove_effect(target, effect)
		
		if effect_durations[target].is_empty():
			targets_to_clean.append(target)
	
	for target in targets_to_clean:
		effect_durations.erase(target)
	
	effects_updated.emit()

## Updates the effect UI for a target
func update_effect_ui(target: Object):
	var party_container = battle_root.get_node_or_null("Control/gui/HBoxContainer2/party")
	
	if target is Party or ("max_stats" in target):  # Party member
		if party_container:
			for i in range(party_container.get_child_count()):
				var ui = party_container.get_child(i)
				if ui.has_method("update_effects_ui"):
					ui.update_effects_ui()
	else:  # Enemy
		var slot = 0
		for i in range(5):
			if battle_root.battle and battle_root.battle.get('enemy_pos' + str(i + 1)) == target:
				slot = i + 1
				break
		if slot > 0:
			var node = battle_root.get_node_or_null("Control/enemy_ui/enemies/enemy" + str(slot))
			if node:
				var container = node.get_node_or_null("EffectContainer")
				if container:
					for child in container.get_children():
						child.queue_free()
					
					# Recreate effect icons
					for effect in target.effects.keys():
						var icon = create_effect_icon(effect)
						container.add_child(icon)

## Creates an effect icon texture
func create_effect_icon(effect: int) -> TextureRect:
	var rect = TextureRect.new()
	rect.custom_minimum_size = Vector2(EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var atlas = load(EFFECT_ATLAS_PATH) if ResourceLoader.exists(EFFECT_ATLAS_PATH) else null
	if atlas:
		var cols = EFFECT_COLS
		var row = effect / cols
		var col = effect % cols
		var region = Rect2(col * EFFECT_TILE_SIZE, row * EFFECT_TILE_SIZE, EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
		var texture = AtlasTexture.new()
		texture.atlas = atlas
		texture.region = region
		rect.texture = texture
	
	return rect

## Applies damage over time effects
func apply_damage_over_time():
	for target in effect_durations.keys():
		if not is_instance_valid(target) or target.hp <= 0:
			continue
		
		# Poison damage
		if target.effects.has(Global.effect.Poison):
			var level = get_effect_level(target, Global.effect.Poison)
			var dmg = floor(target.max_stats["hp"] * 0.05 * level)
			if dmg > 0:
				target.hp = max(0, target.hp - dmg)
		
		# Bleed damage
		if target.effects.has(Global.effect.Bleed):
			var level = get_effect_level(target, Global.effect.Bleed)
			var dmg = floor(target.max_stats["hp"] * 0.03 * level)
			if dmg > 0:
				target.hp = max(0, target.hp - dmg)

const EFFECT_ATLAS_PATH = "res://assets/battleui/status_effects.png"
const EFFECT_TILE_SIZE = 64
const EFFECT_COLS = 4
