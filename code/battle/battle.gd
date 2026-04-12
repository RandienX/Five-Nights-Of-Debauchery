extends Resource
class_name Battle

@export var enemy_pos0: Enemy #NEVER ADD
@export var enemy_pos1: Enemy
@export var enemy_pos2: Enemy
@export var enemy_pos3: Enemy
@export var enemy_pos4: Enemy
@export var enemy_pos5: Enemy

@export_category("Optional")

@export var music_override: AudioStreamMP3
@export var phases: Dictionary[String, Battle]
@export var add_to_party: String

@export_category("Battle End Conditions")
@export var end_conditions: Array[BattleEndCondition]
