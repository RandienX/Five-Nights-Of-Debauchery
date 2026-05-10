@tool
extends Resource
class_name Item

## Item configuration with comprehensive customization

@export_group("Basic Info")
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var texture: Texture2D
@export var icon: Texture2D

@export_group("Type")
@export_enum("Weapon", "Armor", "Consumable", "Key", "Accessory") var type: int = 0

@export_category("General")
@export var sell_price: Dictionary[PlayerStats.CurrencyType, int] = {
	PlayerStats.CurrencyType.GOLD: 10,
	PlayerStats.CurrencyType.SHIT: 10,
	PlayerStats.CurrencyType.FAZTOKENS: 10,
}
@export var max_stack: int = 99
@export var can_use_in_battle: bool = true
@export var can_use_outside_battle: bool = true

@export_group("Stat Bonuses")
@export var item_bonuses: Dictionary[StringName, int] = {
&"hp": 0,
&"mp": 0,
&"atk": 10,
&"def": 5,
&"speed": 0,
&"magic": 0,
}

@export_category("Weapon")
@export_enum("One-Handed", "Two-Handed") var weapon_type: int = 0
@export var weapon_effects_given: Dictionary[BattleEffect, Array] = {}

@export_category("Armor")
@export_enum("Head", "Chest", "Legs", "Shield", "Accessory") var armor_type: int = 0
@export var startup_effects_given: Dictionary[BattleEffect, Array] = {}
@export var armor_value: int = 0

@export_category("Consumable")
@export var consume_effects: Array[BattleEffect] = []
@export var is_item_attack: bool = false
@export var item_attack: Skill
@export var heal_amount: int = 0
@export var mana_amount: int = 0
@export var revive_amount: int = 0

func get_bonus(stat_name: String) -> int:
	return item_bonuses.get(stat_name, 0)
func get_total_hp_bonus() -> int:
	return get_bonus("hp")
func get_total_mp_bonus() -> int:
	return get_bonus("mp")
func get_total_atk_bonus() -> int:
	return get_bonus("atk")
func get_total_def_bonus() -> int:
	return get_bonus("def")

func can_equip(character: Entity) -> bool:
	if character.role != Entity.Role.PARTY:
		return false
	return true

func get_consume_effects_array() -> Array[BattleEffect]:
	return consume_effects
