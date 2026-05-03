extends RefCounted
class_name BattleActionShowTextbox

@export var textbox_data: TextboxData
@export var simple_text: String = ""
@export var simple_speaker: int = 0
@export var wait_for_completion: bool = true

# Shows a textbox during battle
func execute(battle_engine: Node):
	var data_to_use = textbox_data
	
	# If no full data but simple text is provided, create it on the fly
	if not data_to_use and simple_text != "":
		data_to_use = TextboxData.new()
		data_to_use.texts = [simple_text]
		data_to_use.speakers = [simple_speaker]
		data_to_use.has_swag = [false]
		data_to_use.voices = []
		data_to_use.choices = []
	
	if data_to_use:
		# Try to find the player node
		var player_node = null
		
		# Method 1: Try to get from battle_engine's parent
		player_node = battle_engine.get_node_or_null("../player")
		
		# Method 2: Search in scene tree
		if not player_node:
			var nodes = battle_engine.get_tree().get_nodes_in_group("player")
			if nodes.size() > 0:
				player_node = nodes[0]
		
		# Method 3: Get current scene and search
		if not player_node:
			var current_scene = battle_engine.get_tree().current_scene
			if current_scene:
				player_node = current_scene.find_child("player", true, false)
		
		if player_node and player_node.has_method("make_textbox"):
			player_node.make_textbox(data_to_use)
			
			if wait_for_completion:
				# Wait until textbox is freed
				while player_node.get_node_or_null("CanvasLayer/textbox"):
					await battle_engine.get_tree().process_frame
