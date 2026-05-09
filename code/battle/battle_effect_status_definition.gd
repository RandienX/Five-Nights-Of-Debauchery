extends Resource
class_name StatusDefinition
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
enum StackingRule {
	NONE,              # Cannot stack, ignore new applications
	OVERRIDE,          # Replace existing (use higher value/duration)
	EXTEND,            # Add durations, keep higher value
	REFRESH,           # Reset duration, keep value
	ADDITIVE,          # Stack values additively
	MULTIPLICATIVE,    # Stack values multiplicatively
	CAPPED             # Stack up to max_stacks
}

@export var duration_type: DurationType = DurationType.TURNS
@export var duration_value: int = 3   # Turns or seconds depending on type
@export var persists_outside_battle: bool = false  # Survives battle end

@export var stacking_rule: StackingRule = StackingRule.OVERRIDE
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
