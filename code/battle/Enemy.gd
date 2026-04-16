@tool
extends Resource
class_name Enemy

## Enemy configuration with comprehensive customization

@export_group("Basic Info")
@export var enemy_name: String = ""
@export_multiline var description: String = ""
@export var sprite: Texture2D
@export var portrait: Texture2D

@export_group("Stats")
@export var level: int = 1
@export var hp: int = 100
@export var max_hp: int = hp
@export var mp: int = 50
@export var max_mp: int = mp
@export var damage: int = 10
@export var defense: int = 5
@export var speed: int = 10
@export var magic_power: int = 10
@export var magic_defense: int = 5

@export_group("AI Behavior")
@export var ai_type: Global.AI = Global.AI.Casual
@export var aggression: float = 0.5            # 0=passive, 1=aggressive
@export var prefer_defend: bool = false
@export var target_priority: int = 0           # 0=random, 1=lowest HP, 2=highest threat

@export_group("Combat")
@export var attacks: Array[Skill] = []
@export var default_attack: Skill
@export var effects_on_spawn: Array[BattleEffect] = []
@export var effects_on_death: Array[BattleEffect] = []

@export_group("Status Immunities")
@export var immune_to_effects: Array[BattleEffect.StatusEffect] = []

@export_group("Rewards")
@export var xp_reward: int = 10
@export var currency_reward: int = 0
@export var item_drops: Array[BattleItemDrop] = []

@export_group("Battle Settings")
@export var is_boss: bool = false
@export var can_flee: bool = false
@export var flee_threshold_hp_percent: int = 25
@export var back_sprite: Texture2D               # For attacks from behind

@export_category("Legacy Compatibility")
@export var items: Dictionary = {}
@export var effects: Dictionary = {}


func _init():
	max_hp = hp
	max_mp = mp


func is_immune_to(effect: BattleEffect.StatusEffect) -> bool:
	return effect in immune_to_effects


func get_effective_damage() -> int:
	var dmg = damage
	# Could apply buffs/debuffs here
	return dmg


func get_effective_defense() -> int:
	var def_stat = defense
	# Could apply buffs/debuffs here
	return def_stat


func duplicate_deep_custom() -> Enemy:
	var new_enemy = duplicate(true)
	new_enemy.hp = max_hp
	new_enemy.mp = max_mp
	return new_enemy
