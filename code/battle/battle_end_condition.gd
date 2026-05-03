extends Resource
class_name BattleEndCondition

@export var condition_script: GDScript
@export var on_met: BattleEndAction

func check(battle_engine: Node) -> bool:
	if condition_script:
		var instance = condition_script.new()
		if instance.has_method("check"):
			return instance.check(battle_engine)
	return false

func execute(battle_engine: Node):
	if on_met:
		on_met.execute(battle_engine)
