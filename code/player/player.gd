extends CharacterBody2D
@onready var menu := $Camera2D/CanvasLayer/game_menu
@export var stop_move := false
@export var static_shader := true
@export var can_menu := true
@export var inbattle_cam := false
func _ready() -> void:
	$AnimatedSprite2D.play("idle1")
	$Camera2D/CanvasLayer/white_flash.visible = static_shader
	$Camera2D/CanvasLayer/ColorRect.visible = static_shader
	$Camera2D/CanvasLayer/Label.visible = static_shader
	if inbattle_cam:
		$Camera2D.queue_free()
	
func _physics_process(delta: float) -> void:
	movement(delta)
	
	move_and_slide()

@export var move_speed: float = 50.0
var acceleration = 500

var current_direction: Vector2 = Vector2.ZERO
var target_rotation: float = 0.0

func movement(delta) -> void:
	var direction = Input.get_vector("left", "right", "up", "down")
	
	if !stop_move:
		if direction.length() > 1.0:
			direction = direction.normalized()
		current_direction = direction
		if Input.is_action_pressed("run"): velocity = velocity.move_toward(direction * 1.5 * move_speed, acceleration * 1.5 * delta)
		else: velocity = velocity.move_toward(direction * move_speed, acceleration * delta)
	else:
		current_direction = Vector2.ZERO
		velocity = Vector2.ZERO
	
	animate()
	move_and_slide()
	
var idle_state = 0

func animate():
	if current_direction != Vector2.ZERO:
		if current_direction.y == -1:
			$AnimatedSprite2D.play("run2")
			idle_state = 2
		elif current_direction.y == 1:
			$AnimatedSprite2D.play("run1")
			idle_state = 1
		elif current_direction.x != 0:
			$AnimatedSprite2D.play("run0")
			idle_state = 0
			$AnimatedSprite2D.flip_h = current_direction.x < 0
	else:
		$AnimatedSprite2D.play("idle" + str(idle_state))
		
func textbox():
	stop_move = true
	can_menu = false

@export var party: Array[Party]

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("menu") and can_menu:
		if menu.visible == false:
			menu.visible = true
			stop_move = true
		else:
			menu.visible = false
			stop_move = false

func battle_zoom():
	stop_move = true
	$AnimationPlayer.play("camera_battle_zoom")
