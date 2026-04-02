extends Node2D
class_name BattleEngine

## ============================================================================
## BATTLE ENGINE - Complete Rewrite
## A modular, component-based battle system for turn-based RPG combat
## ============================================================================

#region SIGNALS
signal battle_started()
signal battle_ended(victory: bool)
signal turn_started(actor: Object)
signal action_selected(actor: Object, action: Dictionary)
signal attack_executed(attacker: Object, targets: Array, damage: int)
signal enemy_defeated(enemy: Enemy)
signal party_member_defeated(member: Party)
#endregion

#region EXPORTS
@export var battle: Battle
@export var debug_mode: bool = false
#endregion

#region CONSTANTS
const EFFECT_ATLAS_PATH := "res://assets/battleui/status_effects.png"
const EFFECT_TILE_SIZE := 64
const EFFECT_COLS := 4
const MAX_ENEMIES := 5
const BASE_ESCAPE_CHANCE := 0.7
#endregion

#region ENUMS
enum BattleState { 
	INITIALIZING,
	PLAYER_PLANNING, 
	TARGET_SELECTING,
	ENEMY_PLANNING,
	EXECUTING,
	ANIMATING,
	VICTORY,
	DEFEAT,
	ESCAPED
}

enum ActionMenuState {
	HIDDEN,
	MAIN_MENU,
	SKILLS_MENU,
	ITEMS_MENU,
	TARGET_SELECT
}
#endregion

#region CORE VARIABLES
var party: Array[Party] = []
var enemies: Array[Enemy] = []
var initiative_order: Array[Object] = []
var current_initiative_index: int = -1
var current_actor: Object = null
var battle_state: BattleState = BattleState.INITIALIZING
var action_menu_state: ActionMenuState = ActionMenuState.HIDDEN
var planning_phase: bool = true
var battle_turn: int = 0
var battle_start_position: Vector2 = Vector2.ZERO
#endregion

#region PLANNING VARIABLES
var planned_actions: Dictionary = {}  # {actor: {action_type, skill, targets}}
var action_history: Array[Object] = []
var current_party_plan_index: int = 0
var selected_enemy_index: int = 0
var selected_party_index: int = 0
var previous_enemy_index: int = 0
var is_animating_death: bool = false
#endregion

#region UI REFERENCES
var skills_container: Control
var items_container: Control
var skill_boxes: Array[SkillBox] = []
var item_boxes: Array[ItemBox] = []
var available_skills: Array[Skill] = []
var available_items: Array[Resource] = []
var item_amounts: Array[int] = []
var current_skill_index: int = 0
var current_item_index: int = 0
var skill_scroll_offset: int = 0
var item_scroll_offset: int = 0
var max_visible_entries: int = 8
var skill_box_scene: PackedScene
var item_box_scene: PackedScene
#endregion

#region ITEM TARGETING
var item_target_type: int = 0  # 0 = enemy, 1 = party
var saved_party_plan_index: int = 0
#endregion

#region GAME OVER
var game_over_active: bool = false
var game_over_overlay: ColorRect
var game_over_texture: TextureRect
var can_reload: bool = false
#endregion

#region COMPONENT MANAGERS
var initiative_manager: BattleInitiativeManager
var action_planner: BattleActionPlanner
var effect_manager: BattleEffectManager
var battle_logger: BattleLogger
var attack_executor: BattleAttackExecutor
var end_condition_checker: BattleEndConditionChecker
var item_manager: BattleItemManager
#endregion

#region TIMERS
var log_timer: float = 0.0
var log_display_time: float = 8.0
#endregion

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	battle_start_position = Global.player_position
	party = Global.party.duplicate()
	
	_initialize_component_managers()
	await _setup_battle_environment()
	_initialize_ui_components()
	_setup_game_over_ui()
	_setup_battle_log_display()
	
	battle_state = BattleState.PLAYER_PLANNING
	planning_phase = true
	battle_turn = 1
	
	battle_started.emit()
	_start_player_planning_phase()

func _initialize_component_managers() -> void:
	initiative_manager = BattleInitiativeManager.new(party)
	action_planner = BattleActionPlanner.new()
	effect_manager = BattleEffectManager.new()
	battle_logger = BattleLogger.new()
	attack_executor = BattleAttackExecutor.new(self)
	end_condition_checker = BattleEndConditionChecker.new()
	item_manager = BattleItemManager.new(self)

func _setup_battle_environment() -> void:
	await get_tree().create_timer(0.02).timeout
	
	if battle == null and Global.battle_current:
		battle = Global.battle_current.duplicate(true)
	elif battle:
		battle = battle.duplicate(true)
	
	Global.battle_ref = self
	
	await get_tree().create_timer(0.01).timeout
	
	_setup_enemies()
	initiative_order = initiative_manager.setup_initiative(battle)
	enemies = _get_active_enemies()
	_setup_party_ui()
	
	if battle.music_override:
		$AudioStreamPlayer.stream = battle.music_override

func _initialize_ui_components() -> void:
	_setup_skills_ui()
	item_manager.setup_items_ui()
	items_container = item_manager.items_container
	item_box_scene = item_manager.item_box_scene

func _start_player_planning_phase() -> void:
	planning_phase = true
	action_planner.planning_phase = true
	planned_actions.clear()
	action_history.clear()
	current_party_plan_index = 0
	current_initiative_index = -1
	
	_find_next_party_member_to_plan()

func _find_next_party_member_to_plan() -> void:
	var start_index = (current_initiative_index + 1) % initiative_order.size() if initiative_order.size() > 0 else 0
	
	for i in range(initiative_order.size()):
		var idx = (start_index + i) % initiative_order.size()
		var actor = initiative_order[idx]
		
		if actor is Party and not action_planner.has_planned_action(actor) and actor.hp > 0:
			current_initiative_index = idx
			current_actor = actor
			current_party_plan_index = action_history.size()
			_show_action_menu()
			_update_who_moves_indicator()
			return
	
	_start_resolution_phase()

func _start_resolution_phase() -> void:
	planning_phase = false
	action_planner.planning_phase = false
	battle_state = BattleState.ENEMY_PLANNING
	_hide_action_menu()
	
	_plan_enemy_actions()
	
	await get_tree().create_timer(0.4).timeout
	
	battle_state = BattleState.EXECUTING
	_execute_initiative_turn()

func _plan_enemy_actions() -> void:
	for actor in initiative_order:
		if actor is Enemy and actor.hp > 0:
			_generate_enemy_ai_action(actor)

func _generate_enemy_ai_action(enemy: Enemy) -> void:
	if enemy.attacks.is_empty():
		return
	
	var available_attacks: Array[Skill] = []
	for atk in enemy.attacks:
		if atk.mana_cost <= enemy.mp:
			available_attacks.append(atk)
	
	if available_attacks.is_empty():
		return
	
	var selected_attack: Skill = available_attacks[randi_range(0, available_attacks.size() - 1)]
	var targets: Array[Party] = _select_enemy_targets(enemy, selected_attack)
	
	if not targets.is_empty():
		action_planner.add_attack(enemy, targets, selected_attack)

func _select_enemy_targets(enemy: Enemy, attack: Skill) -> Array[Party]:
	var valid_targets: Array[Party] = []
	for p in party:
		if p.hp > 0:
			valid_targets.append(p)
	
	if valid_targets.is_empty():
		return []
	
	if attack.target_type == 2:  # Party-wide
		return valid_targets
	
	# AI targeting logic based on ai_type
	var dumbness = [10, 4, 3, 3, 1]
	var target_weights: Array[int] = []
	var lowest_hp_index = 0
	
	for i in range(valid_targets.size()):
		target_weights.append(1)
		if valid_targets[i].hp < valid_targets[lowest_hp_index].hp:
			lowest_hp_index = i
	
	var rng = randi_range(1, dumbness[enemy.ai_type])
	if rng <= 2:
		target_weights[lowest_hp_index] += 3 - rng
	else:
		var valid_indices: Array[int] = []
		for i in range(target_weights.size()):
			if target_weights[i] > 0:
				valid_indices.append(i)
		if not valid_indices.is_empty():
			target_weights[valid_indices[randi_range(0, valid_indices.size() - 1)]] += 1
	
	# Apply focus effect weighting
	for i in range(valid_targets.size()):
		if Global.effect.Focus in valid_targets[i].effects:
			target_weights[i] += 5 if enemy.ai_type != 4 else 1
	
	# Weighted random selection
	var total_weight = 0
	for w in target_weights:
		total_weight += w
	
	if total_weight == 0:
		return [valid_targets[0]]
	
	var rng_weight = randi_range(1, total_weight)
	for i in range(target_weights.size()):
		rng_weight -= target_weights[i]
		if rng_weight <= 0 and target_weights[i] > 0:
			return [valid_targets[i]]
	
	return [valid_targets[0]]

# ============================================================================
# ENEMY SETUP
# ============================================================================

func _setup_enemies() -> void:
	for e in range(MAX_ENEMIES):
		var path = "Control/enemy_ui/enemies/enemy" + str(e + 1)
		var enemy_key = 'enemy_pos' + str(e + 1)
		
		if battle.get(enemy_key):
			var enemy_data = battle.get(enemy_key).duplicate(true)
			battle.set(enemy_key, enemy_data)
			
			var node = get_node_or_null(path)
			if node:
				node.texture = enemy_data.battleSprite
				node.hp = enemy_data.hp
				node.max_hp = enemy_data.max_hp
				
				_ensure_effect_container(node)
		else:
			var prog = get_node_or_null(path + "/ProgressBar")
			if prog:
				prog.visible = false

func _ensure_effect_container(parent: Node) -> void:
	var effect_cont = parent.get_node_or_null("EffectContainer")
	if not effect_cont:
		effect_cont = GridContainer.new()
		effect_cont.name = "EffectContainer"
		effect_cont.columns = 4
		effect_cont.add_theme_constant_override("h_separation", 4)
		effect_cont.add_theme_constant_override("v_separation", 4)
		effect_cont.custom_minimum_size = Vector2(128, 64)
		effect_cont.position = Vector2(0, 64)
		parent.add_child(effect_cont)

func _setup_party_ui() -> void:
	var party_container = $Control/gui/HBoxContainer2/party
	for child in party_container.get_children():
		child.queue_free()
	
	for p in initiative_order:
		if p is Party:
			var ui = preload("res://scenes/ui/battle_engine_stuff/partyBattleFace.tscn").instantiate()
			ui.setup(p)
			party_container.add_child(ui)

func _get_active_enemies() -> Array[Enemy]:
	var active: Array[Enemy] = []
	for e in range(MAX_ENEMIES):
		var enemy_key = 'enemy_pos' + str(e + 1)
		if battle.get(enemy_key) and battle.get(enemy_key).hp > 0:
			active.append(battle.get(enemy_key))
	return active

# ============================================================================
# UI SETUP
# ============================================================================

func _setup_skills_ui() -> void:
	skill_box_scene = preload("res://scenes/ui/battle_engine_stuff/skill_box.tscn")
	
	if not has_node("Control/gui/HBoxContainer2/skills_container"):
		skills_container = Control.new()
		skills_container.name = "skills_container"
		skills_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		skills_container.visible = false
		
		var scroll = ScrollContainer.new()
		scroll.name = "ScrollContainer"
		scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		skills_container.add_child(scroll)
		
		var grid = GridContainer.new()
		grid.name = "SkillGrid"
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.custom_minimum_size = Vector2(1296, 0)
		
		scroll.add_child(grid)
		$Control/gui/HBoxContainer2.add_child(skills_container)
	else:
		skills_container = $Control/gui/HBoxContainer2/skills_container

func _setup_game_over_ui() -> void:
	game_over_overlay = ColorRect.new()
	game_over_overlay.name = "GameOverOverlay"
	game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.color = Color(0, 0, 0, 0)
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_over_overlay)
	
	game_over_texture = TextureRect.new()
	game_over_texture.name = "GameOverTexture"
	game_over_texture.set_anchors_preset(Control.PRESET_CENTER)
	game_over_texture.texture = load("res://assets/ui/game_over.png") if ResourceLoader.exists("res://assets/ui/game_over.png") else null
	game_over_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game_over_texture.modulate.a = 0
	game_over_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_over_texture)

func _setup_battle_log_display() -> void:
	var label: RichTextLabel = $Control/enemy_ui/CenterContainer/output
	if label is RichTextLabel:
		label.bbcode_enabled = true
		label.fit_content = true
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# ============================================================================
# MAIN LOOP & INPUT
# ============================================================================

func _process(delta: float) -> void:
	_update_enemy_hp_display()
	_update_flash_indicator()
	
	if battle_state == BattleState.PLAYER_PLANNING or battle_state == BattleState.TARGET_SELECTING:
		if action_menu_state == ActionMenuState.SKILLS_MENU or action_menu_state == ActionMenuState.TARGET_SELECT and _is_skill_targeting():
			_check_skill_overlap()
		elif action_menu_state == ActionMenuState.ITEMS_MENU or action_menu_state == ActionMenuState.TARGET_SELECT and _is_item_targeting():
			_check_item_overlap()
	
	if not battle_logger.battle_log.is_empty():
		log_timer += delta
		if log_timer >= log_display_time:
			log_timer = 0.0
			battle_logger.remove_oldest_log_entry()

func _input(event: InputEvent) -> void:
	if game_over_active:
		if can_reload and (event.is_action("use") or event.is_action("menu")):
			Global.reload_last_save()
		return
	
	if battle_state == BattleState.EXECUTING or battle_state == BattleState.ANIMATING:
		if event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	
	if planning_phase and (event.is_action_pressed("ui_undo") or event.is_action_pressed("ui_cancel")):
		_handle_cancel_input()
		return
	
	if not event.is_pressed() or event is InputEventMouseMotion:
		return
	
	match battle_state:
		BattleState.PLAYER_PLANNING:
			_handle_planning_input(event)
		BattleState.TARGET_SELECTING:
			_handle_target_select_input(event)

func _handle_cancel_input() -> void:
	match action_menu_state:
		ActionMenuState.SKILLS_MENU:
			_close_skills_menu()
		ActionMenuState.ITEMS_MENU:
			_close_items_menu()
		_:
			_undo_last_action()

func _handle_planning_input(event: InputEvent) -> void:
	match action_menu_state:
		ActionMenuState.MAIN_MENU:
			if event.is_action_pressed("down"):
				_move_action_cursor(1)
			elif event.is_action_pressed("up"):
				_move_action_cursor(-1)
			elif event.is_action_pressed("use"):
				_simulate_action_button_press()
		
		ActionMenuState.SKILLS_MENU:
			_handle_skills_input(event)
		
		ActionMenuState.ITEMS_MENU:
			_handle_items_input(event)
		
		ActionMenuState.TARGET_SELECT:
			_handle_target_select_input(event)

func _handle_skills_input(event: InputEvent) -> void:
	if event.is_action_pressed("down"):
		_navigate_skills(2)
	elif event.is_action_pressed("up"):
		_navigate_skills(-2)
	elif event.is_action_pressed("right"):
		_navigate_skills(1)
	elif event.is_action_pressed("left"):
		_navigate_skills(-1)
	elif event.is_action_pressed("use"):
		_select_skill()
	elif event.is_action_pressed("ui_cancel"):
		_close_skills_menu()

func _handle_items_input(event: InputEvent) -> void:
	if event.is_action_pressed("down"):
		_navigate_items(2)
	elif event.is_action_pressed("up"):
		_navigate_items(-2)
	elif event.is_action_pressed("right"):
		_navigate_items(1)
	elif event.is_action_pressed("left"):
		_navigate_items(-1)
	elif event.is_action_pressed("use"):
		_select_item()
	elif event.is_action_pressed("ui_cancel"):
		_close_items_menu()

func _handle_target_select_input(event: InputEvent) -> void:
	if _is_skill_targeting():
		_handle_skill_target_input(event)
	elif _is_item_targeting():
		_handle_item_target_input(event)

func _handle_skill_target_input(event: InputEvent) -> void:
	if event.is_action_pressed("left"):
		_move_enemy_selection(-1)
	elif event.is_action_pressed("right"):
		_move_enemy_selection(1)
	elif event.is_action_pressed("use"):
		_confirm_skill_target()
	elif event.is_action_pressed("ui_cancel"):
		_close_skills_menu()

func _handle_item_target_input(event: InputEvent) -> void:
	if item_target_type == 0:  # Enemy target
		if event.is_action_pressed("left"):
			_move_enemy_selection(-1)
		elif event.is_action_pressed("right"):
			_move_enemy_selection(1)
		elif event.is_action_pressed("use"):
			_confirm_item_target()
	elif item_target_type == 1:  # Party target
		var party_in_initiative = initiative_manager.get_party_members_from_initiative()
		if event.is_action_pressed("left"):
			selected_party_index = wrapi(selected_party_index - 1, 0, party_in_initiative.size())
			_update_party_target_highlight()
		elif event.is_action_pressed("right"):
			selected_party_index = wrapi(selected_party_index + 1, 0, party_in_initiative.size())
			_update_party_target_highlight()
		elif event.is_action_pressed("use"):
			_confirm_item_target()
	
	if event.is_action_pressed("ui_cancel"):
		if item_target_type == 1:
			$WhoMoves.visible = true
			_update_who_moves_indicator()
		_close_items_menu()

# ============================================================================
# ACTION MENU NAVIGATION
# ============================================================================

func _show_action_menu() -> void:
	action_menu_state = ActionMenuState.MAIN_MENU
	_update_who_moves_indicator()

func _hide_action_menu() -> void:
	action_menu_state = ActionMenuState.HIDDEN
	$WhoMoves.visible = false

func _move_action_cursor(direction: int) -> void:
	var move_node = $TheMove
	if move_node.position.y == 487 and direction == -1:
		move_node.position.y = 615
	elif move_node.position.y == 615 and direction == 1:
		move_node.position.y = 487
	else:
		move_node.position.y += 32 * direction

func _simulate_action_button_press() -> void:
	var area_node = $TheMove/Area2D
	if not area_node.get_overlapping_areas().is_empty():
		var area = area_node.get_overlapping_areas()[0]
		
		# Check skill box overlap
		if area.owner is SkillBox or area.get_parent() is SkillBox:
			var skill_box = area.owner if area.owner is SkillBox else area.get_parent()
			if skill_box is SkillBox:
				current_skill_index = skill_box.skill_index
				_select_skill()
				return
		
		# Check item box overlap
		if area.owner is ItemBox or area.get_parent() is ItemBox:
			var item_box = area.owner if area.owner is ItemBox else area.get_parent()
			if item_box is ItemBox:
				current_item_index = item_box.item_index
				_select_item()
				return
		
		# Check action buttons
		var buttons = [
			$Control/gui/HBoxContainer2/actions/FightButton/fight,
			$Control/gui/HBoxContainer2/actions/SkillsButton/skills,
			$Control/gui/HBoxContainer2/actions/DefendButton/defend,
			$Control/gui/HBoxContainer2/actions/ItemButton/item,
			$Control/gui/HBoxContainer2/actions/RunButton/run
		]
		var funcs = [
			_on_fight_button_pressed,
			_on_skills_button_pressed,
			_on_defend_button_pressed,
			_on_item_button_pressed,
			_on_run_button_pressed
		]
		
		for i in range(buttons.size()):
			if area == buttons[i]:
				funcs[i].call()
				break

func _update_who_moves_indicator() -> void:
	$WhoMoves.visible = true
	$WhoMoves.position.x = 220 + (current_party_plan_index * $WhoMoves.size.x)

func _move_enemy_selection(direction: int) -> void:
	if direction == 0:
		return
	
	while true:
		selected_enemy_index = wrapi(selected_enemy_index + direction, 0, MAX_ENEMIES)
		var enemy_key = 'enemy_pos' + str(selected_enemy_index + 1)
		if battle.get(enemy_key) and battle.get(enemy_key).hp > 0:
			break

func _update_flash_indicator() -> void:
	for c in $Control/enemy_ui/enemies.get_children():
		if c.material:
			c.material.set("shader_parameter/is_flashing", c.name == "enemy" + str(selected_enemy_index + 1))

func _update_enemy_hp_display() -> void:
	for e in range(MAX_ENEMIES):
		var node = get_node_or_null("Control/enemy_ui/enemies/enemy" + str(e + 1))
		var enemy_key = 'enemy_pos' + str(e + 1)
		if node and battle.get(enemy_key):
			node.hp = max(0, battle.get(enemy_key).hp)

func _update_party_ui() -> void:
	var party_container = $Control/gui/HBoxContainer2/party
	if party_container:
		for i in range(party_container.get_child_count()):
			var ui = party_container.get_child(i)
			if ui.has_method("update_effects_ui"):
				ui.update_effects_ui()

func _update_party_target_highlight() -> void:
	var party_in_initiative = initiative_manager.get_party_members_from_initiative()
	if selected_party_index < party_in_initiative.size():
		var target = party_in_initiative[selected_party_index]
		_log_message("[color=#FFFF00]Targeting: " + target.name + "[/color]")

# ============================================================================
# SKILLS SYSTEM
# ============================================================================

func _open_skills_menu() -> void:
	action_menu_state = ActionMenuState.SKILLS_MENU
	skills_container.visible = true
	$Control/gui/HBoxContainer2/party.visible = false
	$WhoMoves.visible = false
	
	available_skills.clear()
	
	if current_actor is Party and current_actor.skills:
		var levels = current_actor.skills.keys()
		levels.sort()
		
		for level in levels:
			var skill = current_actor.skills[level]
			if skill and current_actor.level >= level:
				available_skills.append(skill)
	
	_create_skill_boxes()
	current_skill_index = 0
	skill_scroll_offset = 0
	_update_skill_selection()

func _create_skill_boxes() -> void:
	var grid = skills_container.get_node("ScrollContainer/SkillGrid")
	for child in grid.get_children():
		child.queue_free()
	skill_boxes.clear()
	
	for i in range(available_skills.size()):
		var skill = available_skills[i]
		var affordable = current_actor.mp >= skill.mana_cost
		var box = skill_box_scene.instantiate()
		grid.add_child(box)
		box.setup(skill, i, affordable)
		skill_boxes.append(box)
	
	_update_skill_selection()

func _update_skill_selection() -> void:
	for i in range(skill_boxes.size()):
		var box = skill_boxes[i]
		var affordable = current_actor.mp >= available_skills[i].mana_cost
		
		if i == current_skill_index and affordable:
			box.modulate = Color(1, 1, 0.5)
			box.set_collisions(true)
		else:
			box.modulate = Color(1, 1, 1) if affordable else Color(0.5, 0.5, 0.5)
			box.set_collisions(false)
	
	# Handle scrolling
	if current_skill_index >= skill_scroll_offset + max_visible_entries:
		skill_scroll_offset = current_skill_index - max_visible_entries + 1
	elif current_skill_index < skill_scroll_offset:
		skill_scroll_offset = current_skill_index
	
	var scroll = skills_container.get_node("ScrollContainer")
	scroll.scroll_vertical = skill_scroll_offset * 70

func _navigate_skills(direction: int) -> void:
	var new_index = current_skill_index + direction
	
	# Loop around
	if new_index < 0:
		new_index = skill_boxes.size() - 1
	elif new_index >= skill_boxes.size():
		new_index = 0
	
	# Skip unaffordable skills
	var attempts = 0
	while attempts < skill_boxes.size():
		if current_actor.mp >= available_skills[new_index].mana_cost:
			break
		new_index += direction
		if new_index < 0:
			new_index = skill_boxes.size() - 1
		elif new_index >= skill_boxes.size():
			new_index = 0
		attempts += 1
	
	if current_actor.mp >= available_skills[new_index].mana_cost:
		current_skill_index = new_index
		_update_skill_selection()

func _check_skill_overlap() -> void:
	var overlapping = $TheMove/Area2D.get_overlapping_areas()
	for area in overlapping:
		var parent = area.get_parent()
		if parent is SkillBox:
			var new_index = parent.skill_index
			if current_actor.mp >= available_skills[new_index].mana_cost and new_index != current_skill_index:
				current_skill_index = new_index
				_update_skill_selection()
			return

func _select_skill() -> void:
	if current_skill_index < 0 or current_skill_index >= available_skills.size():
		return
	
	var skill = available_skills[current_skill_index]
	
	if current_actor.mp < skill.mana_cost:
		_log_message("[color=#F44336]Not enough MP![/color]")
		await get_tree().create_timer(0.5).timeout
		return
	
	match skill.target_type:
		0:  # Single Enemy
			battle_state = BattleState.TARGET_SELECTING
			selected_enemy_index = previous_enemy_index if previous_enemy_index != 0 else 0
			_log_message("[color=#FFFF00]Select target...[/color]")
		1:  # Self
			_queue_action(current_actor, skill, [current_actor])
			_close_skills_menu()
		2:  # Party
			_queue_action(current_actor, skill, party.duplicate())
			_close_skills_menu()
		3:  # Single Ally
			battle_state = BattleState.TARGET_SELECTING
			selected_enemy_index = previous_enemy_index if previous_enemy_index != 0 else 0
			_log_message("[color=#FFFF00]Select ally...[/color]")

func _confirm_skill_target() -> void:
	var skill = available_skills[current_skill_index]
	
	if skill.target_type == 0:
		var enemy_key = 'enemy_pos' + str(selected_enemy_index + 1)
		var target = battle.get(enemy_key)
		if target and target.hp > 0:
			_queue_action(current_actor, skill, [target])
			_close_skills_menu()
	elif skill.target_type == 3:
		var target = party[clamp(selected_enemy_index, 0, party.size() - 1)]
		if target and target.hp > 0:
			_queue_action(current_actor, skill, [target])
			_close_skills_menu()

func _close_skills_menu() -> void:
	skills_container.visible = false
	$Control/gui/HBoxContainer2/party.visible = true
	$WhoMoves.visible = true
	battle_state = BattleState.PLAYER_PLANNING
	action_menu_state = ActionMenuState.MAIN_MENU

func _is_skill_targeting() -> bool:
	if available_skills.is_empty() or current_skill_index >= available_skills.size():
		return false
	var skill = available_skills[current_skill_index]
	return skill.target_type == 0 or skill.target_type == 3

# ============================================================================
# ITEMS SYSTEM
# ============================================================================

func _open_items_menu() -> void:
	item_manager.open_items_menu()

func _select_item() -> void:
	item_manager.select_item()

func _confirm_item_target() -> void:
	item_manager.confirm_item_target()

func _close_items_menu() -> void:
	item_manager.close_items_menu()

func _navigate_items(direction: int) -> void:
	item_manager.navigate_items(direction)

func _check_item_overlap() -> void:
	item_manager.check_item_overlap()

func _is_item_targeting() -> bool:
	return item_manager.item_target_type >= 0

# ============================================================================
# ACTION QUEUEING & EXECUTION
# ============================================================================

func _queue_action(actor: Object, skill: Skill, targets: Array) -> void:
	action_planner.add_attack(actor, targets, skill)
	action_history.append(actor)
	_advance_planning()

func _advance_planning() -> void:
	_find_next_party_member_to_plan()

func _undo_last_action() -> void:
	var last = action_planner.undo_last_action()
	if not last:
		return
	
	current_actor = last
	battle_state = BattleState.PLAYER_PLANNING
	action_menu_state = ActionMenuState.MAIN_MENU
	current_party_plan_index = action_history.size()
	_update_who_moves_indicator()
	_log_message("[color=#FFFF00]Undid " + last.name + "'s move[/color]")

# ============================================================================
# TURN EXECUTION
# ============================================================================

func _execute_initiative_turn() -> void:
	for i in range(initiative_order.size()):
		current_initiative_index = i
		var actor = initiative_order[current_initiative_index]
		
		if not is_instance_valid(actor) or actor.hp <= 0:
			continue
		
		current_actor = actor
		turn_started.emit(actor)
		
		# Check sleep status
		if effect_manager.get_effect_duration(actor, Global.effect.Sleep) > 0:
			if action_planner.has_planned_action(actor):
				action_planner.attack_array.erase(actor)
			_log_message("[color=#FFFF00]" + actor.name + " is asleep![/color]")
			await get_tree().create_timer(0.5).timeout
			continue
		
		if not action_planner.has_planned_action(actor):
			continue
		
		await _execute_single_action(actor)
	
	await _check_enemy_deaths_and_distribute_xp()
	await get_tree().create_timer(0.5).timeout
	
	# Check end conditions
	if await _check_custom_end_conditions():
		return
	
	# Check victory/defeat
	if _check_all_enemies_defeated():
		await _end_battle_victory()
		return
	
	if _check_party_wipe():
		_trigger_game_over()
		return
	
	# Start next round
	_start_new_round()

func _execute_single_action(actor: Object) -> void:
	if not action_planner.has_planned_action(actor):
		return
	
	var action_data = action_planner.attack_array[actor]
	var targets: Array = action_data[0]
	var skill: Skill = action_data[1]
	
	# Filter out dead targets
	var alive_targets: Array = []
	for t in targets:
		if is_instance_valid(t) and t.hp > 0:
			alive_targets.append(t)
	
	# Handle Check skill
	if skill.name == "Check ":
		await _handle_check_skill(actor, targets)
		return
	
	# Retarget if needed
	if alive_targets.is_empty() and skill.target_type == 0:
		alive_targets = _retarget_random_enemy()
		if alive_targets.is_empty():
			return
	
	if alive_targets.is_empty():
		return
	
	# Handle item usage
	if skill.attack_type == 3:
		await _handle_item_usage(actor, alive_targets, skill)
		return
	
	# Handle multi-attack
	if skill.attack_type == 2 and skill.name != "Check ":
		await _execute_multi_attack(actor, alive_targets[0], skill)
		return
	
	# Single target attack
	await _execute_single_target_attack(actor, alive_targets, skill)

func _handle_check_skill(attacker: Object, targets: Array) -> void:
	var desc = "[color=#2196F3]━━━ ENEMY INFO ━━━[/color]"
	if targets.size() > 0 and targets[0] is Enemy:
		var target_enemy = targets[0]
		desc += "\n[color=#FF5722]" + target_enemy.name + "[/color]: " + target_enemy.description
		desc += "\n[color=#4CAF50]HP: " + str(target_enemy.hp) + "/" + str(target_enemy.max_hp) + "[/color] [color=#FFC107]ATK: " + str(target_enemy.damage) + "[/color]"
	_log_message(desc)
	await get_tree().create_timer(1.5).timeout

func _retarget_random_enemy() -> Array:
	var enemies_list: Array = []
	for e in range(MAX_ENEMIES):
		var enemy_key = 'enemy_pos' + str(e + 1)
		if battle.get(enemy_key) and battle.get(enemy_key).hp > 0:
			enemies_list.append(battle.get(enemy_key))
	
	if not enemies_list.is_empty():
		return [enemies_list[randi_range(0, enemies_list.size() - 1)]]
	return []

func _handle_item_usage(attacker: Object, targets: Array, skill: Skill) -> void:
	var used_item = skill.item_reference
	if used_item and targets.size() > 0:
		var target = targets[0]
		var success = Global.use_item(used_item, target)
		
		if success:
			var item_log = "[color=#FFD700]━━━ ITEM ━━━[/color]"
			item_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + skill.name + "[/color] on [color=#FF5722]" + target.name + "[/color]"
			if used_item.heal_amount > 0:
				item_log += " [color=#4CAF50](+" + str(used_item.heal_amount) + " HP)[/color]"
			if used_item.mana_amount > 0:
				item_log += " [color=#2196F3](+" + str(used_item.mana_amount) + " MP)[/color]"
			_log_message(item_log)
			_update_party_ui()
			effect_manager.update_effect_ui(target, self)
		else:
			_log_message("[color=#F44336]Item use failed![/color]")
		
		await get_tree().create_timer(0.75).timeout

func _execute_multi_attack(attacker: Object, target: Object, skill: Skill) -> void:
	var total_dmg = 0
	var total_crits = 0
	var total_misses = 0
	
	var multi_log = "[color=#FFD700]━━━ MULTI-ATTACK ━━━[/color]"
	multi_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + skill.name + "[/color] on [color=#FF5722]" + target.name + "[/color]"
	
	for i in range(skill.hit_count):
		await get_tree().create_timer(0.15).timeout
		
		var crit = randi_range(1, 10 if attacker is Enemy else 8) == 1
		var base = (attacker.damage if attacker is Enemy else attacker.max_stats['atk']) * skill.attack_multiplier * skill.hit_damage_multiplier
		
		var power_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Power)
		var weak_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Weak)
		base *= power_mult * weak_mult
		
		if Global.effect.Power in attacker.effects:
			base *= 2
		base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
		if crit:
			base *= 1.5
		base += skill.attack_bonus
		
		# Check instakill
		if _check_instakill(attacker, target):
			target.hp = 0
			multi_log += "\nHit " + str(i + 1) + ": ★★★ INSTAKILL ★★★"
			await get_tree().create_timer(0.5).timeout
			if attacker is Party and target is Enemy:
				await _animate_enemy_death(target)
			_remove_from_battle(target)
			_log_message(multi_log)
			await get_tree().create_timer(1.0).timeout
			return
		
		var hit_result = _calculate_hit_damage(attacker, target, base, crit, skill)
		total_dmg += hit_result[0]
		if hit_result[1]:
			total_crits += 1
		if hit_result[2]:
			total_misses += 1
		
		multi_log += hit_result[3]
	
	# Apply total damage
	if total_dmg > 0:
		target.hp -= total_dmg
		if attacker is Party and target is Enemy:
			_gain_xp(attacker, target, total_dmg)
		effect_manager.apply_effects(target, skill)
		effect_manager.update_effect_ui(target, self)
	
	multi_log += "\n[color=#03A9F4]Total: " + str(total_dmg) + " DMG | "
	multi_log += str(skill.hit_count - total_misses) + "/" + str(skill.hit_count) + " hits"
	if total_crits > 0:
		multi_log += " | " + str(total_crits) + " CRITs"
	if skill.mana_cost > 0:
		multi_log += " | " + str(skill.mana_cost) + " MP"
	multi_log += "[/color]"
	
	_log_message(multi_log)
	await get_tree().create_timer(0.5).timeout
	
	if target.hp <= 0:
		if attacker is Party and target is Enemy:
			await _animate_enemy_death(target)
		_remove_from_battle(target)

func _execute_single_target_attack(attacker: Object, targets: Array, skill: Skill) -> void:
	var target = targets[0] if targets.size() > 0 else null
	if not target:
		return
	
	var crit = randi_range(1, 10 if attacker is Enemy else 8) == 1
	var base = (attacker.damage if attacker is Enemy else attacker.max_stats['atk']) * skill.attack_multiplier
	
	var power_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Power)
	var weak_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Weak)
	base *= power_mult * weak_mult
	
	if Global.effect.Power in attacker.effects:
		base *= 2
	base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
	if crit:
		base *= 1.5
	base += skill.attack_bonus
	
	var was_instakill = false
	if _check_instakill(attacker, target):
		target.hp = 0
		was_instakill = true
		if attacker is Party and target is Enemy:
			await _animate_enemy_death(target)
		_remove_from_battle(target)
	
	# Calculate defense mitigation
	var tough_mult = effect_manager.get_effect_multiplier(target, Global.effect.Tough)
	var sick_mult = effect_manager.get_effect_multiplier(target, Global.effect.Sick)
	var def_stat = target.max_stats["def"] if attacker is Enemy else target.defense * 2
	var defend_mult = 1.5 if Global.effect.Defend in target.effects else 1.0
	var def_mult = clampf(1.0 - (float(def_stat) / (100.0 / (tough_mult * sick_mult))), 0.0, 1.0)
	def_mult /= defend_mult
	def_mult = clampf(def_mult, 0.0, 1.0)
	
	var dmg = max(0, floor(base * def_mult))
	
	# Hit calculation
	var focus_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Focus)
	var blind_mult = effect_manager.get_effect_multiplier(target, Global.effect.Blind)
	var hit_chance = skill.accuracy * focus_mult * blind_mult
	var hit = randf() <= hit_chance
	
	var effects_applied: Array = []
	if hit and not was_instakill:
		$AnimationPlayer.play("move_around_screen")
		await $AnimationPlayer.animation_finished
		target.hp -= dmg
		effect_manager.apply_effects(target, skill)
		
		if skill.effects:
			for effect in skill.effects.keys():
				var effect_data = skill.effects[effect]
				effects_applied.append([effect, effect_data[0]])
		
		# Wake from sleep on hit
		if target.effects.has(Global.effect.Sleep):
			var sleep_level = target.effects[Global.effect.Sleep][0]
			if randf() < (1.0 - (0.1 * sleep_level)):
				effect_manager.remove_effect(target, Global.effect.Sleep)
		
		if attacker is Party and target is Enemy and target.hp <= 0:
			await _animate_enemy_death(target)
	
	attacker.mp = max(0, attacker.mp - skill.mana_cost)
	
	if not was_instakill:
		_print_attack_outcome(attacker, targets, skill, dmg, crit, not hit, skill.mana_cost, effects_applied)
	else:
		_log_message("[color=#FF0000]" + attacker.name + " used " + skill.name + ": ★★★ INSTAKILL ★★★[/color]")
	
	await get_tree().create_timer(0.5).timeout

func _calculate_hit_damage(attacker: Object, target: Object, base: float, crit: bool, skill: Skill) -> Array:
	var focus_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Focus)
	var blind_mult = effect_manager.get_effect_multiplier(target, Global.effect.Blind)
	var hit_chance = skill.accuracy * focus_mult * blind_mult
	var miss = randf() > hit_chance
	
	if miss:
		return [0, false, true, "\n[color=#FF9800]Hit MISSED[/color]"]
	
	var tough_mult = effect_manager.get_effect_multiplier(target, Global.effect.Tough)
	var sick_mult = effect_manager.get_effect_multiplier(target, Global.effect.Sick)
	var def_stat = target.max_stats["def"] if attacker is Enemy else target.defense * 2
	var defend_mult = 1.5 if Global.effect.Defend in target.effects else 1.0
	var def_mult = clampf(1.0 - (float(def_stat) / (100.0 / (tough_mult * sick_mult))), 0.0, 1.0)
	def_mult /= defend_mult
	def_mult = clampf(def_mult, 0.0, 1.0)
	
	var dmg = max(0, floor(base * def_mult))
	
	var result_str = "\n[color=" + ("#FF0000" if crit else "#FFFFFF") + "]Hit! " + str(dmg) + " DMG"
	if crit:
		result_str += " ★CRIT★"
	result_str += "[/color]"
	
	return [dmg, crit, false, result_str]

func _print_attack_outcome(attacker: Object, targets: Array, skill: Skill, dmg: int, crit: bool, miss: bool, mp_cost: int = 0, effects_applied: Array = []) -> void:
	if targets.is_empty():
		return
	
	var attacker_color = "#4CAF50" if attacker is Party else "#F44336"
	var target_color = "#FF5722" if targets[0] is Enemy else "#4CAF50"
	
	var outcome = ""
	if attacker == targets[0]:
		outcome = "[color=" + attacker_color + "]" + attacker.name + "[/color] used [color=#2196F3]" + skill.name + "[/color] on self"
		if mp_cost > 0:
			outcome += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
	elif miss:
		outcome = "[color=" + attacker_color + "]" + attacker.name + "[/color] missed [color=" + target_color + "]" + targets[0].name + "[/color]"
		if mp_cost > 0:
			outcome += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
	else:
		outcome = "[color=" + attacker_color + "]" + attacker.name + "[/color] hit [color=" + target_color + "]" + targets[0].name + "[/color] for [color=#FFFFFF]" + str(dmg) + "[/color]"
		if crit:
			outcome += " [color=#FFD700]★★CRIT★★[/color]"
		if mp_cost > 0:
			outcome += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
		if effects_applied.size() > 0:
			outcome += " [color=#E91E63]{"
			for i in range(effects_applied.size()):
				if i > 0:
					outcome += ", "
				outcome += effect_manager.get_effect_name_with_level(effects_applied[i][0], effects_applied[i][1])
			outcome += "}[/color]"
	
	_log_message(outcome)

# ============================================================================
# DEATH & VICTORY
# ============================================================================

func _gain_xp(actor: Object, target: Enemy, dmg: int) -> void:
	if actor is Party and target is Enemy:
		actor.xp += int(dmg * 0.1)

func _check_enemy_deaths_and_distribute_xp() -> void:
	var all_dead = true
	for e in range(MAX_ENEMIES):
		var enemy_key = 'enemy_pos' + str(e + 1)
		if battle.get(enemy_key) and battle.get(enemy_key).hp > 0:
			all_dead = false
			break
	
	if all_dead:
		var total_xp = 0
		for e in range(MAX_ENEMIES):
			var enemy_key = 'enemy_pos' + str(e + 1)
			if battle.get(enemy_key):
				total_xp += battle.get(enemy_key).xp_reward
		
		for actor in initiative_order:
			if actor is Party:
				actor.xp += total_xp
				_log_message("[color=#4CAF50]" + actor.name + " gained " + str(total_xp) + " XP![/color]")
				
				while actor.xp >= actor.xp_to_level_up:
					actor.xp -= actor.xp_to_level_up
					actor.level += 1
					actor.xp_to_level_up = ceil(actor.xp_to_level_up * actor.level_up_xp_multilpier)
					
					for stat in ["hp", "mp", "atk", "def", "ai"]:
						actor.max_stats[stat] += int(actor.level_up[stat] * actor.level)
						actor.base_stats[stat] += int(actor.level_up[stat] * actor.level)
					
					actor.hp = actor.max_stats["hp"]
					actor.mp = actor.max_stats["mp"]
					_log_message("[color=#FFD700]" + actor.name + " leveled up to " + str(actor.level) + "![/color]")
					await get_tree().create_timer(1.0).timeout
		
		await _end_battle_victory()

func _check_all_enemies_defeated() -> bool:
	for e in range(MAX_ENEMIES):
		var enemy_key = 'enemy_pos' + str(e + 1)
		if battle.get(enemy_key) and battle.get(enemy_key).hp > 0:
			return false
	return true

func _check_party_wipe() -> bool:
	for p in Global.party:
		if p.hp > 0:
			return false
	return true

func _check_custom_end_conditions() -> bool:
	if not battle or not battle.end_conditions or battle.end_conditions.is_empty():
		return false
	
	for condition in battle.end_conditions:
		if condition.check(self):
			condition.execute(self)
			return true
	
	return false

func _end_battle_victory() -> void:
	battle_state = BattleState.VICTORY
	await get_tree().create_timer(1.0).timeout
	Global.player_position = battle_start_position
	Global.loading = true
	get_tree().change_scene_to_file(Global.current_scene)
	Global.loading = false
	battle_ended.emit(true)

func _remove_from_battle(obj: Object) -> void:
	for i in range(initiative_order.size() - 1, -1, -1):
		if initiative_order[i] == obj:
			initiative_order.remove_at(i)
			if action_planner.has_planned_action(obj):
				action_planner.attack_array.erase(obj)
			if obj is Party and planning_phase and action_history.has(obj):
				action_history.erase(obj)
				current_party_plan_index -= 1
			break
	
	if obj is Party:
		party_member_defeated.emit(obj)
		_check_party_wipe()
	elif obj is Enemy:
		enemy_defeated.emit(obj)

func _trigger_game_over() -> void:
	game_over_active = true
	battle_state = BattleState.DEFEAT
	$Control/gui/HBoxContainer2.visible = false
	$Control/enemy_ui.visible = false
	$WhoMoves.visible = false
	
	var tween = create_tween()
	tween.tween_property(game_over_overlay, "modulate:a", 1.0, 2.0)
	await tween.finished
	
	if game_over_texture.texture:
		tween = create_tween()
		tween.tween_property(game_over_texture, "modulate:a", 1.0, 1.0)
		await tween.finished
	
	await get_tree().create_timer(1.0).timeout
	can_reload = true
	battle_ended.emit(false)

func _animate_enemy_death(enemy: Enemy) -> void:
	if is_animating_death:
		return
	is_animating_death = true
	
	var slot = 0
	for i in range(MAX_ENEMIES):
		var enemy_key = 'enemy_pos' + str(i + 1)
		if battle.get(enemy_key) == enemy:
			slot = i + 1
			break
	
	if slot == 0:
		is_animating_death = false
		return
	
	var node = get_node_or_null("Control/enemy_ui/enemies/enemy" + str(slot))
	if not node:
		is_animating_death = false
		return
	
	var original_pos = node.position
	var mat = node.material
	
	# Flash effect
	for i in range(20):
		if mat:
			mat.set("shader_parameter/flash_intensity", float(i) / 20.0)
		await get_tree().create_timer(0.05).timeout
	
	# Death animation
	var jitter = 3.0
	for i in range(30):
		node.position.y = original_pos.y + i * 2
		node.position.x = original_pos.x + randf_range(-jitter, jitter)
		jitter *= 0.95
		await get_tree().create_timer(0.03).timeout
	
	# Fade out
	for i in range(20):
		if mat:
			mat.set("shader_parameter/opacity", 1.0 - float(i) / 20.0)
		await get_tree().create_timer(0.05).timeout
	
	node.visible = false
	node.position = original_pos
	
	if mat:
		mat.set("shader_parameter/flash_intensity", 0.0)
		mat.set("shader_parameter/opacity", 1.0)
	
	_move_flash_to_next_enemy(slot)
	is_animating_death = false

func _move_flash_to_next_enemy(current_slot: int) -> void:
	for i in range(1, 6):
		var next = ((current_slot + i - 1) % 5) + 1
		var enemy_key = 'enemy_pos' + str(next)
		if battle.get(enemy_key) and battle.get(enemy_key).hp > 0:
			selected_enemy_index = next - 1
			return
	selected_enemy_index = 0

# ============================================================================
# ROUND MANAGEMENT
# ============================================================================

func _start_new_round() -> void:
	effect_manager.update_effects(initiative_order, self)
	action_planner.attack_array.clear()
	action_history.clear()
	planning_phase = true
	current_initiative_index = -1
	current_party_plan_index = 0
	battle_state = BattleState.PLAYER_PLANNING
	action_menu_state = ActionMenuState.MAIN_MENU
	$WhoMoves.visible = false
	_log_message("")
	battle_turn += 1
	_find_next_party_member_to_plan()

# ============================================================================
# ESCAPE MECHANIC
# ============================================================================

func _on_run_button_pressed() -> void:
	var enemy_ai_total = 0
	for e in range(MAX_ENEMIES):
		var enemy_key = 'enemy_pos' + str(e + 1)
		if battle.get(enemy_key):
			enemy_ai_total += battle.get(enemy_key).ai
	
	var party_ai_total = 0
	for p in party:
		party_ai_total += p.max_stats["ai"]
	
	var difficulty = clampf(enemy_ai_total - party_ai_total + 10, 0, 30)
	var escape_roll = randi_range(1, 20)
	
	if escape_roll > difficulty:
		# Successful escape
		Global.player_position = battle_start_position
		Global.loading = true
		get_tree().change_scene_to_file(Global.current_scene)
		Global.loading = false
		battle_state = BattleState.ESCAPED
		battle_ended.emit(true)
	else:
		_log_message("[color=#F44336]Couldn't escape![/color]")
		await get_tree().create_timer(0.5).timeout
		_start_new_round()

# ============================================================================
# BATTLE BUTTON CALLBACKS
# ============================================================================

func _on_fight_button_pressed() -> void:
	battle_state = BattleState.TARGET_SELECTING
	selected_enemy_index = previous_enemy_index if previous_enemy_index != 0 else 0

func _on_skills_button_pressed() -> void:
	_open_skills_menu()

func _on_defend_button_pressed() -> void:
	var defend_skill = load("res://resources/attacks/defend.tres")
	if defend_skill:
		_queue_action(current_actor, defend_skill, [current_actor])

func _on_item_button_pressed() -> void:
	_open_items_menu()

func _on_run_button_pressed_wrapper() -> void:
	_on_run_button_pressed()

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _log_message(text: String) -> void:
	log_timer = 0.0
	battle_logger.add_to_battle_log(text)
	_update_battle_log_display()

func _update_battle_log_display() -> void:
	var output = $Control/enemy_ui/CenterContainer/output
	if output is RichTextLabel:
		if battle_logger.battle_log.is_empty():
			output.text = ""
		else:
			output.text = "\n".join(battle_logger.battle_log)

func add_attack(attacker: Object, attacked: Array, attack: Skill) -> void:
	action_planner.add_attack(attacker, attacked, attack)

func check_instakill(attacker: Object, target: Object) -> bool:
	var kill_level = effect_manager.get_effect_level(attacker, Global.effect.Kill)
	if kill_level > 0:
		if target is Enemy and target.has("is_boss") and target.is_boss:
			return false
		var kill_chance = 0.01 * kill_level
		if randf() < kill_chance:
			return true
	return false

func apply_effects(target: Object, skill: Skill) -> void:
	if skill.effects:
		for effect in skill.effects.keys():
			var effect_data = skill.effects[effect]
			Global.apply_effect(target, effect, effect_data[0], effect_data[1])
