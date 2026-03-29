extends TextureRect

var item: Item

func _ready() -> void:
	item = $"..".selected_item
	if item == null:
		queue_free()

func _process(delta: float) -> void:
	if item:
		$"NameAmount".text = item.item_name + ": " + str(Global.inventory[item]) 
		$Describtion.text = item.desc
		texture = item.texture
