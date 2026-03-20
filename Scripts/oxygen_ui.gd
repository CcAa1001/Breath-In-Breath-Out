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
var rescue_label:    Label

func _ready() -> void:
	player_bar      = find_child("PlayerOxygenBar",  true, false)
	car_bar         = find_child("CarOxygenBar",     true, false)
	panic_bar       = find_child("PanicBar",         true, false)
	prompt          = find_child("BreathPrompt",     true, false)
	breath_hold_bar = find_child("BreathHoldBar",    true, false)
	dialogue_box    = find_child("DialogueLabel",    true, false)
	choice_panel    = find_child("ChoicePanel",      true, false)
	choice_label    = find_child("ChoiceLabel",      true, false)
	rescue_label    = find_child("RescueTimerLabel", true, false)

	if not player_bar:   print("MISSING: PlayerOxygenBar")
	if not car_bar:      print("MISSING: CarOxygenBar")
	if not dialogue_box: print("MISSING: DialogueLabel")
	if not choice_panel: print("MISSING: ChoicePanel")

	GameManager.oxygen_updated.connect(_on_oxygen)
	GameManager.breath_prompt_show.connect(_on_prompt_show)
	GameManager.breath_prompt_hide.connect(_on_prompt_hide)
	GameManager.breath_progress.connect(_on_breath_progress)
	GameManager.breath_taken.connect(_on_breath_taken)
	GameManager.dialogue_requested.connect(_on_dialogue)
	GameManager.choice_requested.connect(_on_choice)
	GameManager.panic_updated.connect(_on_panic)
	GameManager.battery_updated.connect(_on_battery)
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_won.connect(_on_game_won)
	GameManager.rescue_timer_updated.connect(_on_rescue_timer)

	if prompt:          prompt.visible        = false
	if dialogue_box:    dialogue_box.visible  = false
	if choice_panel:    choice_panel.visible  = false
	if rescue_label:    rescue_label.visible  = false
	if breath_hold_bar: breath_hold_bar.value = 0.0
	if panic_bar:       panic_bar.modulate    = Color(0.8, 0.0, 0.8)

# -------------------------------------------------------
# OXYGEN
# -------------------------------------------------------
func _on_oxygen(p_o2: float, c_o2: float) -> void:
	if player_bar:
		player_bar.value = p_o2
		if p_o2 > 60.0:
			player_bar.modulate = Color.WHITE
		elif p_o2 > 30.0:
			player_bar.modulate = Color(1, 0.7, 0)
		else:
			player_bar.modulate = Color(1, 0.2, 0.2)

	if car_bar:
		car_bar.value = c_o2
		if c_o2 > 50.0:
			car_bar.modulate = Color(0.4, 0.85, 1.0)
		elif c_o2 > 25.0:
			car_bar.modulate = Color(1, 0.7, 0)
		else:
			car_bar.modulate = Color(1, 0.2, 0.2)

# -------------------------------------------------------
# BATTERY — handled by battery_icon.gd, but kept here as fallback
# -------------------------------------------------------
func _on_battery(value: float) -> void:
	# battery_icon.gd handles the image swapping
	# this is here in case you want a bar fallback
	var bar = find_child("BatteryBar", true, false)
	if bar:
		bar.value = value

# -------------------------------------------------------
# PANIC
# -------------------------------------------------------
func _on_panic(value: float) -> void:
	if not panic_bar:
		return
	panic_bar.value = value
	if value > 70.0:
		panic_bar.position.x = 30 + randf_range(-2, 2)

# -------------------------------------------------------
# BREATH PROMPT
# -------------------------------------------------------
func _on_prompt_show() -> void:
	if not prompt:
		return
	prompt.visible = true
	var tween = create_tween().set_loops()
	tween.tween_property(prompt, "modulate:a", 0.15, 0.2)
	tween.tween_property(prompt, "modulate:a", 1.0,  0.2)
	prompt.set_meta("flash", tween)

func _on_prompt_hide() -> void:
	if not prompt:
		return
	prompt.visible = false
	if prompt.has_meta("flash"):
		prompt.get_meta("flash").kill()
		prompt.remove_meta("flash")
	prompt.modulate.a = 1.0

func _on_breath_progress(amount: float) -> void:
	if breath_hold_bar:
		breath_hold_bar.value = amount

func _on_breath_taken() -> void:
	if breath_hold_bar:
		breath_hold_bar.value = 0.0
	_on_prompt_hide()

# -------------------------------------------------------
# DIALOGUE
# -------------------------------------------------------
func _on_dialogue(text: String) -> void:
	if not dialogue_box:
		print("ERROR: DialogueLabel missing — cannot show: ", text)
		return
	dialogue_box.text = text
	if dialogue_tween and dialogue_tween.is_valid():
		dialogue_tween.kill()
	dialogue_box.modulate.a = 1.0
	dialogue_box.visible    = true
	dialogue_tween = create_tween()
	dialogue_tween.tween_interval(3.5)
	dialogue_tween.tween_property(dialogue_box, "modulate:a", 0.0, 0.6)
	dialogue_tween.tween_callback(func(): dialogue_box.visible = false)

# -------------------------------------------------------
# CHOICE PANEL
# -------------------------------------------------------
func _on_choice(prompt_text: String, options: Array) -> void:
	if not choice_panel or not choice_label:
		print("ERROR: ChoicePanel or ChoiceLabel missing!")
		return

	choice_label.text    = prompt_text
	choice_panel.visible = true

	# clear old buttons
	for b in choice_buttons:
		b.queue_free()
	choice_buttons.clear()

	# create buttons using .bind() to avoid lambda scoping bug
	for i in options.size():
		var btn = Button.new()
		btn.text     = options[i]
		btn.position = Vector2(20, 60 + i * 50)
		btn.size     = Vector2(560, 40)
		btn.pressed.connect(_on_choice_selected.bind(options[i]))
		choice_panel.add_child(btn)
		choice_buttons.append(btn)

func _on_choice_selected(option: String) -> void:
	choice_panel.visible = false
	for b in choice_buttons:
		b.queue_free()
	choice_buttons.clear()

	match option:

		# ---- ESCAPE / DIGGING ----
		"Start digging!":
			if GameManager.has_item("shovel") and GameManager.jack_complete:
				GameManager.show_dialogue("Digging... almost there...")
				await get_tree().create_timer(3.0).timeout
				GameManager._win("dig")
			else:
				GameManager.show_dialogue("I need the shovel and car jack first.")

		"Wait for rescue instead":
			GameManager.show_dialogue("I'll hold on. They're coming.")

		# ---- HAMMER ----
		"Bang for rescue", "Bang on the car for rescue":
			GameManager.use_hammer_for_noise()

		"Break a window (bad idea)", "Yes — smash it!":
			GameManager.show_dialogue("*CRASH* — Soil starts pouring in through the broken window!")
			GameManager.glass_phases["left"] = 4
			GameManager.soil_multiplier     += 1.5
			GameManager.emit_signal("soil_speed_changed", GameManager.soil_multiplier)

		"Keep it for now", "Put it away", "No, that's a bad idea":
			GameManager.show_dialogue("I'll hold onto it for now.")

		# ---- DUCT TAPE ----
		"Tape it now":
			# show window selection
			GameManager.show_choice(
				"Which window do you want to tape?",
				["Front window", "Left window", "Right window", "Rear window"])

		"Leave it for now", "Leave it":
			GameManager.show_dialogue("I'll come back to it... hopefully in time.")

		# ---- WINDOW SELECTION FOR TAPING ----
		"Front window":
			GameManager.use_duct_tape_on("front")
		"Left window":
			GameManager.use_duct_tape_on("left")
		"Right window":
			GameManager.use_duct_tape_on("right")
		"Rear window":
			GameManager.use_duct_tape_on("rear")

		# ---- DOOR ----
		"Force the door hinges":
			if GameManager.escape_step >= 3:
				GameManager.show_dialogue("Forcing the door with the screwdriver...")
				GameManager.advance_escape_step("screwdriver")
			else:
				GameManager.show_dialogue("I need to be at the right step to do this.")

		"Look for another way":
			GameManager.show_dialogue("There has to be another way... I don't see one yet.")

		# ---- CENTER CONSOLE ----
		"Check the radio":
			GameManager.show_dialogue("Static. No signal this deep underground.")

		"Search for anything useful":
			GameManager.show_dialogue("Some loose change and an old receipt. Nothing useful.")

		"Never mind":
			GameManager.show_dialogue("...")

		# ---- DUCT TAPE FIRST FOUND ----
		"Seal the window cracks":
			GameManager.apply_duct_tape()

		"Save it for later":
			GameManager.show_dialogue("I'll hold onto the duct tape for now.")

		# ---- RESCUE / REST ----
		"Rest for a moment":
			GameManager.show_dialogue("I can't rest. I need to get out of here.")

		_:
			GameManager.show_dialogue("...")

# -------------------------------------------------------
# RESCUE TIMER
# -------------------------------------------------------
func _on_rescue_timer(seconds_left: float) -> void:
	if not rescue_label:
		return
	rescue_label.visible = true
	rescue_label.text    = "🚨 Rescue in: " + str(int(seconds_left)) + "s"
	if seconds_left < 30.0:
		rescue_label.modulate = Color(1, 0.3, 0.3)
	else:
		rescue_label.modulate = Color.WHITE

# -------------------------------------------------------
# GAME OVER / WIN
# -------------------------------------------------------
func _on_game_over(reason: String) -> void:
	var screen = find_child("GameOverScreen", true, false)
	var label  = find_child("ReasonLabel",   true, false)
	if screen: screen.show()
	if label:  label.text = reason + "\n\nClick to restart"

func _on_game_won(ending: String) -> void:
	var screen = find_child("GameOverScreen", true, false)
	var label  = find_child("ReasonLabel",   true, false)
	if screen: screen.show()
	if label:
		match ending:
			"rescue":
				label.text = "You survived until rescue!\n\nThe team broke through. You made it out alive.\n\nClick to play again"
			"dig":
				label.text = "You dug your way out!\n\nFresh air. You're free.\n\nClick to play again"
			_:
				label.text = "You escaped!\n\nClick to play again"
