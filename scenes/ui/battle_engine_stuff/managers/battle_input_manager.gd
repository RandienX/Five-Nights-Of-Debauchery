class_name BattleInputManager
extends Node

## Handles all battle input processing
## Based on tech_demo1_engine.gd _input() logic
## Supports UP/DOWN navigation for 5 action buttons without $TheMove

signal action_button_selected(index: int)
signal action_confirmed(action_index: int)
signal up_pressed()
signal down_pressed()
signal left_pressed()
signal right_pressed()
signal use_pressed()
signal cancel_pressed()

enum InputState {
	ON_ACTION,
	ON_ENEMY,
	ON_SKILLS,
	ON_SKILL_SELECT,
	ON_ITEMS,
	ON_ITEM_SELECT,
	WAITING,
	ON_RUN
}

var current_state: InputState = InputState.ON_ACTION
var battle_root: Node2D = null
var selected_action_index: int = 0  # 0-4 for Fight, Skills, Defend, Item, Run
var selected_enemy: int = 1
var previous_enemy: int = 1
var selected_party_member: int = 0
var item_target_type: int = 0  # 0 = enemy, 1 = party
var saved_party_plan_index: int = 0

# Action button paths (5 main buttons)
const ACTION_BUTTONS = [
	"Control/gui/HBoxContainer2/actions/FightButton/fight",
	"Control/gui/HBoxContainer2/actions/SkillsButton/skills",
	"Control/gui/HBoxContainer2/actions/DefendButton/defend",
	"Control/gui/HBoxContainer2/actions/ItemButton/item",
	"Control/gui/HBoxContainer2/actions/RunButton/run"
]

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root

## Main input handler - processes all battle input
func handle_input(event: InputEvent, game_over_active: bool, can_reload: bool, planning_phase: bool):
	if game_over_active:
		if can_reload:
			if event.is_action("use") or event.is_action("menu"):
				Global.reload_last_save()
		return
	
	if current_state == InputState.WAITING:
		if event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	
	# Handle cancel/undo during planning phase
	if planning_phase and (event.is_action_pressed("ui_undo") or event.is_action_pressed("ui_cancel")):
		if current_state == InputState.ON_SKILLS or current_state == InputState.ON_SKILL_SELECT:
			cancel_pressed.emit()
			get_viewport().set_input_as_handled()
			return
		elif current_state == InputState.ON_ITEMS or current_state == InputState.ON_ITEM_SELECT:
			cancel_pressed.emit()
			get_viewport().set_input_as_handled()
			return
		else:
			# Signal to undo last action
			get_viewport().set_input_as_handled()
			return
	
	if not event.is_pressed() or event is InputEventMouseMotion:
		return
	
	match current_state:
		InputState.ON_ACTION:
			_handle_action_input(event)
		
		InputState.ON_SKILLS:
			_handle_skills_input(event)
		
		InputState.ON_SKILL_SELECT:
			_handle_skill_select_input(event)
		
		InputState.ON_ITEMS:
			_handle_items_input(event)
		
		InputState.ON_ITEM_SELECT:
			_handle_item_select_input(event)
		
		InputState.ON_ENEMY:
			_handle_enemy_input(event)
		
		InputState.ON_RUN:
			_handle_run_input(event)

func _handle_action_input(event: InputEvent):
	if event.is_action_pressed("down"):
		selected_action_index = wrapi(selected_action_index + 1, 0, 5)
		action_button_selected.emit(selected_action_index)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("up"):
		selected_action_index = wrapi(selected_action_index - 1, 0, 5)
		action_button_selected.emit(selected_action_index)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use"):
		action_confirmed.emit(selected_action_index)
		get_viewport().set_input_as_handled()

func _handle_skills_input(event: InputEvent):
	if event.is_action_pressed("down"):
		navigate_skills(2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("up"):
		navigate_skills(-2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right"):
		navigate_skills(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("left"):
		navigate_skills(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use"):
		use_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel_pressed.emit()
		get_viewport().set_input_as_handled()

func _handle_skill_select_input(event: InputEvent):
	if event.is_action_pressed("left"):
		left_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right"):
		right_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use"):
		use_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel_pressed.emit()
		get_viewport().set_input_as_handled()

func _handle_items_input(event: InputEvent):
	if event.is_action_pressed("down"):
		navigate_items(2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("up"):
		navigate_items(-2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right"):
		navigate_items(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("left"):
		navigate_items(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use"):
		use_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel_pressed.emit()
		get_viewport().set_input_as_handled()

func _handle_item_select_input(event: InputEvent):
	if event.is_action_pressed("left"):
		if item_target_type == 0:
			left_pressed.emit()
		else:
			var party_in_initiative = get_party_members_from_initiative()
			selected_party_member = wrapi(selected_party_member - 1, 0, party_in_initiative.size())
			print("DEBUG Input Left: selected_party_member = ", selected_party_member)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right"):
		if item_target_type == 0:
			right_pressed.emit()
		else:
			var party_in_initiative = get_party_members_from_initiative()
			selected_party_member = wrapi(selected_party_member + 1, 0, party_in_initiative.size())
			print("DEBUG Input Right: selected_party_member = ", selected_party_member)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use"):
		use_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel_pressed.emit()
		get_viewport().set_input_as_handled()

func _handle_enemy_input(event: InputEvent):
	if event.is_action_pressed("left"):
		left_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right"):
		right_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use"):
		use_pressed.emit()
		get_viewport().set_input_as_handled()

func _handle_run_input(event: InputEvent):
	# Run state handling
	if event.is_action_pressed("use"):
		use_pressed.emit()
		get_viewport().set_input_as_handled()

## Navigates skills grid
func navigate_skills(direction: int):
	if battle_root and battle_root.has_method("navigate_skills"):
		battle_root.navigate_skills(direction)

## Navigates items grid
func navigate_items(direction: int):
	if battle_root and battle_root.has_method("navigate_items"):
		battle_root.navigate_items(direction)

## Moves enemy selection
func move_enemy_input(input: int):
	if input == 0:
		return
	while true:
		selected_enemy = wrapi(selected_enemy + input - 1, 0, 5) + 1
		if battle_root and battle_root.battle:
			if battle_root.battle.get('enemy_pos' + str(selected_enemy)) in battle_root.initiative:
				break
		else:
			break

## Gets party members from initiative
func get_party_members_from_initiative() -> Array[Object]:
	if battle_root and battle_root.has_method("get_party_members_from_initiative"):
		return battle_root.get_party_members_from_initiative()
	return []

## Sets the input state
func set_state(new_state: InputState):
	current_state = new_state

## Gets the current state
func get_state() -> InputState:
	return current_state

## Resets selection
func reset_selection():
	selected_action_index = 0
	selected_enemy = 1
	selected_party_member = 0
