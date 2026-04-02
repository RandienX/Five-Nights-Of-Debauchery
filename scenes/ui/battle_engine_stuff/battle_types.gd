class_name BattleTypes
extends RefCounted

# Enums for battle states
enum BattleState { STARTING, PLANNING, EXECUTING, ANIMATING, VICTORY, DEFEAT, ESCAPED}
enum ActionMenuState { ROOT, SKILL, ITEM, TARGET_SELECT, CONFIRM }
enum ActionType { ATTACK, SKILL, ITEM, DEFEND, RUN, NONE}
enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES, SELF, NONE }
enum AIPersonality { DUMB, CASUAL, VIOLENT, DEFENSIVE, INTELLIGENT, FLEXIBLE }

# Data structure for a planned action
class PlannedAction:
	var type: ActionType = ActionType.NONE
	var target_ids: Array[String] = [] # IDs of targets
	var skill_id: String = ""
	var item_id: String = ""
	var source_id: String = "" # Who is performing this
	
	func _init(p_source_id: String = "", p_type: ActionType = ActionType.NONE):
		source_id = p_source_id
		type = p_type

# Data structure for status effects
class StatusEffect:
	var id: String
	var name: String
	var duration: int
	var type: String # "buff", "debuff", "dot", "hot"
	var value: int
	
	func _init(effect_id: String, effect_name: String, dur: int, val: int = 0):
		id = effect_id
		name = effect_name
		duration = dur
		value = val

# Data structure for AI Personality
class AIPersonalityData:
	var aggression: float = 1.0 # 0.0 = passive, 1.0 = always attack
	var focus_fire: bool = false # True = target lowest HP, False = random
	var smart_targeting: bool = false # True = target weak elements/status
	
	func _init(p_aggro: float, p_focus: bool, p_smart: bool):
		aggression = p_aggro
		focus_fire = p_focus
		smart_targeting = p_smart

# Data structure for turn order entry
class TurnOrderEntry:
	var actor_id: String
	var speed: int
	var initiative: float # Calculated speed + random variance
	
	func _init(id: String, spd: int):
		actor_id = id
		speed = spd
		initiative = spd + randf_range(-5, 5)

# Data structure for BattleActor
class BattleActor:
	var resource: Resource # The original Party or Enemy resource
	var id: String
	var name: String
	var is_enemy: bool
	var sprite: Sprite2D # Only reference for visuals
	
	# Stats (Copied from resource to allow modification during battle)
	var max_hp: int
	var current_hp: int
	var max_mp: int
	var current_mp: int
	var speed: int
	var attack: int
	var defense: int
	var magic: int
	var spirit: int
	
	# State
	var is_dead: bool = false
	var status_effects: Array[StatusEffect] = []
	var action_plan: PlannedAction = null
	
	func _init(res: Resource, is_enemy_flag: bool, sprite_node: Sprite2D = null):
		resource = res
		is_enemy = is_enemy_flag
		sprite = sprite_node
		
		# Extract data based on resource type
		if res is Party:
			var p: Party = res as Party
			id = p.name if p.name != "" else "party_" + str(p.get_instance_id())
			name = p.name
			max_hp = p.max_stats.get("hp", 100)
			current_hp = p.hp
			max_mp = p.max_stats.get("mp", 50)
			current_mp = p.mp
			speed = p.base_stats.get("ai", 10)  # Using 'ai' stat as speed
			attack = p.base_stats.get("atk", 10)
			defense = p.base_stats.get("def", 5)
			magic = p.base_stats.get("atk", 10)  # Fallback
			spirit = p.base_stats.get("def", 5)  # Fallback
		elif res is Enemy:
			var e: Enemy = res as Enemy
			id = e.name if e.name != "" else "enemy_" + str(e.get_instance_id())
			name = e.name
			max_hp = e.max_hp
			current_hp = e.hp
			max_mp = e.max_mp
			current_mp = e.mp
			speed = e.ai
			attack = e.damage
			defense = e.defense
			magic = e.damage  # Fallback
			spirit = e.defense  # Fallback
			
	func take_damage(amount: int):
		current_hp = max(0, current_hp - amount)
		if current_hp == 0:
			is_dead = true
			
	func heal(amount: int):
		current_hp = min(max_hp, current_hp + amount)
		
	func take_mp_damage(amount: int):
		current_mp = max(0, current_mp - amount)
