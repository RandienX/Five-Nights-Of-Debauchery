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

@export_group("Damage/Heal Values")
@export var base_value: float = 0.0
@export var scaling_type: ScalingType = ScalingType.FLAT
@export var critical_multiplier: float = 2.0
@export var variance_percent: float = 0.1     # Damage variance ±10%

@export_group("Stat Modification")
@export var stat_modifiers: Array[StatModifier] = []

@export_group("Status Application")
@export var status_ref: StatusDefinition  # Reference to status definition
@export var status_duration_override: int = -1   # -1 = use status default
@export var status_apply_chance: float = 100.0   # 0-100%

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
