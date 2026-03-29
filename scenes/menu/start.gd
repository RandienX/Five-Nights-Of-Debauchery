extends Button

func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/maps/1ab.tscn")

var change_text = false

func _on_mouse_entered() -> void:
	change_text = true

func _on_mouse_exited() -> void:
	change_text = false
	
func _physics_process(delta: float) -> void:
	if change_text: self.text = "> Fuck yes."
	else: self.text = "  Start Game"
