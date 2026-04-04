extends Node2D
class_name BattleEngine

@export var battle: Battle
var party: Array = Global.party
var battle_start_position: Vector2 = Vector2.ZERO
var initiative: Array[Object]

enum states { OnAction, OnEnemy, OnSkills, OnSkillSelect, OnItems, OnItemSelect, Waiting, OnRun}
var state: states = states.OnAction

# Managers
var item_manager: ItemManager
var skill_manager: SkillManager
var effect_manager: EffectManager
var action_selector: BattleActionSelector
var selection_manager: BattleSelectionManager

var planning_phase: bool = true
var action_history: Array[Object] = []
var current_attacker: Object
var attack_array: Dictionary = {}
var current_party_plan_index: int = 0
var selected_enemy: int = 1
var previous_enemy: int = 1
var initiative_who: int = -1
var is_animating_death: bool = false

var game_over_active: bool = false
var game_over_overlay: ColorRect
var game_over_texture: TextureRect
var can_reload = false

var battle_log: Array[String] = []
var max_log_entries: int = 6
var log_display_time: float = 8.0
var log_timer: float = 0.0


# === SETUP ===
func _ready() -> void:
	battle_start_position = Global.player_position
	_setup_managers()
	
	await get_tree().create_timer(0.02).timeout
	battle = Global.battle_current.duplicate(true)
	Global.battle_ref = self
	await get_tree().create_timer(0.05).timeout
	
	setup_enemies()
	initiative = setup_initiative()
	setup_party()
	setup_current_attacker()
	_setup_game_over_ui()
	_setup_battle_log_label()
	if battle.music_override:
		$AudioStreamPlayer.stream = battle.music_override

func _setup_managers():
	item_manager = ItemManager.new()
	item_manager.setup_items_ui(self)
	
	skill_manager = SkillManager.new()
	skill_manager.setup_skills_ui(self)
	
	action_selector = BattleActionSelector.new()
	add_child(action_selector)
	action_selector.setup(self, 
		$Control/gui/HBoxContainer2/actions/FightButton/fight,
		$Control/gui/HBoxContainer2/actions/SkillsButton/skills,
		$Control/gui/HBoxContainer2/actions/DefendButton/defend,
		$Control/gui/HBoxContainer2/actions/ItemButton/item,
		$Control/gui/HBoxContainer2/actions/RunButton/run
	)
	
	selection_manager = BattleSelectionManager.new()
	add_child(selection_manager)
	selection_manager.setup(self, action_selector, skill_manager, item_manager)

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
			var speed_mult = effect_manager.get_effect_multiplier(battle.get('enemy_pos'+str(e+1)), Global.effect.Speed)
			var slow_mult = effect_manager.get_effect_multiplier(battle.get('enemy_pos'+str(e+1)), Global.effect.Slow)
			var total_mult = speed_mult * slow_mult
			var rng = randi_range(ceili(ai * 0.75 * total_mult), floori(ai * 1.25 * total_mult))
			while rng in speed: rng += 1
			speed[rng] = battle.get('enemy_pos'+str(e+1))
	for p in party:
		var ai = p.max_stats["ai"]
		var speed_mult = effect_manager.get_effect_multiplier(p, Global.effect.Speed)
		var slow_mult = effect_manager.get_effect_multiplier(p, Global.effect.Slow)
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
		skill_manager.check_skill_overlap()
	if state == states.OnItems or state == states.OnItemSelect:
		item_manager.check_item_overlap()
	
	if not battle_log.is_empty():
		log_timer += delta
		if log_timer >= log_display_time:
			log_timer = 0.0
			remove_oldest_log_entry()

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
			skill_manager.close_skills_menu()
			get_viewport().set_input_as_handled()
			return
		elif state == states.OnItems or state == states.OnItemSelect:
			item_manager.close_items_menu()
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
				selection_manager.navigate(1)
			elif event.is_action_pressed("up"):
				selection_manager.navigate(-1)
			elif event.is_action_pressed("use"):
				selection_manager.confirm_selection()
			if get_viewport():
				get_viewport().set_input_as_handled()
		
		states.OnSkills:
			if event.is_action_pressed("down"):
				selection_manager.switch_selection_type(BattleSelectionManager.SelectionType.SKILLS)
				selection_manager.navigate(2)
			elif event.is_action_pressed("up"):
				selection_manager.switch_selection_type(BattleSelectionManager.SelectionType.SKILLS)
				selection_manager.navigate(-2)
			elif event.is_action_pressed("right"):
				selection_manager.switch_selection_type(BattleSelectionManager.SelectionType.SKILLS)
				selection_manager.navigate(1)
			elif event.is_action_pressed("left"):
				selection_manager.switch_selection_type(BattleSelectionManager.SelectionType.SKILLS)
				selection_manager.navigate(-1)
			elif event.is_action_pressed("use"):
				skill_manager.select_skill()
			elif event.is_action_pressed("ui_cancel"):
				skill_manager.close_skills_menu()
			if get_viewport():
				get_viewport().set_input_as_handled()
		
		states.OnSkillSelect:
			if event.is_action_pressed("left"):
				move_enemy_input(-1)
			elif event.is_action_pressed("right"):
				move_enemy_input(1)
			elif event.is_action_pressed("use"):
				skill_manager.confirm_skill_target()
			elif event.is_action_pressed("ui_cancel"):
				skill_manager.close_skills_menu()
			if get_viewport():
				get_viewport().set_input_as_handled()
		
		states.OnItems:
			if event.is_action_pressed("down"):
				selection_manager.switch_selection_type(BattleSelectionManager.SelectionType.ITEMS)
				selection_manager.navigate(2)  
			elif event.is_action_pressed("up"):
				selection_manager.switch_selection_type(BattleSelectionManager.SelectionType.ITEMS)
				selection_manager.navigate(-2)
			elif event.is_action_pressed("right"):
				selection_manager.switch_selection_type(BattleSelectionManager.SelectionType.ITEMS)
				selection_manager.navigate(1)
			elif event.is_action_pressed("left"):
				selection_manager.switch_selection_type(BattleSelectionManager.SelectionType.ITEMS)
				selection_manager.navigate(-1)
			elif event.is_action_pressed("use"):
				item_manager.select_item()
			elif event.is_action_pressed("ui_cancel"):
				item_manager.close_items_menu()
			if get_viewport():
				get_viewport().set_input_as_handled()
		
		states.OnItemSelect:
			item_manager.item_select_input(event)
		
		states.OnEnemy:
			if event.is_action_pressed("left"):
				move_enemy_input(-1)
			elif event.is_action_pressed("right"):
				move_enemy_input(1)
			elif event.is_action_pressed("use"):
				add_attack(current_attacker, [battle.get('enemy_pos'+str(selected_enemy))], load("res://resources/attacks/attack.tres"))
				action_history.append(current_attacker)
				previous_enemy = selected_enemy
				selected_enemy = 0
				advance_planning()
			if get_viewport():
				get_viewport().set_input_as_handled()
				
func simulate_click_move():
	selection_manager.confirm_selection()

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
	attack_array[attacker] = [attacked, attack]

func undo_last_action():
	if action_history.is_empty(): return
	var last = action_history.pop_back()
	if attack_array.has(last):
		var atk = attack_array[last][1]
		if atk.attack_type == 3 and atk.item_reference:
			var used_item = atk.item_reference
			Global.add_item(used_item, 1)  # Restore item
		attack_array.erase(last)
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
		if actor is Party and not attack_array.has(actor):
			initiative_who = idx
			current_attacker = actor
			state = states.OnAction
			current_party_plan_index += 1
			move_who_moves(current_party_plan_index)
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
		await do_attacks()
		return
	var current = initiative[initiative_who]
	if effect_manager.get_effect_duration(current, Global.effect.Sleep) > 0:
		if attack_array.has(current):
			attack_array.erase(current)
		$Control/enemy_ui/CenterContainer/output.text = current.name + " is asleep!"
		await get_tree().create_timer(0.5).timeout
		advance_initiative()
		return
	if not attack_array.has(current):
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
	if target: attack_array[e] = [target, atk]

func start_round():
	effect_manager.update_effects() 
	attack_array.clear()
	action_history.clear()
	planning_phase = true
	initiative_who = -1
	current_party_plan_index = -1
	state = states.OnAction
	$WhoMoves.visible = false
	$Control/enemy_ui/CenterContainer/output.text = ""
	advance_planning()

func do_attacks() -> void:
	for actor in initiative:
		if attack_array.has(actor):
			if actor is Party:
				current_attacker = actor
			await execute_single_attack(actor)
	await check_enemy_death_and_xp()
	await get_tree().create_timer(0.5).timeout
	start_round()

func execute_single_attack(attacker: Object) -> void:
	var targets = attack_array[attacker][0]
	var atk: Skill = attack_array[attacker][1]
	var alive: Array = []
	for t in targets:
		if t.hp > 0: alive.append(t)
	
	if atk.name == "Check ":
		var desc = "[color=#2196F3]━━━ ENEMY INFO ━━━[/color]"
		if targets.size() > 0 and targets[0] is Enemy:
			var target_enemy = targets[0]
			desc += "\n[color=#FF5722]" + target_enemy.name + "[/color]: " + target_enemy.description
			desc += "\n[color=#4CAF50]HP: " + str(target_enemy.hp) + "/" + str(target_enemy.max_hp) + "[/color] [color=#FFC107]ATK: " + str(target_enemy.damage) + "[/color]"
		add_to_battle_log(desc)
		await get_tree().create_timer(1.5).timeout
		return

	if alive.is_empty() and atk.target_type == 0:  
		var enemies: Array = []
		for e in range(5):
			if battle.get('enemy_pos'+str(e+1)) and battle.get('enemy_pos'+str(e+1)).hp > 0:
				enemies.append(battle.get('enemy_pos'+str(e+1)))
		if not enemies.is_empty():
			alive = [enemies[randi_range(0, enemies.size()-1)]]
			attack_array[attacker][0] = alive
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
				add_to_battle_log(item_log)
				update_party_ui()
				effect_manager.update_effect_ui(target)
			else:
				add_to_battle_log("[color=#F44336]Item use failed![/color]")
			
			await get_tree().create_timer(0.75).timeout
			return

	if alive.is_empty() and atk.target_type == 0:
		var enemies: Array = []
		for e in range(5):
			if battle.get('enemy_pos'+str(e+1)) and battle.get('enemy_pos'+str(e+1)).hp > 0:
				enemies.append(battle.get('enemy_pos'+str(e+1)))
		if not enemies.is_empty():
			alive = [enemies[randi_range(0, enemies.size()-1)]]
			attack_array[attacker][0] = alive
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
			
			var power_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Power)
			var weak_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Weak)
			base *= power_mult * weak_mult
			
			if Global.effect.Power in attacker.effects: base *= 2
			base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
			if crit: base *= 1.5
			base += atk.attack_bonus
			
			if effect_manager.check_instakill(attacker, target):
				target.hp = 0
				multi_log += "\n[color=#FF0000]Hit " + str(i+1) + ": ★★★ INSTAKILL ★★★[/color]"
				await get_tree().create_timer(0.5).timeout
				if attacker is Party and target is Enemy:
					await animate_enemy_death(target)
				death(target)
				add_to_battle_log(multi_log)
				await get_tree().create_timer(1.0).timeout
				return
			
			var tough_mult = effect_manager.get_effect_multiplier(target, Global.effect.Tough)
			var sick_mult = effect_manager.get_effect_multiplier(target, Global.effect.Sick)
			var def_stat = target.max_stats["def"] if attacker is Enemy else target.defense * 2
			var defend_mult = 1.5 if Global.effect.Defend in target.effects else 1.0
			var def_mult = clampf(1.0 - (float(def_stat) / (100.0 / (tough_mult * sick_mult))), 0.0, 1.0)
			def_mult /= defend_mult
			def_mult = clampf(def_mult, 0.0, 1.0)
			
			var dmg = max(0, floor(base * def_mult))
			
			var focus_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Focus)
			var blind_mult = effect_manager.get_effect_multiplier(target, Global.effect.Blind)
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
						effect_manager.remove_effect(target, Global.effect.Sleep)
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
		
		add_to_battle_log(multi_log)
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
		
		var power_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Power)
		var weak_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Weak)
		base *= power_mult * weak_mult
		
		if Global.effect.Power in attacker.effects: base *= 2
		base *= randf_range(0.86 if attacker is Enemy else 0.9, 1.16 if attacker is Enemy else 1.2)
		if crit: base *= 1.5
		base += atk.attack_bonus
		
		var was_instakill = false
		if effect_manager.check_instakill(attacker, target):
			target.hp = 0
			attacker.mp = max(0, attacker.mp - atk.mana_cost)
			was_instakill = true
			if attacker is Party and target is Enemy:
				await animate_enemy_death(target)
			death(target)
		
		var tough_mult = effect_manager.get_effect_multiplier(target, Global.effect.Tough)
		var sick_mult = effect_manager.get_effect_multiplier(target, Global.effect.Sick)
		var def_stat = target.max_stats["def"] if attacker is Enemy else target.defense * 2
		var defend_mult = 1.5 if Global.effect.Defend in target.effects else 1.0
		var def_mult = clampf(1.0 - (float(def_stat) / (100.0 / (tough_mult * sick_mult))), 0.0, 1.0)
		def_mult /= defend_mult
		def_mult = clampf(def_mult, 0.0, 1.0)
		
		var dmg = max(0, floor(base * def_mult))
		
		var focus_mult = effect_manager.get_effect_multiplier(attacker, Global.effect.Focus)
		var blind_mult = effect_manager.get_effect_multiplier(target, Global.effect.Blind)
		var hit = randf() <= (atk.accuracy * focus_mult * blind_mult)
		
		var effects_applied: Array = []
		if hit and not was_instakill:
			$AnimationPlayer.play("move_around_screen")
			target.hp -= dmg
			effect_manager.apply_effects(target, atk)
			
			if atk.effects:
				for effect in atk.effects.keys():
					var level = atk.effects[effect][0]
					var duration = atk.effects[effect][1]
					effects_applied.append([effect, level])
			
			if target.effects.has(Global.effect.Sleep):
				var sleep_level = target.effects[Global.effect.Sleep][0]
				if randf() < (1.0 - (0.1 * sleep_level)):
					effect_manager.remove_effect(target, Global.effect.Sleep)
			
			if attacker is Party and target is Enemy and target.hp <= 0:
				await animate_enemy_death(target)
		
		attacker.mp = max(0, attacker.mp - atk.mana_cost)
		if not was_instakill:
			print_outcome(attacker, [target], atk, dmg, crit, not hit, atk.mana_cost, effects_applied)
		else:
			add_to_battle_log("[color=#FF0000]" + attacker.name + " used " + atk.name + ": ★★★ INSTAKILL ★★★[/color]")

	elif atk.attack_type == 1:
		var buff_log = "[color=#FFD700]━━━ BUFF ━━━[/color]"
		var effects_applied: Array = []
		
		if atk.target_type == 1:
			effect_manager.apply_effects(attacker, atk)
			effect_manager.update_effect_ui(attacker)
			buff_log += "\n[color=#4CAF50]" + attacker.name + "[/color] buffed self"
			if atk.effects:
				for effect in atk.effects.keys():
					var level = atk.effects[effect][0]
					var duration = atk.effects[effect][1]
					effects_applied.append([effect, level])
					buff_log += " [color=#E91E63]" + effect_manager.get_effect_name_with_level(effect, level) + " (" + str(duration) + "t)[/color]"
			if atk.mana_cost > 0: buff_log += " [color=#9C27B0](" + str(atk.mana_cost) + " MP)[/color]"
			add_to_battle_log(buff_log)
			
		elif atk.target_type == 2:
			buff_log += "\n[color=#4CAF50]" + attacker.name + "[/color] buffed party"
			for p in party:
				if p.hp > 0:
					effect_manager.apply_effects(p, atk)
					effect_manager.update_effect_ui(p)
			if atk.effects:
				for effect in atk.effects.keys():
					var level = atk.effects[effect][0]
					var duration = atk.effects[effect][1]
					if not effects_applied.any(func(e): return e[0] == effect):
						effects_applied.append([effect, level])
					buff_log += " [color=#E91E63]" + effect_manager.get_effect_name_with_level(effect, level) + " (" + str(duration) + "t)[/color]"
			if atk.mana_cost > 0: buff_log += " [color=#9C27B0](" + str(atk.mana_cost) + " MP)[/color]"
			add_to_battle_log(buff_log)

	for t in alive:
		if t.hp <= 0:
			death(t)
	await get_tree().create_timer(0.5).timeout

func add_to_battle_log(text: String) -> void:
	log_timer = 0.0
	battle_log.append(text)
	if battle_log.size() > max_log_entries:
		battle_log.remove_at(0)
	update_battle_log_display()

func remove_oldest_log_entry() -> void:
	if not battle_log.is_empty():
		battle_log.remove_at(0)
		update_battle_log_display()

func update_battle_log_display() -> void:
	if battle_log.is_empty():
		$Control/enemy_ui/CenterContainer/output.text = ""
	else:
		$Control/enemy_ui/CenterContainer/output.text = "\n".join(battle_log)

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
					t += effect_manager.get_effect_name_with_level(effects_applied[i][0], effects_applied[i][1])
				t += "}[/color]"
	add_to_battle_log(t)
# === DEATH & VICTORY LOGIC ===

func check_enemy_death_and_xp():
	var all_dead = true
	for e in range(5):
		if battle.get('enemy_pos'+str(e+1)) and battle.get('enemy_pos'+str(e+1)).hp > 0:
			all_dead = false
			break
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
			if attack_array.has(obj): attack_array.erase(obj)
			if obj is Party and planning_phase and action_history.has(obj):
				action_history.erase(obj)
				current_party_plan_index -= 1

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

# === BATTLE BUTTON LOGIC ===

func _on_fight_button_pressed() -> void:
	state = states.OnEnemy
	selected_enemy = previous_enemy if previous_enemy != 0 else 1

func _on_skills_button_pressed() -> void:
	skill_manager.open_skills_menu()
	
func _on_defend_button_pressed() -> void:
	add_attack(current_attacker, [current_attacker], load("res://resources/attacks/defend.tres"))
	action_history.append(current_attacker)
	advance_planning() 

func _on_item_button_pressed() -> void:
	item_manager.open_items_menu()
	
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
