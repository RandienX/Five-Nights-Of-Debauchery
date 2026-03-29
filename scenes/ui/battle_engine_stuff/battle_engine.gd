extends Node2D

@export var battle: Battle
var party: Array = Global.party
var battle_start_position: Vector2 = Vector2.ZERO
var initiative: Array[Object]

# Component managers
var initiative_manager: BattleInitiativeManager
var action_planner: BattleActionPlanner
var effect_manager: BattleEffectManager
var battle_logger: BattleLogger
var attack_executor: BattleAttackExecutor
var end_condition_checker: BattleEndConditionChecker

enum states { OnAction, OnEnemy, OnSkills, OnSkillSelect, OnItems, OnItemSelect, Waiting, OnRun}
var state: states = states.OnAction

var planning_phase: bool = true
var current_attacker: Object
var current_party_plan_index: int = 0
var selected_enemy: int = 1
var previous_enemy: int = 1
var is_animating_death: bool = false

var game_over_active: bool = false
var game_over_overlay: ColorRect
var game_over_texture: TextureRect
var can_reload = false

const EFFECT_ATLAS_PATH = "res://assets/battleui/status_effects.png"
const EFFECT_TILE_SIZE = 64
const EFFECT_COLS = 4

# === SETUP ===
func _ready() -> void:
	battle_start_position = Global.player_position
	await get_tree().create_timer(0.02).timeout
	battle = Global.battle_current.duplicate(true)
	Global.battle_ref = self
	
	# Initialize component managers
	initiative_manager = BattleInitiativeManager.new(party)
	action_planner = BattleActionPlanner.new()
	effect_manager = BattleEffectManager.new()
	battle_logger = BattleLogger.new()
	attack_executor = BattleAttackExecutor.new(self)
	end_condition_checker = BattleEndConditionChecker.new()
	
	await get_tree().create_timer(0.05).timeout
	setup_enemies()
	initiative = initiative_manager.setup_initiative(battle)
	setup_party()
	setup_current_attacker()
	setup_skills_ui()
	setup_items_ui()
	_setup_game_over_ui()
	_setup_battle_log_label()
	if battle.music_override:
		$AudioStreamPlayer.stream = battle.music_override

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
		
		# IMPORTANT: Set minimum size to force wrapping
		grid.custom_minimum_size = Vector2(1296, 0)
		
		scroll.add_child(grid)
		
		$Control/gui/HBoxContainer2.add_child(skills_container)
	
	skills_container = $Control/gui/HBoxContainer2/skills_container
	
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
	
	if not battle_logger.battle_log.is_empty():
		battle_logger.log_timer += delta
		if battle_logger.log_timer >= battle_logger.log_display_time:
			battle_logger.log_timer = 0.0
			battle_logger.remove_oldest_log_entry()

func _input(event: InputEvent) -> void:
	if game_over_active:
		if can_reload:
			if event.is_action("use") or event.is_action("menu"):
				Global.reload_last_save()
		return
	
	if state == states.Waiting:
		if event.is_pressed(): get_viewport().set_input_as_handled()
		return
	
	if planning_phase and (event.is_action_pressed("ui_undo") or event.is_action_pressed("ui_cancel")):
		if state == states.OnSkills or state == states.OnSkillSelect:
			close_skills_menu()
			get_viewport().set_input_as_handled()
			return
		elif state == states.OnItems or state == states.OnItemSelect:
			close_items_menu()
			get_viewport().set_input_as_handled()
			return
		else:
			undo_last_action()
			get_viewport().set_input_as_handled()
			return
	
	if not event.is_pressed() or event is InputEventMouseMotion:
		return
	
	match state:
		states.OnAction:
			if event.is_action_pressed("down"):
				move_the_move(1)
			elif event.is_action_pressed("up"):
				move_the_move(-1)
			elif event.is_action_pressed("use"):
				simulate_click_move()
			if get_viewport():
				get_viewport().set_input_as_handled()
		
		states.OnSkills:
			if event.is_action_pressed("down"):
				navigate_skills(2)
			elif event.is_action_pressed("up"):
				navigate_skills(-2)
			elif event.is_action_pressed("right"):
				navigate_skills(1)
			elif event.is_action_pressed("left"):
				navigate_skills(-1)
			elif event.is_action_pressed("use"):
				select_skill()
			elif event.is_action_pressed("ui_cancel"):
				close_skills_menu()
			if get_viewport():
				get_viewport().set_input_as_handled()
		
		states.OnSkillSelect:
			if event.is_action_pressed("left"):
				move_enemy_input(-1)
			elif event.is_action_pressed("right"):
				move_enemy_input(1)
			elif event.is_action_pressed("use"):
				confirm_skill_target()
			elif event.is_action_pressed("ui_cancel"):
				close_skills_menu()
			if get_viewport():
				get_viewport().set_input_as_handled()
		
		states.OnItems:
			if event.is_action_pressed("down"):
				navigate_items(2)  
			elif event.is_action_pressed("up"):
				navigate_items(-2)
			elif event.is_action_pressed("right"):
				navigate_items(1)
			elif event.is_action_pressed("left"):
				navigate_items(-1)
			elif event.is_action_pressed("use"):
				select_item()
			elif event.is_action_pressed("ui_cancel"):
				close_items_menu()
			if get_viewport():
				get_viewport().set_input_as_handled()
		
		states.OnItemSelect:
			if event.is_action_pressed("left"):
				if item_target_type == 0:
					move_enemy_input(-1)
				else:
					var party_in_initiative = get_party_members_from_initiative()
					selected_party_member = wrapi(selected_party_member - 1, 0, party_in_initiative.size())
					print("DEBUG Input Left: selected_party_member = ", selected_party_member, " target = ", party_in_initiative[selected_party_member].name)
					move_who_moves(selected_party_member)
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("right"):
				if item_target_type == 0:
					move_enemy_input(1)
				else:
					var party_in_initiative = get_party_members_from_initiative()
					selected_party_member = wrapi(selected_party_member + 1, 0, party_in_initiative.size())
					print("DEBUG Input Right: selected_party_member = ", selected_party_member, " target = ", party_in_initiative[selected_party_member].name)
					move_who_moves(selected_party_member)
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("use"):
				confirm_item_target()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_cancel"):
				if item_target_type == 1:
					$WhoMoves.visible = true
					move_who_moves(saved_party_plan_index)
				close_items_menu()
			if get_viewport():
				get_viewport().set_input_as_handled()
		
		states.OnEnemy:
			if event.is_action_pressed("left"):
				move_enemy_input(-1)
			elif event.is_action_pressed("right"):
				move_enemy_input(1)
			elif event.is_action_pressed("use"):
				add_attack(current_attacker, [battle.get('enemy_pos'+str(selected_enemy))], load("res://resources/attacks/attack.tres"))
				action_planner.action_history.append(current_attacker)
				previous_enemy = selected_enemy
				selected_enemy = 0
				advance_planning()
			if get_viewport():
				get_viewport().set_input_as_handled()
				
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

func get_party_members_from_initiative() -> Array:
	var party_members: Array = []
	for actor in initiative:
		if actor is Party:
			party_members.append(actor)
	return party_members

func update_flash():
	for c in $Control/enemy_ui/enemies.get_children():
		if c.material:
			c.material.set("shader_parameter/is_flashing", c.name == "enemy" + str(selected_enemy))

func update_party_ui():
	var party_container = $Control/gui/HBoxContainer2/party
	if party_container:
		for i in range(party_container.get_child_count()):
			var ui = party_container.get_child(i)
			if ui.has_method("update_effects_ui"):
				ui.update_effects_ui()

func add_attack(attacker: Object, attacked: Array, attack: Skill):
	action_planner.add_attack(attacker, attacked, attack)

func undo_last_action():
	var last = action_planner.undo_last_action()
	if not last:
		return
	
	current_attacker = last
	state = states.OnAction
	move_who_moves(current_party_plan_index)
	$Control/enemy_ui/CenterContainer/output.text = "Undid " + last.name + "'s move"

func advance_planning():
	var start = (initiative_manager.initiative_who + 1) % initiative.size() if initiative.size() > 0 else 0
	for i in range(initiative.size()):
		var idx = (start + i) % initiative.size()
		var actor = initiative[idx]
		if actor is Party and not action_planner.has_planned_action(actor):
			initiative_manager.initiative_who = idx
			current_attacker = actor
			state = states.OnAction
			current_party_plan_index += 1
			move_who_moves(current_party_plan_index)
			return
	start_resolution_phase()

func start_resolution_phase():
	planning_phase = false
	action_planner.planning_phase = false
	state = states.Waiting
	$WhoMoves.visible = false
	for actor in initiative:
		if actor is Enemy:
			add_enemy_attack(actor)
	initiative_manager.initiative_who = -1
	await get_tree().create_timer(0.4).timeout
	advance_initiative()

func advance_initiative():
	if planning_phase:
		return
	initiative_manager.advance_initiative_step()
	if initiative_manager.initiative_who >= initiative.size():
		initiative_manager.initiative_who = -1
		await get_tree().process_frame
		await do_attacks()
		return
	var current = initiative[initiative_manager.initiative_who]
	if effect_manager.get_effect_duration(current, Global.effect.Sleep) > 0:
		if action_planner.has_planned_action(current):
			action_planner.attack_array.erase(current)
		$Control/enemy_ui/CenterContainer/output.text = current.name + " is asleep!"
		await get_tree().create_timer(0.5).timeout
		advance_initiative()
		return
	if not action_planner.has_planned_action(current):
		advance_initiative()
		return
	if current is Party:
		current_attacker = current
	advance_initiative()

func add_enemy_attack(e: Enemy):
	if e.attacks.is_empty(): return
	var atk: Skill = e.attacks[randi_range(0, len(e.attacks)-1)]
	while atk.mana_cost > e.mp:
		atk = e.attacks[randi_range(0, len(e.attacks)-1)]
	var prob: Array[int] = []
	var lowest = 0
	for i in range(party.size()):
		prob.append(1 if party[i].hp > 0 else 0)
		if party[i].hp > 0 and party[i].hp < party[lowest].hp: lowest = i
	var dumbness = [10, 4, 3, 3, 1]
	var rng = randi_range(1, dumbness[e.ai_type])
	if rng <= 2: prob[lowest] += 3 - rng
	else:
		var valid: Array[int] = []
		for i in range(prob.size()):
			if prob[i] > 0: valid.append(i)
		if not valid.is_empty(): prob[valid[randi_range(0, valid.size()-1)]] += 1
	for i in range(party.size()):
		if Global.effect.Focus in party[i].effects:
			prob[i] += 5 if e.ai_type != 4 else 1
	var target = null
	if atk.target_type == 0:
		var total = 0
		for p in prob: total += p
		if total == 0: return
		var rng2 = randi_range(1, total)
		for i in range(prob.size()):
			rng2 -= prob[i]
			if rng2 <= 0 and prob[i] > 0:
				target = [party[i]]
				break
	elif atk.target_type == 2:
		target = party
	if target: action_planner.attack_array[e] = [target, atk]

func start_round():
	update_effects() 
	action_planner.attack_array.clear()
	action_planner.action_history.clear()
	planning_phase = true
	initiative_manager.initiative_who = -1
	action_planner.current_party_plan_index = -1
	state = states.OnAction
	$WhoMoves.visible = false
	$Control/enemy_ui/CenterContainer/output.text = ""
	advance_planning()

func do_attacks() -> void:
	for actor in initiative:
		if action_planner.has_planned_action(actor):
			if actor is Party:
				current_attacker = actor
			await execute_single_attack(actor)
	await check_enemy_death_and_xp()
	await get_tree().create_timer(0.5).timeout
	start_round()

func execute_single_attack(attacker: Object) -> void:
	var targets = action_planner.attack_array[attacker][0]
	var atk: Skill = action_planner.attack_array[attacker][1]
	var alive: Array = []
	for t in targets:
		if t.hp > 0: alive.append(t)
	
	if atk.name == "Check ":
		var desc = "[color=#2196F3]━━━ ENEMY INFO ━━━[/color]"
		if targets.size() > 0 and targets[0] is Enemy:
			var target_enemy = targets[0]
			desc += "\n[color=#FF5722]" + target_enemy.name + "[/color]: " + target_enemy.description
			desc += "\n[color=#4CAF50]HP: " + str(target_enemy.hp) + "/" + str(target_enemy.max_hp) + "[/color] [color=#FFC107]ATK: " + str(target_enemy.damage) + "[/color]"
		battle_logger.add_to_battle_log(desc)
		await get_tree().create_timer(1.5).timeout
		return

	if alive.is_empty() and atk.target_type == 0:  
		var enemies: Array = []
		for e in range(5):
			if battle.get('enemy_pos'+str(e+1)) and battle.get('enemy_pos'+str(e+1)).hp > 0:
				enemies.append(battle.get('enemy_pos'+str(e+1)))
		if not enemies.is_empty():
			alive = [enemies[randi_range(0, enemies.size()-1)]]
			action_planner.attack_array[attacker][0] = alive
		else : return
	if alive.is_empty(): return

	if atk.attack_type == 3:
		var used_item = atk.item_reference
		
		if used_item and targets.size() > 0:
			var target = targets[0]
			var success = Global.use_item(used_item, target)
			
			if success:
				var item_log = "[color=#FFD700]━━━ ITEM ━━━[/color]"
				item_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.name + "[/color] on [color=#FF5722]" + target.name + "[/color]"
				if used_item.heal_amount > 0: item_log += " [color=#4CAF50](+" + str(used_item.heal_amount) + " HP)[/color]"
				if used_item.mana_amount > 0: item_log += " [color=#2196F3](+" + str(used_item.mana_amount) + " MP)[/color]"
				battle_logger.add_to_battle_log(item_log)
				update_party_ui()
				update_effect_ui(target)
			else:
				battle_logger.add_to_battle_log("[color=#F44336]Item use failed![/color]")
			
			await get_tree().create_timer(0.75).timeout
			return

	if alive.is_empty() and atk.target_type == 0:
		var enemies: Array = []
		for e in range(5):
			if battle.get('enemy_pos'+str(e+1)) and battle.get('enemy_pos'+str(e+1)).hp > 0:
				enemies.append(battle.get('enemy_pos'+str(e+1)))
		if not enemies.is_empty():
			alive = [enemies[randi_range(0, enemies.size()-1)]]
			action_planner.attack_array[attacker][0] = alive
		else : return
	if alive.is_empty(): return

	if atk.attack_type == 2 and atk.name != "Check ":
		var total_dmg = 0
		var total_crits = 0
		var total_misses = 0
		var target = alive[0] if alive.size() > 0 else null
		if not target: return
		
		var multi_log = "[color=#FFD700]━━━ MULTI-ATTACK ━━━[/color]"
		multi_log += "\n[color=#4CAF50]" + attacker.name + "[/color] used [color=#2196F3]" + atk.name + "[/color] on [color=#FF5722]" + target.name + "[/color]"
		
		for i in range(atk.hit_count):
			await get_tree().create_timer(0.15).timeout
			
			var crit = randi_range(1, 10 if attacker is Enemy else 8) == 1
			var base = (attacker.damage if attacker is Enemy else attacker.max_stats['atk']) * atk.attack_multiplier * atk.hit_damage_multiplier
			
			var power_mult = get_effect_multiplier(attacker, Global.effect.Power)
			var weak_mult = get_effect_multiplier(attacker, Global.effect.Weak)
			base *= power_mult * weak_mult
			
			if Global.effect.Power in attacker.effects: base *= 2
			base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
			if crit: base *= 1.5
			base += atk.attack_bonus
			
			if check_instakill(attacker, target):
				target.hp = 0
				multi_log += "\n[color=#FF0000]Hit " + str(i+1) + ": ★★★ INSTAKILL ★★★[/color]"
				await get_tree().create_timer(0.5).timeout
				if attacker is Party and target is Enemy:
					await animate_enemy_death(target)
				death(target)
				battle_logger.add_to_battle_log(multi_log)
				await get_tree().create_timer(1.0).timeout
				return
			
			var tough_mult = get_effect_multiplier(target, Global.effect.Tough)
			var sick_mult = get_effect_multiplier(target, Global.effect.Sick)
			var def_stat = target.max_stats["def"] if attacker is Enemy else target.defense * 2
			var defend_mult = 1.5 if Global.effect.Defend in target.effects else 1.0
			var def_mult = clampf(1.0 - (float(def_stat) / (100.0 / (tough_mult * sick_mult))), 0.0, 1.0)
			def_mult /= defend_mult
			def_mult = clampf(def_mult, 0.0, 1.0)
			
			var dmg = max(0, floor(base * def_mult))
			
			var focus_mult = get_effect_multiplier(attacker, Global.effect.Focus)
			var blind_mult = get_effect_multiplier(target, Global.effect.Blind)
			var hit = randf() <= (atk.accuracy * focus_mult * blind_mult)
			
			if hit:
				$AnimationPlayer.play("move_around_screen")
				await $AnimationPlayer.animation_finished
				target.hp -= dmg
				total_dmg += dmg
				if crit: total_crits += 1
				
				var hit_color = "#FF0000" if crit else "#FFFFFF"
				multi_log += "\n[color=" + hit_color + "]Hit " + str(i+1) + ": " + str(dmg) + " DMG"
				if crit: multi_log += " ★CRIT★"
				multi_log += "[/color]"
				
				if target.effects.has(Global.effect.Sleep):
					var sleep_level = target.effects[Global.effect.Sleep][0]
					if randf() < (1.0 - (0.1 * sleep_level)):
						remove_effect(target, Global.effect.Sleep)
						multi_log += "\n[color=#FFD700]" + target.name + " woke up![/color]"
				
				for e in range(5):
					var node = get_node_or_null("Control/enemy_ui/enemies/enemy"+str(e+1))
					if node and battle.get('enemy_pos'+str(e+1)):
						node.hp = max(0, battle.get('enemy_pos'+str(e+1)).hp)
			else:
				total_misses += 1
				multi_log += "\n[color=#FF9800]Hit " + str(i+1) + ": MISSED[/color]"
		
		attacker.mp = max(0, attacker.mp - atk.mana_cost)
		
		multi_log += "\n[color=#03A9F4]Total: " + str(total_dmg) + " DMG | "
		multi_log += str(atk.hit_count - total_misses) + "/" + str(atk.hit_count) + " hits"
		if total_crits > 0: multi_log += " | " + str(total_crits) + " CRITs"
		if atk.mana_cost > 0: multi_log += " | " + str(atk.mana_cost) + " MP"
		multi_log += "[/color]"
		
		battle_logger.add_to_battle_log(multi_log)
		await get_tree().create_timer(1.5).timeout
		
		if target.hp <= 0:
			if attacker is Party and target is Enemy:
				await animate_enemy_death(target)
			death(target)
		return

	if atk.attack_type == 0 and atk.target_type == 0:
		var target = alive[0]
		var crit = randi_range(1, 10 if attacker is Enemy else 8) == 1
		var base = (attacker.damage if attacker is Enemy else attacker.max_stats['atk']) * atk.attack_multiplier
		
		var power_mult = get_effect_multiplier(attacker, Global.effect.Power)
		var weak_mult = get_effect_multiplier(attacker, Global.effect.Weak)
		base *= power_mult * weak_mult
		
		if Global.effect.Power in attacker.effects: base *= 2
		base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
		if crit: base *= 1.5
		base += atk.attack_bonus
		
		var was_instakill = false
		if check_instakill(attacker, target):
			target.hp = 0
			attacker.mp = max(0, attacker.mp - atk.mana_cost)
			was_instakill = true
			if attacker is Party and target is Enemy:
				await animate_enemy_death(target)
			death(target)
		
		var tough_mult = get_effect_multiplier(target, Global.effect.Tough)
		var sick_mult = get_effect_multiplier(target, Global.effect.Sick)
		var def_stat = target.max_stats["def"] if attacker is Enemy else target.defense * 2
		var defend_mult = 1.5 if Global.effect.Defend in target.effects else 1.0
		var def_mult = clampf(1.0 - (float(def_stat) / (100.0 / (tough_mult * sick_mult))), 0.0, 1.0)
		def_mult /= defend_mult
		def_mult = clampf(def_mult, 0.0, 1.0)
		
		var dmg = max(0, floor(base * def_mult))
		
		var focus_mult = get_effect_multiplier(attacker, Global.effect.Focus)
		var blind_mult = get_effect_multiplier(target, Global.effect.Blind)
		var hit = randf() <= (atk.accuracy * focus_mult * blind_mult)
		
		var effects_applied: Array = []
		if hit and not was_instakill:
			$AnimationPlayer.play("move_around_screen")
			target.hp -= dmg
			apply_effects(target, atk)
			
			if atk.effects:
				for effect in atk.effects.keys():
					var level = atk.effects[effect][0]
					var duration = atk.effects[effect][1]
					effects_applied.append([effect, level])
			
			if target.effects.has(Global.effect.Sleep):
				var sleep_level = target.effects[Global.effect.Sleep][0]
				if randf() < (1.0 - (0.1 * sleep_level)):
					remove_effect(target, Global.effect.Sleep)
			
			if attacker is Party and target is Enemy and target.hp <= 0:
				await animate_enemy_death(target)
		
		attacker.mp = max(0, attacker.mp - atk.mana_cost)
		if not was_instakill:
			print_outcome(attacker, [target], atk, dmg, crit, not hit, atk.mana_cost, effects_applied)
		else:
			battle_logger.add_to_battle_log("[color=#FF0000]" + attacker.name + " used " + atk.name + ": ★★★ INSTAKILL ★★★[/color]")

	elif atk.attack_type == 1:
		var buff_log = "[color=#FFD700]━━━ BUFF ━━━[/color]"
		var effects_applied: Array = []
		
		if atk.target_type == 1:
			apply_effects(attacker, atk)
			update_effect_ui(attacker)
			buff_log += "\n[color=#4CAF50]" + attacker.name + "[/color] buffed self"
			if atk.effects:
				for effect in atk.effects.keys():
					var level = atk.effects[effect][0]
					var duration = atk.effects[effect][1]
					effects_applied.append([effect, level])
					buff_log += " [color=#E91E63]" + get_effect_name_with_level(effect, level) + " (" + str(duration) + "t)[/color]"
			if atk.mana_cost > 0: buff_log += " [color=#9C27B0](" + str(atk.mana_cost) + " MP)[/color]"
			battle_logger.add_to_battle_log(buff_log)
			
		elif atk.target_type == 2:
			buff_log += "\n[color=#4CAF50]" + attacker.name + "[/color] buffed party"
			for p in party:
				if p.hp > 0:
					apply_effects(p, atk)
					update_effect_ui(p)
			if atk.effects:
				for effect in atk.effects.keys():
					var level = atk.effects[effect][0]
					var duration = atk.effects[effect][1]
					var found = false
					for e in effects_applied:
						if e[0] == effect:
							found = true
							break
					if not found:
						effects_applied.append([effect, level])
					buff_log += " [color=#E91E63]" + get_effect_name_with_level(effect, level) + " (" + str(duration) + "t)[/color]"
			if atk.mana_cost > 0: buff_log += " [color=#9C27B0](" + str(atk.mana_cost) + " MP)[/color]"
			battle_logger.add_to_battle_log(buff_log)

	for t in alive:
		if t.hp <= 0:
			death(t)
	await get_tree().create_timer(0.5).timeout


func add_to_battle_log(text: String) -> void:
	battle_logger.log_timer = 0.0
	battle_logger.battle_log.append(text)
	if battle_logger.battle_log.size() > battle_logger.max_log_entries:
		battle_logger.battle_log.remove_at(0)
	battle_logger.update_battle_log_display()

func remove_oldest_log_entry() -> void:
	if not battle_logger.battle_log.is_empty():
		battle_logger.battle_log.remove_at(0)
		battle_logger.update_battle_log_display()

func update_battle_log_display() -> void:
	if battle_logger.battle_log.is_empty():
		$Control/enemy_ui/CenterContainer/output.text = ""
	else:
		$Control/enemy_ui/CenterContainer/output.text = "\n".join(battle_logger.battle_log)


func print_outcome(atk: Object, targets: Array, attack: Skill, dmg: int, crit: bool, miss: bool, mp_cost: int = 0, effects_applied: Array = []):
	var t = ""
	if targets.size() > 0:
		var attacker_color = "#4CAF50" if atk is Party else "#F44336"
		var target_color = "#FF5722" if targets[0] is Enemy else "#4CAF50"
		
		if atk == targets[0]:
			t = "[color=" + attacker_color + "]" + atk.name + "[/color] used [color=#2196F3]" + attack.name + "[/color] on self"
			if mp_cost > 0: t += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
		elif miss:
			t = "[color=" + attacker_color + "]" + atk.name + "[/color] missed [color=" + target_color + "]" + targets[0].name + "[/color]"
			if mp_cost > 0: t += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
		else:
			t = "[color=" + attacker_color + "]" + atk.name + "[/color] hit [color=" + target_color + "]" + targets[0].name + "[/color] for [color=#FFFFFF]" + str(dmg) + "[/color]"
			if crit: t += " [color=#FFD700]★★CRIT★★[/color]"
			if mp_cost > 0: t += " [color=#9C27B0](" + str(mp_cost) + " MP)[/color]"
			if effects_applied.size() > 0:
				t += " [color=#E91E63]{"
				for i in range(effects_applied.size()):
					if i > 0: t += ", "
					t += get_effect_name_with_level(effects_applied[i][0], effects_applied[i][1])
				t += "}[/color]"
	battle_logger.add_to_battle_log(t)
# === DEATH & VICTORY LOGIC ===

func check_enemy_death_and_xp():
	var all_dead = true
	for e in range(5):
		if battle.get('enemy_pos'+str(e+1)) and battle.get('enemy_pos'+str(e+1)).hp > 0:
			all_dead = false
			break
	
	# Check custom end conditions first
	if await check_custom_end_conditions():
		return
	
	if all_dead:
		var total_xp = 0
		for e in range(5):
			if battle.get('enemy_pos'+str(e+1)):
				total_xp += battle.get('enemy_pos'+str(e+1)).xp_reward
		for actor in initiative:
			if actor is Party:
				actor.xp += total_xp
				$Control/enemy_ui/CenterContainer/output.text = actor.name + " gained " + str(total_xp) + " XP! "
				while actor.xp >= actor.xp_to_level_up:
					actor.xp -= actor.xp_to_level_up
					actor.level += 1
					actor.xp_to_level_up = ceil(actor.xp_to_level_up * actor.level_up_xp_multilpier)
					for stat in ["hp", "mp", "atk", "def", "ai"]:
						actor.max_stats[stat] += int(actor.level_up[stat] * actor.level)
						actor.base_stats[stat] += int(actor.level_up[stat] * actor.level)
					actor.hp = actor.max_stats["hp"]
					actor.mp = actor.max_stats["mp"]
					$Control/enemy_ui/CenterContainer/output.text = actor.name + " leveled up to " + str(actor.level) + "! "
					await get_tree().create_timer(1.0).timeout
		await end_battle_victory()
		return

func check_custom_end_conditions() -> bool:
	if not battle or not battle.end_conditions or battle.end_conditions.is_empty():
		return false
	
	for condition in battle.end_conditions:
		if condition.check(self):
			condition.execute(self)
			return true
	
	return false

func end_battle_victory() -> void:
	await get_tree().create_timer(1.0).timeout
	Global.player_position = battle_start_position
	Global.loading = true
	get_tree().change_scene_to_file(Global.current_scene)
	Global.loading = false

func animate_enemy_death(e: Enemy) -> void:
	if is_animating_death: return
	is_animating_death = true
	var slot = 0
	for i in range(5):
		if battle.get('enemy_pos'+str(i+1)) == e:
			slot = i + 1
			break
	if slot == 0:
		is_animating_death = false
		return
	var node = get_node_or_null("Control/enemy_ui/enemies/enemy" + str(slot))
	if not node:
		is_animating_death = false
		return
	var orig = node.position
	var mat = node.material
	for i in range(20):
		if mat: mat.set("shader_parameter/flash_intensity", float(i)/20.0)
		await get_tree().create_timer(0.05).timeout
	var jitter = 3.0
	for i in range(30):
		node.position.y = orig.y + i*2
		node.position.x = orig.x + randf_range(-jitter, jitter)
		jitter *= 0.95
		await get_tree().create_timer(0.03).timeout
	for i in range(20):
		if mat: mat.set("shader_parameter/opacity", 1.0 - float(i)/20.0)
		await get_tree().create_timer(0.05).timeout
	node.visible = false
	node.position = orig
	if mat:
		mat.set("shader_parameter/flash_intensity", 0.0)
		mat.set("shader_parameter/opacity", 1.0)
	move_flash_to_next_enemy(slot)
	is_animating_death = false

func move_flash_to_next_enemy(slot: int):
	for i in range(1, 6):
		var next = ((slot + i - 1) % 5) + 1
		if battle.get('enemy_pos'+str(next)) and battle.get('enemy_pos'+str(next)).hp > 0:
			selected_enemy = next
			return
	selected_enemy = 0

func death(obj):
	for i in range(initiative.size()-1, -1, -1):
		if initiative[i] == obj:
			initiative.remove_at(i)
			if action_planner.has_planned_action(obj): action_planner.attack_array.erase(obj)
			if obj is Party and planning_phase and action_planner.action_history.has(obj):
				action_planner.action_history.erase(obj)
				action_planner.current_party_plan_index -= 1

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

# === EFFECT SYSTEM ===
var effect_durations: Dictionary = {}  # {target: {effect: [level, duration]}}

func get_effect_level(target: Object, effect: Global.effect) -> int:
	if target.effects.has(effect) and target.effects[effect].size() >= 1:
		return target.effects[effect][0]
	return 0

func get_effect_duration(target: Object, effect: Global.effect) -> int:
	if target.effects.has(effect) and target.effects[effect].size() >= 2:
		return target.effects[effect][1]
	return 0

func get_effect_multiplier(target: Object, effect: Global.effect) -> float:
	var level = get_effect_level(target, effect)
	if level <= 0: return 1.0
	match effect:
		Global.effect.Power:
			return 1.0 + (level * 0.25)
		Global.effect.Tough:
			return 1.0 + (level * 0.25)
		Global.effect.Focus:
			return 1.0 + (level * 0.05)
		Global.effect.Speed:
			return 1.0 + (level * 0.1)
		Global.effect.Blind:
			return 1.0 - (level * 0.2)
		Global.effect.Absorption:
			return 1.0 + (level * 0.2)
		Global.effect.Weak:
			return 1.0 - (level * 0.2)
		Global.effect.Sick:
			return 1.0 - (level * 0.2)
		Global.effect.Slow:
			return 1.0 - (level * 0.1)
	return 1.0

func remove_effect(target: Object, effect: Global.effect):
	if target.effects.has(effect):
		target.effects.erase(effect)
	if effect_durations.has(target) and effect_durations[target].has(effect):
		effect_durations[target].erase(effect)
	
	var party_container = $Control/gui/HBoxContainer2/party
	if target is Party:
		for i in range(party_container.get_child_count()):
			var ui = party_container.get_child(i)
			if ui.has_method("update_effects_ui"):
				ui.update_effects_ui()
	else:
		var slot = 0
		for i in range(5):
			if battle.get('enemy_pos'+str(i+1)) == target:
				slot = i + 1
				break
		if slot > 0:
			var node = get_node_or_null("Control/enemy_ui/enemies/enemy" + str(slot))
			if node:
				var container = node.get_node_or_null("EffectContainer")
				if container:
					for child in container.get_children():
						child.queue_free()

func apply_effects(target: Object, atk: Skill):
	if atk.effects:
		for effect in atk.effects.keys():
			var level = atk.effects[effect][0]
			var duration = atk.effects[effect][1]
			Global.apply_effect(target, effect, level, duration)
			
func apply_effect(target: Object, effect: Global.effect, level: int, duration: int):
	if not target.effects.has(effect):
		target.effects[effect] = [0, 0]

		target.effects[effect][0] = max(target.effects[effect][0], level)
		target.effects[effect][1] = max(target.effects[effect][1], duration)

	if not effect_durations.has(target):
		effect_durations[target] = {}
	if not effect_durations[target].has(effect):
		effect_durations[target][effect] = [level, duration]
	else:
		effect_durations[target][effect][0] = max(effect_durations[target][effect][0], level)
		effect_durations[target][effect][1] = max(effect_durations[target][effect][1], duration)

func apply_effect_duration(target: Object, effect: int, level: int, duration: int):
	if not target.effects.has(effect):
		target.effects[effect] = [0, 0]
	target.effects[effect][0] = max(target.effects[effect][0], level)
	target.effects[effect][1] = max(target.effects[effect][1], duration)

	if not effect_durations.has(target):
		effect_durations[target] = {}
	if not effect_durations[target].has(effect):
		effect_durations[target][effect] = [level, duration]
	else:
		effect_durations[target][effect][0] = max(effect_durations[target][effect][0], level)
		effect_durations[target][effect][1] = max(effect_durations[target][effect][1], duration)
	
	if effect == Global.effect.Absorption:
		apply_absorption_bonus(target, level)
	
	update_effect_ui(target)

func apply_absorption_bonus(target: Object, level: int):
	var bonus = floor(target.max_stats["hp"] * 0.1 * level)
	target.max_stats["hp"] += bonus
	target.hp = min(target.hp + bonus, target.max_stats["hp"])

func remove_absorption_bonus(target: Object, level: int):
	var bonus = floor(target.max_stats["hp"] * 0.1 * level)
	target.max_stats["hp"] -= bonus
	target.hp = min(target.hp, target.max_stats["hp"])

func update_effects():
	var targets_to_clean = []
	for target in effect_durations.keys():
		if not is_instance_valid(target):
			targets_to_clean.append(target)
			continue

		var effects_to_remove = []
		for effect in effect_durations[target].keys():
			var data = effect_durations[target][effect]
			var level = data[0]
			
			if effect == Global.effect.Heal and target.hp > 0:
				target.hp = min(target.hp + floor(target.max_stats["hp"] * 0.05 * level), target.max_stats["hp"])
			elif effect == Global.effect.Mana_Heal and target.mp > 0:
				target.mp = min(target.mp + floor(target.max_stats["mp"] * 0.05 * level), target.max_stats["mp"])
			elif effect == Global.effect.Revive and target.hp <= 0:
				target.hp = floor(target.max_stats["hp"] * 0.5)
				effects_to_remove.append(effect)
				continue
			elif effect == Global.effect.Poison:
				var dmg = floor(target.max_stats["hp"] * 0.1 * level)
				target.hp -= dmg
			elif effect == Global.effect.Bleed:
				var dmg = floor(target.max_stats["hp"] * 0.15 * level)
				target.hp -= dmg

			data[1] -= 1
			if data[1] <= 0:
				effects_to_remove.append(effect)
				if effect == Global.effect.Absorption:
					remove_absorption_bonus(target, level)

		for effect in effects_to_remove:
			effect_durations[target].erase(effect)
			if target.effects.has(effect):
				target.effects.erase(effect)

		if effect_durations[target].is_empty():
			targets_to_clean.append(target)

	for target in targets_to_clean:
		if effect_durations.has(target):
			effect_durations.erase(target)
	
	for actor in initiative:
		if is_instance_valid(actor):
			update_effect_ui(actor)

func update_effect_ui(actor: Object) -> void:
	var container: GridContainer = null
	if actor is Party:
		var party_container = $Control/gui/HBoxContainer2/party
		for i in range(party_container.get_child_count()):
			var ui = party_container.get_child(i)
			if ui.has_method("setup") and ui.party_member == actor:
				container = ui.effect_container
				break
	else:
		var slot = 0
		for i in range(5):
			if battle.get('enemy_pos'+str(i+1)) == actor:
				slot = i + 1
				break
		if slot > 0:
			var node = get_node_or_null("Control/enemy_ui/enemies/enemy" + str(slot))
			if node:
				container = node.get_node_or_null("EffectContainer")
	
	if container:
		for child in container.get_children():
			child.queue_free()
		
		if actor.effects:
			for effect in actor.effects.keys():
				var data = actor.effects[effect]
				if data is Array and data.size() >= 2 and data[1] > 0:
					var icon = create_effect_icon(effect)
					if icon:
						container.add_child(icon)

func create_effect_icon(effect: int) -> TextureRect:
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var atlas = AtlasTexture.new()
	atlas.atlas = load(EFFECT_ATLAS_PATH)
	var x = (effect % EFFECT_COLS) * EFFECT_TILE_SIZE
	var y = floori(effect / EFFECT_COLS) * EFFECT_TILE_SIZE
	atlas.region = Rect2(x, y, EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
	icon.texture = atlas
	return icon

func apply_damage_over_time():
	for actor in initiative:
		if not is_instance_valid(actor): continue

		# Poison damage
		var poison_level = get_effect_level(actor, Global.effect.Poison)
		if poison_level > 0:
			var poison_dmg = floor(actor.max_stats["hp"] * 0.1 * poison_level)
			actor.hp -= poison_dmg
			$Control/enemy_ui/CenterContainer/output.text = actor.name + " takes " + str(poison_dmg) + " poison damage!"
			await get_tree().create_timer(0.5).timeout

		# Bleed damage (stronger, not healable by items)
		var bleed_level = get_effect_level(actor, Global.effect.Bleed)
		if bleed_level > 0:
			var bleed_dmg = floor(actor.max_stats["hp"] * 0.15 * bleed_level)
			actor.hp -= bleed_dmg
			$Control/enemy_ui/CenterContainer/output.text = actor.name + " takes " + str(bleed_dmg) + " bleed damage!"
			await get_tree().create_timer(0.5).timeout

func check_instakill(attacker: Object, target: Object) -> bool:
	var kill_level = get_effect_level(attacker, Global.effect.Kill)
	if kill_level > 0:
		if target is Enemy and target.is_boss:
			return false
		var kill_chance = 0.01 * kill_level  # 1% per level
		if randf() < kill_chance:
			return true
	return false

func get_effect_name_with_level(effect: Global.effect, level: int) -> String:
	var names = {
		Global.effect.Blind: "Blind",
		Global.effect.Poison: "Poison",
		Global.effect.Bleed: "Bleed",
		Global.effect.Power: "Power",
		Global.effect.Tough: "Tough",
		Global.effect.Speed: "Speed",
		Global.effect.Focus: "Focus",
		Global.effect.Defend: "Defend",
		Global.effect.Kill: "Kill",
		Global.effect.Absorption: "Absorption",
		Global.effect.Revive: "Revive",
		Global.effect.Sick: "Sick",
		Global.effect.Weak: "Weak",
		Global.effect.Slow: "Slow",
		Global.effect.Sleep: "Sleep"
	}
	var base_name = names.get(effect, "Unknown")
	if level > 1:
		var roman = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
		if level <= 10:
			base_name += " " + roman[level]
		else:
			base_name += " " + str(level)
	return base_name

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

func open_skills_menu():
	state = states.OnSkills
	skills_container.visible = true
	$Control/gui/HBoxContainer2/party.visible = false
	$WhoMoves.visible = false
	
	available_skills.clear()
	skill_affordable.clear()
	
	# Add ALL party member's skills (show all, gray out unaffordable)
	if current_attacker is Party and current_attacker.skills:
		var levels = current_attacker.skills.keys()
		levels.sort()
		
		for level in levels:
			var skill = current_attacker.skills[level]
			if skill and current_attacker.level >= level:
				available_skills.append(skill)
				skill_affordable.append(current_attacker.mp >= skill.mana_cost)
	
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
			box.set_collisions(true)
		else:
			# Keep affordable skills white, unaffordable gray
			box.modulate = Color(1, 1, 1) if affordable else Color(0.5, 0.5, 0.5)
			box.set_collisions(false)
	
	# Handle scrolling
	if current_skill_index >= skill_scroll_offset + max_visible_skills:
		skill_scroll_offset = current_skill_index - max_visible_skills + 1
	elif current_skill_index < skill_scroll_offset:
		skill_scroll_offset = current_skill_index
	
	var scroll = skills_container.get_node("ScrollContainer")
	scroll.scroll_vertical = skill_scroll_offset * 70

func navigate_skills(direction: int):
	var columns = 2  # Must match grid.columns
	var new_index = current_skill_index + direction
	
	# Loop around if needed
	if new_index < 0:
		new_index = skill_boxes.size() - 1
	elif new_index >= skill_boxes.size():
		new_index = 0
	
	# Skip unaffordable skills when navigating
	var attempts = 0
	while attempts < skill_boxes.size():
		if skill_affordable[new_index]:
			break
		new_index += direction
		if new_index < 0:
			new_index = skill_boxes.size() - 1
		elif new_index >= skill_boxes.size():
			new_index = 0
		attempts += 1
	
	# Only update if we found an affordable skill
	if skill_affordable[new_index]:
		current_skill_index = new_index
		update_skill_selection()

func check_skill_overlap():
	var overlapping = $TheMove/Area2D.get_overlapping_areas()
	for area in overlapping:
		var parent = area.get_parent()
		if parent is SkillBox:
			var new_index = parent.skill_index
			if skill_affordable[new_index] and new_index != current_skill_index:
				current_skill_index = new_index
				update_skill_selection()
			return

func select_skill():
	if current_skill_index < 0 or current_skill_index >= available_skills.size():
		return
	
	if not skill_affordable[current_skill_index]:
		$Control/enemy_ui/CenterContainer/output.text = "Not enough MP!"
		await get_tree().create_timer(0.5).timeout
		return
	
	var skill = available_skills[current_skill_index]
	
	if skill.mana_cost > current_attacker.mp:
		$Control/enemy_ui/CenterContainer/output.text = "Not enough MP!"
		await get_tree().create_timer(0.5).timeout
		return
	
	if skill.target_type == 0:
		state = states.OnSkillSelect
		selected_enemy = previous_enemy if previous_enemy != 0 else 1
		$Control/enemy_ui/CenterContainer/output.text = "Select target..."
		return
	elif skill.target_type == 1:
		add_attack(current_attacker, [current_attacker], skill)
		action_planner.action_history.append(current_attacker)
		close_skills_menu()
		advance_planning()
	elif skill.target_type == 2:
		add_attack(current_attacker, party.duplicate(), skill)
		action_planner.action_history.append(current_attacker)
		close_skills_menu()
		advance_planning()
	elif skill.target_type == 3:
		state = states.OnSkillSelect
		selected_enemy = previous_enemy if previous_enemy != 0 else 1
		$Control/enemy_ui/CenterContainer/output.text = "Select ally..."

func confirm_skill_target():
	var skill = available_skills[current_skill_index]
	if skill.target_type == 0:
		add_attack(current_attacker, [battle.get('enemy_pos'+str(selected_enemy))], skill)
		action_planner.action_history.append(current_attacker)
		close_skills_menu()
		advance_planning()
	elif skill.target_type == 3:
		var target = party[clamp(selected_enemy - 1, 0, party.size() - 1)]
		add_attack(current_attacker, [target], skill)
		action_planner.action_history.append(current_attacker)
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
			
			saved_party_plan_index = action_planner.current_party_plan_index
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
				action_planner.action_history.append(current_attacker)
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
			
			action_planner.action_history.append(current_attacker)
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
	action_planner.action_history.append(current_attacker)
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
