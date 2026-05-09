extends Button

@onready var saves = $"../../save_box/Control"

func _ready() -> void:
	saves.global_position = Vector2(300, 64)
	saves.scale = Vector2(0.8, 0.8)
	saves.saving = false
	saves.save_update()

func _on_pressed() -> void:
	saves.visible = !saves.visible
	$"../../settings".visible = false
	
var change_text = false
func _on_mouse_entered() -> void:
	change_text = true

func _on_mouse_exited() -> void:
	change_text = false
	
func _physics_process(delta: float) -> void:
	if change_text: self.text = "> Back to debauchery."
	else: self.text = "  Load Game"
