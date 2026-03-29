extends Resource
class_name Skill

@export_enum("Attack", "Buff", "Multiattack", "Item") var attack_type
@export_enum("SingleEnemy", "Self", "Party", "SingleAlly") var target_type
@export var mana_cost: int
@export var name: String
@export_multiline var desc: String
@export_range(0.01, 1) var accuracy: float = 1

@export_category("Effects")
@export var effects: Dictionary[Global.effect, Array] # {effect: [level, duration]}

@export_category("Attack")
@export var attack_multiplier: float
@export var attack_bonus: int

@export_category("Multiattack")
@export var hit_count: int = 3  
@export var hit_damage_multiplier: float = 0.5 

@export_category("Item")
@export var item_reference: Resource 

@export var sfx: AudioStreamMP3
