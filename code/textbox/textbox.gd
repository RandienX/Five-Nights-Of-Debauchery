extends Control
var data: TextboxData
var logic: RefCounted = null
var current_index: int = 0
var typing: bool = true
var player_ref: CharacterBody2D = null
var speaker_id = {0: 0, 1: 1, 2: 2, 3: 3}

func init(d: TextboxData, player: CharacterBody2D):
	data = d
	player_ref = player
	if d.logic_script:
		logic = d.logic_script.new()

func _ready() -> void:
	if data == null or data.texts.is_empty():
		end_textbox()
		return
	advance_entry()

func advance_entry():
	if current_index >= data.texts.size():
		end_textbox()
		return
	if logic:
		var found = false
		while current_index < data.texts.size():
			if logic.check_entry(current_index, self):
				found = true
				break
			current_index += 1
		if not found:
			end_textbox()
			return
	show_entry()

func show_entry():
	var idx = current_index
	if idx >= data.texts.size():
		end_textbox()
		return
		
	if logic and logic.has_method("on_entry_show"):
		logic.on_entry_show(idx, self)
		
	var spk = data.speakers[idx] if idx < data.speakers.size() else 0
	var swag = data.has_swag[idx] if idx < data.has_swag.size() else false
	var region = Rect2(speaker_id.get(spk, 0) * 96, 96 if swag else 0, 96, 96)
	
	$Container/HBoxContainer/face/Sprite2D.region_rect = region
	$AudioStreamPlayer2D.stream = data.voices[idx] if idx < data.voices.size() else null
	$AudioStreamPlayer2D.playing = $AudioStreamPlayer2D.stream != null
	$Container/HBoxContainer/textbox/MarginContainer/RichTextLabel.text = data.texts[idx]
	$Container/HBoxContainer/textbox/MarginContainer/RichTextLabel.visible_characters = 0
	typing = true
	
	for child in $NinePatchRect/ChoiceContainer.get_children():
		child.queue_free()
	$NinePatchRect.visible = false
	
	if idx < data.choices.size() and data.choices[idx].size() > 0:
		for i in range(data.choices[idx].size()):
			var choice = data.choices[idx][i]
			var btn = Button.new()
			btn.text = choice.label if choice.has("label") else "Option " + str(i + 1)
			var target = current_index + 1
			if logic:
				target = logic.get_choice_target(idx, i, self)
			btn.pressed.connect(_on_choice_pressed.bind(target, i))  # FIXED: Pass choice_index
			$NinePatchRect/ChoiceContainer.add_child(btn)
		$NinePatchRect.visible = true

func _physics_process(delta: float) -> void:
	if typing:
		var label = $Container/HBoxContainer/textbox/MarginContainer/RichTextLabel
		if label.visible_characters < label.text.length():
			label.visible_characters += 1
		else:
			typing = false

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("use"):
		var label = $Container/HBoxContainer/textbox/MarginContainer/RichTextLabel
		if typing:
			label.visible_characters = label.text.length()
			typing = false
		elif not $NinePatchRect.visible:
			current_index += 1
			advance_entry()

func _on_choice_pressed(target_index: int, choice_index: int = 0):  # FIXED: Added choice_index
	if logic and logic.has_method("set_choice_flags"):
		logic.set_choice_flags(current_index, choice_index, self)
	current_index = target_index
	advance_entry()

func end_textbox():
	if player_ref and is_instance_valid(player_ref):
		player_ref.stop_move = false
	queue_free()
