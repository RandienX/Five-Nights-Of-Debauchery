extends Resource
class_name StatModifier
## Modifier that changes entity stats temporarily or permanently

enum ScalingType {
	NONE,                # No scaling
	FLAT,                # Add flat value
	PERCENT_BASE,        # % of base stat
	PERCENT_CURRENT,     # % of current stat
	LEVEL_SCALE,         # Scale with source level
	STAT_SCALE           # Scale with a specific stat
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
@export var stat_key: String = "atk"  # Which stat to modify
@export var value: float = 0.0        # Base modification value
@export var scaling_type: ScalingType = ScalingType.FLAT
@export var scale_stat: String = ""   # Stat to scale with (if STAT_SCALE)
@export var scale_factor: float = 1.0 # Multiplier for scaling

@export var duration_type: DurationType = DurationType.TURNS
@export var duration_turns: int = 3
@export var stacking_rule: StackingRule = StackingRule.OVERRIDE

@export var max_stacks: int = 99
@export var clamp_min: float = -9999
@export var clamp_max: float = 9999

# Runtime tracking (not serialized)
var applied_delta: float = 0.0  # Track what we actually applied for reversal
var stack_count: int = 0
var turns_remaining: int = 0

func calculate_final_value(source: Entity, target: Entity) -> float:
	var final_value: float = value
	
	match scaling_type:
		ScalingType.NONE:
			pass
		ScalingType.FLAT:
			pass  # value is already flat
		ScalingType.PERCENT_BASE:
			var base_stat = target.get_base_stat(stat_key)
			final_value = base_stat * (value / 100.0)
		ScalingType.PERCENT_CURRENT:
			var current_stat = target.get_effective_stat(stat_key)
			final_value = current_stat * (value / 100.0)
		ScalingType.LEVEL_SCALE:
			final_value = value * source.level
		ScalingType.STAT_SCALE:
			if scale_stat != "":
				var scale_value = source.get_base_stat(scale_stat)
				final_value = value + (scale_value * scale_factor)
	
	return clamp(final_value, clamp_min, clamp_max)

func get_modifier_type() -> int:
	# Returns 1 for buff, -1 for debuff, 0 for neutral
	if value > 0:
		return 1
	elif value < 0:
		return -1
	return 0
