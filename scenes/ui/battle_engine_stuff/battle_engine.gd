extends Node2D
class_name BattleEngine

@export var battle: Battle
var party: Array[Object] = PlayerStats.party
var initiative: Array[Entity]
var enemy_instances: Array[Entity] = []  
var enemies_by_slot: Array[Entity] = []  

enum states { OnAction, OnEnemy, OnSkills, OnSkillSelect, OnItems, OnItemSelect, Waiting, OnRun}
var state: states = states.OnAction

# Managers
var item_manager: ItemManager
var skill_manager: SkillManager
var effect_manager: EffectManager
var death_manager: DeathManager
var log_manager: LogManager
var attack_executor: AttackExecutor

var planning_phase: bool = true
var action_history: Array[Entity] = []
var current_attacker: Entity
var current_party_plan_index: int = 0
var selected_enemy: int = 0  
var previous_enemy: int = 0
var initiative_who: int = -1

# === SETUP ===
func _ready() -> void:
	battle = Global.battle_current.duplicate(true)
	Global.battle_ref = self
	
	setup_enemies()
	initiative = setup_initiative()
	setup_party()
	_setup_managers()
	setup_current_attacker()
	_setup_battle_log_label()
	if battle.music:
		$AudioStreamPlayer.stream = battle.music
		$AudioStreamPlayer.play()
	if battle.background:
		$Control/enemy_ui/bg.texture = battle.background

func _setup_managers():
	print("battle_engine.gd: _setup_managers: START")
	effect_manager = EffectManager.new()
	print("battle_engine.gd: _setup_managers: created EffectManager, initializing with party_count=%d, enemy_count=%d" % [party.size(), enemy_instances.size()])
	effect_manager.initialize(party, enemy_instances)
	effect_manager.status_applied.connect(_on_status_applied)
	print("battle_engine.gd: _setup_managers: connected status_applied signal to _on_status_applied")
	
	item_manager = ItemManager.new()
	print("battle_engine.gd: _setup_managers: created ItemManager")
	item_manager.setup_items_ui(self)
	
	skill_manager = SkillManager.new()
	print("battle_engine.gd: _setup_managers: created SkillManager")
	skill_manager.setup_skills_ui(self)
	
	death_manager = DeathManager.new()
	print("battle_engine.gd: _setup_managers: created DeathManager")
	death_manager.setup(self, battle)
	
	log_manager = LogManager.new()
	print("battle_engine.gd: _setup_managers: created LogManager")
	log_manager.setup(self, effect_manager)
	
	attack_executor = AttackExecutor.new()
	print("battle_engine.gd: _setup_managers: created AttackExecutor")
	attack_executor.setup(self, death_manager, effect_manager, log_manager, battle)
	print("battle_engine.gd: _setup_managers: END - all managers initialized")
	
func _on_status_applied(entity: Entity, status_id: String, stacks: int) -> void:
	print("battle_engine.gd: _on_status_applied: entity=%s, status_id=%s, stacks=%d" % [entity.name if entity else "null", status_id, stacks])
	# Update UI for both party and enemies
	_update_all_battle_faces()

func _update_all_battle_faces() -> void:
	print("battle_engine.gd: _update_all_battle_faces: updating all party and enemy UIs")
	# Update party faces
	var party_container = $Control/gui/HBoxContainer2/party
	if party_container:
		for i in range(party_container.get_child_count()):
			var ui = party_container.get_child(i)
			if ui.has_method("update_effects_ui"):
				ui.update_effects_ui()
				print("battle_engine.gd: _update_all_battle_faces: updated party face %d" % i)
	# Update enemy faces
	var enemy_container = $Control/enemy_ui/enemies
	if enemy_container:
		for i in range(enemy_container.get_child_count()):
			var ui = enemy_container.get_child(i)
			if ui.has_method("update_effects_ui"):
				ui.update_effects_ui()
				print("battle_engine.gd: _update_all_battle_faces: updated enemy face %d" % i)
								
func setup_enemies():
	enemy_instances.clear()
	enemies_by_slot.clear()
	enemies_by_slot.resize(5)
	for i in range(5):
		enemies_by_slot[i] = null

	for e in battle.enemies:
		var path = "Control/enemy_ui/enemies/enemy" + str(e.position_index+1)
		var node = get_node_or_null(path)
		
		var enemy = e.enemy.duplicate_deep()
		enemies_by_slot[e.position_index] = enemy
		var prog = node.get_node_or_null("ProgressBar")
		if prog: prog.visible = true
		node.texture = enemy.portrait
		node.enemy = enemy
		
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
		enemy_instances.append(enemy)
		

func setup_initiative() -> Array[Entity]:
	var speed: Dictionary[int, Entity] = {}
	for e in enemy_instances:
		if e and e.hp > 0:
			var rng = randi_range(ceili(e.base_stats[&"speed"] * 0.75), floori(e.base_stats[&"speed"] * 1.25))
			while rng in speed: rng += 1
			speed[rng] = e
	for p in party:
		var spd = p.base_stats[&"speed"] if p.base_stats.has(&"speed") else p.base_stats.get(&"speed", 10)
		var speed_mult = _get_status_multiplier(p, "speed", 0.15)
		var slow_mult = _get_status_multiplier(p, "slow", -0.15)
		var total_mult = speed_mult * slow_mult
		var rng = randi_range(ceili(spd * total_mult * 0.75), floori(spd * total_mult * 1.25))
		while rng in speed: rng += 1
		speed[rng] = p
	var keys = speed.keys()
	keys.sort()
	var rev: Array[Entity] = []
	for k in range(keys.size()-1, -1, -1):
		rev.append(speed[keys[k]])
	return rev
	
func _get_status_multiplier(entity: Entity, status_id: String, per_stack_value: float) -> float:
	"""Helper to get status multiplier without relying on effect_manager."""
	if not entity.has_status(status_id):
		return 1.0
	var stacks = entity.get_status_stacks(status_id)
	return 1.0 + (float(stacks) * per_stack_value)

func setup_party():
	for p in initiative:
		if p in PlayerStats.party:
			var ui = preload("res://scenes/ui/battle_engine_stuff/partyBattleFace.tscn").instantiate()
			ui.setup(p)
			$Control/gui/HBoxContainer2/party.add_child(ui)
			
	
func setup_current_attacker():
	for o in initiative:
		if o.role == Entity.Role.PARTY:
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
	# Sync enemy HP with UI
	for e in range(len(battle.enemies)):
		var node = get_node("Control/enemy_ui/enemies/enemy" + str(battle.enemies[e].position_index+1))
		node.enemy = enemy_instances[e]
			

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return
	if death_manager.game_over_active:
		if death_manager.can_reload and (event.is_action_pressed("use") or event.is_action_pressed("menu") or event.is_action_pressed("lmb")):
			Global.reload_last_save()
			return
		return
	
	if state == states.Waiting:
		if event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	
	if death_manager.game_over_active: return
	if planning_phase and (event.is_action_pressed("back") or event.is_action_pressed("menu")) and event.is_pressed():
		match state:
			states.OnSkills: skill_manager.close_skills_menu()
			states.OnSkillSelect: state = states.OnSkills
			states.OnItems: item_manager.close_items_menu()
			states.OnItemSelect: state = states.OnItems
			_: undo_last_action()
		get_viewport().set_input_as_handled()
		return
	
	if not event.is_pressed() or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		return
	
	if state == states.OnSkills:
			if death_manager.game_over_active: return
			if event.is_action_pressed("down"):
				get_viewport().set_input_as_handled()
				skill_manager.navigate_skills(-2)
			elif event.is_action_pressed("up"):
				get_viewport().set_input_as_handled()
				skill_manager.navigate_skills(2)
			elif event.is_action_pressed("right"):
				get_viewport().set_input_as_handled()
				skill_manager.navigate_skills(1)
			elif event.is_action_pressed("left"):
				get_viewport().set_input_as_handled()
				skill_manager.navigate_skills(-1)
			elif event.is_action_pressed("use"):
				get_viewport().set_input_as_handled()
				skill_manager.select_skill()
		
	elif state == states.OnSkillSelect:
			if death_manager.game_over_active: return
			if event.is_action_pressed("left"):
				get_viewport().set_input_as_handled()
				move_enemy_input(-1)
			elif event.is_action_pressed("right"):
				get_viewport().set_input_as_handled()
				move_enemy_input(1)
			elif event.is_action_pressed("use"):
				get_viewport().set_input_as_handled()
				skill_manager.confirm_skill_target()
		
	elif state == states.OnItems:
			if death_manager.game_over_active: return
			if event.is_action_pressed("down"):
				get_viewport().set_input_as_handled()
				item_manager.navigate_items(2)
			elif event.is_action_pressed("up"):
				get_viewport().set_input_as_handled()
				item_manager.navigate_items(-2)
			elif event.is_action_pressed("right"):
				get_viewport().set_input_as_handled()
				item_manager.navigate_items(1)
			elif event.is_action_pressed("left"):
				get_viewport().set_input_as_handled()
				item_manager.navigate_items(-1)
			elif event.is_action_pressed("use"):
				get_viewport().set_input_as_handled()
				item_manager.select_item()
		
	elif state == states.OnItemSelect:
			if death_manager.game_over_active: return
			await item_manager.item_select_input(event)
		
	elif state == states.OnEnemy:
			if death_manager.game_over_active: return
			if event.is_action_pressed("left"):
				get_viewport().set_input_as_handled()
				move_enemy_input(-1)
			elif event.is_action_pressed("right"):
				get_viewport().set_input_as_handled()
				move_enemy_input(1)
			elif event.is_action_pressed("use"):
				get_viewport().set_input_as_handled()
				var target_enemy = null
				if selected_enemy >= 0 and selected_enemy < enemy_instances.size():
					target_enemy = get_enemy(selected_enemy)
				add_attack(current_attacker, [target_enemy], load("res://resources/attacks/attack.tres"))
				action_history.append(current_attacker)
				previous_enemy = selected_enemy
				selected_enemy = 0
				advance_planning()
		
	elif state == states.OnAction:
			if death_manager.game_over_active: return
			get_viewport().set_input_as_handled()
	if event.has_meta("_processed"): return
	event.set_meta("_processed", true)

func move_who_moves(index: int):
	$WhoMoves.visible = true
	$WhoMoves.position.x = 220 + (index * $WhoMoves.size.x)

func move_enemy_input(input: int):
	if input == 0 or battle.enemies.is_empty(): return
	var attempts = 0
	while attempts < 5:
		selected_enemy = wrapi(selected_enemy + input, 0, 5)
		var enemy_at_slot = get_enemy(selected_enemy)
		if enemy_at_slot != null and enemy_at_slot.hp > 0 and enemy_at_slot in initiative:
				break
		attempts += 1

func update_flash():
	for c in $Control/enemy_ui/enemies.get_children():
		if c.material:
			var slot_index = int(c.name.replace("enemy", "")) - 1
			var enemy_at_slot = get_enemy(slot_index)
			var is_flashing = enemy_at_slot != null and enemy_at_slot.hp > 0 and slot_index == selected_enemy
			c.material.set("shader_parameter/is_flashing", is_flashing)
			
func get_enemy_by_slot(slot_index: int) -> Entity:
	if slot_index >= 0 and slot_index < 5:
		return enemies_by_slot[slot_index]
	return null
		
func get_party_members_from_initiative() -> Array[Entity]:
	var party_members: Array[Entity] = []
	for actor in initiative:
		if actor.role == Entity.Role.PARTY:
			party_members.append(actor)
	return party_members

func update_party_ui():
	if death_manager.game_over_active: return
	var party_container = $Control/gui/HBoxContainer2/party
	if party_container:
		for i in range(party_container.get_child_count()):
			var ui = party_container.get_child(i)
			if ui.has_method("update_effects_ui"):
				ui.update_effects_ui()

func add_attack(attacker: Object, attacked: Array, attack: Skill):
	attack_executor.attack_array[attacker] = [attacked, attack]

func get_enemy(index: int) -> Entity:
	return get_enemy_by_slot(index)

func get_enemy_index(enemy: Entity) -> int:
	for i in range(5):
		if enemies_by_slot[i] == enemy:
			return i
	return -1

func get_alive_enemies() -> Array[Entity]:
	var alive: Array[Entity] = []
	for e in enemy_instances:
		if e and e.hp > 0:
			alive.append(e)
	return alive

func are_all_enemies_defeated() -> bool:
	for e in enemy_instances:
		if e and e.hp > 0:
			return false
	return true

func undo_last_action():
	if action_history.is_empty(): return
	var last = action_history.pop_back()
	if attack_executor.attack_array.has(last):
		var atk = attack_executor.attack_array[last][1]
		if atk.is_item_attack:
			var used_item = item_manager.item_ref
			PlayerStats.add_item(used_item, 1)  # Restore item                        
			if item_manager and item_manager.available_items.has(used_item):
				var idx = item_manager.available_items.find(used_item)
				if idx >= 0:
					item_manager.item_amounts[idx] += 1
		attack_executor.attack_array.erase(last)
	current_attacker = last
	state = states.OnAction
	current_party_plan_index = max(0, current_party_plan_index - 1)
	move_who_moves(current_party_plan_index)
	$Control/enemy_ui/CenterContainer/output.text = "Undid " + last.name + "'s move"

func advance_planning():
	if death_manager.game_over_active: return
	var start = (initiative_who + 1) % initiative.size() if initiative.size() > 0 else 0
	for i in range(initiative.size()):
		var idx = (start + i) % initiative.size()
		var actor = initiative[idx]
		if actor.role == Entity.Role.PARTY and not attack_executor.attack_array.has(actor) and not actor.hp <= 0:
			initiative_who = idx
			current_attacker = actor
			state = states.OnAction
			current_party_plan_index += 1
			move_who_moves(current_party_plan_index)
			return
	if are_all_enemies_defeated():
		await death_manager.check_enemy_death_and_xp()
		return
	else:
		death_manager.check_party_wipe()
	start_resolution_phase()

func start_resolution_phase():
	if death_manager.game_over_active: return
	planning_phase = false
	state = states.Waiting
	$WhoMoves.visible = false
	for actor in initiative:
		if actor.role == Entity.Role.ENEMY:
			add_enemy_attack(actor)
	initiative_who = -1
	await get_tree().create_timer(0.33 * Settings.battle_speed).timeout
	advance_initiative()

func advance_initiative():
	if death_manager.game_over_active: return
	if planning_phase:
		return
	initiative_who += 1
	if initiative_who >= initiative.size():
		initiative_who = -1
		await get_tree().process_frame
		await attack_executor.do_attacks()
		return
	var current = initiative[initiative_who]
	if current.has_status("sleep"):
		if attack_executor.attack_array.has(current):
			attack_executor.attack_array.erase(current)
		$Control/enemy_ui/CenterContainer/output.text = current.name + " is asleep!"
		await get_tree().create_timer(0.5 * Settings.battle_speed).timeout
		advance_initiative()
		return
	if not attack_executor.attack_array.has(current):
		advance_initiative()
		return
	if current.role == Entity.Role.PARTY:
		current_attacker = current
	advance_initiative()

func add_enemy_attack(e: Entity):
	if death_manager.game_over_active: return
	if not e or e.hp <= 0: return
	if e.skills.is_empty(): 
		# Use default attack if no attacks defined
		attack_executor.attack_array.merge({e: [[party[randi_range(0, party.size()-1)]], e.default_attack]})
		return
	
	# Collect all skills from all levels
	var all_skills: Array[Skill] = []
	for level_skills in e.skills.values():
		all_skills.append_array(level_skills)
	
	if all_skills.is_empty():
		attack_executor.attack_array.merge({e: [[party[randi_range(0, party.size()-1)]], e.default_attack]})
		return
	
	var atk: Skill = all_skills[randi_range(0, all_skills.size()-1)]
	var attempts = 0
	while atk.mana_cost > e.mp and attempts < 10:
		if randi_range(1, 2) == 1:
			atk = all_skills[randi_range(0, all_skills.size()-1)]
			attempts += 1
		else:
			atk = e.default_attack
	
	var prob: Array[int] = []
	var lowest = 0
	for i in range(party.size()):
		if party[i].hp > 0:
			prob.append(1)
			if party[i].hp < party[lowest].hp:
				lowest = i
			else:
				prob.append(0)

	var dumbness = [10, 4, 3, 3, 1]
	var ai_idx = clamp(e.ai_type as int, 0, dumbness.size()-1)
	var rng = randi_range(1, dumbness[ai_idx])
	if rng <= 2:
		prob[lowest] += 3 - rng
	else:
		var valid: Array[int] = []
		for i in range(prob.size()):
			if prob[i] > 0:
				valid.append(i)
			if not valid.is_empty():
				prob[valid[randi_range(0, valid.size()-1)]] += 1
				
	for i in range(party.size()):
		if party[i].has_status("focus"):
			prob[i] += 5 if e.ai_type != Entity.AIType.INTELLIGENT else 1

	var target = null
	if atk.target_type == 0: # SingleEnemy - target a party member
		var total = 0
		for p in prob:
			total += p
			if total == 0:
				# Fallback: pick any alive party member
				var alive_party = party.filter(func(pa): return pa and pa.hp > 0)
				if not alive_party.is_empty():
					target = [alive_party[randi_range(0, alive_party.size()-1)]]
				else:
					return
			else:
				var rng2 = randi_range(1, total)
				for i in range(prob.size()):
					rng2 -= prob[i]
					if rng2 <= 0 and prob[i] > 0:
						target = [party[i % party.size()]]
						break
	if target:
		add_attack(e, target, atk)
	elif atk.target_type == 1: #Self
		add_attack(e, [e], atk)
	elif atk.target_type == 2: #AllAllies (for enemy, this means other enemies)
		var valid_allies: Array[Entity] = []
		for ally in enemy_instances:
			if ally and ally != e and ally.hp > 0:
				valid_allies.append(ally)
			if not valid_allies.is_empty():
				add_attack(e, valid_allies, atk)
			else:
				add_attack(e, [e], atk)
	elif atk.target_type == 3: #AllEnemies (for enemy, this means the player's party)
		add_attack(e, party.filter(func(p): return p and p.hp > 0), atk)
	elif atk.target_type == 4: #RandomEnemy (for enemy, this means random party member)
		var valid_party: Array[Entity] = []
		for p in party:
			if p and p.hp > 0:
				valid_party.append(p)
				if not valid_party.is_empty():
					add_attack(e, [valid_party[randi_range(0, valid_party.size()-1)]], atk)
				else:
					add_attack(e, [party[randi_range(0, party.size()-1)]], atk)
	elif atk.target_type == 5: #SingleAlly (for enemy, this means another enemy)
		var valid_allies: Array[Entity] = []
		for ally in enemy_instances:
			if ally and ally != e and ally.hp > 0:
				valid_allies.append(ally)
			if not valid_allies.is_empty():
				add_attack(e, [valid_allies[randi_range(0, valid_allies.size()-1)]], atk)
			else:
				add_attack(e, [e], atk)

func start_round():
	if death_manager.game_over_active: return
	effect_manager.tick_all_statuses()
	attack_executor.attack_array.clear()
	action_history.clear()
	planning_phase = true
	initiative_who = -1
	current_party_plan_index = -1
	state = states.OnAction
	$WhoMoves.visible = false
	$Control/enemy_ui/CenterContainer/output.text = ""
	advance_planning()

# === BATTLE BUTTON LOGIC ===

func _on_fight_button_pressed() -> void:
	state = states.OnEnemy
	selected_enemy = previous_enemy if previous_enemy >= 0 and previous_enemy < enemy_instances.size() else 0

func _on_skills_button_pressed() -> void:
	skill_manager.open_skills_menu()
	
func _on_defend_button_pressed() -> void:
	var defend_skill = load("res://resources/attacks/defend.tres")
	add_attack(current_attacker, [current_attacker], defend_skill)
	action_history.append(current_attacker)
	advance_planning() 

func _on_item_button_pressed() -> void:
	if not battle.can_use_items:
		$Control/enemy_ui/CenterContainer/output.text = "Items are disabled in this battle!"
		await get_tree().create_timer(0.5 * Settings.battle_speed).timeout
		return

	item_manager.open_items_menu()

func _on_run_button_pressed() -> void:
	if not battle.can_flee:
		$Control/enemy_ui/CenterContainer/output.text = "Cannot flee from this battle!"
		await get_tree().create_timer(0.5 * Settings.battle_speed).timeout
		return

	var counter = 0
	for e in enemy_instances:
		counter += e.speed if e.hp > 0 else 0
	var chance = 0
	for p in party: 
		chance += p.base_stats[&"speed"] if p.base_stats.has(&"speed") else p.base_stats.get(&"speed", 10)
	var diff = clampf(counter - chance + 10, 0, 30)
	if randi_range(1, 20) > diff:
		Global.loading = true
		get_tree().change_scene_to_file(Global.current_scene)
		Global.loading = false
	else:
		$Control/enemy_ui/CenterContainer/output.text = "Couldn't escape!"
		await get_tree().create_timer(0.5 * Settings.battle_speed).timeout
		for e in enemy_instances:
			if e.hp > 0:
				add_enemy_attack(e)
		await attack_executor.do_attacks()
