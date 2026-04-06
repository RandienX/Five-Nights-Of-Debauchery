extends Node
class_name BattleActionSelector

var root
var action_buttons: Array[Button] = []
var current_action_index: int = 0
var action_funcs: Array[Callable] = []

func setup(battleroot, fight_btn, skills_btn, defend_btn, item_btn, run_btn):
	root = battleroot
	
	# Get action buttons as array (id is the index in this array)
	action_buttons = [fight_btn, skills_btn, defend_btn, item_btn, run_btn]
	action_funcs = [
		root._on_fight_button_pressed,
		root._on_skills_button_pressed,
		root._on_defend_button_pressed,
		root._on_item_button_pressed,
		root._on_run_button_pressed
	]
	update_action_selection()

func update_action_selection():
	for i in range(action_buttons.size()):
		if i == current_action_index:
			# Yellow highlight like skills do
			action_buttons[i].modulate = Color(1, 1, 0.5)
		else:
			action_buttons[i].modulate = Color(1, 1, 1)

func navigate(direction: int):
	# Add/subtract id (index) to switch selection
	current_action_index = wrapi(current_action_index + direction, 0, action_buttons.size())
	update_action_selection()

func confirm_selection():
	if current_action_index < action_funcs.size():
		action_funcs[current_action_index].call()

func _input(event):
	if event.is_action_pressed("ui_accept"): # 'use' input action
		confirm_selection()
