extends Node2D

@export var battle: Battle
var party: Array = Global.party
var battle_start_position: Vector2 = Vector2.ZERO
var initiative: Array[Object]

enum states { OnAction, OnEnemy, OnSkills, OnSkillSelect, OnItems, OnItemSelect, Waiting, OnRun}
var state: states = states.OnAction

var planning_phase: bool = true
var action_history: Array[Object] = []
var current_attacker: Object
var attack_array: Dictionary = {}
var current_party_plan_index: int = 0
var selected_enemy: int = 1
var previous_enemy: int = 1
var initiative_who: int = -1
var is_animating_death: bool = false

# Manager instances
var action_selector: BattleActionSelector
var input_manager: BattleInputManager
var effect_manager: BattleEffectManager
var logger_manager: BattleLogger
var attack_executor: BattleAttackExecutor
var planner_manager: BattleActionPlanner
var initiative_manager: BattleInitiativeManager
var ui_manager: BattleUIManager

var game_over_active: bool = false
var game_over_overlay: ColorRect
var game_over_texture: TextureRect
var can_reload = false

# === SETUP ===
func _ready() -> void:
	battle_start_position = Global.player_position
	await get_tree().create_timer(0.02).timeout
	battle = Global.battle_current.duplicate(true)
	Global.battle_ref = self
	await get_tree().create_timer(0.05).timeout
	
	init_managers()
	
	setup_enemies()
	initiative = initiative_manager.calculate_initiative(battle, party)
	setup_party()
	setup_current_attacker()
	ui_manager.setup_skills_ui()
	ui_manager.setup_items_ui()
	_setup_game_over_ui()
	logger_manager.setup_label()
	if battle.music_override:
		$AudioStreamPlayer.stream = battle.music_override

func init_managers():
	action_selector = BattleActionSelector.new()
	add_child(action_selector)
	
	var fight_btn = get_node_or_null("Control/gui/HBoxContainer2/actions/FightButton/fight")
	var skill_btn = get_node_or_null("Control/gui/HBoxContainer2/actions/SkillsButton/skills")
	var defend_btn = get_node_or_null("Control/gui/HBoxContainer2/actions/DefendButton/defend")
	var item_btn = get_node_or_null("Control/gui/HBoxContainer2/actions/ItemButton/item")
	var run_btn = get_node_or_null("Control/gui/HBoxContainer2/actions/RunButton/run")
	
	if fight_btn: action_selector.fight_button = fight_btn
	if skill_btn: action_selector.skill_button = skill_btn
	if defend_btn: action_selector.defend_button = defend_btn
	if item_btn: action_selector.item_button = item_btn
	if run_btn: action_selector.run_button = run_btn
	
	action_selector.action_selected.connect(_on_action_selected)
	action_selector.action_confirmed.connect(_on_action_confirmed)
	
	input_manager = BattleInputManager.new()
	add_child(input_manager)
	input_manager.setup(self, action_selector)
	
	effect_manager = BattleEffectManager.new()
	add_child(effect_manager)
	effect_manager.setup(self)
	
	logger_manager = BattleLogger.new()
	add_child(logger_manager)
	logger_manager.setup(get_node_or_null("Control/enemy_ui/CenterContainer/output"))
	
	attack_executor = BattleAttackExecutor.new()
	add_child(attack_executor)
	attack_executor.setup(self, effect_manager, logger_manager)
	
	planner_manager = BattleActionPlanner.new()
	add_child(planner_manager)
	planner_manager.setup(self, action_selector)
	
	initiative_manager = BattleInitiativeManager.new()
	add_child(initiative_manager)
	initiative_manager.setup(self, effect_manager)
	
	ui_manager = BattleUIManager.new()
	add_child(ui_manager)
	ui_manager.setup(self, effect_manager)

func setup_enemies():
	for e in range(5):
		var path = "Control/enemy_ui/enemies/enemy" + str(e+1)
		if battle.get('enemy_pos'+str(e+1)):
			battle.set('enemy_pos'+str(e+1), battle.get('enemy_pos'+str(e+1)).duplicate(true))
			var node = get_node(path)
			node.texture = battle.get('enemy_pos'+str(e+1)).battleSprite
			node.hp = battle.get('enemy_pos'+str(e+1)).hp
			node.max_hp = battle.get('enemy_pos'+str(e+1)).hp
			
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
			if prog: prog.visible = false

func setup_initiative() -> Array[Object]:
	var speed: Dictionary[int, Object] = {}
	for e in range(5):
		if battle.get('enemy_pos'+str(e+1)):
			var ai = battle.get('enemy_pos'+str(e+1)).ai
			var speed_mult = get_effect_multiplier(battle.get('enemy_pos'+str(e+1)), Global.effect.Speed)
			var slow_mult = get_effect_multiplier(battle.get('enemy_pos'+str(e+1)), Global.effect.Slow)
			var total_mult = speed_mult * slow_mult
			var rng = randi_range(ceili(ai * 0.75 * total_mult), floori(ai * 1.25 * total_mult))
			while rng in speed: rng += 1
			speed[rng] = battle.get('enemy_pos'+str(e+1))
	for p in party:
		var ai = p.max_stats["ai"]
		var speed_mult = get_effect_multiplier(p, Global.effect.Speed)
		var slow_mult = get_effect_multiplier(p, Global.effect.Slow)
		var total_mult = speed_mult * slow_mult
		var rng = randi_range(ceili(ai * 0.75 * total_mult), floori(ai * 1.25 * total_mult))
		while rng in speed: rng += 1
		speed[rng] = p
	var keys = speed.keys()
	keys.sort()
	var rev: Array[Object] = []
	for k in range(keys.size()-1, -1, -1):
		rev.append(speed[keys[k]])
	return rev

func setup_party():
	for p in initiative:
		if p in party:
			var ui = preload("res://scenes/ui/battle_engine_stuff/partyBattleFace.tscn").instantiate()
			ui.setup(p)
			$Control/gui/HBoxContainer2/party.add_child(ui)
			
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
	
func setup_current_attacker():
	for o in initiative:
		if o is Party:
			current_attacker = o
			break
			
func _setup_battle_log_label() -> void:
	var label: RichTextLabel = $Control/enemy_ui/CenterContainer/output
	if label is RichTextLabel:
		label.bbcode_enabled = true
		label.fit_content = true
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# === MAIN BATTLE LOOP ===

func _process(delta: float) -> void:
	update_flash()
	for e in range(5):
		var node = get_node_or_null("Control/enemy_ui/enemies/enemy"+str(e+1))
		if node and battle.get('enemy_pos'+str(e+1)):
			node.hp = max(0, battle.get('enemy_pos'+str(e+1)).hp)
	if state == states.OnSkills or state == states.OnSkillSelect:
		check_skill_overlap()
	if state == states.OnItems or state == states.OnItemSelect:
		check_item_overlap()
	
	if not battle_log.is_empty():
		log_timer += delta
		if log_timer >= log_display_time:
			log_timer = 0.0
			remove_oldest_log_entry()

func _input(event: InputEvent) -> void:
	if input_manager:
		input_manager.handle_input(event, game_over_active, can_reload, planning_phase)
				
func simulate_click_move():
	if not $TheMove/Area2D.get_overlapping_areas(): return
	var area = $TheMove/Area2D.get_overlapping_areas()[0]
	
	# Check if overlapping with skill box
	if area.owner is SkillBox or area.get_parent() is SkillBox:
		var skill_box = area.owner if area.owner is SkillBox else area.get_parent()
		if skill_box is SkillBox:
			current_skill_index = skill_box.skill_index
			select_skill()
			return
	
	# Check if overlapping with item box
	if area.owner is ItemBox or area.get_parent() is ItemBox:
		var item_box = area.owner if area.owner is ItemBox else area.get_parent()
		if item_box is ItemBox:
			current_item_index = item_box.item_index
			select_item()
			return
	
	var buttons = [$Control/gui/HBoxContainer2/actions/FightButton/fight,
		$Control/gui/HBoxContainer2/actions/SkillsButton/skills,
		$Control/gui/HBoxContainer2/actions/DefendButton/defend,
		$Control/gui/HBoxContainer2/actions/ItemButton/item,
		$Control/gui/HBoxContainer2/actions/RunButton/run]
	var funcs = [_on_fight_button_pressed, _on_skills_button_pressed, _on_defend_button_pressed, _on_item_button_pressed, _on_run_button_pressed]
	for i in range(buttons.size()):
		if area == buttons[i]:
			funcs[i].call()

func move_the_move(input: int):
	if $TheMove.position.y == 487 and input == -1: $TheMove.position.y = 615
	elif $TheMove.position.y == 615 and input == 1: $TheMove.position.y = 487
	else: $TheMove.position.y += 32 * input

func move_who_moves(index: int):
	$WhoMoves.visible = true
	$WhoMoves.position.x = 220 + (index * $WhoMoves.size.x)

func move_enemy_input(input: int):
	if input == 0: return
	while true:
		selected_enemy = wrapi(selected_enemy + input - 1, 0, 5) + 1
		if battle.get('enemy_pos'+str(selected_enemy)) in initiative: break

func update_flash():
	for c in $Control/enemy_ui/enemies.get_children():
		if c.material:
			c.material.set("shader_parameter/is_flashing", c.name == "enemy" + str(selected_enemy))

func get_party_members_from_initiative() -> Array[Object]:
	var party_members: Array[Object] = []
	for actor in initiative:
		if actor is Party:
			party_members.append(actor)
	return party_members

func update_party_ui():
	var party_container = $Control/gui/HBoxContainer2/party
	if party_container:
		for i in range(party_container.get_child_count()):
			var ui = party_container.get_child(i)
			if ui.has_method("update_effects_ui"):
				ui.update_effects_ui()

func add_attack(attacker: Object, attacked: Array, attack: Skill):
	planner_manager.add_attack(attacker, attacked, attack)

func undo_last_action():
	planner_manager.undo_last_action()

func advance_planning():
	planner_manager.advance_planning()

func start_resolution_phase():
	planner_manager.start_resolution_phase()

func start_round():
	planner_manager.start_round()

func add_enemy_attack(e: Enemy):
	planner_manager.add_enemy_attack(e)

func move_who_moves(index: int):
	planner_manager.move_who_moves(index)

func do_attacks() -> void:
	await attack_executor.do_attacks(initiative, planner_manager.attack_array, current_attacker)
	await check_enemy_death_and_xp()
	await get_tree().create_timer(0.5).timeout
	start_round()

func execute_single_attack(attacker: Object) -> void:
	if not planner_manager.attack_array.has(attacker): return
	var targets = planner_manager.attack_array[attacker][0]
	var atk: Skill = planner_manager.attack_array[attacker][1]
	await attack_executor.execute_single_attack(attacker, targets, atk, battle, initiative)

func death(obj):
	planner_manager.remove_from_initiative(obj)

func check_party_wipe() -> void:
	var alive = false
	for p in Global.party:
		if p.hp > 0:
			alive = true
			break
	if not alive:
		trigger_game_over()

func trigger_game_over() -> void:
	game_over_active = true
	state = states.Waiting
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


		var target = party[clamp(selected_enemy - 1, 0, party.size() - 1)]
		add_attack(current_attacker, [target], skill)
		action_history.append(current_attacker)
		close_skills_menu()
		advance_planning()
		
func close_skills_menu():
	skills_container.visible = false
	$Control/gui/HBoxContainer2/party.visible = true
	$WhoMoves.visible = true
	state = states.OnAction
# === ITEMS SYSTEM ===
var items_container: Control
var item_boxes: Array[ItemBox] = []
var current_item_index: int = 0
var item_scroll_offset: int = 0
var max_visible_items: int = 8
var available_items: Array[Resource] = []
var item_amounts: Array[int] = []
var item_box_scene: PackedScene

var item_target_type: int = 0  # 0 = enemy, 1 = party
var saved_party_plan_index: int = 0
var selected_party_member: int = 0

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
		grid.columns = 2  # MATCH SKILLS: 2 columns
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.custom_minimum_size = Vector2(1296, 0)  # MATCH SKILLS: 1296px width
		scroll.add_child(grid)
		
		$Control/gui/HBoxContainer2.add_child(items_container)
	
	items_container = $Control/gui/HBoxContainer2/items_container

func open_items_menu():
	state = states.OnItems
	items_container.visible = true
	$Control/gui/HBoxContainer2/party.visible = false
	$WhoMoves.visible = false
	
	available_items.clear()
	item_amounts.clear()

	# Get items from Global inventory
	for item in Global.inventory.keys():
		if item and item.type == 2:
			var amount = Global.inventory[item]
			if amount > 0:
				available_items.append(item)
				item_amounts.append(amount)

	if available_items.is_empty():
		$Control/enemy_ui/CenterContainer/output.text = "No items!"
		await get_tree().create_timer(0.5).timeout
		close_items_menu()
		return

	create_item_boxes()

	current_item_index = 0
	item_scroll_offset = 0
	update_item_selection()

func create_item_boxes():
	var grid = items_container.get_node("ScrollContainer/ItemGrid")
	for child in grid.get_children():
		child.queue_free()
	item_boxes.clear()
	
	for i in range(available_items.size()):
		var item = available_items[i]
		var amount = item_amounts[i]
		var box = item_box_scene.instantiate()
		grid.add_child(box)
		box.setup(item, i, amount)
		item_boxes.append(box)
	
	update_item_selection()

func update_item_selection():
	for i in range(item_boxes.size()):
		var box = item_boxes[i]
		var has_items = item_amounts[i] > 0
		
		if i == current_item_index and has_items:
			box.modulate = Color(1, 1, 0.5)
			box.set_collisions(true)
		else:
			box.modulate = Color(1, 1, 1) if has_items else Color(0.5, 0.5, 0.5)
			box.set_collisions(false)
	
	if current_item_index >= item_scroll_offset + max_visible_items:
		item_scroll_offset = current_item_index - max_visible_items + 1
	elif current_item_index < item_scroll_offset:
		item_scroll_offset = current_item_index
	
	var scroll = items_container.get_node("ScrollContainer")
	scroll.scroll_vertical = item_scroll_offset * 70

func navigate_items(direction: int):
	var columns = 2  
	var new_index = current_item_index + direction
	
	if new_index < 0:
		new_index = item_boxes.size() - 1
	elif new_index >= item_boxes.size():
		new_index = 0
	
	var attempts = 0
	while attempts < item_boxes.size():
		if item_amounts[new_index] > 0:
			break
		new_index += direction
		if new_index < 0:
			new_index = item_boxes.size() - 1
		elif new_index >= item_boxes.size():
			new_index = 0
		attempts += 1
	
	if item_amounts[new_index] > 0:
		current_item_index = new_index
		update_item_selection()

func check_item_overlap():
	var overlapping = $TheMove/Area2D.get_overlapping_areas()
	for area in overlapping:
		var parent = area.get_parent()
		if parent is ItemBox:
			var new_index = parent.item_index
			if item_amounts[new_index] > 0 and new_index != current_item_index:
				current_item_index = new_index
				update_item_selection()
			return

func select_item():
	if current_item_index < 0 or current_item_index >= available_items.size():
		return
	
	if item_amounts[current_item_index] <= 0:
		$Control/enemy_ui/CenterContainer/output.text = "No items left!"
		await get_tree().create_timer(0.5).timeout
		return
	
	var item = available_items[current_item_index]
	
	if item.type == 2:
		if item.is_item_attack and item.item_attack:
			item_target_type = 0
			state = states.OnItemSelect
			items_container.visible = false
			selected_enemy = previous_enemy if previous_enemy != 0 else 1
			$Control/enemy_ui/CenterContainer/output.text = "Select enemy..."
			return
		else:
			item_target_type = 1
			state = states.OnItemSelect
			
			var party_in_initiative = get_party_members_from_initiative()
			selected_party_member = 0
			for i in range(party_in_initiative.size()):
				if party_in_initiative[i] == current_attacker:
					selected_party_member = i
					break
			
			saved_party_plan_index = current_party_plan_index
			items_container.visible = false
			$Control/gui/HBoxContainer2/party.visible = true
			$WhoMoves.visible = true
			move_who_moves(selected_party_member)
			$Control/enemy_ui/CenterContainer/output.text = "Select party member..."
			return

func confirm_item_target():
	var item = available_items[current_item_index]
	
	if item_target_type == 0:
		if item.is_item_attack and item.item_attack:
			var target = battle.get('enemy_pos'+str(selected_enemy))
			if target and target.hp > 0:
				var item_attack = item.item_attack.duplicate()
				item_attack.item_reference = item
				item_attack.name = item.item_name
				
				add_attack(current_attacker, [target], item_attack)
				action_history.append(current_attacker)
				close_items_menu()
				advance_planning()
	else:
		var party_in_initiative = get_party_members_from_initiative()
		selected_party_member = clamp(selected_party_member, 0, party_in_initiative.size() - 1)
		var target = party_in_initiative[selected_party_member]
		
		if target and target.hp > 0:
			var item_attack = Skill.new()
			item_attack.name = item.item_name
			item_attack.attack_type = 3
			item_attack.target_type = 1
			item_attack.mana_cost = 0
			item_attack.item_reference = item
			
			add_attack(current_attacker, [target], item_attack)
			
			$WhoMoves.visible = true
			move_who_moves(saved_party_plan_index)
			
			action_history.append(current_attacker)
			close_items_menu()
			advance_planning()

func close_items_menu():
	items_container.visible = false
	$Control/gui/HBoxContainer2/party.visible = true
	$WhoMoves.visible = true
	move_who_moves(saved_party_plan_index)
	state = states.OnAction

# === BATTLE BUTTON LOGIC ===

func _on_fight_button_pressed() -> void:
	state = states.OnEnemy
	selected_enemy = previous_enemy if previous_enemy != 0 else 1

func _on_skills_button_pressed() -> void:
	open_skills_menu()
	
func _on_defend_button_pressed() -> void:
	add_attack(current_attacker, [current_attacker], load("res://resources/attacks/defend.tres"))
	action_history.append(current_attacker)
	advance_planning() 

func _on_item_button_pressed() -> void:
	open_items_menu()
	
func _on_run_button_pressed() -> void:
	var counter = 0
	for e in range(5):
		if battle.get('enemy_pos'+str(e+1)): counter += battle.get('enemy_pos'+str(e+1)).ai
	var chance = 0
	for p in party: chance += p.max_stats["ai"]
	var diff = clampf(counter - chance + 10, 0, 30)
	if randi_range(1, 20) > diff:
		Global.player_position = battle_start_position
		Global.loading = true
		get_tree().change_scene_to_file(Global.current_scene)
		Global.loading = false
	else:
		$Control/enemy_ui/CenterContainer/output.text = "Couldn't escape!"
		await get_tree().create_timer(0.5).timeout
		start_round()
