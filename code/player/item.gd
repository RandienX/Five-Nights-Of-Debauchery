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

@export_group("Stat Bonuses")
@export var item_bonuses: Dictionary[String, int] = {
"hp": 0,
"mp": 0,
"atk": 10,
"def": 5,
"speed": 0,
"magic": 0,
}

@export_category("Weapon")
@export_enum("One-Handed", "Two-Handed") var weapon_type: int = 0
@export var weapon_effects_given: Dictionary[BattleEffect.StatusEffect, Array] = {}
@export var required_level: int = 0
@export var required_class: String = ""

@export_category("Armor")
@export_enum("Head", "Chest", "Legs", "Shield", "Accessory") var armor_type: int = 0
@export var startup_effects_given: Dictionary[BattleEffect.StatusEffect, Array] = {}
@export var armor_value: int = 0

@export_category("Consumable")
@export var consume_effects: Array[BattleEffect] = []
@export var legacy_consume_effects: Dictionary[BattleEffect.StatusEffect, Array] = {}
@export var is_item_attack: bool = false
@export var item_attack: Skill
@export var heals_effects: Array[BattleEffect.StatusEffect] = []
@export var heal_amount: int = 0
@export var mana_amount: int = 0
@export var revive_amount: int = 0

@export_category("General")
@export var sell_price: int = 10
@export var max_stack: int = 99
@export var can_use_in_battle: bool = true
@export var can_use_outside_battle: bool = true


func _init():
pass


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


func can_equip(character: Party) -> bool:
if required_level > 0 and character.level < required_level:
return false
if not required_class.is_empty():
# Could check character class here
pass
return true


func get_consume_effects_array() -> Array[BattleEffect]:
return consume_effects
