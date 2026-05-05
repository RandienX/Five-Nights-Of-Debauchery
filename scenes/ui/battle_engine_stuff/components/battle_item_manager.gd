extends RefCounted
class_name ItemManager

var root

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

func item_select_input(event):
	print("DEBUG item_select_input: event=", event, " item_target_type=", item_target_type)
	if event.is_action_pressed("left"):
		if item_target_type == 0:
			root.move_enemy_input(-1)
		else:
			var party_in_initiative = root.get_party_members_from_initiative()
			selected_party_member = wrapi(selected_party_member - 1, 0, party_in_initiative.size())
			root.move_who_moves(selected_party_member)
		root.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right"):
		if item_target_type == 0:
			root.move_enemy_input(1)
		else:
			var party_in_initiative = root.get_party_members_from_initiative()
			selected_party_member = wrapi(selected_party_member + 1, 0, party_in_initiative.size())
			print("DEBUG Input Right: selected_party_member = ", selected_party_member, " target = ", party_in_initiative[selected_party_member].name)
			root.move_who_moves(selected_party_member)
		root.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use"):
		print("DEBUG item_select_input: use pressed, calling confirm_item_target()")
		confirm_item_target()
		root.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if item_target_type == 1:
			root.get_node("WhoMoves").visible = true
			root.move_who_moves(saved_party_plan_index)
		close_items_menu()
	if root.get_viewport():
		root.get_viewport().set_input_as_handled()
		
func setup_items_ui(battleroot):
	root = battleroot
	item_box_scene = preload("res://scenes/ui/battle_engine_stuff/item_box.tscn")
	
	if not root.has_node("Control/gui/HBoxContainer2/items_container"):
		items_container = Control.new()
		items_container.name = "items_container"
		items_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		items_container.visible = false
		items_container.z_index = 10
		
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
		
		root.get_node("Control/gui/HBoxContainer2").add_child(items_container)
	
	items_container = root.get_node("Control/gui/HBoxContainer2/items_container")

func open_items_menu():
	print("DEBUG open_items_menu: START")
	root.state = root.states.OnItems
	items_container.visible = true
	root.get_node("Control/gui/HBoxContainer2/party").visible = false
	root.get_node("WhoMoves").visible = false
	
	available_items.clear()
	item_amounts.clear()

	# Get items from Global inventory
	print("DEBUG open_items_menu: PlayerStats.inventory=", PlayerStats.inventory)
	for item in PlayerStats.inventory.keys():
		print("DEBUG open_items_menu: checking item=", item, " type=", item.type if item else null)
		if item and item.type == 2:
			var amount = PlayerStats.inventory[item]
			print("DEBUG open_items_menu: amount=", amount)
			if amount > 0:
				available_items.append(item)
				item_amounts.append(amount)
				print("DEBUG open_items_menu: ADDED item=", item.item_name if item.has_method('get') or 'item_name' in item else item)

	if available_items.is_empty():
		print("DEBUG open_items_menu: NO ITEMS AVAILABLE")
		root.get_node("Control/enemy_ui/CenterContainer/output").text = "No items!"
		await root.get_tree().create_timer(0.5).timeout
		close_items_menu()
		return

	print("DEBUG open_items_menu: available_items.size=", available_items.size())
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
		else:
			box.modulate = Color(1, 1, 1) if has_items else Color(0.5, 0.5, 0.5)
	
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

func select_item():
	print("DEBUG select_item: current_item_index=", current_item_index, " available_items.size=", available_items.size())
	if current_item_index < 0 or current_item_index >= available_items.size():
		print("DEBUG select_item: INVALID INDEX")
		return
	
	if item_amounts[current_item_index] <= 0:
		print("DEBUG select_item: NO ITEMS LEFT")
		root.get_node("Control/enemy_ui/CenterContainer/output").text = "No items left!"
		await root.get_tree().create_timer(0.5).timeout
		return
	
	var item = available_items[current_item_index]
	print("DEBUG select_item: item=", item, " type=", item.type, " is_item_attack=", item.is_item_attack)
	
	if item.type == 2:
		if item.is_item_attack and item.item_attack:
			print("DEBUG select_item: ITEM ATTACK - setting target_type=0 (enemy)")
			item_target_type = 0
			root.state = root.states.OnItemSelect
			items_container.visible = false
			root.selected_enemy = root.previous_enemy if root.previous_enemy != 0 else 1
			root.get_node("Control/enemy_ui/CenterContainer/output").text = "Select enemy..."
			return
		else:
			print("DEBUG select_item: PARTY TARGET - setting target_type=1 (party)")
			item_target_type = 1
			root.state = root.states.OnItemSelect
			
			var party_in_initiative = root.get_party_members_from_initiative()
			selected_party_member = 0
			for i in range(party_in_initiative.size()):
				if party_in_initiative[i] == root.current_attacker:
					selected_party_member = i
					break
			
			saved_party_plan_index = root.current_party_plan_index
			items_container.visible = false
			root.get_node("Control/gui/HBoxContainer2/party").visible = true
			root.get_node("WhoMoves").visible = true
			root.move_who_moves(selected_party_member)
			root.get_node("Control/enemy_ui/CenterContainer/output").text = "Select party member..."
			return

func confirm_item_target():
	print("DEBUG confirm_item_target: item_target_type=", item_target_type)
	var item = available_items[current_item_index]
	print("DEBUG confirm_item_target: item=", item)
	
	if item_target_type == 0:
		print("DEBUG confirm_item_target: ENEMY TARGET path")
		if item.is_item_attack and item.item_attack:
			var target = root.get_enemy_by_slot(root.selected_enemy)
			print("DEBUG confirm_item_target: selected_enemy=", root.selected_enemy, " target=", target, " target.hp=", target.hp if target else null)
			if target and target.hp > 0:
				var item_attack = item.item_attack.duplicate()
				item_attack.item_reference = item
				item_attack.name = item.item_name
				
				print("DEBUG confirm_item_target: Calling add_attack with attacker=", root.current_attacker, " target=", target, " attack=", item_attack)
				root.add_attack(root.current_attacker, [target], item_attack)
				root.action_history.append(root.current_attacker)
				PlayerStats.remove_item(item, 1)
				item_amounts[current_item_index] -= 1
				close_items_menu()
				root.advance_planning()
			else:
				print("DEBUG confirm_item_target: INVALID TARGET (dead or null)")
				root.get_node("Control/enemy_ui/CenterContainer/output").text = "Invalid target!"
				await root.get_tree().create_timer(0.5).timeout
				close_items_menu()
	else:
		print("DEBUG confirm_item_target: PARTY TARGET path")
		var party_in_initiative = root.get_party_members_from_initiative()
		selected_party_member = clamp(selected_party_member, 0, party_in_initiative.size() - 1)
		var target = party_in_initiative[selected_party_member]
		print("DEBUG confirm_item_target: selected_party_member=", selected_party_member, " target=", target, " target.hp=", target.hp if target else null)
		
		if target and target.hp > 0:
			var item_attack = item.item_attack.duplicate() if item.is_item_attack and item.item_attack else null
			if item_attack:
				item_attack.item_reference = item
				item_attack.name = item.item_name
				print("DEBUG confirm_item_target: ITEM ATTACK on party - Calling add_attack")
				root.add_attack(root.current_attacker, [target], item_attack)
				PlayerStats.remove_item(item, 1)
				item_amounts[current_item_index] -= 1
			else:
				print("DEBUG confirm_item_target: REGULAR ITEM USE - Calling PlayerStats.use_item")
				PlayerStats.use_item(item, target)
			
			root.get_node("WhoMoves").visible = true
			root.move_who_moves(saved_party_plan_index)
			
			root.action_history.append(root.current_attacker)
			close_items_menu()
			root.advance_planning()
		else:
			print("DEBUG confirm_item_target: PARTY MEMBER DEAD OR NULL")

func close_items_menu():
	items_container.visible = false
	root.get_node("Control/gui/HBoxContainer2/party").visible = true
	root.get_node("WhoMoves").visible = true
	root.move_who_moves(saved_party_plan_index)
	root.state = root.states.OnAction
