extends Area2D

func _input(event) -> void:
	if $"../../player" in get_overlapping_bodies():
		if Input.is_action_just_pressed("use"):
			$"../..".create_battle()
