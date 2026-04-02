class_name BattleEngine
extends Node2D

## Main Battle Engine - Orchestrates all battle components
## Simplified architecture with component-based design

# Signals
signal battle_started()
signal battle_ended(victory: bool)
signal turn_changed(actor: Node2D, is_player: bool)
signal action_executed(action_data: Dictionary)

# Exported battle configuration
@export var battle: Battle

# Component references
@onready var initiative_manager: BattleInitiativeManager = $BattleInitiativeManager if has_node("BattleInitiativeManager") else null
@onready var action_planner: BattleActionPlanner = $BattleActionPlanner if has_node("BattleActionPlanner") else null
@onready var effect_manager: BattleEffectManager = $BattleEffectManager if has_node("BattleEffectManager") else null
@onready var logger: BattleLogger = $BattleLogger if has_node("BattleLogger") else null
@onready var attack_executor: BattleAttackExecutor = $BattleAttackExecutor if has_node("BattleAttackExecutor") else null
@onready var end_checker: BattleEndConditionChecker = $BattleEndConditionChecker if has_node("BattleEndConditionChecker") else null
@onready var ai_manager: BattleAIManager = $BattleAIManager if has_node("BattleAIManager") else null
@onready var item_manager: BattleItemManager = $BattleItemManager if has_node("BattleItemManager") else null

# Battle state
var state: BattleTypes.State = BattleTypes.State.INIT
var party_members: Array[Node2D] = []
var enemy_members: Array[Node2D] = []
var current_actor: Node2D = null
var is_player_phase: bool = true

# Configuration
var enable_planning_phase: bool = true
var escape_chance: float = 0.7

func _ready():
	_initialize_components()
	_connect_signals()
	_start_battle_from_resource()

## Initializes all components
func _initialize_components():
	# Create components if they don't exist
	if not initiative_manager:
		initiative_manager = BattleInitiativeManager.new()
		initiative_manager.name = "BattleInitiativeManager"
		add_child(initiative_manager)
	
	if not action_planner:
		action_planner = BattleActionPlanner.new()
		action_planner.name = "BattleActionPlanner"
		add_child(action_planner)
	
	if not effect_manager:
		effect_manager = BattleEffectManager.new()
		effect_manager.name = "BattleEffectManager"
		add_child(effect_manager)
	
	if not logger:
		logger = BattleLogger.new()
		logger.name = "BattleLogger"
		add_child(logger)
	
	if not attack_executor:
		attack_executor = BattleAttackExecutor.new()
		attack_executor.name = "BattleAttackExecutor"
		add_child(attack_executor)
	
	if not end_checker:
		end_checker = BattleEndConditionChecker.new()
		end_checker.name = "BattleEndConditionChecker"
		add_child(end_checker)
	
	if not ai_manager:
		ai_manager = BattleAIManager.new()
		ai_manager.name = "BattleAIManager"
		add_child(ai_manager)
	
	if not item_manager:
		item_manager = BattleItemManager.new()
		item_manager.name = "BattleItemManager"
		add_child(item_manager)
	
	# Initialize components with references
	logger.init_manager(self)
	attack_executor.init_manager(self, effect_manager, logger)
	end_checker.init_manager(self, logger)
	ai_manager.init_manager(self, logger, effect_manager)
	item_manager.init_manager(self, logger, effect_manager)
	initiative_manager.init_manager(self)

## Connects component signals
func _connect_signals():
	if initiative_manager:
		initiative_manager.turn_started.connect(_on_turn_started)
	
	if action_planner:
		action_planner.planning_complete.connect(_on_planning_complete)
	
	if end_checker:
		end_checker.victory_achieved.connect(_on_victory)
		end_checker.defeat_suffered.connect(_on_defeat)

## Starts battle from the exported Battle resource
func _start_battle_from_resource():
	if not battle:
		push_warning("BattleEngine: No battle resource assigned!")
		return
	
	var party = Global.party.duplicate(true)
	var enemies = []
	
	# Collect enemies from battle resource
	if battle.enemy_pos0: enemies.append(battle.enemy_pos0)
	if battle.enemy_pos1: enemies.append(battle.enemy_pos1)
	if battle.enemy_pos2: enemies.append(battle.enemy_pos2)
	if battle.enemy_pos3: enemies.append(battle.enemy_pos3)
	if battle.enemy_pos4: enemies.append(battle.enemy_pos4)
	if battle.enemy_pos5: enemies.append(battle.enemy_pos5)
	
	if enemies.is_empty():
		push_warning("BattleEngine: No enemies in battle resource!")
		return
	
	# Convert enemy resources to Node2D wrappers for battle system
	var enemy_instances = []
	for i in range(enemies.size()):
		if enemies[i]:
			var enemy_node = _create_enemy_node(enemies[i], i)
			if enemy_node:
				enemy_instances.append(enemy_node)
	
	start_battle(party, enemy_instances)

## Creates a Node2D wrapper for an enemy resource
func _create_enemy_node(enemy_res: Enemy, index: int) -> Node2D:
	var node = Node2D.new()
	node.name = "Enemy_%d_%s" % [index, enemy_res.name]
	
	# Copy all enemy resource properties to the node
	node.set_meta("enemy_resource", enemy_res)
	node.set_meta("hp", enemy_res.hp)
	node.set_meta("max_hp", enemy_res.max_hp)
	node.set_meta("mp", enemy_res.mp)
	node.set_meta("max_mp", enemy_res.max_mp)
	node.set_meta("damage", enemy_res.damage)
	node.set_meta("defense", enemy_res.defense)
	node.set_meta("ai_type", enemy_res.ai_type)
	node.set_meta("enemy_name", enemy_res.name)
	node.set_meta("xp_reward", enemy_res.xp_reward)
	node.set_meta("battle_sprite", enemy_res.battleSprite)
	node.set_meta("effects", enemy_res.effects.duplicate(true))
	node.set_meta("attacks", enemy_res.attacks)
	node.set_meta("items", enemy_res.items)
	
	# Add helper methods via script-like behavior
	node.set_script(_create_enemy_wrapper_script())
	
	# Add to scene tree for visualization if needed
	var enemies_container = $Control/enemy_ui/enemies if has_node("Control/enemy_ui/enemies") else null
	if enemies_container and index < enemies_container.get_child_count():
		var ui_slot = enemies_container.get_child(index)
		if ui_slot.has_node("ProgressBar"):
			var hp_bar = ui_slot.get_node("ProgressBar")
			hp_bar.max_value = enemy_res.max_hp
			hp_bar.value = enemy_res.hp
			# Store reference for updates
			node.set_meta("hp_bar", hp_bar)
		
		if ui_slot.has_node("Sprite2D") or ui_slot.has_node("TextureRect"):
			var sprite = ui_slot.get_node("Sprite2D") if ui_slot.has_node("Sprite2D") else ui_slot
			if enemy_res.battleSprite:
				if sprite is TextureRect:
					sprite.texture = enemy_res.battleSprite
	
	return node

## Creates a script for enemy wrapper functionality
func _create_enemy_wrapper_script() -> Script:
	var script = GDScript.new()
	script.source_code = """
extends Node2D

func get_character_name() -> String:
	return get_meta("enemy_name") if has_meta("enemy_name") else "Enemy"

func get_hp() -> int:
	return get_meta("hp") if has_meta("hp") else 0

func set_hp(value: int) -> void:
	set_meta("hp", value)
	if has_meta("hp_bar"):
		var bar = get_meta("hp_bar")
		if bar:
			bar.value = value

func get_max_hp() -> int:
	return get_meta("max_hp") if has_meta("max_hp") else 0

func get_mp() -> int:
	return get_meta("mp") if has_meta("mp") else 0

func set_mp(value: int) -> void:
	set_meta("mp", value)

func get_max_mp() -> int:
	return get_meta("max_mp") if has_meta("max_mp") else 0

func get_damage() -> int:
	return get_meta("damage") if has_meta("damage") else 0

func get_defense() -> int:
	return get_meta("defense") if has_meta("defense") else 0

func get_ai_personality() -> int:
	return get_meta("ai_type") if has_meta("ai_type") else Global.AI.Casual

func is_dead() -> bool:
	return get_hp() <= 0

func take_damage(amount: int) -> int:
	var actual_damage = max(1, amount - get_defense())
	var new_hp = max(0, get_hp() - actual_damage)
	set_hp(new_hp)
	return actual_damage

func heal(amount: int) -> void:
	var new_hp = min(get_max_hp(), get_hp() + amount)
	set_hp(new_hp)

func get_effects() -> Dictionary:
	return get_meta("effects") if has_meta("effects") else {}

func get_attacks() -> Array:
	return get_meta("attacks") if has_meta("attacks") else []

func get_xp_reward() -> int:
	return get_meta("xp_reward") if has_meta("xp_reward") else 0
"""
	return script

## Starts a new battle
func start_battle(party: Array, enemies: Array):
	party_members = party
	enemy_members = enemies
	
	state = BattleTypes.State.INIT
	
	# Clear previous battle data
	effect_manager.clear_all()
	logger.clear_log()
	
	# Calculate initiative
	initiative_manager.calculate_initiative(party_members, enemy_members)
	
	battle_started.emit()
	
	# Start first turn
	_start_next_turn()

## Starts the next turn
func _start_next_turn():
	current_actor = initiative_manager.get_next_actor()
	
	if not current_actor:
		# Round complete, recalculate initiative
		initiative_manager.reset_round(party_members, enemy_members)
		current_actor = initiative_manager.get_next_actor()
	
	if not current_actor:
		return
	
	is_player_phase = initiative_manager.is_player_turn()
	turn_changed.emit(current_actor, is_player_phase)
	
	# Tick status effects
	effect_manager.tick_effects()
	
	if is_player_phase:
		_handle_player_turn()
	else:
		_handle_enemy_turn()

## Handles player turn
func _handle_player_turn():
	if enable_planning_phase:
		state = BattleTypes.State.PLAYER_TURN
		action_planner.start_planning(party_members)
		# UI should show action menu here
	else:
		_execute_player_action(current_actor)

## Handles enemy turn
func _handle_enemy_turn():
	state = BattleTypes.State.ENEMY_TURN
	
	# Get enemy AI personality (default to normal)
	var personality = BattleAIManager.AI_NORMAL
	if current_actor.has_method("get_ai_personality"):
		personality = current_actor.get_ai_personality()
	elif current_actor.has("ai_personality"):
		personality = ai_manager.get_personality_from_name(current_actor.ai_personality)
	
	# Decide action
	var action = ai_manager.decide_action(current_actor, party_members, enemy_members, personality)
	
	if not action.is_empty():
		await _execute_action(action)
	
	# Check end conditions
	_check_end_conditions()
	
	# Next turn
	if state != BattleTypes.State.VICTORY and state != BattleTypes.State.DEFEAT:
		_start_next_turn()

## Player selects an action
func player_select_action(action_type: BattleTypes.ActionType, target: Node2D = null, skill_id: String = "", item_id: String = ""):
	if not is_player_phase or not current_actor:
		return
	
	var action = action_planner.plan_action(current_actor, action_type, target, skill_id, item_id)
	
	if not enable_planning_phase:
		await _execute_action(action)
		_check_end_conditions()
		
		if state != BattleTypes.State.VICTORY and state != BattleTypes.State.DEFEAT:
			_start_next_turn()

## Executes a planned action
func _execute_action(action: BattleTypes.PlannedAction):
	if not is_instance_valid(action.actor):
		return
	
	state = BattleTypes.State.ANIMATING
	
	var result = {}
	
	match action.type:
		BattleTypes.ActionType.ATTACK:
			result = attack_executor.execute_attack(action.actor, action.target)
		
		BattleTypes.ActionType.SKILL:
			var skill_data = _get_skill_data(action.actor, action.skill_id)
			result = attack_executor.execute_skill(action.actor, action.target, skill_data)
		
		BattleTypes.ActionType.ITEM:
			var item_data = _get_item_data(action.item_id)
			item_manager.use_item(action.actor, item_data, action.target)
		
		BattleTypes.ActionType.DEFEND:
			_apply_defend(action.actor)
		
		BattleTypes.ActionType.RUN:
			_attempt_escape()
	
	action_executed.emit(action)
	state = BattleTypes.State.PLAYER_TURN if is_player_phase else BattleTypes.State.ENEMY_TURN

## Executes a player action directly (no planning phase)
func _execute_player_action(actor: Node2D):
	# Default to attack for now
	var target = _get_random_enemy_target()
	var action = BattleTypes.PlannedAction.new(actor, BattleTypes.ActionType.ATTACK)
	action.target = target
	
	await _execute_action(action)

## Gets skill data from actor
func _get_skill_data(actor: Node2D, skill_id: String) -> Dictionary:
	if actor.has_method("get_skill"):
		return actor.get_skill(skill_id)
	return {}

## Gets item data
func _get_item_data(item_id: String) -> Dictionary:
	# This should fetch from game's item database
	return {"id": item_id, "name": "Unknown Item", "effect_type": "heal", "value": 50}

## Applies defend action
func _apply_defend(actor: Node2D):
	if actor.has_method("set_defending"):
		actor.set_defending(true)
	
	if logger:
		var name = actor.get_character_name() if actor.has_method("get_character_name") else "Unknown"
		logger.add_message("%s is defending!" % [name], "#90EE90")

## Attempts to escape from battle
func _attempt_escape():
	var success = randf() < escape_chance
	
	if logger:
		logger.add_escape_message(success)
	
	if success:
		state = BattleTypes.State.ESCAPE
		battle_ended.emit(false) # False = didn't win, but escaped

## Called when planning phase is complete
func _on_planning_complete():
	if enable_planning_phase:
		action_planner.end_planning()
		_execute_planned_actions()

## Executes all planned actions in order
func _execute_planned_actions():
	action_planner.reset_execution()
	
	var action = action_planner.get_next_action()
	while action:
		if is_instance_valid(action.actor) and not action.actor.is_dead():
			await _execute_action(action)
			
			# Check end conditions after each action
			if _check_end_conditions():
				return
		
		action = action_planner.get_next_action()
	
	# All actions complete, start enemy turns
	if state != BattleTypes.State.VICTORY and state != BattleTypes.State.DEFEAT:
		_execute_enemy_actions()

## Executes enemy actions after player phase
func _execute_enemy_actions():
	for enemy in enemy_members:
		if is_instance_valid(enemy) and not enemy.is_dead():
			var personality = BattleAIManager.AI_NORMAL
			if enemy.has_method("get_ai_personality"):
				personality = enemy.get_ai_personality()
			
			var action = ai_manager.decide_action(enemy, party_members, enemy_members, personality)
			
			if not action.is_empty():
				await _execute_action(action)
				
				if _check_end_conditions():
					return
	
	# Enemy phase complete, recalculate initiative
	if state != BattleTypes.State.VICTORY and state != BattleTypes.State.DEFEAT:
		initiative_manager.reset_round(party_members, enemy_members)
		_start_next_turn()

## Checks for battle end conditions
func _check_end_conditions() -> bool:
	if end_checker.check_victory(enemy_members):
		return true
	
	if end_checker.check_defeat(party_members):
		return true
	
	var custom = end_checker.check_custom_conditions()
	if not custom.is_empty():
		return true
	
	return false

## Called on victory
func _on_victory():
	state = BattleTypes.State.VICTORY
	end_checker.on_victory(party_members, enemy_members)
	battle_ended.emit(true)

## Called on defeat
func _on_defeat():
	state = BattleTypes.State.DEFEAT
	end_checker.on_defeat()
	battle_ended.emit(false)

## Called when a turn starts
func _on_turn_started(actor: Node2D):
	current_actor = actor

## Gets party members
func get_party_members() -> Array:
	return party_members

## Gets enemy members
func get_enemy_members() -> Array:
	return enemy_members

## Checks if battle is active
func is_battle_active() -> bool:
	return state != BattleTypes.State.VICTORY and state != BattleTypes.State.DEFEAT and state != BattleTypes.State.ESCAPE

## Helper to get random enemy target
func _get_random_enemy_target() -> Node2D:
	for enemy in enemy_members:
		if is_instance_valid(enemy) and not enemy.is_dead():
			return enemy
	return null
