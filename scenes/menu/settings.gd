extends Button

func _on_pressed() -> void:
	$"../../settings".visible = !$"../../settings".visible
	$"../../save_box/Control".visible = false

var change_text = false

func _on_mouse_entered() -> void:
	change_text = true

func _on_mouse_exited() -> void:
	change_text = false
	
func _physics_process(delta: float) -> void:
	if $".." == get_tree().root.get_node("menu/buttons"):
		if change_text: self.text = "> Gamechanging."
		else: self.text = "  Settings"
	elif $".." == get_tree().root.get_node("menu/settings"):
		if change_text: self.text = "> Back"
		else: self.text = "  Back"
