extends CanvasLayer

var player_bar:      ProgressBar
var car_bar:         ProgressBar
var panic_bar:       ProgressBar
var prompt:          Label
var breath_hold_bar: ProgressBar
var dialogue_box:    Label
var dialogue_tween:  Tween
var choice_panel:    Panel
var choice_label:    Label
var choice_buttons:  Array = []

func _ready() -> void:
	player_bar      = find_child("PlayerOxygenBar",  true, false)
	car_bar         = find_child("CarOxygenBar",     true, false)
	panic_bar       = find_child("PanicBar",         true, false)
	prompt          = find_child("BreathPrompt",     true, false)
	breath_hold_bar = find_child("BreathHoldBar",    true, false)
	dialogue_box    = find_child("DialogueLabel",    true, false)
	choice_panel    = find_child("ChoicePanel",      true, false)
	choice_label    = find_child("ChoiceLabel",      true, false)

	GameManager.oxygen_updated.connect(_on_oxygen)
	GameManager.breath_prompt_show.connect(_on_prompt_show)
	GameManager.breath_prompt_hide.connect(_on_prompt_hide)
	GameManager.breath_progress.connect(_on_breath_progress)
	GameManager.breath_taken.connect(_on_breath_taken)
	GameManager.dialogue_requested.connect(_on_dialogue)
	GameManager.choice_requested.connect(_on_choice)
	GameManager.panic_updated.connect(_on_panic)
	GameManager.game_over.connect(_on_game_over)

	if prompt:          prompt.visible       = false
	if dialogue_box:    dialogue_box.visible = false
	if choice_panel:    choice_panel.visible = false
	if breath_hold_bar: breath_hold_bar.value = 0.0
	if panic_bar:       panic_bar.modulate = Color(0.8, 0.0, 0.8)

func _on_oxygen(p_o2: float, c_o2: float) -> void:
	if player_bar:
		player_bar.value = p_o2
		if p_o2 > 60.0:   player_bar.modulate = Color.WHITE
		elif p_o2 > 30.0: player_bar.modulate = Color(1, 0.7, 0)
		else:              player_bar.modulate = Color(1, 0.2, 0.2)
	if car_bar:
		car_bar.value = c_o2
		if c_o2 > 50.0:   car_bar.modulate = Color(0.4, 0.85, 1.0)
		elif c_o2 > 25.0: car_bar.modulate = Color(1, 0.7, 0)
		else:              car_bar.modulate = Color(1, 0.2, 0.2)

func _on_panic(value: float) -> void:
	if panic_bar:
		panic_bar.value = value
		if value > 70.0:
			panic_bar.position.x = 30 + randf_range(-2, 2)

func _on_prompt_show() -> void:
	if not prompt: return
	prompt.visible = true
	var tween = create_tween().set_loops()
	tween.tween_property(prompt, "modulate:a", 0.15, 0.2)
	tween.tween_property(prompt, "modulate:a", 1.0,  0.2)
	prompt.set_meta("flash", tween)

func _on_prompt_hide() -> void:
	if not prompt: return
	prompt.visible = false
	if prompt.has_meta("flash"):
		prompt.get_meta("flash").kill()
		prompt.remove_meta("flash")
	prompt.modulate.a = 1.0

func _on_breath_progress(amount: float) -> void:
	if breath_hold_bar: breath_hold_bar.value = amount

func _on_breath_taken() -> void:
	if breath_hold_bar: breath_hold_bar.value = 0.0
	_on_prompt_hide()

func _on_dialogue(text: String) -> void:
	if not dialogue_box: return
	dialogue_box.text = text
	if dialogue_tween and dialogue_tween.is_valid():
		dialogue_tween.kill()
	dialogue_box.modulate.a = 1.0
	dialogue_box.visible    = true
	dialogue_tween = create_tween()
	dialogue_tween.tween_interval(3.5)
	dialogue_tween.tween_property(dialogue_box, "modulate:a", 0.0, 0.6)
	dialogue_tween.tween_callback(func(): dialogue_box.visible = false)

func _on_choice(prompt_text: String, options: Array) -> void:
	if not choice_panel or not choice_label: return

	# pause the game slightly so player can read
	choice_label.text = prompt_text
	choice_panel.visible = true

	# clear old buttons
	for b in choice_buttons:
		b.queue_free()
	choice_buttons.clear()

	# create a button for each option
	for i in options.size():
		var btn = Button.new()
		btn.text = options[i]
		btn.position = Vector2(20, 60 + i * 50)
		btn.size = Vector2(560, 40)
		var option_text = options[i]
		btn.pressed.connect(func(): _on_choice_selected(option_text))
		choice_panel.add_child(btn)
		choice_buttons.append(btn)

func _on_choice_selected(option: String) -> void:
	choice_panel.visible = false
	for b in choice_buttons:
		b.queue_free()
	choice_buttons.clear()

	# handle choice outcomes
	match option:
		"Force the door with it":
			if GameManager.escape_step == 2:
				GameManager.show_dialogue("I'm using the screwdriver on the door hinges...")
				GameManager.advance_escape_step("screwdriver")
		"Start digging":
			if GameManager.escape_step == 4 and GameManager.has_item("shovel"):
				GameManager.advance_escape_step("shovel")
		"Seal the window cracks":
			GameManager.apply_duct_tape()
		"Save it for later":
			GameManager.show_dialogue("I'll hold onto the duct tape for now.")
		"Check the radio":
			GameManager.show_dialogue("Just static. No signal down here.")
		"Look for anything useful":
			GameManager.show_dialogue("Some loose change and an old receipt. Nothing helpful.")
		"Rest for a moment":
			GameManager.show_dialogue("I can't rest. I need to get out of here.")
		_:
			GameManager.show_dialogue("...")

func _on_game_over(reason: String) -> void:
	var screen = find_child("GameOverScreen", true, false)
	var label  = find_child("ReasonLabel",   true, false)
	if screen: screen.show()
	if label:  label.text = reason + "\n\nClick to restart"
