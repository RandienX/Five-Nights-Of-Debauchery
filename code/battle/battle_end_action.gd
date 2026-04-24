extends Resource
class_name BattleEndAction

enum ActionType { VICTORY, DEFEAT, TRANSITION, CUSTOM }

@export var action_type: ActionType
@export var transition_scene: String
@export var custom_script: GDScript

func execute(battle_engine: Node):
	match action_type:
		ActionType.VICTORY:
			if battle_engine.has_method("end_battle_victory"):
				await battle_engine.end_battle_victory()
		ActionType.DEFEAT:
			if battle_engine.has_method("trigger_game_over"):
				battle_engine.trigger_game_over()
		ActionType.TRANSITION:
			if transition_scene != "":
				Global.player_position = battle_engine.battle_start_position
				Global.loading = true
				var tree = Engine.get_main_loop()
				tree.change_scene_to_file(transition_scene)
				Global.loading = false
		ActionType.CUSTOM:
			if custom_script:
				var instance = custom_script.new()
				if instance.has_method("execute"):
					instance.execute(battle_engine)
