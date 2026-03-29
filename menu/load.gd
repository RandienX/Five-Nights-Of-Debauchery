extends Button

func _on_pressed() -> void:
	if len($"../../save_box".get_children()) != 1:
		var saves = preload("res://scenes/ui/game_menu/save/saves.tscn").instantiate()
		saves.global_position = Vector2(300, 64)
		saves.scale = Vector2(0.8, 0.8)
		saves.saving = false
		$"../../save_box".add_child(saves)
		saves.save_update()
	else:
		$"../../save_box".get_children()[0].queue_free()
	

var change_text = false

func _on_mouse_entered() -> void:
	change_text = true

func _on_mouse_exited() -> void:
	change_text = false
	
func _physics_process(delta: float) -> void:
	if change_text: self.text = "> Back to debauchery."
	else: self.text = "  Load Game"
