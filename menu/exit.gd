extends Button

func _on_pressed() -> void:
	get_tree().quit()

var change_text = false

func _on_mouse_entered() -> void:
	change_text = true

func _on_mouse_exited() -> void:
	change_text = false
	
func _physics_process(delta: float) -> void:
	if change_text: self.text = "> Not ready for Freddy."
	else: self.text = "  Exit"
