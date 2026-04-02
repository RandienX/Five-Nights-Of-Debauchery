class_name BattleTypes
extends RefCounted

# Enum for battle states
enum State { INIT, PLAYER_TURN, ENEMY_TURN, ANIMATING, VICTORY, DEFEAT, ESCAPE }

# Enum for action types
enum ActionType { ATTACK, SKILL, ITEM, DEFEND, RUN }

# Data structure for a planned action
class PlannedAction:
	var actor: Node2D # Character node
	var type: ActionType
	var target: Node2D = null
	var skill_id: String = ""
	var item_id: String = ""
	var data: Dictionary = {} # Extra data (e.g., skill params)
	
	func _init(p_actor: Node2D, p_type: ActionType):
		actor = p_actor
		type = p_type

# Data structure for status effects
class StatusEffect:
	var id: String
	var name: String
	var duration: int
	var stat_modifiers: Dictionary = {} # e.g., {"atk": 1.5}
	var flags: Array = [] # e.g., ["poison", "stun"]
	
	func _init(p_id: String, p_name: String, p_duration: int):
		id = p_id
		name = p_name
		duration = p_duration

# Data structure for AI Personality
class AIPersonality:
	var aggression: float = 1.0 # 0.0 = passive, 1.0 = always attack
	var focus_fire: bool = false # True = target lowest HP, False = random
	var smart_targeting: bool = false # True = target weak elements/status
	
	func _init(p_aggro: float, p_focus: bool, p_smart: bool):
		aggression = p_aggro
		focus_fire = p_focus
		smart_targeting = p_smart
