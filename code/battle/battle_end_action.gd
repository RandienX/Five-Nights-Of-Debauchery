extends Node
class_name BattleEndAction

enum ActionType { VICTORY, DEFEAT, TRANSITION, TEXTBOX, CUSTOM }

@export var action_type: ActionType
@export var textbox_data: TextboxData
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
				get_tree().change_scene_to_file(transition_scene)
				Global.loading = false
		ActionType.TEXTBOX:
			if textbox_data:
				var party_node = battle_engine.get_node_or_null("../player")
				if not party_node:
					party_node = get_tree().get_first_node_in_group("player")
				if party_node and party_node.has_method("make_textbox"):
					party_node.make_textbox(textbox_data)
					# Wait for textbox to finish before continuing
					await get_tree().create_timer(0.1).timeout
		ActionType.CUSTOM:
			if custom_script:
				var instance = custom_script.new()
				if instance.has_method("execute"):
					instance.execute(battle_engine)
