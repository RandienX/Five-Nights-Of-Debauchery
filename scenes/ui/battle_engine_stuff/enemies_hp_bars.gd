extends TextureRect

@export var enemy: Entity

func _process(delta: float) -> void:
	if enemy:
		$ProgressBar.value = enemy.hp
		$ProgressBar.max_value = enemy.base_stats["hp"]
	else:
		$ProgressBar.visible = false
		
