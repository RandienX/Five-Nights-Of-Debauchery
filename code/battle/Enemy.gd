extends Resource
class_name Enemy

@export var hp: int
@export var max_hp: int = hp
@export var mp: int
@export var max_mp: int = mp
@export var damage: int
@export var defense: int
@export var ai: int
@export var ai_type: Global.AI = 1
@export var name: String
@export_multiline var description: String = ""

@export var items: Dictionary
@export var attacks: Array[Skill]
@export var xp_reward: int
@export var battleSprite: Texture2D
@export var effects: Dictionary = {}
