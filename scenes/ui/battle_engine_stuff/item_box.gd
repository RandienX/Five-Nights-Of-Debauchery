extends MarginContainer
class_name ItemBox

var texture_rect: TextureRect
var name_label: Label
var amount_label: Label

var item: Resource
var item_index: int = 0
var amount: int = 0

func _ready() -> void:
	texture_rect = find_child("item_texture", true, false)
	name_label = find_child("name", true, false)
	amount_label = find_child("item_amount", true, false)
	
	if not texture_rect: texture_rect = get_node_or_null("HSplitContainer/HSplitContainer/item_texture")
	if not name_label: name_label = get_node_or_null("HSplitContainer/HSplitContainer/name")
	if not amount_label: amount_label = get_node_or_null("HSplitContainer/item_amount")
	
	custom_minimum_size = Vector2(370, 70)

func setup(item_: Resource, index: int, item_amount: int):
	item = item_
	item_index = index
	amount = item_amount
	
	if texture_rect and item and item.texture:
		texture_rect.texture = item.texture
	
	if name_label and item:
		name_label.text = item.item_name
	
	if amount_label:
		amount_label.text = "x" + str(amount)
	
	if amount <= 0:
		modulate = Color(0.33, 0.33, 0.4)
	else:
		modulate = Color(1, 1, 1)
	Global.lower_font(name_label)

func update_amount(new_amount: int):
	amount = new_amount
	if amount_label:
		amount_label.text = "x" + str(amount)
	
	if amount <= 0:
		modulate = Color(0.33, 0.33, 0.4)
