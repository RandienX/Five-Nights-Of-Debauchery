# Example custom effect: Play a sound
static func apply(effect: DialogueEffect, runner: DialogueRunner):
	var sound_path = effect.param_string
	if sound_path.is_empty():
		push_error("Custom play_sound effect: No sound path specified")
		return
	
	var sound = load(sound_path)
	if not sound:
		push_error("Custom play_sound effect: Failed to load sound: %s" % sound_path)
		return
	
	# Play the sound (adjust for your audio system)
	var audio = AudioStreamPlayer.new()
	audio.stream = sound
	runner.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
