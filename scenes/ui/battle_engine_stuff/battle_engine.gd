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
		var actor = BattleTypes.BattleActor.new(p, false, null)
		battle_actors.append(actor)
	
	for e in enemy_members:
		var actor = BattleTypes.BattleActor.new(e, true, null)
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
		initiative_manager.reset_round(battle_actors)
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
		state = BattleTypes.BattleState.PLANNING
		action_planner.start_planning(battle_actors.filter(func(a): return not a.is_enemy))
		# UI should show action menu here
	else:
		_execute_player_action(current_actor)

## Handles enemy turn
func _handle_enemy_turn():
	state = BattleTypes.BattleState.EXECUTING
	
	# Get enemy AI personality from Global.AI enum
	var global_ai = Global.AI.Casual  # Default
	if current_actor.resource is Enemy:
		var enemy_res = current_actor.resource as Enemy
		if enemy_res.has_property("ai_type") or enemy_res.has_method("get_ai_type"):
			global_ai = enemy_res.get("ai_type") if enemy_res.has_property("ai_type") else enemy_res.call("get_ai_type")
	
	var personality = ai_manager.get_personality_from_global(global_ai)
	
	# Decide action
	var action = ai_manager.decide_action(current_actor, battle_actors.filter(func(a): return not a.is_enemy), battle_actors.filter(func(a): return a.is_enemy), personality)
	
	if not action.is_empty():
		await _execute_action(action)
	
	# Check end conditions
	_check_end_conditions()
	
	# Next turn
	if state != BattleTypes.BattleState.VICTORY and state != BattleTypes.BattleState.DEFEAT:
		_start_next_turn()

## Player selects an action
func player_select_action(action_type: BattleTypes.ActionType, target: BattleTypes.BattleActor = null, skill_id: String = "", item_id: String = ""):
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
	var actor = _get_actor_by_id(action.source_id)
	if not actor or actor.is_dead:
		return
	
	state = BattleTypes.BattleState.ANIMATING
	
	var result = {}
	
	match action.type:
		BattleTypes.ActionType.ATTACK:
			var target = _get_target_by_id(action.target_ids)
			if target:
				result = attack_executor.execute_attack(actor, target)
		
		BattleTypes.ActionType.SKILL:
			var target = _get_target_by_id(action.target_ids)
			var skill_data = _get_skill_data(actor, action.skill_id)
			if target and not skill_data.is_empty():
				result = attack_executor.execute_skill(actor, target, skill_data)
		
		BattleTypes.ActionType.ITEM:
			var target = _get_target_by_id(action.target_ids)
			var item_data = _get_item_data(action.item_id)
			item_manager.use_item(actor, item_data, target)
		
		BattleTypes.ActionType.DEFEND:
			_apply_defend(actor)
		
		BattleTypes.ActionType.RUN:
			_attempt_escape()
	
	action_executed.emit(action)
	state = BattleTypes.BattleState.PLANNING if is_player_phase else BattleTypes.BattleState.EXECUTING

## Executes an action from dictionary (for AI decisions)
func _execute_action_from_dict(action_dict: Dictionary):
	if action_dict.is_empty():
		return
	
	state = BattleTypes.BattleState.ANIMATING
	
	var actor = action_dict.get("actor") as BattleTypes.BattleActor
	var action_type = action_dict.get("type") as BattleTypes.ActionType
	var target = action_dict.get("target") as BattleTypes.BattleActor
	var data = action_dict.get("data", {})
	
	var result = {}
	
	match action_type:
		BattleTypes.ActionType.ATTACK:
			if target:
				result = attack_executor.execute_attack(actor, target)
		
		BattleTypes.ActionType.SKILL:
			if target and not data.is_empty():
				result = attack_executor.execute_skill(actor, target, data)
		
		BattleTypes.ActionType.DEFEND:
			_apply_defend(actor)
		
		BattleTypes.ActionType.RUN:
			_attempt_escape()
	
	state = BattleTypes.BattleState.PLANNING if is_player_phase else BattleTypes.BattleState.EXECUTING

## Executes a player action directly (no planning phase)
func _execute_player_action(actor: BattleTypes.BattleActor):
	# Default to attack for now
	var target = _get_random_enemy_target()
	var action = BattleTypes.PlannedAction.new(actor.id, BattleTypes.ActionType.ATTACK)
	if target:
		action.target_ids = [target.id]
	
	var action_dict = {
		"actor": actor,
		"type": BattleTypes.ActionType.ATTACK,
		"target": target,
		"data": {}
	}
	await _execute_action_from_dict(action_dict)

## Gets skill data from actor
func _get_skill_data(actor: BattleTypes.BattleActor, skill_id: String) -> Dictionary:
	if actor.resource is Party:
		var p: Party = actor.resource as Party
		for key in p.skills.keys():
			var skill: Skill = p.skills[key]
			if skill and skill is Skill:
				if skill.name == skill_id or str(key) == skill_id:
					return {
						"skill": skill,
						"name": skill.name,
						"attack_type": skill.attack_type,
						"target_type": skill.target_type,
						"mana_cost": skill.mana_cost,
						"accuracy": skill.accuracy,
						"effects": skill.effects,
						"attack_multiplier": skill.attack_multiplier,
						"attack_bonus": skill.attack_bonus,
						"hit_count": skill.hit_count,
						"hit_damage_multiplier": skill.hit_damage_multiplier,
						"item_reference": skill.item_reference
					}
	return {}

## Gets item data
func _get_item_data(item_id: String) -> Dictionary:
	# This should fetch from game's item database
	return {"id": item_id, "name": "Unknown Item", "effect_type": "heal", "value": 50}

## Applies defend action
func _apply_defend(actor: BattleTypes.BattleActor):
	# Add defend status effect via effect_manager
	if effect_manager and actor.sprite:
		effect_manager.apply_defend(actor.sprite)
	
	if logger:
		logger.add_message("%s is defending!" % [actor.name], "#90EE90")

## Attempts to escape from battle
func _attempt_escape():
	var success = randf() < escape_chance
	
	if logger:
		logger.add_escape_message(success)
	
	if success:
		state = BattleTypes.BattleState.ESCAPED
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
		var actor = _get_actor_by_id(action.source_id)
		if actor and not actor.is_dead:
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
	for actor in battle_actors:
		if actor.is_enemy and not actor.is_dead:
			# Get enemy AI personality from Global.AI enum
			var global_ai = Global.AI.Casual  # Default
			if actor.resource is Enemy:
				var enemy_res = actor.resource as Enemy
				if "ai_type" in enemy_res:
					global_ai = enemy_res.ai_type
			
			var personality = ai_manager.get_personality_from_global(global_ai)
			
			var action = ai_manager.decide_action(actor, battle_actors.filter(func(a): return not a.is_enemy), battle_actors.filter(func(a): return a.is_enemy), personality)
			
			if not action.is_empty():
				await _execute_action(action)
				
				if _check_end_conditions():
					return
	
	# Enemy phase complete, recalculate initiative
	if state != BattleTypes.BattleState.VICTORY and state != BattleTypes.BattleState.DEFEAT:
		initiative_manager.reset_round(battle_actors)
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
func _on_turn_started(actor: BattleTypes.BattleActor):
	current_actor = actor

## Gets party members
func get_party_members() -> Array[Resource]:
	return party_members

## Gets enemy members
func get_enemy_members() -> Array[Resource]:
	return enemy_members

## Checks if battle is active
func is_battle_active() -> bool:
	return state != BattleTypes.BattleState.VICTORY and state != BattleTypes.BattleState.DEFEAT and state != BattleTypes.BattleState.ESCAPED

## Helper to get random enemy target
func _get_random_enemy_target() -> BattleTypes.BattleActor:
	for actor in battle_actors:
		if actor.is_enemy and not actor.is_dead:
			return actor
	return null

## Helper to get target by ID from target_ids array
func _get_target_by_id(target_ids: Array[String]) -> BattleTypes.BattleActor:
	if target_ids.is_empty():
		return null
	for actor in battle_actors:
		if actor.id == target_ids[0]:
			return actor
	return null

## Helper to get actor by ID
func _get_actor_by_id(actor_id: String) -> BattleTypes.BattleActor:
	for actor in battle_actors:
		if actor.id == actor_id:
			return actor
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
