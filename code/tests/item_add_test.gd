extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body == $"../../player":
		Global.add_item(load("res://resources/items/consumables/attack_item.tres"))
