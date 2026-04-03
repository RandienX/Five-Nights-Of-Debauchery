class_name BattleUIManager
extends Node

## Handles all UI operations for battle
## Skills menu, items menu, selection navigation, overlap checking

var battle_root: Node2D = null
var effect_manager: BattleEffectManager = null

var skill_box_scene: PackedScene
var skills_container: Control
var item_box_scene: PackedScene
var items_container: Control

var current_skill_index: int = 0
var current_item_index: int = 0
var selected_party_member: int = 0
var saved_party_plan_index: int = 0
var item_target_type: int = 0  # 0 = enemy, 1 = party

func setup(root: Node2D, eff_mgr: BattleEffectManager):
	battle_root = root
	effect_manager = eff_mgr

func setup_skills_ui():
	skill_box_scene = preload("res://scenes/ui/battle_engine_stuff/skill_box.tscn")
	
	if not battle_root.has_node("Control/gui/HBoxContainer2/skills_container"):
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
		battle_root.get_node("Control/gui/HBoxContainer2").add_child(skills_container)
	
	skills_container = battle_root.get_node("Control/gui/HBoxContainer2/skills_container")

func setup_items_ui():
	item_box_scene = preload("res://scenes/ui/battle_engine_stuff/item_box.tscn")
	
	if not battle_root.has_node("Control/gui/HBoxContainer2/items_container"):
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
		battle_root.get_node("Control/gui/HBoxContainer2").add_child(items_container)
	
	items_container = battle_root.get_node("Control/gui/HBoxContainer2/items_container")

func open_skills_menu():
	battle_root.state = battle_root.states.OnSkills
	skills_container.visible = true
	current_skill_index = 0
	create_skill_boxes()
	update_skill_selection()

func create_skill_boxes():
	var grid = skills_container.get_node("ScrollContainer/SkillGrid")
	for child in grid.get_children():
		child.queue_free()
	
	for skill in battle_root.current_attacker.skills:
		var box = skill_box_scene.instantiate()
		box.setup(skill, grid.get_child_count())
		grid.add_child(box)

func update_skill_selection():
	var grid = skills_container.get_node("ScrollContainer/SkillGrid")
	for i in range(grid.get_child_count()):
		var box = grid.get_child(i)
		if box.has_method("set_selected"):
			box.set_selected(i == current_skill_index)

func navigate_skills(direction: int):
	var grid = skills_container.get_node("ScrollContainer/SkillGrid")
	var cols = 2
	var count = grid.get_child_count()
	if count == 0: return
	
	var row = current_skill_index / cols
	var col = current_skill_index % cols
	
	if direction == 1:  # Right
		col = (col + 1) % cols
	elif direction == -1:  # Left
		col = (col - 1 + cols) % cols
	elif direction == 2:  # Down
		row = (row + 1) % ((count + cols - 1) / cols)
	elif direction == -2:  # Up
		row = (row - 1 + (count + cols - 1) / cols) % ((count + cols - 1) / cols)
	
	current_skill_index = min(row * cols + col, count - 1)
	update_skill_selection()

func check_skill_overlap():
	pass  # Could add mouse hover detection here

func select_skill():
	var grid = skills_container.get_node("ScrollContainer/SkillGrid")
	if current_skill_index >= grid.get_child_count(): return
	
	var box = grid.get_child(current_skill_index)
	var skill = box.skill
	battle_root.selected_enemy = 1
	
	if skill.target_type == 0 or skill.target_type == 2:  # Single enemy or all enemies
		battle_root.state = battle_root.states.OnSkillSelect
		battle_root.move_enemy_input(0)
	elif skill.target_type == 1:  # All enemies
		confirm_skill_target()
	elif skill.target_type == 3:  # Self
		battle_root.add_attack(battle_root.current_attacker, [battle_root.current_attacker], skill)
		battle_root.action_history.append(battle_root.current_attacker)
		battle_root.close_skills_menu()
		battle_root.advance_planning()
	elif skill.target_type == 4:  # Single ally
		battle_root.state = battle_root.states.OnSkillSelect
		battle_root.item_target_type = 1
		battle_root.saved_party_plan_index = battle_root.current_party_plan_index
		battle_root.$WhoMoves.visible = false
		var party_in_initiative = battle_root.get_party_members_from_initiative()
		battle_root.selected_party_member = 0
		battle_root.move_who_moves(battle_root.selected_party_member)
	elif skill.target_type == 5:  # All allies
		var targets: Array[Object] = []
		for p in battle_root.party:
			if p.hp > 0: targets.append(p)
		battle_root.add_attack(battle_root.current_attacker, targets, skill)
		battle_root.action_history.append(battle_root.current_attacker)
		battle_root.close_skills_menu()
		battle_root.advance_planning()

func confirm_skill_target():
	var skill = battle_root.current_attacker.skills[current_skill_index]
	var target = battle_root.battle.get('enemy_pos'+str(battle_root.selected_enemy))
	
	if skill.target_type == 0:  # Single enemy
		battle_root.add_attack(battle_root.current_attacker, [target], skill)
	elif skill.target_type == 2:  # All enemies
		var targets: Array[Object] = []
		for e in range(5):
			var enemy = battle_root.battle.get('enemy_pos'+str(e+1))
			if enemy and enemy.hp > 0: targets.append(enemy)
		battle_root.add_attack(battle_root.current_attacker, targets, skill)
	
	battle_root.action_history.append(battle_root.current_attacker)
	battle_root.previous_enemy = battle_root.selected_enemy
	battle_root.selected_enemy = 0
	battle_root.close_skills_menu()
	battle_root.advance_planning()

func close_skills_menu():
	skills_container.visible = false
	var grid = skills_container.get_node("ScrollContainer/SkillGrid")
	for child in grid.get_children():
		child.queue_free()
	battle_root.state = battle_root.states.OnAction

func open_items_menu():
	battle_root.state = battle_root.states.OnItems
	items_container.visible = true
	current_item_index = 0
	create_item_boxes()
	update_item_selection()

func create_item_boxes():
	var grid = items_container.get_node("ScrollContainer/ItemGrid")
	for child in grid.get_children():
		child.queue_free()
	
	var inventory = Global.inventory
	for item_key in inventory.keys():
		if inventory[item_key] > 0:
			var item_data = Global.items[item_key]
			var box = item_box_scene.instantiate()
			box.setup(item_data, inventory[item_key], grid.get_child_count())
			grid.add_child(box)

func update_item_selection():
	var grid = items_container.get_node("ScrollContainer/ItemGrid")
	for i in range(grid.get_child_count()):
		var box = grid.get_child(i)
		if box.has_method("set_selected"):
			box.set_selected(i == current_item_index)

func navigate_items(direction: int):
	var grid = items_container.get_node("ScrollContainer/ItemGrid")
	var cols = 2
	var count = grid.get_child_count()
	if count == 0: return
	
	var row = current_item_index / cols
	var col = current_item_index % cols
	
	if direction == 1:  # Right
		col = (col + 1) % cols
	elif direction == -1:  # Left
		col = (col - 1 + cols) % cols
	elif direction == 2:  # Down
		row = (row + 1) % ((count + cols - 1) / cols)
	elif direction == -2:  # Up
		row = (row - 1 + (count + cols - 1) / cols) % ((count + cols - 1) / cols)
	
	current_item_index = min(row * cols + col, count - 1)
	update_item_selection()

func check_item_overlap():
	pass  # Could add mouse hover detection here

func select_item():
	var grid = items_container.get_node("ScrollContainer/ItemGrid")
	if current_item_index >= grid.get_child_count(): return
	
	var box = grid.get_child(current_item_index)
	var item_key = box.item_key
	var item_data = Global.items[item_key]
	
	battle_root.selected_enemy = 1
	
	if item_data.target_type == 0:  # Single enemy
		battle_root.state = battle_root.states.OnItemSelect
		battle_root.item_target_type = 0
		battle_root.move_enemy_input(0)
	elif item_data.target_type == 1:  # All enemies
		confirm_item_target()
	elif item_data.target_type == 2:  # Self
		confirm_item_target()
	elif item_data.target_type == 3:  # Single ally
		battle_root.state = battle_root.states.OnItemSelect
		battle_root.item_target_type = 1
		battle_root.saved_party_plan_index = battle_root.current_party_plan_index
		battle_root.$WhoMoves.visible = false
		var party_in_initiative = battle_root.get_party_members_from_initiative()
		battle_root.selected_party_member = 0
		battle_root.move_who_moves(battle_root.selected_party_member)
	elif item_data.target_type == 4:  # All allies
		confirm_item_target()

func confirm_item_target():
	var grid = items_container.get_node("ScrollContainer/ItemGrid")
	if current_item_index >= grid.get_child_count(): return
	
	var box = grid.get_child(current_item_index)
	var item_key = box.item_key
	var item_data = Global.items[item_key]
	
	var attack = Skill.new()
	attack.attack_name = item_data.name
	attack.attack_type = 3
	attack.item_reference = item_key
	attack.effects = item_data.effects.duplicate(true) if item_data.effects else {}
	
	var targets: Array[Object] = []
	
	if item_data.target_type == 0:  # Single enemy
		targets.append(battle_root.battle.get('enemy_pos'+str(battle_root.selected_enemy)))
	elif item_data.target_type == 1:  # All enemies
		for e in range(5):
			var enemy = battle_root.battle.get('enemy_pos'+str(e+1))
			if enemy and enemy.hp > 0: targets.append(enemy)
	elif item_data.target_type == 2:  # Self
		targets.append(battle_root.current_attacker)
	elif item_data.target_type == 3:  # Single ally
		var party_in_initiative = battle_root.get_party_members_from_initiative()
		targets.append(party_in_initiative[battle_root.selected_party_member])
	elif item_data.target_type == 4:  # All allies
		for p in battle_root.party:
			if p.hp > 0: targets.append(p)
	
	Global.add_item(item_key, -1)
	battle_root.add_attack(battle_root.current_attacker, targets, attack)
	battle_root.action_history.append(battle_root.current_attacker)
	battle_root.close_items_menu()
	battle_root.advance_planning()

func close_items_menu():
	items_container.visible = false
	var grid = items_container.get_node("ScrollContainer/ItemGrid")
	for child in grid.get_children():
		child.queue_free()
	battle_root.state = battle_root.states.OnAction
