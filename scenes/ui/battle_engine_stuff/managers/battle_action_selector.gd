class_name BattleActionSelector
extends Node

## Handles the selection of the 5 main action buttons (Fight, Skill, Defend, Item, Run)
## using UP/DOWN input, replacing the old $TheMove logic.

signal action_selected(index: int)
signal selection_changed(index: int)

var selected_action_index: int = 0
const ACTION_COUNT: int = 5

# References to the actual button nodes in the UI
@export var fight_button: Button
@export var skill_button: Button
@export var defend_button: Button
@export var item_button: Button
@export var run_button: Button

var _buttons: Array[Button]

func _ready() -> void:
	# Cache buttons in order
	_buttons = [fight_button, skill_button, defend_button, item_button, run_button]
	update_visual_selection()

func handle_navigation_input(input_value: int) -> void:
	"""
	Called by Input Manager when UP/DOWN is pressed during PLANNING phase.
	input_value: 1 for Down, -1 for Up
	"""
	var new_index = wrapi(selected_action_index + input_value, 0, ACTION_COUNT)
	if new_index != selected_action_index:
		selected_action_index = new_index
		update_visual_selection()
		selection_changed.emit(selected_action_index)

func confirm_selection() -> void:
	"""
	Called when ENTER/CONFIRM is pressed. Emits the selected action index.
	"""
	action_selected.emit(selected_action_index)
	execute_selected_action()

func update_visual_selection() -> void:
	"""
	Highlights the selected button (Yellow) and resets others (White).
	"""
	for i in range(ACTION_COUNT):
		if _buttons[i]:
			if i == selected_action_index:
				_buttons[i].add_theme_color_override("font_color", Color.YELLOW)
				# Optional: Add a slight scale or outline effect here if desired
			else:
				_buttons[i].add_theme_color_override("font_color", Color.WHITE)

func execute_selected_action() -> void:
	"""
	Triggers the logic associated with the selected button.
	This assumes the parent (BattleEngine) has these methods or signals connected.
	"""
	match selected_action_index:
		0: # Fight
			if fight_button:
				fight_button.pressed.emit()
		1: # Skills
			if skill_button:
				skill_button.pressed.emit()
		2: # Defend
			if defend_button:
				defend_button.pressed.emit()
		3: # Item
			if item_button:
				item_button.pressed.emit()
		4: # Run
			if run_button:
				run_button.pressed.emit()

func reset_selection() -> void:
	selected_action_index = 0
	update_visual_selection()
