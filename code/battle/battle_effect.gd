@tool
class_name BattleEffect
extends Resource

## Effect that runs during battle (on skill use, on turn start, on hit, etc.)
## This is a complete replacement for Global.effect enum system.
## All effects from Global.effect can be recreated using this resource.

## Status effect types matching Global.effect enum for compatibility
enum StatusEffect {
	Heal,           # Gradually restores HP over time
	Mana_Heal,      # Gradually restores MP over time
	Blind,          # Reduces accuracy
	Poison,         # Deals damage over time
	Bleed,          # Deals stronger damage over time, not healable by items
	Power,          # Increases damage dealt
	Tough,          # Increases defense
	Focus,          # Increases accuracy
	Defend,         # Reduces damage taken
	Kill,           # Chance to instantly kill non-boss enemies
	Absorb,         # Increases max HP temporarily
	Revive,         # Revives knocked out ally
	Sick,           # Reduces effectiveness of healing
	Weak,           # Reduces damage dealt
	Slow,           # Reduces speed/initiative
	Sleep,          # Skips turns until hit
	Burn,           # Deals damage over time, reduces attack
	Freeze,         # Skips turns, deals damage
	Paralyzed,      # Chance to skip turn, reduces speed
	Shock,          # Random stat reductions
	Confuse         # May cause attacking self or allies
}

enum EffectType {
	# Stat Modification
	MODIFY_STAT,          # Modify a stat temporarily or permanently
	SET_STAT,             # Set a stat to a specific value
	
	# Health/MP
	HEAL_HP,              # Restore HP
	HEAL_MP,              # Restore MP
	DAMAGE_HP,            # Deal HP damage
	DAMAGE_MP,            # Deal MP damage
	
	# Status Effects (replaces Global.effect system)
	ADD_STATUS,           # Apply a status effect from StatusEffect enum
	REMOVE_STATUS,        # Remove a status effect
	CLEAR_ALL_STATUS,     # Remove all status effects
	
	# Battle Flow
	FORCE_TARGET,         # Force attack to target specific unit
	SKIP_TURN,            # Skip the target's next turn
	EXTRA_TURN,           # Grant an extra turn
	CHANGE_INITIATIVE,    # Modify turn order priority
	
	# Resource Management
	ADD_ITEM,             # Give item after battle
	REMOVE_ITEM,          # Remove item during battle
	GAIN_XP,              # Grant experience points
	GAIN_CURRENCY,        # Grant currency/gold
	
	# Conditional Effects
	CONDITIONAL_EFFECT,   # Only run if condition is met
	COUNTER_ATTACK,       # Set up counter attack
	REFLECT_DAMAGE,       # Reflect percentage of damage
	
	# Visual/Audio
	PLAY_ANIMATION,       # Play specific animation
	PLAY_SOUND,           # Play sound effect
	SHAKE_SCREEN,         # Shake the camera
	FLASH_SCREEN,         # Flash the screen
	
	# Custom
	CUSTOM_SCRIPT         # Run custom GDScript
}

enum TargetType {
	NONE,
	SELF,
	SINGLE_ALLY,
	SINGLE_ENEMY,
	ALL_ALLIES,
	ALL_ENEMIES,
	ENTIRE_BATTLE,
	ATTACKER,
	DEFENDER
}

enum Timing {
	ON_USE,               # When skill/ability is used
	ON_HIT,               # When attack hits
	ON_MISS,              # When attack misses
	ON_TURN_START,        # At start of turn
	ON_TURN_END,          # At end of turn
	ON_TAKE_DAMAGE,       # When taking damage
	ON_DEATH,             # When unit dies
	ON_BATTLE_START,      # When battle begins
	ON_BATTLE_END,        # When battle ends
	PASSIVE               # Always active
}

@export_group("Effect Definition")
@export_enum(
	"Modify Stat", "Set Stat",
	"Heal HP", "Heal MP", "Damage HP", "Damage MP",
	"Add Status", "Remove Status", "Clear All Status",
	"Force Target", "Skip Turn", "Extra Turn", "Change Initiative",
	"Add Item", "Remove Item", "Gain XP", "Gain Currency",
	"Conditional Effect", "Counter Attack", "Reflect Damage",
	"Play Animation", "Play Sound", "Shake Screen", "Flash Screen",
	"Custom Script"
)
var effect_type: int = 0

@export var target_type: TargetType = TargetType.SELF
@export var timing: Timing = Timing.ON_USE

@export_group("Parameters")
@export var stat_name: String = ""              # For MODIFY_STAT, SET_STAT
@export var stat_value: float = 0.0             # Value or multiplier
@export var stat_operation: int = 0             # 0=Add, 1=Multiply, 2=Set
@export_range(-10, 10) var stat_levels: int = 0 # For buff/debuff levels

@export var heal_amount: int = 0
@export var heal_percent: float = 0.0
@export var damage_amount: int = 0
@export var damage_percent: float = 0.0

@export var status_effect: StatusEffect = StatusEffect.Heal
@export_range(1, 99) var status_level: int = 1
@export_range(1, 99) var status_duration: int = 3

@export var xp_amount: int = 0
@export var currency_amount: int = 0
@export var item_reference: Resource              # Item to add/remove
@export var item_quantity: int = 1

@export var animation_name: String = ""
@export var sound_path: String = ""
@export var shake_intensity: float = 5.0
@export var flash_color: Color = Color.WHITE
@export var flash_duration: float = 0.3

@export var chance_percent: float = 100.0       # Chance for effect to trigger
@export var custom_script_path: String = ""     # Path to custom effect script

@export_group("Conditions")
@export var require_hp_below_percent: float = 0.0  # Only trigger if HP below %
@export var require_hp_above_percent: float = 0.0  # Only trigger if HP above %
@export var require_mp_below_percent: float = 0.0  # Only trigger if MP below %
@export var require_status: Array[StatusEffect] = []  # Must have these statuses
@export var require_no_status: Array[StatusEffect] = []  # Must not have these
@export var require_turn_number_min: int = 0
@export var require_turn_number_max: int = 0


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	
	match effect_type:
		EffectType.MODIFY_STAT, EffectType.SET_STAT:
			props.append({"name": "stat_name", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "stat_value", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "stat_operation", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "stat_levels", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.HEAL_HP, EffectType.DAMAGE_HP:
			props.append({"name": "heal_amount", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "heal_percent", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.HEAL_MP, EffectType.DAMAGE_MP:
			props.append({"name": "heal_amount", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "heal_percent", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.ADD_STATUS, EffectType.REMOVE_STATUS:
			props.append({"name": "status_effect", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "status_level", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "status_duration", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.GAIN_XP:
			props.append({"name": "xp_amount", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.GAIN_CURRENCY:
			props.append({"name": "currency_amount", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.ADD_ITEM, EffectType.REMOVE_ITEM:
			props.append({"name": "item_reference", "type": TYPE_OBJECT, "usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Resource"})
			props.append({"name": "item_quantity", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.PLAY_ANIMATION:
			props.append({"name": "animation_name", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.PLAY_SOUND:
			props.append({"name": "sound_path", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_FILE, "hint_string": "*.mp3,*.ogg,*.wav"})
		
		EffectType.SHAKE_SCREEN:
			props.append({"name": "shake_intensity", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.FLASH_SCREEN:
			props.append({"name": "flash_color", "type": TYPE_COLOR, "usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "flash_duration", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
		
		EffectType.CUSTOM_SCRIPT:
			props.append({"name": "custom_script_path", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_FILE, "hint_string": "*.gd"})
	
	# Always show these
	props.append({"name": "target_type", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "timing", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "chance_percent", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
	
	return props


func check_conditions(source: Object, target: Object, battle_context: Dictionary) -> bool:
	if chance_percent < 100.0 and randf() * 100.0 > chance_percent:
		return false
	
	if require_hp_below_percent > 0:
		var hp_percent = (float(target.hp) / float(target.max_stats.get("hp", target.max_hp))) * 100.0
		if hp_percent >= require_hp_below_percent:
			return false
	
	if require_hp_above_percent > 0:
		var hp_percent = (float(target.hp) / float(target.max_stats.get("hp", target.max_hp))) * 100.0
		if hp_percent <= require_hp_above_percent:
			return false
	
	if require_mp_below_percent > 0:
		var mp_percent = (float(target.mp) / float(target.max_stats.get("mp", target.max_mp))) * 100.0
		if mp_percent >= require_mp_below_percent:
			return false
	
	for status in require_status:
		if not target.effects.has(status):
			return false
	
	for status in require_no_status:
		if target.effects.has(status):
			return false
	
	var turn_num = battle_context.get("turn_number", 0)
	if require_turn_number_min > 0 and turn_num < require_turn_number_min:
		return false
	if require_turn_number_max > 0 and turn_num > require_turn_number_max:
		return false
	
	return true


func get_target_objects(source: Object, targets: Array, enemies: Array, battle_context: Dictionary) -> Array:
	var result: Array = []
	
	match target_type:
		TargetType.NONE:
			pass
		TargetType.SELF:
			result.append(source)
		TargetType.SINGLE_ALLY:
			if battle_context.has("selected_ally"):
				result.append(battle_context["selected_ally"])
		TargetType.SINGLE_ENEMY:
			if battle_context.has("selected_enemy"):
				result.append(battle_context["selected_enemy"])
		TargetType.ALL_ALLIES:
			result.assign(targets)
		TargetType.ALL_ENEMIES:
			result.assign(enemies)
		TargetType.ENTIRE_BATTLE:
			result.assign(targets)
			result.append_array(enemies)
		TargetType.ATTACKER:
			result.append(source)
		TargetType.DEFENDER:
			if battle_context.has("defender"):
				result.append(battle_context["defender"])
	
	return result


func execute(source: Object, targets: Array, enemies: Array, battle_context: Dictionary = {}) -> bool:
	if not check_conditions(source, source if targets.is_empty() else targets[0], battle_context):
		return false
	
	var actual_targets = get_target_objects(source, targets, enemies, battle_context)
	if actual_targets.is_empty():
		actual_targets = [source]
	
	for target in actual_targets:
		if not is_instance_valid(target):
			continue
		
		match effect_type:
			EffectType.MODIFY_STAT:
				_apply_stat_mod(target, stat_name, stat_value, stat_operation)
			
			EffectType.SET_STAT:
				if stat_name in target:
					target.set(stat_name, stat_value)
			
			EffectType.HEAL_HP:
				var heal = heal_amount
				if heal_percent > 0:
					heal += floor(target.max_stats.get("hp", target.max_hp) * heal_percent)
				target.hp = min(target.hp + heal, target.max_stats.get("hp", target.max_hp))
			
			EffectType.HEAL_MP:
				var heal = heal_amount
				if heal_percent > 0:
					heal += floor(target.max_stats.get("mp", target.max_mp) * heal_percent)
				target.mp = min(target.mp + heal, target.max_stats.get("mp", target.max_mp))
			
			EffectType.DAMAGE_HP:
				var dmg = damage_amount
				if damage_percent > 0:
					dmg += floor(target.max_stats.get("hp", target.max_hp) * damage_percent)
				target.hp = max(target.hp - dmg, 0)
			
			EffectType.DAMAGE_MP:
				var dmg = damage_amount
				if damage_percent > 0:
					dmg += floor(target.max_stats.get("mp", target.max_mp) * damage_percent)
				target.mp = max(target.mp - dmg, 0)
			
			EffectType.ADD_STATUS:
				_apply_status_effect(target, status_effect, status_level, status_duration)
			
			EffectType.REMOVE_STATUS:
				if target.effects.has(status_effect):
					target.effects.erase(status_effect)
			
			EffectType.CLEAR_ALL_STATUS:
				target.effects.clear()
			
			EffectType.SKIP_TURN:
				target.skip_turn = true
			
			EffectType.EXTRA_TURN:
				target.extra_turn = true
			
			EffectType.GAIN_XP:
				if source is Party:
					source.xp += xp_amount
			
			EffectType.GAIN_CURRENCY:
				if Global.has_method("add_currency"):
					Global.add_currency(currency_amount)
			
			EffectType.ADD_ITEM:
				if item_reference and Global.has_method("add_item"):
					Global.add_item(item_reference, item_quantity)
			
			EffectType.REMOVE_ITEM:
				if item_reference and Global.has_method("remove_item"):
					Global.remove_item(item_reference, item_quantity)
			
			EffectType.PLAY_ANIMATION:
				if battle_context.has("battle_root") and animation_name != "":
					var battle_root = battle_context["battle_root"]
					if battle_root.has_method("play_animation"):
						battle_root.play_animation(animation_name, target)
			
			EffectType.PLAY_SOUND:
				if sound_path != "":
					var audio = AudioStreamPlayer.new()
					audio.stream = load(sound_path)
					target.add_child(audio)
					audio.play()
					await target.get_tree().create_timer(0.5).timeout
					audio.queue_free()
			
			EffectType.SHAKE_SCREEN:
				if battle_context.has("battle_root"):
					var battle_root = battle_context["battle_root"]
					if battle_root.has_method("shake_camera"):
						battle_root.shake_camera(shake_intensity)
			
			EffectType.FLASH_SCREEN:
				if battle_context.has("battle_root"):
					var battle_root = battle_context["battle_root"]
					if battle_root.has_method("flash_screen"):
						battle_root.flash_screen(flash_color, flash_duration)
			
			EffectType.CUSTOM_SCRIPT:
				if custom_script_path != "":
					var script = load(custom_script_path)
					if script and script.has_method("execute"):
						script.execute(source, target, battle_context)
	
	return true


func _apply_status_effect(target: Object, effect: StatusEffect, level: int, duration: int):
	## Applies a status effect matching the behavior of Global.effect enum
	if not target.effects.has(effect):
		target.effects[effect] = [0, 0]
	target.effects[effect][0] = max(target.effects[effect][0], level)
	target.effects[effect][1] = max(target.effects[effect][1], duration)
	
	# Apply immediate effects based on status type
	match effect:
		StatusEffect.Heal:
			# Gradual HP restoration over time (handled in battle loop)
			pass
		
		StatusEffect.Mana_Heal:
			# Gradual MP restoration over time (handled in battle loop)
			pass
		
		StatusEffect.Blind:
			# Reduces accuracy - handled in attack calculation
			pass
		
		StatusEffect.Poison:
			# Damage over time - handled in battle loop
			pass
		
		StatusEffect.Bleed:
			# Stronger damage over time, not healable by items
			pass
		
		StatusEffect.Power:
			# Increases damage dealt - handled in damage calculation
			pass
		
		StatusEffect.Tough:
			# Increases defense - handled in damage calculation
			pass
		
		StatusEffect.Focus:
			# Increases accuracy - handled in hit calculation
			pass
		
		StatusEffect.Defend:
			# Reduces damage taken - handled in damage calculation
			pass
		
		StatusEffect.Kill:
			# Instakill chance - handled in attack execution
			pass
		
		StatusEffect.Absorb:
			# Increases max HP temporarily
			_apply_absorption_bonus(target, level)
		
		StatusEffect.Revive:
			# Revives knocked out ally
			if target.hp <= 0:
				target.hp = floor(target.max_stats.get("hp", target.max_hp) * 0.5)
		
		StatusEffect.Sick:
			# Reduces healing effectiveness - handled in heal calculation
			pass
		
		StatusEffect.Weak:
			# Reduces damage dealt - handled in damage calculation
			pass
		
		StatusEffect.Slow:
			# Reduces speed/initiative - handled in turn order
			pass
		
		StatusEffect.Sleep:
			# Skips turns until hit - handled in turn execution
			pass
		
		StatusEffect.Burn:
			# Damage over time + reduces attack
			pass
		
		StatusEffect.Freeze:
			# Skips turns + damage over time
			pass
		
		StatusEffect.Paralyzed:
			# Chance to skip turn + reduces speed
			pass
		
		StatusEffect.Shock:
			# Random stat reductions
			pass
		
		StatusEffect.Confuse:
			# May cause attacking self or allies
			pass


func _apply_stat_mod(target: Object, stat_name: String, value: float, operation: int):
	if not stat_name in target:
		return
	
	var current = target.get(stat_name)
	var new_value: float = current
	
	match operation:
		0:  # Add
			new_value = current + value
		1:  # Multiply
			new_value = current * value
		2:  # Set
			new_value = value
	
	if stat_name in target.max_stats:
		target.max_stats[stat_name] = int(new_value)
	else:
		target.set(stat_name, int(new_value))


func _apply_absorption_bonus(target: Object, level: int):
	## Applies absorption bonus (increases max HP temporarily)
	## Matches behavior from battle_effect_manager.gd
	var bonus = floor(target.max_stats.get("hp", target.max_hp) * 0.1 * level)
	target.max_stats["hp"] = target.max_stats.get("hp", target.max_hp) + bonus
	target.hp = min(target.hp + bonus, target.max_stats["hp"])


func _remove_absorption_bonus(target: Object, level: int):
	## Removes absorption bonus when effect expires
	var bonus = floor(target.max_stats.get("hp", target.max_hp) * 0.1 * level)
	target.max_stats["hp"] = max(target.max_stats.get("hp", target.max_hp) - bonus, 1)
	target.hp = min(target.hp, target.max_stats["hp"])


func get_status_effect_name(effect: StatusEffect, level: int) -> String:
	## Returns the display name for a status effect with level
	## Matches behavior from battle_effect_manager.get_effect_name_with_level()
	var names = {
		StatusEffect.Blind: "Blind",
		StatusEffect.Poison: "Poison",
		StatusEffect.Bleed: "Bleed",
		StatusEffect.Power: "Power",
		StatusEffect.Tough: "Tough",
		StatusEffect.Speed: "Speed",
		StatusEffect.Focus: "Focus",
		StatusEffect.Defend: "Defend",
		StatusEffect.Kill: "Kill",
		StatusEffect.Absorb: "Absorption",
		StatusEffect.Revive: "Revive",
		StatusEffect.Sick: "Sick",
		StatusEffect.Weak: "Weak",
		StatusEffect.Slow: "Slow",
		StatusEffect.Sleep: "Sleep",
		StatusEffect.Burn: "Burn",
		StatusEffect.Freeze: "Freeze",
		StatusEffect.Paralyzed: "Paralyzed",
		StatusEffect.Shock: "Shock",
		StatusEffect.Confuse: "Confuse",
		StatusEffect.Heal: "Heal",
		StatusEffect.Mana_Heal: "Mana Heal"
	}
	var base_name = names.get(effect, "Unknown")
	if level > 1:
		var roman = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
		if level <= 10:
			base_name += " " + roman[level]
		else:
			base_name += " " + str(level)
	return base_name
