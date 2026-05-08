@tool
class_name BattleEffect
extends Resource

## Data-driven battle effect resource with structured sub-resources
## Supports targeting, timing, conditions, stat modifiers, and status application

# ==================== ENUMS ====================

enum EffectType {
	DAMAGE,              # Deal HP/MP damage
	HEAL,                # Restore HP/MP
	BUFF,                # Temporary positive stat modifier
	DEBUFF,              # Temporary negative stat modifier
	STATUS_APPLY,        # Apply a status effect
	STATUS_REMOVE,       # Remove a status effect
	PARAMETER_CHANGE,    # Permanent stat change
	UTILITY,             # Skip turn, extra turn, item give/take, etc.
	CUSTOM               # Run custom script/callback
}

enum TargetType {
	SELF,                # The caster/source
	SINGLE_ALLY,         # One ally (selected or random)
	SINGLE_ENEMY,        # One enemy (selected or random)
	ALL_ALLIES,          # All allied units
	ALL_ENEMIES,         # All enemy units
	PARTY,               # Entire party (for exploration persistence)
	ENTIRE_BATTLE        # Everyone in battle
}

enum Timing {
	ON_CAST,             # When skill/effect is cast
	ON_HIT,              # When attack hits target
	ON_MISS,             # When attack misses
	ON_TURN_START,       # At beginning of turn
	ON_TURN_END,         # At end of turn
	ON_DEATH,            # When entity dies
	ON_DAMAGE_TAKEN,     # When entity takes damage
	PERSISTENT           # Ticks every turn automatically
}

enum ScalingType {
	NONE,                # No scaling
	FLAT,                # Add flat value
	PERCENT_BASE,        # % of base stat
	PERCENT_CURRENT,     # % of current stat
	LEVEL_SCALE,         # Scale with source level
	STAT_SCALE           # Scale with a specific stat
}

enum Operator {
	GREATER_THAN,        # >
	LESS_THAN,           # <
	EQUALS,              # ==
	GREATER_EQUAL,       # >=
	LESS_EQUAL,          # <=
	HAS_STATUS,          # Has specific status
	NOT_HAS_STATUS,      # Does not have status
}

# ==================== SUB-RESOURCES ====================

@resource_class_name("ConditionRule")
class ConditionRule extends Resource:
	## Rule for checking if an effect should trigger
	
	@export var enabled: bool = true
	@export var check_stat: String = "hp"  # Stat to check (hp, mp, atk, etc.)
	@export var operator: Operator = Operator.GREATER_THAN
	@export var threshold_value: float = 0.0
	@export var status_id: String = ""  # For HAS_STATUS checks (use string ID)
	@export var compare_entity: String = "self"  # "self", "target", "source"
	@export var invert: bool = false  # Invert the result
	
	func evaluate(entity: Entity, context: Dictionary = {}) -> bool:
		if not enabled:
			return true
		
		var result: bool = false
		var actual_value: float = 0.0
		
		# Special handling for status checks
		if operator == Operator.HAS_STATUS or operator == Operator.NOT_HAS_STATUS:
			if not status_id.is_empty():
				result = entity.has_status(status_id)
				if operator == Operator.NOT_HAS_STATUS:
					result = not result
			else:
				result = false
		else:
			# Get stat value
			match check_stat:
				"hp":
					actual_value = float(entity.hp)
				"hp_percent":
					if entity.get_max_stat("hp") > 0:
						actual_value = (float(entity.hp) / float(entity.get_max_stat("hp"))) * 100.0
					else:
						actual_value = 0.0
				"mp":
					actual_value = float(entity.mp)
				"mp_percent":
					if entity.get_max_stat("mp") > 0:
						actual_value = (float(entity.mp) / float(entity.get_max_stat("mp"))) * 100.0
					else:
						actual_value = 0.0
				_:
					actual_value = float(entity.get_base_stat(check_stat))
			
			# Compare against threshold
			match operator:
				Operator.GREATER_THAN:
					result = actual_value > threshold_value
				Operator.LESS_THAN:
					result = actual_value < threshold_value
				Operator.EQUALS:
					result = abs(actual_value - threshold_value) < 0.001
				Operator.GREATER_EQUAL:
					result = actual_value >= threshold_value
				Operator.LESS_EQUAL:
					result = actual_value <= threshold_value
		
		return not result if invert else result
	
	func _get_icon() -> String:
		match operator:
			Operator.GREATER_THAN: return ">"
			Operator.LESS_THAN: return "<"
			Operator.EQUALS: return "=="
			Operator.GREATER_EQUAL: return ">="
			Operator.LESS_EQUAL: return "<="
			Operator.HAS_STATUS: return "HAS"
			Operator.NOT_HAS_STATUS: return "!HAS"
		return "?"

@resource_class_name("StatModifier")
class StatModifier extends Resource:
	## Modifier that changes entity stats temporarily or permanently
	
	@export var stat_key: String = "atk"  # Which stat to modify
	@export var value: float = 0.0        # Base modification value
	@export var modifier_type: ModifierType = ModifierType.ADD
	@export var duration_type: DurationType = DurationType.TURNS
	@export var duration_turns: int = 3
	@export var stacking_rule: StackingRule = StackingRule.OVERRIDE
	@export var max_stacks: int = 99
	@export var clamp_min: float = -9999
	@export var clamp_max: float = 9999
	@export var hidden: bool = false  # If true, don't show in UI
	
	enum ModifierType { 
		ADD,               # Add flat value
		MULTIPLY,          # Multiply current value
		FLAT_SET,          # Set to exact value
		PERCENT_ADD,       # Add percentage of base
	}
	
	enum DurationType {
		INSTANT,           # Applied once, never removed
		TURNS,             # Lasts N turns
		BATTLE,            # Lasts entire battle
		PERMANENT,         # Persists outside battle
		CUSTOM             # Custom duration logic
	}
	
	enum StackingRule {
		NONE,              # Cannot stack, ignore new applications
		OVERRIDE,          # Replace existing (use higher value/duration)
		EXTEND,            # Add durations, keep higher value
		REFRESH,           # Reset duration, keep value
		ADDITIVE,          # Stack values additively
		MULTIPLICATIVE,    # Stack values multiplicatively
		CAPPED             # Stack up to max_stacks
	}
	
	# Runtime tracking (not serialized by default)
	var applied_delta: float = 0.0  # Track what we actually applied for reversal
	var stack_count: int = 0
	var turns_remaining: int = 0
	var unique_id: String = ""
	
	func _init():
		unique_id = str(randi()) + "_" + str(Time.get_ticks_msec())
	
	## Calculate the final modified value based on modifier type
	func calculate_final_value(base_value: float, current_value: float) -> float:
		var final_value: float = base_value
		
		match modifier_type:
			ModifierType.ADD:
				final_value = current_value + value
			ModifierType.MULTIPLY:
				final_value = current_value * value
			ModifierType.FLAT_SET:
				final_value = value
			ModifierType.PERCENT_ADD:
				final_value = current_value + (base_value * (value / 100.0))
		
		return clamp(final_value, clamp_min, clamp_max)
	
	## Get the delta this modifier applies (for reversal)
	func get_applied_delta(base_value: float, current_value: float) -> float:
		var new_value = calculate_final_value(base_value, current_value)
		return new_value - current_value
	
	## Serialize for save system
	func serialize() -> Dictionary:
		return {
			"stat_key": stat_key,
			"value": value,
			"modifier_type": modifier_type,
			"duration_type": duration_type,
			"duration_turns": duration_turns,
			"stacking_rule": stacking_rule,
			"max_stacks": max_stacks,
			"clamp_min": clamp_min,
			"clamp_max": clamp_max,
			"hidden": hidden,
			"applied_delta": applied_delta,
			"stack_count": stack_count,
			"turns_remaining": turns_remaining,
			"unique_id": unique_id
		}
	
	## Deserialize from save system
	func deserialize(data: Dictionary):
		if data.has("stat_key"):
			stat_key = data["stat_key"]
		if data.has("value"):
			value = data["value"]
		if data.has("modifier_type"):
			modifier_type = data["modifier_type"]
		if data.has("duration_type"):
			duration_type = data["duration_type"]
		if data.has("duration_turns"):
			duration_turns = data["duration_turns"]
		if data.has("stacking_rule"):
			stacking_rule = data["stacking_rule"]
		if data.has("max_stacks"):
			max_stacks = data["max_stacks"]
		if data.has("clamp_min"):
			clamp_min = data["clamp_min"]
		if data.has("clamp_max"):
			clamp_max = data["clamp_max"]
		if data.has("hidden"):
			hidden = data["hidden"]
		if data.has("applied_delta"):
			applied_delta = data["applied_delta"]
		if data.has("stack_count"):
			stack_count = data["stack_count"]
		if data.has("turns_remaining"):
			turns_remaining = data["turns_remaining"]
		if data.has("unique_id"):
			unique_id = data["unique_id"]
	
	## Create a runtime instance of this modifier
	func create_instance(source_entity: Entity = null, target_entity: Entity = null) -> ModifierInstance:
		var instance = ModifierInstance.new()
		instance.source_definition = self
		instance.stat_key = stat_key
		instance.base_value = value
		instance.modifier_type = modifier_type
		instance.duration_type = duration_type
		instance.turns_remaining = duration_turns
		instance.stacking_rule = stacking_rule
		instance.max_stacks = max_stacks
		instance.clamp_min = clamp_min
		instance.clamp_max = clamp_max
		instance.hidden = hidden
		instance.stack_count = 1
		if source_entity:
			instance.source_entity_ref = weakref(source_entity)
		if target_entity:
			instance.target_entity_ref = weakref(target_entity)
		return instance


## ModifierInstance.gd
## Runtime instance of a StatModifier (not a Resource, used during battle)
class_name ModifierInstance
extends RefCounted

var source_definition: StatModifier
var stat_key: String
var base_value: float
var modifier_type: StatModifier.ModifierType
var duration_type: StatModifier.DurationType
var turns_remaining: int
var stacking_rule: StatModifier.StackingRule
var max_stacks: int
var clamp_min: float
var clamp_max: float
var hidden: bool
var stack_count: int = 1
var applied_delta: float = 0.0
var source_entity_ref: WeakRef
var target_entity_ref: WeakRef
var unique_id: String = ""

func _init():
	unique_id = str(randi()) + "_" + str(Time.get_ticks_msec())

func get_source_entity() -> Entity:
	if source_entity_ref == null:
		return null
	return source_entity_ref.get_ref() as Entity

func get_target_entity() -> Entity:
	if target_entity_ref == null:
		return null
	return target_entity_ref.get_ref() as Entity

## Serialize this instance for save/load
func serialize() -> Dictionary:
	return {
		"stat_key": stat_key,
		"base_value": base_value,
		"modifier_type": modifier_type,
		"duration_type": duration_type,
		"turns_remaining": turns_remaining,
		"stacking_rule": stacking_rule,
		"max_stacks": max_stacks,
		"clamp_min": clamp_min,
		"clamp_max": clamp_max,
		"hidden": hidden,
		"stack_count": stack_count,
		"applied_delta": applied_delta,
		"unique_id": unique_id
	}

## Deserialize from saved data
static func deserialize(data: Dictionary) -> ModifierInstance:
	var instance = ModifierInstance.new()
	instance.stat_key = data.get("stat_key", "")
	instance.base_value = data.get("base_value", 0.0)
	instance.modifier_type = data.get("modifier_type", StatModifier.ModifierType.ADD)
	instance.duration_type = data.get("duration_type", StatModifier.DurationType.TURNS)
	instance.turns_remaining = data.get("turns_remaining", 3)
	instance.stacking_rule = data.get("stacking_rule", StatModifier.StackingRule.OVERRIDE)
	instance.max_stacks = data.get("max_stacks", 99)
	instance.clamp_min = data.get("clamp_min", -9999)
	instance.clamp_max = data.get("clamp_max", 9999)
	instance.hidden = data.get("hidden", false)
	instance.stack_count = data.get("stack_count", 1)
	instance.applied_delta = data.get("applied_delta", 0.0)
	instance.unique_id = data.get("unique_id", str(randi()) + "_" + str(Time.get_ticks_msec()))
	return instance

@resource_class_name("StatusDefinition")
class StatusDefinition extends Resource:
	## Definition for a reusable status effect
	
	@export var id: String = ""           # Unique identifier (e.g., "poison", "power_buff")
	@export var name: String = ""         # Display name
	@export var description: String = ""  # Tooltip description
	@export var icon: Texture2D = null    # UI icon
	@export var is_positive: bool = false # Buff vs debuff for UI coloring
	
	enum DurationType {
		TURNS,             # Expires after N turns
		REAL_TIME,         # Expires after N seconds
		PERMANENT,         # Never expires naturally
		UNTIL_CONDITION    # Expires when condition met
	}
	
	@export var duration_type: DurationType = DurationType.TURNS
	@export var duration_value: int = 3   # Turns or seconds depending on type
	@export var persists_outside_battle: bool = false  # Survives battle end
	
	@export var stacking_rule: StatModifier.StackingRule = StatModifier.StackingRule.OVERRIDE
	@export var max_stacks: int = 1
	@export var can_be_removed: bool = true  # Can be cleansed/removed
	
	# Effects applied while status is active
	@export var stat_modifiers: Array[StatModifier] = []
	@export var tick_callback: String = ""  # Optional method name to call each tick
	@export var on_apply_callback: String = ""
	@export var on_remove_callback: String = ""
	@export var on_tick_callback: String = ""
	
	# Conditions for auto-removal
	@export var removal_conditions: Array[ConditionRule] = []
	
	func duplicate_config() -> StatusDefinition:
		var new_status = StatusDefinition.new()
		new_status.id = id
		new_status.name = name
		new_status.description = description
		new_status.icon = icon
		new_status.is_positive = is_positive
		new_status.duration_type = duration_type
		new_status.duration_value = duration_value
		new_status.persists_outside_battle = persists_outside_battle
		new_status.stacking_rule = stacking_rule
		new_status.max_stacks = max_stacks
		new_status.can_be_removed = can_be_removed
		for mod in stat_modifiers:
			new_status.stat_modifiers.append(mod.duplicate())
		new_status.tick_callback = tick_callback
		new_status.on_apply_callback = on_apply_callback
		new_status.on_remove_callback = on_remove_callback
		for cond in removal_conditions:
			new_status.removal_conditions.append(cond.duplicate())
		return new_status

# ==================== BATTLE EFFECT PROPERTIES ====================

@export_group("Effect Definition")
@export var effect_id: String = ""                    # Unique identifier for scripting
@export var effect_name: String = ""                  # Display name
@export var effect_type: EffectType = EffectType.DAMAGE
@export var target_type: TargetType = TargetType.SELF
@export var timing: Timing = Timing.ON_CAST
@export var description: String = ""

@export_group("Targeting")
@export var can_target_dead: bool = false
@export var require_line_of_sight: bool = false
@export var range_override: float = -1.0  # -1 = use default

@export_group("Damage/Heal Values")
@export var base_value: float = 0.0
@export var scaling_type: ScalingType = ScalingType.FLAT
@export var damage_type: String = "physical"  # physical, magical, true, etc.
@export var element: String = ""              # fire, ice, lightning, etc.
@export var critical_multiplier: float = 2.0
@export var variance_percent: float = 0.1     # Damage variance ±10%

@export_group("Stat Modification")
@export var stat_modifiers: Array[StatModifier] = []

@export_group("Status Application")
@export var status_ref: StatusDefinition = null  # Reference to status definition
@export var status_duration_override: int = -1   # -1 = use status default
@export var status_apply_chance: float = 100.0   # 0-100%
@export var status_resist_stat: String = "magic" # Stat used for resistance check

@export_group("Conditions")
@export var conditions: Array[ConditionRule] = []

@export_group("Visual/Audio")
@export var animation_name: String = ""
@export var sound_effect: String = ""
@export var screen_shake_intensity: float = 0.0
@export var flash_color: Color = Color.TRANSPARENT

@export_group("Custom Script")
@export var custom_script_path: String = ""
@export var custom_data: Dictionary = {}  # Arbitrary data for custom scripts

# ==================== UTILITY FUNCTIONS ====================

func get_scaled_value(source: Entity, target: Entity = null) -> float:
	"""Calculate the final value based on scaling type."""
	var final_value: float = base_value
	
	match scaling_type:
		ScalingType.NONE:
			pass
		ScalingType.FLAT:
			pass
		ScalingType.PERCENT_BASE:
			if target:
				var base_hp = target.get_base_stat("hp")
				final_value = base_hp * (base_value / 100.0)
		ScalingType.PERCENT_CURRENT:
			if target:
				final_value = target.hp * (base_value / 100.0)
		ScalingType.LEVEL_SCALE:
			final_value = base_value * source.level
		ScalingType.STAT_SCALE:
			# Would need additional config for which stat to scale with
			pass
	
	return final_value

func check_all_conditions(source: Entity, target: Entity, context: Dictionary = {}) -> bool:
	"""Evaluate all conditions. Returns true only if ALL conditions pass."""
	for condition in conditions:
		if not condition.evaluate(source if target == null else target, context):
			return false
	return true

func get_targets(source: Entity, allies: Array, enemies: Array, context: Dictionary = {}) -> Array:
	"""Resolve TargetType to actual Entity instances."""
	var targets: Array = []
	
	match target_type:
		TargetType.SELF:
			targets.append(source)
		TargetType.SINGLE_ALLY:
			if context.has("selected_ally") and context["selected_ally"]:
				targets.append(context["selected_ally"])
			elif not allies.is_empty():
				targets.append(allies[randi() % allies.size()])
		TargetType.SINGLE_ENEMY:
			if context.has("selected_enemy") and context["selected_enemy"]:
				targets.append(context["selected_enemy"])
			elif not enemies.is_empty():
				targets.append(enemies[randi() % enemies.size()])
		TargetType.ALL_ALLIES:
			targets.assign(allies)
		TargetType.ALL_ENEMIES:
			targets.assign(enemies)
		TargetType.PARTY:
			for ally in allies:
				if ally.role == Entity.Role.PARTY:
					targets.append(ally)
		TargetType.ENTIRE_BATTLE:
			targets.assign(allies)
			targets.append_array(enemies)
	
	# Filter out dead targets if necessary
	if not can_target_dead:
		targets = targets.filter(func(e): return e.hp > 0)
	
	return targets

func serialize() -> Dictionary:
	"""Serialize effect configuration for save/load."""
	return {
		"effect_id": effect_id,
		"effect_name": effect_name,
		"effect_type": effect_type,
		"target_type": target_type,
		"timing": timing,
		"base_value": base_value,
		"scaling_type": scaling_type,
		"damage_type": damage_type,
		"element": element,
		"custom_data": custom_data,
	}

func deserialize(data: Dictionary):
	"""Deserialize effect configuration from save data."""
	if data.has("effect_id"): effect_id = data["effect_id"]
	if data.has("effect_name"): effect_name = data["effect_name"]
	if data.has("effect_type"): effect_type = data["effect_type"]
	if data.has("target_type"): target_type = data["target_type"]
	if data.has("timing"): timing = data["timing"]
	if data.has("base_value"): base_value = data["base_value"]
	if data.has("scaling_type"): scaling_type = data["scaling_type"]
	if data.has("damage_type"): damage_type = data["damage_type"]
	if data.has("element"): element = data["element"]
	if data.has("custom_data"): custom_data = data["custom_data"]

# ==================== LEGACY COMPATIBILITY ====================
# Keep old StatusEffect enum for backward compatibility during migration

enum StatusEffect {
	Heal, Mana_Heal, Blind, Poison, Bleed, Power, Tough, Focus, Speed,
	Defend, Kill, Absorb, Revive, Sick, Weak, Slow, Sleep, Burn, Freeze,
	Paralyzed, Shock, Confuse
}

func get_status_effect_name(effect: StatusEffect, level: int = 1) -> String:
	"""Legacy function for backward compatibility."""
	var names = {
		StatusEffect.Heal: "Regen",
		StatusEffect.Mana_Heal: "Mana Regen",
		StatusEffect.Blind: "Blind",
		StatusEffect.Poison: "Poison",
		StatusEffect.Bleed: "Bleed",
		StatusEffect.Power: "Power Up",
		StatusEffect.Tough: "Tough",
		StatusEffect.Focus: "Focus",
		StatusEffect.Speed: "Haste",
		StatusEffect.Defend: "Defend",
		StatusEffect.Kill: "Death",
		StatusEffect.Absorb: "Absorb",
		StatusEffect.Revive: "Revive",
		StatusEffect.Sick: "Sick",
		StatusEffect.Weak: "Weak",
		StatusEffect.Slow: "Slow",
		StatusEffect.Sleep: "Sleep",
		StatusEffect.Burn: "Burn",
		StatusEffect.Freeze: "Freeze",
		StatusEffect.Paralyzed: "Paralyzed",
		StatusEffect.Shock: "Shock",
		StatusEffect.Confuse: "Confused",
	}
	var name = names.get(effect, "Unknown")
	if level > 1:
		name += " " + str(level)
	return name
