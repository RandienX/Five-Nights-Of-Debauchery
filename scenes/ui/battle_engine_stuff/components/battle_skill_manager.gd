extends RefCounted
class_name SkillManager

var root

# === SKILLS SYSTEM ===
var skills_container: Control
var skill_boxes: Array[SkillBox] = []
var current_skill_index: int = 0
var skill_scroll_offset: int = 0
var max_visible_skills: int = 8
var available_skills: Array[Skill] = []
var skill_unlocked: Array[bool] = []
var skill_affordable: Array[bool] = []
var skill_box_scene: PackedScene


func setup_skills_ui(battleroot):
	root = battleroot
	skill_box_scene = preload("res://scenes/ui/battle_engine_stuff/skill_box.tscn")
	
	if not root.has_node("Control/gui/HBoxContainer2/skills_container"):
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
		
		# IMPORTANT: Set minimum size to force wrapping
		grid.custom_minimum_size = Vector2(1296, 0)
		
		scroll.add_child(grid)
		root.get_node("Control/gui/HBoxContainer2").add_child(skills_container)
		
	skills_container = root.get_node("Control/gui/HBoxContainer2/skills_container")

func open_skills_menu():
	root.state = root.states.OnSkills
	skills_container.visible = true
	root.get_node("Control/gui/HBoxContainer2/party").visible = false
	root.get_node("WhoMoves").visible = false
	
	available_skills.clear()
	skill_affordable.clear()
	
	if root.current_attacker.role == Entity.Role.PARTY and not root.current_attacker.skills.is_empty():
		var all_skills: Array[Skill] = []
		for level_skills in root.current_attacker.skills.values():
			all_skills.append_array(level_skills)
		
		for skill in all_skills:
			if skill:
				available_skills.append(skill)
				skill_affordable.append(root.current_attacker.mp >= skill.mana_cost)
	
	create_skill_boxes()
	
	current_skill_index = 0
	skill_scroll_offset = 0
	update_skill_selection()

func create_skill_boxes():
	var grid = skills_container.get_node("ScrollContainer/SkillGrid")
	for child in grid.get_children():
		child.queue_free()
	skill_boxes.clear()
	
	for i in range(available_skills.size()):
		var skill = available_skills[i]
		var affordable = skill_affordable[i]
		var box = skill_box_scene.instantiate()
		grid.add_child(box)
		box.setup(skill, i, affordable)
		skill_boxes.append(box)
	
	update_skill_selection()

func update_skill_selection():
	for i in range(skill_boxes.size()):
		var box = skill_boxes[i]
		var affordable = skill_affordable[i]
		
		if i == current_skill_index and affordable:
			box.modulate = Color(1, 1, 0.5)  # Yellow highlight
			box.can_select = true
		else:
			# Keep affordable skills white, unaffordable gray
			box.modulate = Color(1, 1, 1) if affordable else Color(0.5, 0.5, 0.5)
			box.can_select = false
	
	# Handle scrolling
	if current_skill_index >= skill_scroll_offset + max_visible_skills:
		skill_scroll_offset = current_skill_index - max_visible_skills + 1
	elif current_skill_index < skill_scroll_offset:
		skill_scroll_offset = current_skill_index
	
	var scroll = skills_container.get_node("ScrollContainer")
	scroll.scroll_vertical = skill_scroll_offset * 70

func navigate_skills(direction: int):
	var new_index = current_skill_index + direction
	
	if new_index < 0:
		if skill_boxes.size() % 2 == 0:
			new_index = skill_boxes.size() - 1 if new_index % skill_boxes.size() == -1 else skill_boxes.size() - 2
		else:
			new_index = skill_boxes.size() - 2 if new_index % skill_boxes.size() == -1 else skill_boxes.size() - 1
		if abs(direction) == 1:
			new_index = skill_boxes.size() - 1
	elif new_index >= skill_boxes.size():
		if skill_boxes.size() % 2 == 0:
			new_index = direction - 1 if new_index % skill_boxes.size() != 0 else 0
		else:
			new_index = direction - 1 if new_index % skill_boxes.size() == 0 else 0
	
	# Skip unaffordable skills when navigating
	var attempts = 0
	while attempts < skill_boxes.size():
		if skill_affordable[new_index]:
			break
		new_index += direction
		if new_index < 0:
			if skill_boxes.size() % 2 == 0:
				new_index = skill_boxes.size() - 1 if new_index % skill_boxes.size() == -1 else skill_boxes.size() - 2
			else:
				new_index = skill_boxes.size() - 2 if new_index % skill_boxes.size() == -1 else skill_boxes.size() - 1
			if abs(direction) == 1:
				new_index = skill_boxes.size() - 1
		elif new_index >= skill_boxes.size():
			if skill_boxes.size() % 2 == 0:
				new_index = direction - 1 if new_index % skill_boxes.size() != 0 else 0
			else:
				new_index = direction - 1 if new_index % skill_boxes.size() == 0 else 0
		attempts += 1
	
	# Only update if we found an affordable skill
	if skill_affordable[new_index]:
		current_skill_index = new_index
		update_skill_selection()

func select_skill():
	if current_skill_index < 0 or current_skill_index >= available_skills.size():
		return
	
	if not skill_affordable[current_skill_index]:
		root.get_node("Control/enemy_ui/CenterContainer/output").text = "Not enough MP!"
		await root.get_tree().create_timer(0.5 * Settings.battle_speed).timeout
		return
	
	var skill = available_skills[current_skill_index]
	
	if skill.mana_cost > root.current_attacker.mp:
		root.get_node("Control/enemy_ui/CenterContainer/output").text = "Not enough MP!"
		await root.get_tree().create_timer(0.5 * Settings.battle_speed).timeout
		return
	
	if skill.target_type == 0: #SingleEnemy
		root.state = root.states.OnSkillSelect
		root.selected_enemy = root.previous_enemy if root.previous_enemy != 0 else 1
		root.get_node("Control/enemy_ui/CenterContainer/output").text = "Select target..."
		return
	elif skill.target_type == 1: #Self 
		root.add_attack(root.current_attacker, [root.current_attacker], skill)
		root.action_history.append(root.current_attacker)
		close_skills_menu()
		await root.advance_planning()
	elif skill.target_type == 2: #Party
		root.add_attack(root.current_attacker, root.party, skill)
		root.action_history.append(root.current_attacker)
		close_skills_menu()
		await root.advance_planning()
	elif skill.target_type == 3: #AllEnemies
		root.add_attack(root.current_attacker, root.enemy_instances, skill)
		root.action_history.append(root.current_attacker)
		close_skills_menu()
		await root.advance_planning()
	elif skill.target_type == 4: #SingleAlly
		root.state = root.states.OnSkillSelect
		root.selected_enemy = root.previous_enemy if root.previous_enemy != 0 else 1
		root.get_node("Control/enemy_ui/CenterContainer/output").text = "Select ally..."
		return
	elif skill.target_type == 5: #RandomEnemy
		root.add_attack(root.current_attacker, root.enemy_instances[randi_range(0, root.enemy_instances.duplicate().size()-1)], skill)
		root.action_history.append(root.current_attacker)
		close_skills_menu()
		await root.advance_planning()
		
func confirm_skill_target():
	var skill = available_skills[current_skill_index]
	if skill.target_type == 0: #SingleEnemy
		var target = root.get_enemy(root.selected_enemy)
		if target and target.hp > 0:
			root.add_attack(root.current_attacker, [target], skill)
			root.action_history.append(root.current_attacker)
			close_skills_menu()
			await root.advance_planning()
	elif skill.target_type == 4: #SingleAlly
		var target = root.party[clamp(root.selected_enemy - 1, 0, root.party.size() - 1)]
		root.add_attack(root.current_attacker, [target], skill)
		root.action_history.append(root.current_attacker)
		close_skills_menu()
		await root.advance_planning()
		
func close_skills_menu():
	skills_container.visible = false
	root.get_node("Control/gui/HBoxContainer2/party").visible = true
	root.get_node("WhoMoves").visible = true
	root.state = root.states.OnAction
