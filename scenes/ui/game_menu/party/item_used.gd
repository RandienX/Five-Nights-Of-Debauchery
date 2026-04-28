extends TextureRect

var item: Item

func _ready() -> void:
	item = $"..".selected_item
	if item == null:
		queue_free()

func _process(delta: float) -> void:
	if item and PlayerStats.inventory.has(item):
		$"NameAmount".text = item.item_name + ": " + str(PlayerStats.inventory[item]) 
		$Describtion.text = item.description
		if item.texture:
			texture = item.texture
