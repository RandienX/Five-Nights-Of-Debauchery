class_name BattleActionPlanner
extends Node

## Manages action planning phase (RPG Maker style)
## Based on tech_demo1_engine.gd planning logic

signal planning_started()
signal planning_ended()
signal action_planned(attacker: Object, action_data: Dictionary)
signal undo_requested()

var battle_root: Node2D = null
var attack_array: Dictionary = {}  # {attacker: [targets, attack]}
var action_history: Array[Object] = []
var current_attacker: Object
var current_party_plan_index: int = 0
var planning_phase: bool = true

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Starts the planning phase
func start_round():
	if battle_root and battle_root.has_method("update_effects"):
		battle_root.update_effects()
	
	attack_array.clear()
	action_history.clear()
	planning_phase = true
	
	if battle_root:
		battle_root.initiative_who = -1
		battle_root.current_party_plan_index = -1
		battle_root.state = battle_root.states.OnAction
		
		var who_moves = battle_root.get_node_or_null("WhoMoves")
		if who_moves:
			who_moves.visible = false
		
		var output = battle_root.get_node_or_null("Control/enemy_ui/CenterContainer/output")
		if output:
			output.text = ""
	
	advance_planning()
	planning_started.emit()

## Adds an attack to the plan
func add_attack(attacker: Object, attacked: Array, attack: Skill):
	attack_array[attacker] = [attacked, attack]

## Undoes the last planned action
func undo_last_action():
	if action_history.is_empty():
		return
	
	var last = action_history.pop_back()
	if attack_array.has(last):
		var atk = attack_array[last][1]
		if atk.attack_type == 3 and atk.item_reference:
			var used_item = atk.item_reference
			Global.add_item(used_item, 1)  # Restore item
		attack_array.erase(last)
	
	current_attacker = last
	
	if battle_root:
		battle_root.state = battle_root.states.OnAction
		battle_root.current_party_plan_index = max(0, battle_root.current_party_plan_index - 1)
		move_who_moves(battle_root.current_party_plan_index)
		
		var output = battle_root.get_node_or_null("Control/enemy_ui/CenterContainer/output")
		if output:
			output.text = "Undid " + last.name + "'s move"
	
	undo_requested.emit()

## Advances to the next party member in planning
func advance_planning():
	if not battle_root:
		return
	
	var start = (battle_root.initiative_who + 1) % battle_root.initiative.size() if battle_root.initiative.size() > 0 else 0
	
	for i in range(battle_root.initiative.size()):
		var idx = (start + i) % battle_root.initiative.size()
		var actor = battle_root.initiative[idx]
		if actor is Party and not attack_array.has(actor):
			battle_root.initiative_who = idx
			current_attacker = actor
			battle_root.state = battle_root.states.OnAction
			battle_root.current_party_plan_index += 1
			move_who_moves(battle_root.current_party_plan_index)
			return
	
	start_resolution_phase()

## Starts the resolution phase (all actions locked in)
func start_resolution_phase():
	planning_phase = false
	
	if battle_root:
		battle_root.state = battle_root.states.Waiting
		
		var who_moves = battle_root.get_node_or_null("WhoMoves")
		if who_moves:
			who_moves.visible = false
		
		# Add enemy attacks
		for actor in battle_root.initiative:
			if actor is Enemy:
				add_enemy_attack(actor)
		
		battle_root.initiative_who = -1
	
	await get_tree().create_timer(0.4).timeout
	
	if battle_root and battle_root.has_method("advance_initiative"):
		battle_root.advance_initiative()
	
	planning_ended.emit()

## Adds AI attack for an enemy
func add_enemy_attack(e: Enemy):
	if not battle_root:
		return
	
	if e.attacks.is_empty():
		return
	
	var atk: Skill = e.attacks[randi_range(0, len(e.attacks) - 1)]
	while atk.mana_cost > e.mp:
		atk = e.attacks[randi_range(0, len(e.attacks) - 1)]
	
	var prob: Array[int] = []
	var lowest = 0
	
	for i in range(battle_root.party.size()):
		prob.append(1 if battle_root.party[i].hp > 0 else 0)
		if battle_root.party[i].hp > 0 and battle_root.party[i].hp < battle_root.party[lowest].hp:
			lowest = i
	
	var dumbness = [10, 4, 3, 3, 1]
	var rng = randi_range(1, dumbness[e.ai_type])
	
	if rng <= 2:
		prob[lowest] += 3 - rng
	else:
		var valid: Array[int] = []
		for i in range(prob.size()):
			if prob[i] > 0:
				valid.append(i)
		if not valid.is_empty():
			prob[valid[randi_range(0, valid.size() - 1)]] += 1
	
	for i in range(battle_root.party.size()):
		if Global.effect.Focus in battle_root.party[i].effects:
			prob[i] += 5 if e.ai_type != 4 else 1
	
	var target = null
	if atk.target_type == 0:
		var total = 0
		for p in prob:
			total += p
		if total == 0:
			return
		var rng2 = randi_range(1, total)
		for i in range(prob.size()):
			rng2 -= prob[i]
			if rng2 <= 0 and prob[i] > 0:
				target = [battle_root.party[i]]
				break
	elif atk.target_type == 2:
		target = battle_root.party
	
	if target:
		attack_array[e] = [target, atk]

## Moves the "who moves" indicator
func move_who_moves(index: int):
	if not battle_root:
		return
	
	var who_moves = battle_root.get_node_or_null("WhoMoves")
	if who_moves:
		who_moves.visible = true
		who_moves.position.x = 220 + (index * who_moves.size.x)

## Checks if planning is active
func is_planning() -> bool:
	return planning_phase

## Gets the current attacker
func get_current_attacker() -> Object:
	return current_attacker

## Gets the planned action for an actor
func get_planned_action(actor: Object) -> Dictionary:
	if attack_array.has(actor):
		var data = attack_array[actor]
		return {
			"targets": data[0],
			"attack": data[1]
		}
	return {}
