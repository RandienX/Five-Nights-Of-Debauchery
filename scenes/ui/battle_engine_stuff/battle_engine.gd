class_name BattleEngine
extends Node2D

## Main Battle Engine - Orchestrates all battle components
## Works directly with Party and Enemy resources (no Node2D wrappers)
## Uses partyBattleFace.tscn for initiative display and "who moves" indicator

# Signals
signal battle_started()
signal battle_ended(victory: bool)
signal turn_changed(actor_resource: Resource, is_player: bool)
signal action_executed(action_data: Dictionary)
signal planning_index_changed(index: int)

# Exported battle configuration
@export var battle: Battle

# Component references (auto-created if not in scene)
var initiative_manager: BattleInitiativeManager
var action_planner: BattleActionPlanner
var effect_manager: BattleEffectManager
var logger: BattleLogger
var attack_executor: BattleAttackExecutor
var end_checker: BattleEndConditionChecker
var ai_manager: BattleAIManager
var item_manager: BattleItemManager

# Battle state - Now uses Resource arrays, not Node2D
var state: BattleTypes.BattleState = BattleTypes.BattleState.STARTING
var party_members: Array[Resource] = []  # Array of Party resources
var enemy_members: Array[Resource] = []  # Array of Enemy resources
var battle_actors: Array[BattleTypes.BattleActor] = []  # Unified actor data
var current_actor: BattleTypes.BattleActor = null
var is_player_phase: bool = true

# Planning phase state
var current_party_plan_index: int = 0
var party_battle_faces: Array[Control] = []  # References to partyBattleFace instances

# Configuration
var enable_planning_phase: bool = true
var escape_chance: float = 0.7

# Preloaded scenes
const PARTY_BATTLE_FACE_SCENE: PackedScene = preload("res://scenes/ui/battle_engine_stuff/partyBattleFace.tscn")

func _ready():
	_initialize_components()
	_connect_signals()
	_start_battle_from_resource()

## Initializes all components
func _initialize_components():
	# Create components if they don't exist as nodes
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
	
	# Initialize components with references to main engine
	for comp in [initiative_manager, action_planner, effect_manager, logger, 
				 attack_executor, end_checker, ai_manager, item_manager]:
		if comp.has_method("init_manager"):
			comp.init_manager(self)

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
	
	# Get party from Global (deep copy to preserve original)
	var party: Array[Resource] = []
	for p in Global.party:
		party.append(p.duplicate(true))
	
	# Collect enemies from battle resource
	var enemies: Array[Resource] = []
	if battle.enemy_pos0: enemies.append(battle.enemy_pos0)
	if battle.enemy_pos1: enemies.append(battle.enemy_pos1)
	if battle.enemy_pos2: enemies.append(battle.enemy_pos2)
	if battle.enemy_pos3: enemies.append(battle.enemy_pos3)
	if battle.enemy_pos4: enemies.append(battle.enemy_pos4)
	if battle.enemy_pos5: enemies.append(battle.enemy_pos5)
	
	if enemies.is_empty():
		push_warning("BattleEngine: No enemies in battle resource!")
		return
	
	# Start battle with resource arrays directly (no Node2D wrappers needed)
	start_battle(party, enemies)

## Starts a new battle with Party and Enemy resources
func start_battle(party: Array[Resource], enemies: Array[Resource]):
	party_members = party
	enemy_members = enemies
	
	# Create unified battle actor data from resources
	battle_actors.clear()
	for p in party_members:
		var actor = BattleTypes.BattleActor.new(p, false)
		battle_actors.append(actor)
	
	for e in enemy_members:
		var actor = BattleTypes.BattleActor.new(e, true)
		battle_actors.append(actor)
	
	state = BattleTypes.BattleState.STARTING
	
	# Clear previous battle data
	if effect_manager:
		effect_manager.clear_all()
	if logger:
		logger.clear_log()
	
	# Calculate initiative order
	if initiative_manager:
		initiative_manager.calculate_initiative(battle_actors)
	
	# Setup party UI with battle faces
	_setup_party_ui()
	
	battle_started.emit()
	
	# Start first turn
	_start_next_turn()

## Sets up the party UI using partyBattleFace.tscn instances
func _setup_party_ui():
	# Find the party container in the scene tree
	var party_container = get_node_or_null("Control/gui/HBoxContainer2/party")
	if not party_container:
		return
	
	# Clear existing children
	for child in party_container.get_children():
		child.queue_free()
	
	party_battle_faces.clear()
	
	# Create a battle face for each party member in initiative order
	for actor in battle_actors:
		if not actor.is_enemy:
			var ui = PARTY_BATTLE_FACE_SCENE.instantiate()
			party_container.add_child(ui)
			ui.setup_from_actor(actor)  # Use BattleActor setup method
			party_battle_faces.append(ui)
	
	# Initialize planning index
	current_party_plan_index = 0
	_update_who_moves_indicator()

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
		state = BattleTypes.BattleState.PLAYER_TURN
		action_planner.start_planning(party_members)
		# UI should show action menu here
	else:
		_execute_player_action(current_actor)

## Handles enemy turn
func _handle_enemy_turn():
	state = BattleTypes.BattleState.ENEMY_TURN
	
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
	if state != BattleTypes.BattleState.VICTORY and state != BattleTypes.BattleState.DEFEAT:
		_start_next_turn()

## Player selects an action
func player_select_action(action_type: BattleTypes.ActionType, target: Node2D = null, skill_id: String = "", item_id: String = ""):
	if not is_player_phase or not current_actor:
		return
	
	var action = action_planner.plan_action(current_actor, action_type, target, skill_id, item_id)
	
	if not enable_planning_phase:
		await _execute_action(action)
		_check_end_conditions()
		
		if state != BattleTypes.BattleState.VICTORY and state != BattleTypes.BattleState.DEFEAT:
			_start_next_turn()

## Executes a planned action
func _execute_action(action: BattleTypes.PlannedAction):
	if not is_instance_valid(action.actor):
		return
	
	state = BattleTypes.BattleState.ANIMATING
	
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
	state = BattleTypes.BattleState.PLAYER_TURN if is_player_phase else BattleTypes.BattleState.ENEMY_TURN

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
		state = BattleTypes.BattleState.ESCAPE
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
	if state != BattleTypes.BattleState.VICTORY and state != BattleTypes.BattleState.DEFEAT:
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
	if state != BattleTypes.BattleState.VICTORY and state != BattleTypes.BattleState.DEFEAT:
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
	state = BattleTypes.BattleState.VICTORY
	end_checker.on_victory(party_members, enemy_members)
	battle_ended.emit(true)

## Called on defeat
func _on_defeat():
	state = BattleTypes.BattleState.DEFEAT
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
	return state != BattleTypes.BattleState.VICTORY and state != BattleTypes.BattleState.DEFEAT and state != BattleTypes.BattleState.ESCAPE

## Helper to get random enemy target
func _get_random_enemy_target() -> Node2D:
	for enemy in enemy_members:
		if is_instance_valid(enemy) and not enemy.is_dead():
			return enemy
	return null

## Updates the "who moves" indicator shader effect on the current party member
func _update_who_moves_indicator():
	var who_moves_node = get_node_or_null("WhoMoves")
	if not who_moves_node:
		return
	
	if party_battle_faces.is_empty() or current_party_plan_index >= party_battle_faces.size():
		who_moves_node.visible = false
		return
	
	# Get the position of the current party battle face
	var current_face = party_battle_faces[current_party_plan_index]
	if current_face and is_instance_valid(current_face):
		who_moves_node.visible = true
		# Position the indicator over the current party member
		# The WhoMoves node is at the parent level, so we need global coordinates
		var face_global_pos = current_face.global_position
		who_moves_node.global_position = Vector2(face_global_pos.x - 55, face_global_pos.y)
		
		# Emit signal for UI updates
		planning_index_changed.emit(current_party_plan_index)

## Advances the planning index to the next party member
func advance_planning_index():
	if party_battle_faces.is_empty():
		return
	
	current_party_plan_index = wrapi(current_party_plan_index + 1, 0, party_battle_faces.size())
	_update_who_moves_indicator()

## Goes back to the previous party member in planning
func previous_planning_index():
	if party_battle_faces.is_empty():
		return
	
	current_party_plan_index = wrapi(current_party_plan_index - 1, 0, party_battle_faces.size())
	_update_who_moves_indicator()

## Resets planning index to start
func reset_planning_index():
	current_party_plan_index = 0
	_update_who_moves_indicator()

## Gets the current party member being planned for
func get_current_planning_party() -> Resource:
	if party_battle_faces.is_empty() or current_party_plan_index >= party_battle_faces.size():
		return null
	
	# Get the party resource from the battle actor
	for actor in battle_actors:
		if not actor.is_enemy and actor.id == party_members[current_party_plan_index].character_id:
			return actor.resource
	
	return party_members[current_party_plan_index] if current_party_plan_index < party_members.size() else null
