extends TextureRect

@export var enemy: Entity
var effect_container: GridContainer
const EFFECT_ATLAS_PATH = "res://assets/battleui/status_effects.png"
const EFFECT_TILE_SIZE = 64
const EFFECT_COLS = 4

func _ready() -> void:
	# Create effect container for status icons
	effect_container = $EffectContainer

func _physics_process(delta: float) -> void:
	if enemy:
		$ProgressBar.value = enemy.hp
		$ProgressBar.max_value = enemy.base_stats["hp"]
	else:
		$ProgressBar.visible = false
	update_effects_ui()

## Updates status effects display for enemy
func update_effects_ui() -> void:
	for child in effect_container.get_children():
		child.queue_free()

	if enemy:
		# Use new status system API
		var active_status_ids = enemy.get_active_status_ids()
		for status_id in enemy.get_active_status_ids():
			var stacks = enemy.get_status_stacks(status_id)
			var duration = enemy.get_status_duration(status_id)
			var status_data = enemy._statuses.get(status_id)
			
			if status_data and status_data.has("definition"):
				var status_def = status_data["definition"] as StatusDefinition

				# Create icon using status definition's icon if available
				var icon: TextureRect
				if status_def.icon != null:
					icon = create_effect_icon_from_texture(status_def.icon)

				if icon:
					# Add stack count label if stacked
					if stacks > 1:
						var stack_label = Label.new()
						stack_label.text = "x" + str(stacks)
						stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
						stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
						stack_label.add_theme_color_override("font_shadow_color", Color.BLACK)
						stack_label.add_theme_constant_override("shadow_offset_x", 1)
						stack_label.add_theme_constant_override("shadow_offset_y", 1)
						stack_label.add_theme_font_size_override("font_size", 8)
						icon.add_child(stack_label)
						stack_label.set_anchors_preset(Control.PRESET_FULL_RECT)

						# Add duration tooltip
						icon.tooltip_text = "%s\nDuration: %d turn(s)" % [status_def.name if not status_def.name.is_empty() else status_id, duration]

					effect_container.add_child(icon)

## Creates an effect icon from a Texture2D resource
func create_effect_icon_from_texture(tex: Texture2D) -> TextureRect:
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = tex
	return icon
