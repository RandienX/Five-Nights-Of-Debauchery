@tool
extends Resource
class_name InventoryItemConfig

## Configuration resource for inventory item display

@export_group("Layout")
@export var min_size: Vector2 = Vector2(180, 80)
@export var icon_size: Vector2 = Vector2(48, 48)
@export var show_amount: bool = true
@export var show_delete_button: bool = true

@export_group("Textures")
@export var background_texture: Texture2D
@export var delete_icon: Texture2D
@export var pressed_background: Texture2D

@export_group("Fonts")
@export var name_font_size: int = 16
@export var amount_font_size: int = 14

@export_group("Colors")
@export var name_color: Color = Color.WHITE
@export var amount_color: Color = Color.WHITE

func _init():
	pass
