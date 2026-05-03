extends Button

func _on_pressed() -> void:
	if $".." == get_tree().root.get_node("menu/Control"):
		$"../../settings_anim".play("fade_in_settings_from_control")
		await get_tree().create_timer(1).timeout
		$"..".visible = false
		get_tree().root.get_node("menu/settings").visible = true
	elif $".." == get_tree().root.get_node("menu/settings"):
		$"../../settings_anim".play("fade_in_control")
		await get_tree().create_timer(1).timeout
		$"..".visible = false
		get_tree().root.get_node("menu/Control").visible = true

var change_text = false

func _on_mouse_entered() -> void:
	change_text = true

func _on_mouse_exited() -> void:
	change_text = false
	
func _physics_process(delta: float) -> void:
	if $".." == get_tree().root.get_node("menu/settings"):
		if change_text: self.text = "> Controls"
		else: self.text = "  Controls"
	elif $".." == get_tree().root.get_node("menu/Control"):
		if change_text: self.text = "> Back"
		else: self.text = "  Back"
