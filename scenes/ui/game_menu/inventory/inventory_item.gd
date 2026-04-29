extends Control

@export var config: InventoryItemConfig
@export var item: Item
@export var amount: int
@onready var item_display_name = $HBoxContainer/Item/NinePatchRect/ItemName
@onready var item_display_texture = $HBoxContainer/Item/NinePatchRect/ItemTexture
@onready var item_display_amount = $HBoxContainer/Amount/Label

enum itemBox_types {Null, Equip}
var itemBox_type = itemBox_types.Null
var item_type: String
var party_member: Entity

func _ready() -> void:
	# Apply config settings if available
	if config:
		custom_minimum_size = config.min_size
		if item_display_name:
			item_display_name.add_theme_font_size_override("font_size", config.name_font_size)
		if item_display_amount:
			item_display_amount.add_theme_font_size_override("font_size", config.amount_font_size)
	
	if itemBox_type == itemBox_types.Null:
		redisplay()
	else:
		redisplay_equip()
	
func redisplay():
	item_display_name.text = item.item_name
	item_display_texture.texture = item.texture
	item_display_amount.text = "x" + str(amount)
	
	if amount <= 0:
		queue_free()

func _on_item_pressed() -> void:
	if itemBox_type == itemBox_types.Null and item != null and item.type != 3:  # Not Key type
		var parent_menu = $"../../../.."
		if parent_menu and parent_menu.has_method("display_party"):
			parent_menu.is_visible = false
			parent_menu.selected_item = item
			parent_menu.display_party(item)
	elif itemBox_type == itemBox_types.Equip:
		$"../..".equip_item(item, item_type)

func _on_delete_pressed() -> void:
	amount -= 1
	PlayerStats.remove_item(item)
	redisplay()

func redisplay_equip():
	if $HBoxContainer/Delete:
		$HBoxContainer/Delete.queue_free()
		
	item_display_name.text = item.item_name
	if item.texture:
		item_display_texture.texture = item.texture
	
	if item.type == 0:  # Weapon
		var atk_bonus: int = 0
		if party_member.equipped.get(item_type) != null:
			atk_bonus = party_member.equipped[item_type].get_bonus("atk")
			
		var diff = item.get_bonus("atk") - atk_bonus
		if diff >= 0:
			item_display_amount.text = "+" + str(diff)
		else:
			item_display_amount.text = str(diff)
	elif item.type == 1:  # Armor
		var def_bonus: int = 0
		if party_member.equipped.get(item_type) != null:
			def_bonus = party_member.equipped[item_type].get_bonus("def")
			
		var diff = item.get_bonus("def") - def_bonus
		if diff >= 0:
			item_display_amount.text = "+" + str(diff)
		else:
			item_display_amount.text = str(diff)
	
	
