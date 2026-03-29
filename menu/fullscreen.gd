extends Button

var text_mode: String = "OFF"

func _on_toggled(toggled_on: bool) -> void:
	var mode := DisplayServer.window_get_mode()
	var is_window: bool = mode != DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_window:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		text_mode = "ON"
	else: 
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		text_mode = "OFF"


var change_text = false

func _on_mouse_entered() -> void:
	change_text = true

func _on_mouse_exited() -> void:
	change_text = false
	
func _physics_process(delta: float) -> void:
	if change_text: self.text = "> Fullscreen " + text_mode
	else: self.text = "  Fullscreen " + text_mode
