extends Resource
class_name Item

@export_enum("Weapon", "Armor", "Consumable", "Key") var type
@export var item_name: String
@export_multiline var desc: String
@export var texture: Texture2D
@export var item_bonuses: Dictionary[String, int] = {
	"hp": 0,
	"mp": 0,
	"atk": 0,
	"def": 0,
	"ai": 0,
	"cool": 0,
}

@export_category("Weapon")
@export_enum("One-Handed", "Two-Handed") var weapon_type
@export var weapon_effects_given: Dictionary[Global.effect, Array]#[int, int]

@export_category("Armor")
@export_enum("Head", "Chest", "Legs", "Shield") var armor_type
@export var startup_effects_given: Dictionary[Global.effect, Array]#[int, int]

@export_category("Consumable")
@export var consume_effects_given: Dictionary[Global.effect, Array]#[int, int]
@export var is_item_attack: bool
@export var item_attack: Skill
@export var heals_effects: Array[Global.effect]  # ONLY for removing effects
@export var heal_amount: int = 0  # HP to restore
@export var mana_amount: int = 0  # MP to restore
