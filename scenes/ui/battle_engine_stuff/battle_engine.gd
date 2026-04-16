extends Node2D
class_name BattleEngine

@export var battle: Battle
var party: Array = Global.party
var battle_start_position: Vector2 = Vector2.ZERO
var initiative: Array[Object]
var enemy_instances: Array[Enemy] = []  # Runtime enemy instances from BattleEnemySlot

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
var action_history: Array[Object] = []
var current_attacker: Object
var current_party_plan_index: int = 0
var selected_enemy: int = 0  # Index into enemy_instances array
var previous_enemy: int = 0
var initiative_who: int = -1

# === SETUP ===
func _ready() -> void:
	battle_start_position = Global.player_position
	battle = Global.battle_current.duplicate(true)
	Global.battle_ref = self
	
	_setup_managers()
	setup_enemies()
	initiative = setup_initiative()
	setup_party()
	setup_current_attacker()
	death_manager.setup_game_over_ui()
	_setup_battle_log_label()
	if battle.music:
		$AudioStreamPlayer.stream = battle.music

func _setup_managers():
	effect_manager = EffectManager.new()
	effect_manager.setup(self)
	
	item_manager = ItemManager.new()
	item_manager.setup_items_ui(self)
	
	skill_manager = SkillManager.new()
	skill_manager.setup_skills_ui(self)
	
	death_manager = DeathManager.new()
	death_manager.setup(self, battle)
	
	log_manager = LogManager.new()
	log_manager.setup(self, effect_manager)
	
	attack_executor = AttackExecutor.new()
	attack_executor.setup(self, death_manager, effect_manager, log_manager, battle)

func setup_enemies():
	# Clear and populate enemy_instances from BattleEnemySlot array
	enemy_instances.clear()
	for slot in battle.enemies:
		if slot and slot.enemy:
			var enemy_copy = slot.enemy.duplicate_deep_custom()
			enemy_instances.append(enemy_copy)
	
	# Setup UI for up to 5 enemies (legacy compatibility)
	for e in range(5):
		var path = "Control/enemy_ui/enemies/enemy" + str(e+1)
		var node = get_node_or_null(path)
		
		if e < enemy_instances.size():
			var enemy = enemy_instances[e]
			var prog = node.get_node_or_null("ProgressBar")
			if prog: prog.visible = true
			node.texture = enemy.sprite
			node.hp = enemy.hp
			node.max_hp = enemy.max_hp
			
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
			var prog = node.get_node_or_null("ProgressBar") if node else null
			if prog: prog.visible = false
			if node: node.texture = null

func setup_initiative() -> Array[Object]:
	var speed: Dictionary[int, Object] = {}
	# Add enemies to initiative
	for e in enemy_instances:
		if e and e.hp > 0:
			var speed_mult = effect_manager.get_effect_multiplier(e, BattleEffect.StatusEffect.Speed)
			var slow_mult = effect_manager.get_effect_multiplier(e, BattleEffect.StatusEffect.Slow)
			var total_mult = speed_mult * slow_mult
			var rng = randi_range(ceili(e.speed * 0.75 * total_mult), floori(e.speed * 1.25 * total_mult))
			while rng in speed: rng += 1
			speed[rng] = e
	# Add party members to initiative
	for p in party:
		var ai = p.max_stats["ai"] if p.max_stats.has("ai") else p.base_stats.get("speed", 10)
		var speed_mult = effect_manager.get_effect_multiplier(p, BattleEffect.StatusEffect.Speed)
		var slow_mult = effect_manager.get_effect_multiplier(p, BattleEffect.StatusEffect.Slow)
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
	# Sync enemy HP with UI
	for e in range(enemy_instances.size()):
		if e < 5:  # Only update first 5 for UI compatibility
			var node = get_node_or_null("Control/enemy_ui/enemies/enemy"+str(e+1))
			if node and e < enemy_instances.size():
				node.hp = max(0, enemy_instances[e].hp)
	
	if not log_manager.battle_log.is_empty():
		log_manager.log_timer += delta
		if log_manager.log_timer >= log_manager.log_display_time:
			log_manager.log_timer = 0.0
			log_manager.remove_oldest_log_entry()

func _input(event: InputEvent) -> void:
	if event.is_echo(): return
	if death_manager.game_over_active:
		if death_manager.can_reload and event.is_action_pressed("use") or event.is_action_pressed("menu"):
			get_viewport().set_input_as_handled()
			Global.reload_last_save()
		return
	
	if state == states.Waiting:
		if event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	
	if planning_phase and (event.is_action_pressed("ui_undo") or event.is_action_pressed("ui_cancel")) and event.is_pressed():
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
			elif event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				skill_manager.close_skills_menu()
		
	elif state == states.OnSkillSelect:
			if event.is_action_pressed("left"):
				get_viewport().set_input_as_handled()
				move_enemy_input(-1)
			elif event.is_action_pressed("right"):
				get_viewport().set_input_as_handled()
				move_enemy_input(1)
			elif event.is_action_pressed("use"):
				get_viewport().set_input_as_handled()
				skill_manager.confirm_skill_target()
			elif event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				skill_manager.close_skills_menu()
		
	elif state == states.OnItems:
			if event.is_action_pressed("down"):
				get_viewport().set_input_as_handled()
				item_manager.navigate_items(-2)
			elif event.is_action_pressed("up"):
				get_viewport().set_input_as_handled()
				item_manager.navigate_items(2)
			elif event.is_action_pressed("right"):
				get_viewport().set_input_as_handled()
				item_manager.navigate_items(1)
			elif event.is_action_pressed("left"):
				get_viewport().set_input_as_handled()
				item_manager.navigate_items(-1)
			elif event.is_action_pressed("use"):
				get_viewport().set_input_as_handled()
				item_manager.select_item()
			elif event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				item_manager.close_items_menu()
		
	elif state == states.OnItemSelect:
			if event.is_action_pressed("use") or event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
			item_manager.item_select_input(event)
		
	elif state == states.OnEnemy:
			if event.is_action_pressed("left"):
				get_viewport().set_input_as_handled()
				move_enemy_input(-1)
			elif event.is_action_pressed("right"):
				get_viewport().set_input_as_handled()
				move_enemy_input(1)
			elif event.is_action_pressed("use"):
				get_viewport().set_input_as_handled()
				# Use enemy_instances array instead of battle.enemy_pos
				var target_enemy = null
				if selected_enemy >= 0 and selected_enemy < enemy_instances.size():
					target_enemy = enemy_instances[selected_enemy]
				add_attack(current_attacker, [target_enemy], load("res://resources/attacks/attack.tres"))
				action_history.append(current_attacker)
				previous_enemy = selected_enemy
				selected_enemy = 0
				advance_planning()
		
	elif state == states.OnAction:
			get_viewport().set_input_as_handled()
	if event.has_meta("_processed"): return
	event.set_meta("_processed", true)

func move_who_moves(index: int):
	$WhoMoves.visible = true
	$WhoMoves.position.x = 220 + (index * $WhoMoves.size.x)

func move_enemy_input(input: int):
	if input == 0 or enemy_instances.is_empty(): return
	# Find next valid enemy in initiative
	var attempts = 0
	while attempts < enemy_instances.size():
		selected_enemy = wrapi(selected_enemy + input, 0, enemy_instances.size())
		if selected_enemy < enemy_instances.size() and enemy_instances[selected_enemy] in initiative and enemy_instances[selected_enemy].hp > 0:
			break
		attempts += 1

func update_flash():
	for c in $Control/enemy_ui/enemies.get_children():
		if c.material:
			var enemy_index = int(c.name.replace("enemy", "")) - 1
			c.material.set("shader_parameter/is_flashing", enemy_index == selected_enemy and enemy_index < enemy_instances.size())

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
	attack_executor.attack_array[attacker] = [attacked, attack]

func get_enemy(index: int) -> Enemy:
	if index >= 0 and index < enemy_instances.size():
		return enemy_instances[index]
	return null

func get_enemy_index(enemy: Enemy) -> int:
	for i in range(enemy_instances.size()):
		if enemy_instances[i] == enemy:
			return i
	return -1

func get_alive_enemies() -> Array[Enemy]:
	var alive: Array[Enemy] = []
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
		if atk.attack_type == 3 and atk.item_reference:
			var used_item = atk.item_reference
			Global.add_item(used_item, 1)  # Restore item
		attack_executor.attack_array.erase(last)
	current_attacker = last
	state = states.OnAction
	current_party_plan_index = max(0, current_party_plan_index - 1)
	move_who_moves(current_party_plan_index)
	$Control/enemy_ui/CenterContainer/output.text = "Undid " + last.name + "'s move"

func advance_planning():
	var start = (initiative_who + 1) % initiative.size() if initiative.size() > 0 else 0
	for i in range(initiative.size()):
		var idx = (start + i) % initiative.size()
		var actor = initiative[idx]
		if actor is Party and not attack_executor.attack_array.has(actor):
			initiative_who = idx
			current_attacker = actor
			state = states.OnAction
			current_party_plan_index += 1
			move_who_moves(current_party_plan_index)
			return
	# Check if all enemies are defeated before starting resolution
	if are_all_enemies_defeated():
		death_manager.check_victory()
		return
	start_resolution_phase()

func start_resolution_phase():
	planning_phase = false
	state = states.Waiting
	$WhoMoves.visible = false
	for actor in initiative:
		if actor is Enemy:
			add_enemy_attack(actor)
	initiative_who = -1
	await get_tree().create_timer(0.4).timeout
	advance_initiative()

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
	if effect_manager.get_effect_duration(current, BattleEffect.StatusEffect.Sleep) > 0:
		if attack_executor.attack_array.has(current):
			attack_executor.attack_array.erase(current)
		$Control/enemy_ui/CenterContainer/output.text = current.name + " is asleep!"
		await get_tree().create_timer(0.5).timeout
		advance_initiative()
		return
	if not attack_executor.attack_array.has(current):
		advance_initiative()
		return
	if current is Party:
		current_attacker = current
	advance_initiative()

func add_enemy_attack(e: Enemy):
	if not e or e.hp <= 0: return
	if e.attacks.is_empty(): 
		# Use default attack if no attacks defined
		var default_atk = Skill.new()
		default_atk.skill_name = "Attack"
		default_atk.attack_type = 0
		default_atk.target_type = 0
		default_atk.accuracy = 1.0
		attack_executor.attack_array[e] = [[party[randi_range(0, party.size()-1)]], default_atk]
		return
	
	var atk: Skill = e.attacks[randi_range(0, e.attacks.size()-1)]
	# Find affordable attack
	var attempts = 0
	while atk.mana_cost > e.mp and attempts < 10:
		atk = e.attacks[randi_range(0, e.attacks.size()-1)]
		attempts += 1
	
	var prob: Array[int] = []
	var lowest = 0
	for i in range(party.size()):
		prob.append(1 if party[i].hp > 0 else 0)
		if party[i].hp > 0 and party[i].hp < party[lowest].hp: 
			lowest = i
	
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
		if BattleEffect.StatusEffect.Focus in party[i].effects:
			prob[i] += 5 if e.ai_type != Enemy.AI.Intelligent else 1
	
	var target = null
	if atk.target_type == 0:  # SingleEnemy
		var total = 0
		for p in prob: 
			total += p
		if total == 0: 
			return
		var rng2 = randi_range(1, total)
		for i in range(prob.size()):
			rng2 -= prob[i]
			if rng2 <= 0 and prob[i] > 0:
				target = [party[i]]
				break
	elif atk.target_type == 2:  # Party
		target = party.filter(func(p): return p.hp > 0)
	
	if target and not target.is_empty(): 
		attack_executor.attack_array[e] = [target, atk]

func start_round():
	effect_manager.update_effects() 
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
	var defend_skill = Skill.new()
	defend_skill.skill_name = "Defend"
	defend_skill.attack_type = 1  # Buff
	defend_skill.target_type = 1  # Self
	defend_skill.on_use_effects.resize(1)
	var defend_effect = BattleEffect.new()
	defend_effect.effect_type = BattleEffect.EffectType.ADD_STATUS
	defend_effect.status_effect = BattleEffect.StatusEffect.Defend
	defend_effect.status_level = 1
	defend_effect.status_duration = 1
	defend_skill.on_use_effects[0] = defend_effect
	add_attack(current_attacker, [current_attacker], defend_skill)
	action_history.append(current_attacker)
	advance_planning() 

func _on_item_button_pressed() -> void:
	item_manager.open_items_menu()
	
func _on_run_button_pressed() -> void:
	var counter = 0
	for e in enemy_instances:
		counter += e.speed if e.hp > 0 else 0
	var chance = 0
	for p in party: 
		chance += p.max_stats["ai"] if p.max_stats.has("ai") else p.base_stats.get("speed", 10)
	var diff = clampf(counter - chance + 10, 0, 30)
	if randi_range(1, 20) > diff:
		Global.player_position = battle_start_position
		Global.loading = true
		get_tree().change_scene_to_file(Global.current_scene)
		Global.loading = false
	else:
		$Control/enemy_ui/CenterContainer/output.text = "Couldn't escape!"
		await get_tree().create_timer(0.5).timeout
		for e in enemy_instances:
			if e.hp > 0:
				add_enemy_attack(e)
		await attack_executor.do_attacks()
