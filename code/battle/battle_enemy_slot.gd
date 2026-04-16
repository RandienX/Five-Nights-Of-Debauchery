@tool
class_name BattleEnemySlot
extends Resource

## A single enemy slot in a battle configuration

@export_group("Enemy")
@export var enemy: Enemy

@export_group("Spawn Settings")
@export var spawn_delay: float = 0.0              # Seconds before enemy appears
@export var spawn_on_phase: int = 0               # Phase number when enemy spawns (0 = start)
@export var spawn_condition: String = ""          # Custom condition to trigger spawn

@export_group("Positioning")
@export var position_index: int = 0               # Visual position slot (0-5)
@export var is_reinforcement: bool = false        # True = spawned mid-battle

@export_group("Rewards (Override)")
@export var override_xp: bool = false
@export var xp_override: int = 0
@export var override_currency: bool = false
@export var currency_override: int = 0
@export var drop_items: Array[BattleItemDrop] = []


func duplicate_enemy() -> Enemy:
	if not enemy:
		return null
	return enemy.duplicate_deep()


func get_xp_reward() -> int:
	if override_xp:
		return xp_override
	return enemy.xp_reward if enemy else 0


func get_currency_reward() -> int:
	if override_currency:
		return currency_override
	return 0
