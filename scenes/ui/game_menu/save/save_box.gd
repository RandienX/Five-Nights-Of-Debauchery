extends Control

var saving = true

func save_update() -> void:
	for c in $VBoxContainer.get_children():
		c.saving = saving
		
func _physics_process(delta: float) -> void:
	var multiplier = $VScrollBar.value
	$VBoxContainer.global_position.y = 32 - 170 * multiplier * scale.y
