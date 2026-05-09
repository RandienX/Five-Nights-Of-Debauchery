extends Control

func _on_back_pressed() -> void:
	# Go back to the main game menu
	var display = $"../../display_category"
	if display:
		for c in display.get_children():
			c.queue_free()
		$"../../../..".layer_down = 0
		$"../../../..".visible = false
		$"../../../../../../..".stop_move = false

func _on_exit_pressed() -> void:
	# Exit to main menu
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")

func _on_achievements_pressed() -> void:
	# TODO: Open achievements scene
	print("Achievements button pressed - to be implemented")
