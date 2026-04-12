extends Node
class_name SelectionManager

@export var target_container: Control
@export var navigation_action: String = "ui_right"
@export var back_navigation_action: String = "ui_left"
@export var use_action: String = "ui_accept"

var current_index: int = 0
var selected_button: Button = null

func _ready():
	if target_container:
		update_selection()

func _input(event):
	if get_tree().root.get_node("BattleEngine").state == get_tree().root.get_node("BattleEngine").states.OnAction:
		if not target_container or target_container.get_child_count() == 0:
			return
		
		if get_tree().paused:
			return

		if event.is_action_pressed(navigation_action):
			change_selection(1)
		elif event.is_action_pressed(back_navigation_action):
			change_selection(-1)
		elif event.is_action_pressed(use_action):
			activate_selected()
		if get_tree() != null:
			get_viewport().set_input_as_handled()

func change_selection(direction: int):
	var child_count = target_container.get_child_count()
	if child_count == 0:
		return

	if selected_button and is_instance_valid(selected_button):
		set_button_glow(selected_button, false)

	current_index = wrapi(current_index - direction, 0, child_count)
	update_selection()

func update_selection():
	var child_count = target_container.get_child_count()
	if child_count == 0:
		selected_button = null
		return

	current_index = clamp(current_index, 0, child_count - 1)
	
	var child = target_container.get_child(current_index)
	if child is Button:
		selected_button = child
		set_button_glow(selected_button, true)
	else:
		selected_button = null

func set_button_glow(btn: Button, is_glowing: bool):
	if is_glowing:
		btn.add_theme_color_override("font_color", Color.YELLOW)
	else:
		btn.remove_theme_color_override("font_color")

func activate_selected():
	if selected_button and is_instance_valid(selected_button):
		selected_button.emit_signal("pressed")
