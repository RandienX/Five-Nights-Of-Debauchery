extends TextureRect

var hp: int = 0
var max_hp: int = 0

func _process(delta: float) -> void:
	if hp != 0:
		$ProgressBar.value = hp
		$ProgressBar.max_value = max_hp
	else:
		$ProgressBar.visible = false
		
