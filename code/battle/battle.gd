@tool
class_name Battle
extends Resource

## Data-driven battle configuration
## Similar structure to DialogueData for consistency

@export_group("Battle Configuration")
@export var battle_name: String = ""
@export_multiline var description: String = ""

@export_group("Enemies")
@export var enemies: Array[BattleEnemySlot] = []

@export_group("Party Members (Optional)")
@export var forced_party_members: Array[Party] = []  # Empty = use current party

@export_group("Battle Settings")
@export var background: Texture2D
@export var music: AudioStreamMP3
@export var can_flee: bool = true
@export var can_use_items: bool = true
@export var xp_multiplier: float = 1.0
@export var currency_reward: int = 0

@export_group("Battle Phases")
@export var phases: Array[BattlePhase] = []
@export var current_phase_index: int = 0

@export_group("On Battle Start Effects")
@export var on_battle_start_effects: Array[BattleEffect] = []

@export_group("On Battle End Effects")
@export var on_victory_effects: Array[BattleEffect] = []
@export var on_defeat_effects: Array[BattleEffect] = []

@export_group("End Conditions")
@export var end_conditions: Array[BattleEndCondition] = []

@export_group("Battle Conditions (Optional)")
@export var battle_conditions: Array[BattleCondition] = []  # For dynamic battle flow control


func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if enemies.is_empty():
		errors.append("Battle has no enemies configured")
	
	# Validate enemy slots
	for i in range(enemies.size()):
		var slot = enemies[i]
		if not slot:
			errors.append("Enemy slot %d is null" % i)
		elif not slot.enemy:
			errors.append("Enemy slot %d has no enemy resource" % i)
	
	# Validate phases
	for i in range(phases.size()):
		var phase = phases[i]
		if not phase:
			errors.append("Phase %d is null" % i)
		elif phase.trigger_condition.is_empty():
			errors.append("Phase %d has no trigger condition" % i)
	
	# Validate end conditions
	if end_conditions.is_empty():
		errors.append("Battle has no end conditions - consider adding 'All Enemies Defeated'")
	
	return errors


func get_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for slot in enemies:
		if slot and slot.enemy:
			result.append(slot.enemy.duplicate_deep())
	return result


func get_total_enemy_count() -> int:
	return enemies.size()


func has_phase_trigger(trigger_type: String) -> bool:
	for phase in phases:
		if phase and phase.trigger_condition == trigger_type:
			return true
	return false


## Evaluate battle conditions
## Returns array of conditions that are currently true
func evaluate_conditions(evaluator: BattleConditionEvaluator) -> Array[BattleCondition]:
	var true_conditions: Array[BattleCondition] = []
	
	for condition in battle_conditions:
		if condition and evaluator.evaluate(condition):
			true_conditions.append(condition)
	
	return true_conditions


## Check if a specific condition type is met
func check_condition_type(evaluator: BattleConditionEvaluator, type_check: BattleCondition.ConditionType) -> bool:
	for condition in battle_conditions:
		if condition and condition.condition_type == type_check:
			if evaluator.evaluate(condition):
				return true
	return false
