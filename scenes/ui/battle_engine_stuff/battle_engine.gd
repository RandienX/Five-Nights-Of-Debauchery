class_name BattleEngine
extends Node2D

## Main Battle Engine - Orchestrates all battle managers
## Based on tech_demo1_engine.gd as template
## Uses UP/DOWN input to select 5 action buttons (no $TheMove)

# Signals
signal battle_started()
signal battle_ended(victory: bool)
signal turn_changed(actor: Object, is_player: bool)

# Exported battle configuration
@export var battle: Battle

# Manager components
var initiative_manager: BattleInitiativeManager
var input_manager: BattleInputManager
var effect_manager: BattleEffectManager
var logger: BattleLogger
var attack_executor: BattleAttackExecutor
var action_planner: BattleActionPlanner

# Battle state - matches old engine states
enum states { OnAction, OnEnemy, OnSkills, OnSkillSelect, OnItems, OnItemSelect, Waiting, OnRun }
var state: states = states.OnAction

# Party and enemies (from Global)
var party: Array = []
var battle_start_position: Vector2 = Vector2.ZERO
var initiative: Array[Object] = []

# Planning phase variables
var planning_phase: bool = true
var action_history: Array[Object] = []
var current_attacker: Object
var attack_array: Dictionary = {}
var current_party_plan_index: int = 0
var selected_enemy: int = 1
var previous_enemy: int = 1
var initiative_who: int = -1
var is_animating_death: bool = false

# Game over variables
var game_over_active: bool = false
var game_over_overlay: ColorRect
var game_over_texture: TextureRect
var can_reload = false

# Battle log variables
var battle_log: Array[String] = []
var max_log_entries: int = 6
var log_display_time: float = 8.0
var log_timer: float = 0.0

# Effect system variables
var effect_durations: Dictionary = {}
const EFFECT_ATLAS_PATH = "res://assets/battleui/status_effects.png"
const EFFECT_TILE_SIZE = 64
const EFFECT_COLS = 4

# Skills UI variables
var skills_container: Control
var skill_boxes: Array = []
var current_skill_index: int = 0
var skill_box_scene: PackedScene

# Items UI variables
var items_container: Control
var item_boxes: Array = []
var current_item_index: int = 0
var item_box_scene: PackedScene
var item_target_type: int = 0
var saved_party_plan_index: int = 0
var selected_party_member: int = 0

# Configuration
var enable_planning_phase: bool = true

func _ready():
	battle_start_position = Global.player_position
	await get_tree().create_timer(0.02).timeout
	battle = Global.battle_current.duplicate(true)
	Global.battle_ref = self
	await get_tree().create_timer(0.05).timeout
	
	_initialize_managers()
	_connect_manager_signals()
	
	setup_enemies()
	initiative = setup_initiative()
	setup_party()
	setup_current_attacker()
	setup_skills_ui()
	setup_items_ui()
	_setup_game_over_ui()
	_setup_battle_log_label()
	
	if battle.music_override:
		$AudioStreamPlayer.stream = battle.music_override
	
	battle_started.emit()

## Initializes all manager components
func _initialize_managers():
	# Create and add managers
	initiative_manager = BattleInitiativeManager.new()
	initiative_manager.name = "BattleInitiativeManager"
	add_child(initiative_manager)
	
	input_manager = BattleInputManager.new()
	input_manager.name = "BattleInputManager"
	add_child(input_manager)
	
	effect_manager = BattleEffectManager.new()
	effect_manager.name = "BattleEffectManager"
	add_child(effect_manager)
	
	logger = BattleLogger.new()
	logger.name = "BattleLogger"
	add_child(logger)
	
	attack_executor = BattleAttackExecutor.new()
	attack_executor.name = "BattleAttackExecutor"
	add_child(attack_executor)
	
	action_planner = BattleActionPlanner.new()
	action_planner.name = "BattleActionPlanner"
	add_child(action_planner)
	
	# Initialize all managers with reference to this engine
	for manager in [initiative_manager, input_manager, effect_manager, logger, attack_executor, action_planner]:
		if manager.has_method("init_manager"):
			manager.init_manager(self)

## Connects manager signals
func _connect_manager_signals():
	if initiative_manager:
		initiative_manager.turn_started.connect(_on_turn_started)
		initiative_manager.round_complete.connect(_on_round_complete)
	
	if input_manager:
		input_manager.action_confirmed.connect(_on_action_confirmed)
		input_manager.cancel_pressed.connect(_on_cancel_pressed)
		input_manager.use_pressed.connect(_on_use_pressed)
		input_manager.left_pressed.connect(_on_left_pressed)
		input_manager.right_pressed.connect(_on_right_pressed)

func _process(delta):
	# Update flash effect
	update_flash()
	
	# Update enemy HP display
	for e in range(5):
		var node = get_node_or_null("Control/enemy_ui/enemies/enemy" + str(e + 1))
		if node and battle.get('enemy_pos' + str(e + 1)):
			node.hp = max(0, battle.get('enemy_pos' + str(e + 1)).hp)
	
	# Check skill/item overlap for UI updates
	if state == states.OnSkills or state == states.OnSkillSelect:
		check_skill_overlap()
	if state == states.OnItems or state == states.OnItemSelect:
		check_item_overlap()
	
	# Process battle log timer
	logger.process_log(delta)

func _input(event):
	if input_manager:
		input_manager.handle_input(event, game_over_active, can_reload, planning_phase)

## Sets up enemies from battle resource
func setup_enemies():
	for e in range(5):
		var path = "Control/enemy_ui/enemies/enemy" + str(e + 1)
		if battle.get('enemy_pos' + str(e + 1)):
			battle.set('enemy_pos' + str(e + 1), battle.get('enemy_pos' + str(e + 1)).duplicate(true))
			var node = get_node(path)
			node.texture = battle.get('enemy_pos' + str(e + 1)).battleSprite
			node.hp = battle.get('enemy_pos' + str(e + 1)).hp
			node.max_hp = battle.get('enemy_pos' + str(e + 1)).hp
			
			var effect_cont = node.get_node_or_null("EffectContainer")
			if not effect_cont:
				effect_cont = GridContainer.new()
				effect_cont.name = "EffectContainer"
				effect_cont.columns = 4
				effect_cont.add_theme_constant_override("h_separation", 4)
				effect_cont.add_theme_constant_override("v_separation", 4)
				effect_cont.custom_minimum_size = Vector2(128, 64)
				effect_cont.position = Vector2(0, 64)
				node.add_child(effect_cont)
		else:
			var prog = get_node_or_null(path + "/ProgressBar")
			if prog:
				prog.visible = false

## Sets up initiative order
func setup_initiative() -> Array[Object]:
	return initiative_manager.calculate_initiative(party, [])

## Sets up party UI
func setup_party():
	var party_container = get_node_or_null("Control/gui/HBoxContainer2/party")
	if not party_container:
		return
	
	for p in initiative:
		if p is Party or ("max_stats" in p):
			var ui = preload("res://scenes/ui/battle_engine_stuff/partyBattleFace.tscn").instantiate()
			party_container.add_child(ui)
			ui.setup(p)

## Sets up current attacker
func setup_current_attacker():
	for o in initiative:
		if o is Party or ("max_stats" in o):
			current_attacker = o
			break

## Sets up skills UI container
func setup_skills_ui():
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
		get_node("Control/gui/HBoxContainer2").add_child(skills_container)
	
	skills_container = get_node("Control/gui/HBoxContainer2/skills_container")

## Sets up items UI container
func setup_items_ui():
	item_box_scene = preload("res://scenes/ui/battle_engine_stuff/item_box.tscn")
	
	if not has_node("Control/gui/HBoxContainer2/items_container"):
		items_container = Control.new()
		items_container.name = "items_container"
		items_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		items_container.visible = false
		
		var scroll = ScrollContainer.new()
		scroll.name = "ScrollContainer"
		scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		items_container.add_child(scroll)
		
		var grid = GridContainer.new()
		grid.name = "ItemGrid"
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.custom_minimum_size = Vector2(1296, 0)
		
		scroll.add_child(grid)
		get_node("Control/gui/HBoxContainer2").add_child(items_container)
	
	items_container = get_node("Control/gui/HBoxContainer2/items_container")

## Sets up game over UI
func _setup_game_over_ui():
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

## Sets up battle log label
func _setup_battle_log_label():
	var label = get_node_or_null("Control/enemy_ui/CenterContainer/output")
	if label is RichTextLabel:
		label.bbcode_enabled = true
		label.fit_content = true
		label.autowrap_mode = TextServer.AUTOWRAY_WORD_SMART

## Updates flash effect on selected enemy
func update_flash():
	for c in get_node_or_null("Control/enemy_ui/enemies").get_children():
		if c.material:
			c.material.set("shader_parameter/is_flashing", c.name == "enemy" + str(selected_enemy))

## Moves enemy selection
func move_enemy_input(input: int):
	if input == 0:
		return
	while true:
		selected_enemy = wrapi(selected_enemy + input - 1, 0, 5) + 1
		if battle.get('enemy_pos' + str(selected_enemy)) in initiative:
			break

## Gets party members from initiative
func get_party_members_from_initiative() -> Array[Object]:
	return initiative_manager.get_party_members_from_initiative()

## Updates party UI effects
func update_party_ui():
	var party_container = get_node_or_null("Control/gui/HBoxContainer2/party")
	if party_container:
		for i in range(party_container.get_child_count()):
			var ui = party_container.get_child(i)
			if ui.has_method("update_effects_ui"):
				ui.update_effects_ui()

## Navigates skills grid
func navigate_skills(direction: int):
	# Implementation for skill navigation
	current_skill_index = wrapi(current_skill_index + direction, 0, skill_boxes.size())
	update_skill_selection()

## Updates skill selection visual
func update_skill_selection():
	for i in range(skill_boxes.size()):
		if skill_boxes[i]:
			skill_boxes[i].selected = (i == current_skill_index)

## Checks skill overlap
func check_skill_overlap():
	pass  # Implement as needed

## Selects current skill
func select_skill():
	# Open skill confirmation/targeting
	state = states.OnSkillSelect

## Confirms skill target
func confirm_skill_target():
	var current_skill = skill_boxes[current_skill_index] if current_skill_index < skill_boxes.size() else null
	if current_skill:
		action_planner.add_attack(current_attacker, [battle.get('enemy_pos' + str(selected_enemy))], current_skill.skill)
		action_history.append(current_attacker)
		advance_planning()

## Closes skills menu
func close_skills_menu():
	if skills_container:
		skills_container.visible = false
	state = states.OnAction

## Navigates items grid
func navigate_items(direction: int):
	current_item_index = wrapi(current_item_index + direction, 0, item_boxes.size())
	update_item_selection()

## Updates item selection visual
func update_item_selection():
	for i in range(item_boxes.size()):
		if item_boxes[i]:
			item_boxes[i].selected = (i == current_item_index)

## Checks item overlap
func check_item_overlap():
	pass  # Implement as needed

## Selects current item
func select_item():
	state = states.OnItemSelect

## Confirms item target
func confirm_item_target():
	var current_item = item_boxes[current_item_index] if current_item_index < item_boxes.size() else null
	if current_item:
		# Create skill from item
		var item_skill = Skill.new()
		item_skill.attack_type = 3
		item_skill.item_reference = current_item.item_resource
		action_planner.add_attack(current_attacker, [battle.get('enemy_pos' + str(selected_enemy))], item_skill)
		action_history.append(current_attacker)
		advance_planning()

## Closes items menu
func close_items_menu():
	if items_container:
		items_container.visible = false
	state = states.OnAction

## Advances planning to next party member
func advance_planning():
	action_planner.advance_planning()

## Starts resolution phase
func start_resolution_phase():
	action_planner.start_resolution_phase()

## Advances initiative
func advance_initiative():
	if planning_phase:
		return
	
	initiative_who += 1
	if initiative_who >= initiative.size():
		initiative_who = -1
		await get_tree().process_frame
		await attack_executor.do_attacks()
		return
	
	var current = initiative[initiative_who]
	if effect_manager.get_effect_duration(current, Global.effect.Sleep) > 0:
		if attack_array.has(current):
			attack_array.erase(current)
		var output = get_node_or_null("Control/enemy_ui/CenterContainer/output")
		if output:
			output.text = current.name + " is asleep!"
		await get_tree().create_timer(0.5).timeout
		advance_initiative()
		return
	
	if not attack_array.has(current):
		advance_initiative()
		return
	
	if current is Party or ("max_stats" in current):
		current_attacker = current
	
	advance_initiative()

## Executes attacks
func do_attacks():
	await attack_executor.do_attacks()

## Adds attack to plan
func add_attack(attacker: Object, attacked: Array, attack: Skill):
	attack_array[attacker] = [attacked, attack]

## Undoes last action
func undo_last_action():
	action_planner.undo_last_action()

## Starts a new round
func start_round():
	action_planner.start_round()

## Updates effects
func update_effects():
	effect_manager.update_effects()

## Gets effect multiplier
func get_effect_multiplier(target: Object, effect: Global.effect) -> float:
	return effect_manager.get_effect_multiplier(target, effect)

## Gets effect duration
func get_effect_duration(target: Object, effect: Global.effect) -> int:
	return effect_manager.get_effect_duration(target, effect)

## Applies effects
func apply_effects(target: Object, atk: Skill):
	effect_manager.apply_effects(target, atk)

## Updates effect UI
func update_effect_ui(target: Object):
	effect_manager.update_effect_ui(target)

## Adds to battle log
func add_to_battle_log(text: String):
	logger.add_to_battle_log(text)

## Prints outcome
func print_outcome(atk: Object, targets: Array, attack: Skill, dmg: int, crit: bool, miss: bool, mp_cost: int = 0, effects_applied: Array = []):
	logger.print_outcome(atk, targets, attack, dmg, crit, miss, mp_cost, effects_applied)

## Animates enemy death
func animate_enemy_death(e: Enemy):
	e.hp = 0
	var node = get_node_or_null("Control/enemy_ui/enemies/" + e.name.replace(" ", ""))
	if node:
		# Flash white
		var tween = create_tween()
		tween.tween_property(node, "modulate", Color.WHITE, 0.1)
		tween.tween_property(node, "modulate", Color.RED, 0.1)
		tween.tween_property(node, "modulate", Color.WHITE, 0.1)
		tween.tween_property(node, "modulate", Color(1, 1, 1, 0), 0.5)
		await tween.finished
		node.queue_free()

## Handles death
func death(obj):
	obj.hp = 0

## Checks enemy death and XP
func check_enemy_death_and_xp():
	await attack_executor.check_enemy_death_and_xp()

## Ends battle victory
func end_battle_victory():
	await get_tree().create_timer(1.0).timeout
	Global.player_position = battle_start_position
	Global.loading = true
	get_tree().change_scene_to_file(Global.current_scene)
	Global.loading = false

## Triggers game over
func trigger_game_over():
	game_over_active = true
	var tween = create_tween()
	tween.tween_property(game_over_overlay, "color", Color(0, 0, 0, 0.7), 1.0)
	tween.parallel().tween_property(game_over_texture, "modulate:a", 1.0, 1.0)
	await tween.finished
	can_reload = true

## Signal handlers
func _on_turn_started(actor: Object, index: int):
	turn_changed.emit(actor, actor is Party or ("max_stats" in actor))

func _on_round_complete():
	# Recalculate initiative for new round
	initiative = initiative_manager.calculate_initiative(party, [])

func _on_action_confirmed(action_index: int):
	match action_index:
		0:  # Fight
			add_attack(current_attacker, [battle.get('enemy_pos' + str(selected_enemy))], load("res://resources/attacks/attack.tres"))
			action_history.append(current_attacker)
			advance_planning()
		1:  # Skills
			open_skills_menu()
		2:  # Defend
			# Add defend action
			var defend_skill = Skill.new()
			defend_skill.name = "Defend"
			defend_skill.effects = {Global.effect.Defend: [1, 1]}
			add_attack(current_attacker, [current_attacker], defend_skill)
			action_history.append(current_attacker)
			advance_planning()
		3:  # Item
			open_items_menu()
		4:  # Run
			attempt_escape()

func _on_cancel_pressed():
	if state == states.OnSkills or state == states.OnSkillSelect:
		close_skills_menu()
	elif state == states.OnItems or state == states.OnItemSelect:
		close_items_menu()
	else:
		undo_last_action()

func _on_use_pressed():
	match state:
		states.OnAction:
			_on_action_confirmed(input_manager.selected_action_index)
		states.OnSkills:
			select_skill()
		states.OnSkillSelect:
			confirm_skill_target()
		states.OnItems:
			select_item()
		states.OnItemSelect:
			confirm_item_target()
		states.OnEnemy:
			add_attack(current_attacker, [battle.get('enemy_pos' + str(selected_enemy))], load("res://resources/attacks/attack.tres"))
			action_history.append(current_attacker)
			advance_planning()

func _on_left_pressed():
	match state:
		states.OnSkillSelect, states.OnItemSelect, states.OnEnemy:
			move_enemy_input(-1)

func _on_right_pressed():
	match state:
		states.OnSkillSelect, states.OnItemSelect, states.OnEnemy:
			move_enemy_input(1)

## Opens skills menu
func open_skills_menu():
	state = states.OnSkills
	if skills_container:
		skills_container.visible = false  # Will be shown when populated
	# Populate skill boxes based on current_attacker's skills
	populate_skills()

## Populates skills from current attacker
func populate_skills():
	if not skills_container or not current_attacker:
		return
	
	# Clear existing
	for child in skills_container.get_children():
		child.queue_free()
	skill_boxes.clear()
	
	# Get skills from current_attacker
	var skills = current_attacker.skills if current_attacker.has_method("get_skills") else []
	
	var grid = skills_container.get_node_or_null("ScrollContainer/SkillGrid")
	if not grid:
		return
	
	for i in range(skills.size()):
		var box = skill_box_scene.instantiate()
		grid.add_child(box)
		box.setup(skills[i], i)
		skill_boxes.append(box)
	
	skills_container.visible = true

## Opens items menu
func open_items_menu():
	state = states.OnItems
	if items_container:
		items_container.visible = false  # Will be shown when populated
	# Populate item boxes from inventory
	populate_items()

## Populates items from inventory
func populate_items():
	if not items_container:
		return
	
	# Clear existing
	for child in items_container.get_children():
		child.queue_free()
	item_boxes.clear()
	
	var grid = items_container.get_node_or_null("ScrollContainer/ItemGrid")
	if not grid:
		return
	
	# Get items from Global inventory
	var inventory = Global.inventory if Global.has_property("inventory") else {}
	var index = 0
	
	for item_id in inventory.keys():
		if inventory[item_id] > 0:
			var item_resource = load(item_id) if item_id.begins_with("res://") else null
			if item_resource:
				var box = item_box_scene.instantiate()
				grid.add_child(box)
				box.setup(item_resource, inventory[item_id], index)
				item_boxes.append(box)
				index += 1
	
	items_container.visible = true

## Attempts to escape battle
func attempt_escape():
	var success_chance = calculate_escape_chance()
	if randf() < success_chance:
		add_to_battle_log("[color=#4CAF50]Successfully escaped![/color]")
		await get_tree().create_timer(1.0).timeout
		end_battle_victory()
	else:
		add_to_battle_log("[color=#F44336]Failed to escape![/color]")
		await get_tree().create_timer(0.5).timeout
		advance_planning()

## Calculates escape chance
func calculate_escape_chance() -> float:
	var base_chance = 0.7
	# Modify based on speed difference, etc.
	return base_chance
