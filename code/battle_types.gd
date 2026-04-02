class_name BattleTypes
extends RefCounted

# Enums
enum BattleState { STARTING, PLANNING, EXECUTING, VICTORY, DEFEAT, ESCAPED }
enum ActionMenuState { ROOT, SKILL, ITEM, TARGET_SELECT, CONFIRM }
enum ActionType { ATTACK, SKILL, ITEM, DEFEND, ESCAPE, NONE }
enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES, SELF, NONE }
enum AIPersonality { DUMB, CASUAL, VIOLENT, DEFENSIVE, INTELLIGENT, FLEXIBLE }

# Data Containers (Pure Data, no Node references)
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
			id = res.character_id
			name = res.character_name
			max_hp = res.max_hp
			current_hp = res.current_hp
			max_mp = res.max_mp
			current_mp = res.current_mp
			speed = res.speed
			attack = res.attack
			defense = res.defense
			magic = res.magic
			spirit = res.spirit
		elif res is Enemy:
			id = res.enemy_id
			name = res.enemy_name
			max_hp = res.max_hp
			current_hp = res.current_hp
			max_mp = res.max_mp # Enemies might have MP
			current_mp = res.current_mp
			speed = res.speed
			attack = res.attack
			defense = res.defense
			magic = res.magic
			spirit = res.spirit
			
	func take_damage(amount: int):
		current_hp = max(0, current_hp - amount)
		if current_hp == 0:
			is_dead = true
			
	func heal(amount: int):
		current_hp = min(max_hp, current_hp + amount)
		
	func take_mp_damage(amount: int):
		current_mp = max(0, current_mp - amount)

class PlannedAction:
	var type: ActionType = ActionType.NONE
	var target_ids: Array[String] = [] # IDs of targets
	var skill_id: String = ""
	var item_id: String = ""
	var source_id: String = "" # Who is performing this

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

class TurnOrderEntry:
	var actor_id: String
	var speed: int
	var initiative: float # Calculated speed + random variance
	
	func _init(id: String, spd: int):
		actor_id = id
		speed = spd
		initiative = spd + randf_range(-5, 5)
