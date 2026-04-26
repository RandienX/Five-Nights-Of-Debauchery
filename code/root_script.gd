extends Node2D
class_name RootScene

@export var room_name: String
@export var possible_battles: Array[Battle]
@export_range(1, 1000) var enemy_intensity: int
@export_range(1, 100) var enemy_population: int
@export_range(1, 100) var enemy_agressiveness: int 
@onready var textbox_root = $Textboxes
var textboxes_deactivated := []
var player_position: Vector2
var player_steps: int = 100

func _ready() -> void:
	Global.current_scene = scene_file_path
	if !(room_name in Global.scene_data.keys()):
		Global.set_scene_data(self)
	for v in Global.scene_data[room_name].keys():
		if v == "textboxes_deactivated":
			textboxes_deactivated = Global.scene_data[room_name][v]
	
	if Global.loading:
		$player.global_position = PlayerStats.player_position
		
func save_data():
	Global.set_scene_data(self)

func _physics_process(delta: float) -> void:
	player_position = $player.global_position
	PlayerStats.player_position = player_position
	
func _input(event: InputEvent) -> void:
	var rng = randi_range(1, (1000 - enemy_intensity) * (enemy_agressiveness / 100.0))
	if event.is_action("left"):
		if (rng * 0.5 if event.is_action("run") else rng * 1) <= enemy_intensity:
			player_steps -= 1
	elif event.is_action("right"):
		if (rng * 0.5 if event.is_action("run") else rng * 1) <= enemy_intensity:
			player_steps -= 1
	elif event.is_action("up"):
		if (rng * 0.5 if event.is_action("run") else rng * 1) <= enemy_intensity:
			player_steps -= 1
	elif event.is_action("down"):
		if (rng * 0.5 if event.is_action("run") else rng * 1) <= enemy_intensity:
			player_steps -= 1
	if player_steps <= enemy_agressiveness:
		create_battle()
	print(player_steps)

func create_battle():
	Global.set_scene_data(self)
	$player.battle_zoom()
	var battle = possible_battles.pick_random()
	
	await get_tree().create_timer(1.5).timeout
	
	Global.load_battle(battle)
	
