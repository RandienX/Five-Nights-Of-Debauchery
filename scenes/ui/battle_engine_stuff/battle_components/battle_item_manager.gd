extends Node

class_name BattleItemManager

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

var battle_engine: Node2D
var state_enum

func _init(engine: Node2D):
	battle_engine = engine
	state_enum = engine.get("states")

func setup_items_ui():
	item_box_scene = preload("res://scenes/ui/battle_engine_stuff/item_box.tscn")
	
	if not battle_engine.has_node("Control/gui/HBoxContainer2/items_container"):
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
		
		battle_engine.get_node("Control/gui/HBoxContainer2").add_child(items_container)
	
	items_container = battle_engine.get_node("Control/gui/HBoxContainer2/items_container")

func open_items_menu():
	battle_engine.state = state_enum.OnItems
	items_container.visible = true
	battle_engine.get_node("Control/gui/HBoxContainer2/party").visible = false
	battle_engine.get_node("WhoMoves").visible = false
	
	available_items.clear()
	item_amounts.clear()

	for item in Global.inventory.keys():
		if item and item.type == 2:
			var amount = Global.inventory[item]
			if amount > 0:
				available_items.append(item)
				item_amounts.append(amount)

	if available_items.is_empty():
		battle_engine.get_node("Control/enemy_ui/CenterContainer/output").text = "No items!"
		await battle_engine.get_tree().create_timer(0.5).timeout
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
	var overlapping = battle_engine.get_node("TheMove/Area2D").get_overlapping_areas()
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
		battle_engine.get_node("Control/enemy_ui/CenterContainer/output").text = "No items left!"
		await battle_engine.get_tree().create_timer(0.5).timeout
		return
	
	var item = available_items[current_item_index]
	
	if item.type == 2:
		if item.is_item_attack and item.item_attack:
			item_target_type = 0
			battle_engine.state = state_enum.OnItemSelect
			items_container.visible = false
			battle_engine.selected_enemy = battle_engine.previous_enemy if battle_engine.previous_enemy != 0 else 1
			battle_engine.get_node("Control/enemy_ui/CenterContainer/output").text = "Select enemy..."
			return
		else:
			item_target_type = 1
			battle_engine.state = state_enum.OnItemSelect
			
			var party_in_initiative = battle_engine.initiative_manager.get_party_members_from_initiative()
			selected_party_member = 0
			for i in range(party_in_initiative.size()):
				if party_in_initiative[i] == battle_engine.current_attacker:
					selected_party_member = i
					break
			
			saved_party_plan_index = battle_engine.action_planner.current_party_plan_index
			items_container.visible = false
			battle_engine.get_node("Control/gui/HBoxContainer2/party").visible = true
			battle_engine.get_node("WhoMoves").visible = true
			battle_engine.move_who_moves(selected_party_member)
			battle_engine.get_node("Control/enemy_ui/CenterContainer/output").text = "Select party member..."
			return

func confirm_item_target():
	var item = available_items[current_item_index]
	
	if item_target_type == 0:
		if item.is_item_attack and item.item_attack:
			var target = battle_engine.battle.get('enemy_pos'+str(battle_engine.selected_enemy))
			if target and target.hp > 0:
				var item_attack = item.item_attack.duplicate()
				item_attack.item_reference = item
				item_attack.name = item.item_name
				
				battle_engine.add_attack(battle_engine.current_attacker, [target], item_attack)
				battle_engine.action_planner.action_history.append(battle_engine.current_attacker)
				close_items_menu()
				battle_engine.advance_planning()
	else:
		var party_in_initiative = battle_engine.initiative_manager.get_party_members_from_initiative()
		selected_party_member = clamp(selected_party_member, 0, party_in_initiative.size() - 1)
		var target = party_in_initiative[selected_party_member]
		
		if target and target.hp > 0:
			var item_attack = Skill.new()
			item_attack.name = item.item_name
			item_attack.attack_type = 3
			item_attack.target_type = 1
			item_attack.mana_cost = 0
			item_attack.item_reference = item
			
			battle_engine.add_attack(battle_engine.current_attacker, [target], item_attack)
			
			battle_engine.get_node("WhoMoves").visible = true
			battle_engine.move_who_moves(saved_party_plan_index)
			
			battle_engine.action_planner.action_history.append(battle_engine.current_attacker)
			close_items_menu()
			battle_engine.advance_planning()

func close_items_menu():
	items_container.visible = false
	battle_engine.get_node("Control/gui/HBoxContainer2/party").visible = true
	battle_engine.get_node("WhoMoves").visible = true
	battle_engine.move_who_moves(saved_party_plan_index)
	battle_engine.state = state_enum.OnAction
