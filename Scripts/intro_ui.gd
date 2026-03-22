extends Control

var dialogue_lines = [
	{"speaker": "Mom",  "text": "John, how long will you be here?"},
	{"speaker": "John", "text": "About an hour, Mom."},
	{"speaker": "Mom",  "text": "Your father is in an emergency situation and wants to see you now."},
	{"speaker": "John", "text": "I will try to get there faster."},
	{"speaker": "Mom",  "text": "Which road are you on now?"},
	{"speaker": "John", "text": "I'm on Linden Street right now."},
	{"speaker": "Mom",  "text": "Okay, anyway. Be careful on the road, I'll wait until you arrive."},
]
var current_line: int  = 0
var on_finished: Callable
var _waiting: bool     = false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)

func show_intro(finished_callback: Callable) -> void:
	on_finished  = finished_callback
	current_line = 0
	visible      = true
	get_tree().paused = true

	var bg = get_node_or_null("IntroBG")
	if bg and ResourceLoader.exists("res://assets/intro_car.png"):
		bg.texture = load("res://assets/intro_car.png")

	# play talk sound when dialogue starts
	var audio = get_node_or_null("/root/Main/AudioManager")
	if audio: audio.play_on(audio.music_player, "talk", true)

	_show_line(0)

func _finish_intro() -> void:
	_waiting = false

	# stop talk music
	var audio = get_node_or_null("/root/Main/AudioManager")
	if audio: audio.stop_on(audio.music_player)

	var dialogue_box = get_node_or_null("DialogueBox")
	if dialogue_box: dialogue_box.visible = false

	# crash sounds
	if audio:
		audio.play("rubble")
		await get_tree().create_timer(0.3).timeout
		audio.play("glass")

	# fade to black
	var bg = get_node_or_null("IntroBG")
	if bg:
		var tween = create_tween()
		tween.tween_property(bg, "modulate", Color(0, 0, 0, 1), 0.5)
		await tween.finished
	else:
		await get_tree().create_timer(0.5).timeout

	await get_tree().create_timer(2.5).timeout
	visible = false
	get_tree().paused = false

	# heavy breath plays AFTER tutorial finishes — pass it in callback
	if on_finished.is_valid():
		on_finished.call()

func _show_line(idx: int) -> void:
	print("Showing intro line: ", idx)
	var speaker_label = get_node_or_null("DialogueBox/SpeakerLabel")
	var text_label    = get_node_or_null("DialogueBox/DialogueText")
	var hint_label    = get_node_or_null("DialogueBox/HintLabel")
	var dialogue_box  = get_node_or_null("DialogueBox")

	if not speaker_label:
		speaker_label = find_child("SpeakerLabel", true, false)
	if not text_label:
		text_label = find_child("DialogueText", true, false)

	if not speaker_label or not text_label:
		print("ERROR: SpeakerLabel or DialogueText not found!")
		print("Children of IntroScreen:")
		for c in get_children():
			print(" - ", c.name)
		return

	if dialogue_box: dialogue_box.visible = true
	speaker_label.text = dialogue_lines[idx]["speaker"] + ":"
	text_label.text    = dialogue_lines[idx]["text"]
	if hint_label:
		hint_label.text = "Click anywhere to continue"
	_waiting = true

func _input(event: InputEvent) -> void:
	if not visible: return
	if not _waiting: return
	if not event is InputEventMouseButton: return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if not event.pressed: return

	get_viewport().set_input_as_handled()
	_waiting = false
	current_line += 1

	if current_line >= dialogue_lines.size():
		_finish_intro()
	else:
		_show_line(current_line)
