extends Control

@export var item: Item
@export var amount: int
@onready var item_display_name = $HBoxContainer/Item/NinePatchRect/ItemName
@onready var item_display_texture = $HBoxContainer/Item/NinePatchRect/ItemTexture
@onready var item_display_amount = $HBoxContainer/Amount/Label

enum itemBox_types {Null, Equip}
var itemBox_type = itemBox_types.Null
var item_type: String
var party_member: Party

func _ready() -> void:
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
	if itemBox_type == itemBox_types.Null and item.type != 3:
		$"../../../..".is_visible = false
		$"../../../..".selected_item = item
		$"../../../..".display_party(item)
	elif itemBox_type == itemBox_types.Equip:
		$"../..".equip_item(item, item_type)

func _on_delete_pressed() -> void:
	amount -= 1
	Global.remove_item(item)
	redisplay()

func redisplay_equip():
	if $HBoxContainer/Delete:
		$HBoxContainer/Delete.queue_free()
		
	item_display_name.text = item.item_name
	item_display_texture.texture = item.texture
	if item.type == 0:
		var atk_bonus: int
		if party_member.equipped[item_type] == null:
			atk_bonus = 0
		else:
			atk_bonus = party_member.equipped[item_type].item_bonuses["atk"]
			
		if item.item_bonuses["atk"] >= atk_bonus:
			item_display_amount.text = "+" + str(item.item_bonuses["atk"] - atk_bonus)
		else:
			item_display_amount.text = str(item.item_bonuses["atk"] - atk_bonus)
	elif item.type == 1:
		var def_bonus: int
		if party_member.equipped[item_type] == null:
			def_bonus = 0
		else:
			def_bonus = party_member.equipped[item_type].item_bonuses["def"]
			
		if item.item_bonuses["def"] >= def_bonus:
			item_display_amount.text = "+" + str(item.item_bonuses["def"] - def_bonus)
		else:
			item_display_amount.text = str(item.item_bonuses["def"] - def_bonus)
	
	
