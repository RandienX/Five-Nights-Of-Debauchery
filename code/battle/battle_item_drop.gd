@tool
class_name BattleItemDrop
extends Resource

## Item drop configuration for battles

@export_group("Item")
@export var item: Resource

@export_group("Drop Chance")
@export_range(0, 100) var drop_chance_percent: float = 100.0
@export var guaranteed_count: int = 0           # Always drop this many
@export_range(0, 99) var random_bonus_count: int = 0  # Random additional items


func should_drop() -> bool:
	if guaranteed_count > 0:
		return true
	return randf() * 100.0 <= drop_chance_percent


func get_drop_quantity() -> int:
	var total = guaranteed_count
	if random_bonus_count > 0:
		total += randi() % (random_bonus_count + 1)
	return max(1, total) if guaranteed_count > 0 else total
