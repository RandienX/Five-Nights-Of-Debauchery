extends Area2D
@export var textbox_data: TextboxData
@export var id: String
@export var one_time: bool = true

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "player":
		if $ConditionsScript.condition():
			var root = get_tree().current_scene
			if not (id in root.textboxes_deactivated):
				body.make_textbox(textbox_data)
				if one_time:
					root.textboxes_deactivated.append(id)
					root.save_data()
					queue_free()
