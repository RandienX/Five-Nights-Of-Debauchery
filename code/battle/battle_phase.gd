@tool
class_name BattlePhase
extends Resource

## A phase in a multi-phase battle

enum PhaseTrigger {
	ON_TURN_NUMBER,           # Trigger at specific turn
	ON_ENEMY_DEFEATED,        # Trigger when enemy dies
	ON_ENEMY_COUNT,           # Trigger when X enemies remain
	ON_HP_THRESHOLD,          # Trigger when boss HP drops below %
	ON_TIME_ELAPSED,          # Trigger after X seconds
	CUSTOM_CONDITION          # Custom script condition
}

@export_group("Phase Info")
@export var phase_name: String = "Phase 1"
@export_multiline var description: String = ""

@export_group("Trigger")
@export var trigger_type: PhaseTrigger = PhaseTrigger.ON_TURN_NUMBER
@export var trigger_turn_number: int = 3         # For ON_TURN_NUMBER
@export var trigger_enemy_defeated_index: int = 0  # Which enemy death triggers this
@export var trigger_enemy_count: int = 1         # For ON_ENEMY_COUNT
@export_range(1, 100) var trigger_hp_percent: int = 50  # For ON_HP_THRESHOLD
@export var trigger_time_seconds: float = 60.0   # For ON_TIME_ELAPSED
@export var trigger_condition: String = ""       # Custom condition name/script

@export_group("On Phase Start Effects")
@export var on_start_effects: Array[BattleEffect] = []

@export_group("Phase Settings (Override)")
@export var override_music: bool = false
@export var music_override: AudioStreamMP3
@export var override_background: bool = false
@export var background_override: Texture2D

@export_group("Spawn Reinforcements")
@export var spawn_reinforcements: bool = false
@export var reinforcement_slots: Array[BattleEnemySlot] = []


func should_trigger(battle_context: Dictionary) -> bool:
	match trigger_type:
		PhaseTrigger.ON_TURN_NUMBER:
			return battle_context.get("turn_number", 0) >= trigger_turn_number
		
		PhaseTrigger.ON_ENEMY_DEFEATED:
			var defeated_count = battle_context.get("enemies_defeated", 0)
			return defeated_count > trigger_enemy_defeated_index
		
		PhaseTrigger.ON_ENEMY_COUNT:
			var alive_count = battle_context.get("enemies_alive", 0)
			return alive_count <= trigger_enemy_count
		
		PhaseTrigger.ON_HP_THRESHOLD:
			var boss = battle_context.get("boss_enemy")
			if boss:
				var hp_percent = floor((float(boss.hp) / float(boss.max_hp)) * 100)
				return hp_percent <= trigger_hp_percent
			return false
		
		PhaseTrigger.ON_TIME_ELAPSED:
			var elapsed = battle_context.get("battle_time", 0.0)
			return elapsed >= trigger_time_seconds
		
		PhaseTrigger.CUSTOM_CONDITION:
			# Would be evaluated by custom script
			return false
	
	return false
