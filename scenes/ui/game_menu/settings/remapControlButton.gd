extends Button
class_name RemapInputButton

@export var action: String
@export var action_event_index: int = 0
@export var action_text_override: String = ""

func _ready() -> void:
	toggle_mode = true
	$Label.text = action.to_upper() if action_text_override == "" else action_text_override.to_upper() + " [%s]"
	$Label.text = $Label.text % [OS.get_keycode_string(InputMap.action_get_events(action)[action_event_index].physical_keycode)]
	
func _unhandled_input(event: InputEvent) -> void:
	if !InputMap.has_action(action) or !is_pressed():
		return
		
	if event.is_pressed() and event is InputEventKey:
		var action_events_list = InputMap.action_get_events(action)
		if action_event_index < action_events_list.size():
			InputMap.action_erase_event(action, action_events_list[action_event_index])
		
		InputMap.action_add_event(action, event)
		action_event_index = InputMap.action_get_events(action).size()-1
		$Label.text = action.to_upper() if action_text_override == "" else action_text_override.to_upper() + " [%s]"
		$Label.text = $Label.text % [OS.get_keycode_string(InputMap.action_get_events(action)[action_event_index].physical_keycode)]
	
		button_pressed = false
		release_focus()
		
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("lmb"):
		button_pressed = false
		release_focus()
	
func _on_toggled(toggled_on: bool) -> void:
	if !action or !InputMap.has_action(action):
		return
	
	if toggled_on:
		$Label.text= "Changing Input!"
		return
		
	if action_event_index >= InputMap.action_get_events(action).size():
		$Label.text = "Unassigned"
		return
		
	var input = InputMap.action_get_events(action)[action_event_index]
	if input is InputEventKey:
		if input.physical_keycode != 0:
			$Label.text = action.to_upper() if action_text_override == "" else action_text_override.to_upper() + " [%s]"
			$Label.text = $Label.text % [OS.get_keycode_string(InputMap.action_get_events(action)[action_event_index].physical_keycode)]
		else:
			$Label.text = action.to_upper() if action_text_override == "" else action_text_override.to_upper() + " [%s]"
			$Label.text = $Label.text % [OS.get_keycode_string(InputMap.action_get_events(action)[action_event_index].physical_keycode)]
			
	
