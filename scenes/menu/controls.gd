extends Control

@onready var inputButton = preload("res://scenes/menu/inputbutton.tscn")
@onready var actionList = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ActionList

var remapping = false
var actionRemap = null
var remapButton = null

var actions = {
	"left": " Left",
	"up": "  Up",
	"down": " Down",
	"right": "Right",
	"run": "Run",
	"use": "Use/Interact",
}

func _ready() -> void:
	_create_action_list()
	
func _create_action_list():
	InputMap.load_from_project_settings()
	for i in actionList.get_children():
		i.queue_free()
		
	for a in actions:
		var button = inputButton.instantiate()
		var actLabel = button.find_child("ActLabel")
		var keyLabel = button.find_child("KeyLabel")
		
		actLabel.text = actions[str(a)]
		var event = InputMap.action_get_events(a)
		if event.size() > 0:
			keyLabel.text = event[0].as_text().trim_suffix(" (Physical)")
		else:
			keyLabel.text = ""
			
		actionList.add_child(button)
		button.pressed.connect(_on_input_button_pressed.bind(button, a))
		
func _on_input_button_pressed(button, action):
	if !remapping:
		remapping = true
		actionRemap = action
		remapButton = button
		button.find_child("KeyLabel").text = "Press key..."
		
func _input(event: InputEvent) -> void:
	if remapping:
		if event is InputEventKey || (event is InputEventMouseButton && event.pressed):
			if event is InputEventMouseButton && event.double_click:
				event.double_click = false
			
			InputMap.action_erase_events(actionRemap)
			InputMap.action_add_event(actionRemap, event)
			_update_action_list(remapButton, event)
			
			remapping = false
			remapButton = null
			actionRemap = null
			
			accept_event()
			
func _update_action_list(button, event):
	button.find_child("KeyLabel").text = event.as_text().trim_suffix(" (Physical)")

func _on_default_pressed() -> void:
	_create_action_list()
