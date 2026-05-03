extends Node2D
class_name RootScene

@export var room_name: String
@export var possible_battles: Array[Battle]
@export_range(1, 1000) var enemy_intensity: int
@export_range(1, 100) var enemy_agressiveness: int 
@export var player: CharacterBody2D
@export var room_size: Rect2

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
	
	setup_player()
	
func setup_player():
	await get_tree().physics_frame
	player.global_position = PlayerStats.player_position
		
	player.camera.limit_left = room_size.position.x*32 #32 cuz tile size *2 cuz idfk
	player.camera.limit_top = room_size.position.y*32
	player.camera.limit_right = room_size.position.x*32 + room_size.size.x*32
	player.camera.limit_bottom = room_size.position.y*32 + room_size.size.y*32
		
func save_data():
	Global.set_scene_data(self)

func _physics_process(delta: float) -> void:
	player_position = player.global_position
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

func create_battle():
	Global.set_scene_data(self)
	$player.battle_zoom()
	var battle = possible_battles.pick_random()
	
	await get_tree().create_timer(1.5).timeout
	
	Global.load_battle(battle)
	
