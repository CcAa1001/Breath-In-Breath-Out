extends Panel

# nodes
var operator_label:  Label
var player_label:    Label
var choice_container: VBoxContainer
var call_status:     Label
var transcript_box:  VBoxContainer

# state
var current_step:     int  = 0
var call_complete:    bool = false
var wrong_attempts:   int  = 0

func _ready() -> void:
	hide()
	operator_label   = get_node_or_null("OperatorLabel")
	player_label     = get_node_or_null("PlayerLabel")
	choice_container = get_node_or_null("ChoiceContainer")
	call_status      = get_node_or_null("CallStatus")
	transcript_box   = get_node_or_null("ScrollContainer/TranscriptBox")

func open_call() -> void:
	if not GameManager.has_emergency_number:
		GameManager.show_dialogue("I need the emergency number from the glove box.")
		return
	if GameManager.phone_is_dead:
		GameManager.show_dialogue("My phone is dead. I can't call.")
		return
	if GameManager.rescue_called:
		GameManager.show_dialogue("I already called. Help is coming.")
		return
	visible      = true
	current_step = 0
	wrong_attempts = 0
	_clear_transcript()
	_start_call()

func _start_call() -> void:
	if call_status: call_status.text = "📞 Connected to Emergency Services"
	# play calling sound
	var audio = get_node_or_null("/root/Main/AudioManager")
	if audio: audio.play("phone_calling")
	await get_tree().create_timer(2.0).timeout
	_advance_dialogue()

func _advance_dialogue() -> void:
	if current_step >= PhoneContent.emergency_dialogue.size():
		_end_call()
		return

	var step = PhoneContent.emergency_dialogue[current_step]

	# show operator line
	await _show_operator(step["text"])

	# handle step type
	match step["type"]:
		"player_choice":
			_show_choices(step)
		"player_input":
			# fixed player line — auto responds
			await get_tree().create_timer(0.8).timeout
			_show_player_line(step["player_line"])
			await get_tree().create_timer(1.5).timeout
			current_step += 1
			_advance_dialogue()
		"operator_only":
			# no player response — just wait and continue
			await get_tree().create_timer(2.0).timeout
			current_step += 1
			_advance_dialogue()

func _show_operator(text: String) -> void:
	await get_tree().create_timer(PhoneContent.operator_response_delay).timeout
	if operator_label:
		operator_label.text = "Operator: " + text
	_add_transcript("Operator", text, Color(0.4, 0.8, 1.0))

func _show_player_line(text: String) -> void:
	if player_label:
		player_label.text = "You: " + text
	_add_transcript("You", text, Color(0.8, 1.0, 0.6))

func _show_choices(step: Dictionary) -> void:
	if not choice_container: return
	# clear old buttons
	for child in choice_container.get_children():
		child.queue_free()

	for i in step["choices"].size():
		var btn = Button.new()
		btn.text = step["choices"][i]
		btn.custom_minimum_size = Vector2(700, 44)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var idx = i
		btn.pressed.connect(func(): _on_choice(step, idx))
		choice_container.add_child(btn)

func _on_choice(step: Dictionary, chosen_idx: int) -> void:
	# clear buttons immediately
	if choice_container:
		for child in choice_container.get_children():
			child.queue_free()

	var chosen_text = step["choices"][chosen_idx]
	_show_player_line(chosen_text)

	if chosen_idx == step.get("correct", 0):
		# correct answer — advance
		await get_tree().create_timer(1.0).timeout
		current_step += 1
		_advance_dialogue()
	else:
		# wrong answer — operator repeats
		wrong_attempts += 1
		await get_tree().create_timer(0.8).timeout
		var wrong_response = step.get("wrong_response",
			"I'm sorry, could you repeat that?")
		await _show_operator(wrong_response)
		# show choices again
		_show_choices(step)

func _add_transcript(speaker: String, text: String, color: Color) -> void:
	if not transcript_box: return
	var lbl = Label.new()
	lbl.text = "[" + speaker + "] " + text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = color
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transcript_box.add_child(lbl)
	var sep = HSeparator.new()
	transcript_box.add_child(sep)

func _clear_transcript() -> void:
	if not transcript_box: return
	for child in transcript_box.get_children():
		child.queue_free()

func _end_call() -> void:
	if call_status:
		call_status.text = "✓ Call ended. Help is on the way!"
	if choice_container:
		for child in choice_container.get_children():
			child.queue_free()

	# trigger rescue
	GameManager.call_emergency()
	call_complete = true

	await get_tree().create_timer(3.0).timeout
	hide()

func _input(event: InputEvent) -> void:
	# allow closing with Escape if call is done
	if not visible: return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and call_complete:
			hide()
