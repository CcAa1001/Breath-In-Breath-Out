extends CanvasLayer

var player_bar:      Node
var car_bar:         Node
var panic_bar:       Node
var prompt:          Label
var breath_hold_bar: Node
var dialogue_box:    Label
var dialogue_tween:  Tween
var choice_panel:    Panel
var choice_label:    Label
var choice_buttons:  Array = []
var rescue_label:    Label
var blackout_label:  Label
var blackout_tween:  Tween
var jack_bar:        Node

func _ready() -> void:
	player_bar      = find_child("PlayerOxygenBar",   true, false)
	car_bar         = find_child("CarOxygenBar",      true, false)
	panic_bar       = find_child("PanicBar",          true, false)
	prompt          = find_child("BreathPrompt",      true, false)
	breath_hold_bar = find_child("BreathHoldBar",     true, false)
	dialogue_box    = find_child("DialogueLabel",     true, false)
	choice_panel    = find_child("ChoicePanel",       true, false)
	choice_label    = find_child("ChoiceLabel",       true, false)
	rescue_label    = find_child("RescueTimerLabel",  true, false)
	blackout_label  = find_child("BlackoutCountdown", true, false)
	jack_bar        = find_child("JackProgressBar",   true, false)

	print("PlayerOxygenBar: ", player_bar.get_class() if player_bar else "NOT FOUND")
	print("CarOxygenBar: ",    car_bar.get_class()    if car_bar    else "NOT FOUND")
	if not dialogue_box: print("MISSING: DialogueLabel")
	if not choice_panel: print("MISSING: ChoicePanel")

	# connect signals — oxygen handled in _process instead
	GameManager.breath_prompt_show.connect(_on_prompt_show)
	GameManager.breath_prompt_hide.connect(_on_prompt_hide)
	GameManager.breath_progress.connect(_on_breath_progress)
	GameManager.breath_taken.connect(_on_breath_taken)
	GameManager.dialogue_requested.connect(_on_dialogue)
	GameManager.choice_requested.connect(_on_choice)
	GameManager.panic_updated.connect(_on_panic)
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_won.connect(_on_game_won)
	GameManager.rescue_timer_updated.connect(_on_rescue_timer)
	GameManager.player_blacked_out.connect(_on_blackout)
	GameManager.escape_step_changed.connect(_on_escape_step_for_jack)
	GameManager.jack_progress_updated.connect(_on_jack_progress)

	if prompt:         prompt.visible         = false
	if dialogue_box:   dialogue_box.visible   = false
	if choice_panel:   choice_panel.visible   = false
	if rescue_label:   rescue_label.visible   = false
	if blackout_label: blackout_label.visible = false

	if breath_hold_bar:
		breath_hold_bar.set("value", 0.0)
	if panic_bar:
		panic_bar.modulate = Color(0.8, 0.0, 0.8)
	if jack_bar:
		jack_bar.visible = false
		jack_bar.set("min_value", 0.0)
		jack_bar.set("max_value", 1.0)
		jack_bar.set("value",     0.0)
	if player_bar:
		player_bar.set("min_value", 0.0)
		player_bar.set("max_value", 100.0)
		player_bar.set("value",     100.0)
	if car_bar:
		car_bar.set("min_value", 0.0)
		car_bar.set("max_value", 100.0)
		car_bar.set("value",     100.0)

# -------------------------------------------------------
# PROCESS — updates bars every frame directly
# bypasses signal system completely for 100% reliability
# -------------------------------------------------------
func _process(_delta: float) -> void:
	if not GameManager.game_running: return

	if player_bar: player_bar.set("value", GameManager.player_o2)
	if car_bar:    car_bar.set("value",    GameManager.car_o2)

	# red vignette when car O2 is low
	var red_overlay = find_child("HeartbeatOverlay", true, false)
	if red_overlay:
		var car_danger = clamp(1.0 - (GameManager.car_o2 / 30.0), 0.0, 1.0)
		red_overlay.modulate = Color(1, 0.1, 0.1,
			clamp(car_danger * 0.5 + GameManager.panic / 300.0, 0.0, 0.6))

	# color updates
	if player_bar:
		var p = GameManager.player_o2
		if p > 60.0:   player_bar.modulate = Color.WHITE
		elif p > 30.0: player_bar.modulate = Color(1, 0.7, 0)
		else:          player_bar.modulate = Color(1, 0.2, 0.2)
	if car_bar:
		var c = GameManager.car_o2
		if c > 50.0:   car_bar.modulate = Color(0.4, 0.85, 1.0)
		elif c > 25.0: car_bar.modulate = Color(1, 0.7, 0)
		else:          car_bar.modulate = Color(1, 0.2, 0.2)

# -------------------------------------------------------
# PANIC
# -------------------------------------------------------
func _on_panic(value: float) -> void:
	if not panic_bar: return
	panic_bar.set("value", value)

	# red screen overlay when car O2 low
	var red = find_child("HeartbeatOverlay", true, false)
	if red:
		red.modulate = Color(1, 0, 0, clamp(value / 200.0, 0.0, 0.4))


# -------------------------------------------------------
# BLACKOUT
# -------------------------------------------------------
func _on_blackout(is_out: bool) -> void:
	if is_out:
		_start_blackout_countdown()
	else:
		_stop_blackout_countdown()

func _start_blackout_countdown() -> void:
	if not blackout_label: return
	blackout_label.visible = true
	var time_left = GameManager.blackout_death_time
	if blackout_tween and blackout_tween.is_valid():
		blackout_tween.kill()
	blackout_tween = create_tween()
	blackout_tween.tween_method(
		func(v: float):
			if blackout_label and blackout_label.visible:
				blackout_label.text = str(ceil(v))
				var urgency = 1.0 - (v / GameManager.blackout_death_time)
				blackout_label.modulate = Color(1, 1 - urgency, 1 - urgency),
		time_left, 0.0, time_left)

func _stop_blackout_countdown() -> void:
	if blackout_label: blackout_label.visible = false
	if blackout_tween and blackout_tween.is_valid():
		blackout_tween.kill()

# -------------------------------------------------------
# CAR JACK
# -------------------------------------------------------
func _on_jack_progress(amount: float) -> void:
	if not jack_bar: return
	if amount >= 1.0 or GameManager.jack_complete:
		jack_bar.visible = false
		return
	if amount > 0.0:
		jack_bar.visible = true
		jack_bar.set("value", amount)
	else:
		jack_bar.visible = false

func _on_escape_step_for_jack(step: int) -> void:
	if step >= 6 and jack_bar:
		jack_bar.visible = false

# -------------------------------------------------------
# BREATH PROMPT
# -------------------------------------------------------
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
	if breath_hold_bar:
		breath_hold_bar.set("value", amount)

func _on_breath_taken() -> void:
	if breath_hold_bar:
		breath_hold_bar.set("value", 0.0)
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
	for b in choice_buttons:
		b.queue_free()
	choice_buttons.clear()
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
		"Start digging!":
			if GameManager.has_item("shovel") and GameManager.jack_complete:
				GameManager.show_dialogue("Digging frantically upward...")
				await get_tree().create_timer(3.0).timeout
				GameManager._win("dig")
			else:
				GameManager.show_dialogue("I need the shovel and car jack first.")

		"Wait and see":
			GameManager.show_dialogue("I'll wait... hopefully the right choice.")

		"Wait for rescue instead":
			GameManager.show_dialogue("Help is coming. Just hold on a little longer.")

		"Bang on the car for rescue", "Bang for rescue":
			GameManager.use_hammer_for_noise()

		"Break a window (bad idea)", "Yes — smash it!":
			GameManager.show_dialogue("*CRASH* — Soil starts pouring in!")
			GameManager.glass_phases["left"] = 4
			GameManager.soil_multiplier     += 1.5
			GameManager.emit_signal("soil_speed_changed", GameManager.soil_multiplier)

		"Keep it for now", "Put it away", "No, that's a bad idea":
			GameManager.show_dialogue("I'll hold onto it for now.")

		"Tape it now":
			GameManager.apply_duct_tape()

		"Leave it for now", "Leave it":
			GameManager.show_dialogue("I'll come back to it... hopefully in time.")

		"Front windshield": GameManager.use_duct_tape_on("front")
		"Left window":      GameManager.use_duct_tape_on("left")
		"Right window":     GameManager.use_duct_tape_on("right")

		"Force the door hinges":
			if GameManager.escape_step >= 3:
				GameManager.show_dialogue("Forcing the door with the screwdriver...")
				GameManager.advance_escape_step("screwdriver")
			else:
				GameManager.show_dialogue("I need to be further along to do this.")

		"Look for another way":
			GameManager.show_dialogue("There has to be another way... I don't see one yet.")

		"Check the radio":
			GameManager.show_dialogue("Static. No signal this deep underground.")

		"Search for anything useful":
			GameManager.show_dialogue("Some loose change and an old receipt. Nothing useful.")

		"Never mind":
			GameManager.show_dialogue("...")

		"Seal the window cracks":
			GameManager.apply_duct_tape()

		"Save it for later":
			GameManager.show_dialogue("I'll hold onto the duct tape for now.")

		"Rest for a moment":
			GameManager.show_dialogue("I can't rest. I need to get out of here.")
			
		"Dig — I'll take my chances":
			GameManager.show_dialogue("Digging frantically... the soil collapses in!")
			await get_tree().create_timer(2.0).timeout
			GameManager._die("The soil caved in. You were buried alive.")

		_:
			GameManager.show_dialogue("...")

# -------------------------------------------------------
# RESCUE TIMER
# -------------------------------------------------------
func _on_rescue_timer(seconds_left: float) -> void:
	if not rescue_label: return
	rescue_label.visible  = true
	rescue_label.text     = "🚨 Rescue in: " + str(int(seconds_left)) + "s"
	rescue_label.modulate = Color(1, 0.3, 0.3) if seconds_left < 30.0 else Color.WHITE

# -------------------------------------------------------
# GAME OVER / WIN
# -------------------------------------------------------
func _on_game_over(reason: String) -> void:
	var screen = find_child("GameOverScreen", true, false)
	var label  = find_child("ReasonLabel",    true, false)
	var bg     = find_child("EndingBG",       true, false)
	if screen: screen.show()
	match reason:
		"suffocated":
			if bg and ResourceLoader.exists("res://assets/ending_suffocated.png"):
				bg.texture = load("res://assets/ending_suffocated.png")
				bg.visible = true
			if label: label.visible = false
		"buried":
			if bg and ResourceLoader.exists("res://assets/ending_buried.png"):
				bg.texture = load("res://assets/ending_buried.png")
				bg.visible = true
			if label: label.visible = false
		_:
			if bg: bg.visible = false
			if label:
				label.visible = true
				label.text = reason + "\n\nClick to try again"

func _on_game_won(ending: String) -> void:
	var screen = find_child("GameOverScreen", true, false)
	var label  = find_child("ReasonLabel",    true, false)
	var bg     = find_child("EndingBG",       true, false)
	if screen: screen.show()

	match ending:
		"dig":
			if bg:
				bg.texture = load("res://assets/ending_dig.png")
				bg.visible = true
			if label: label.text = ""
		"rescue":
			if label:
				label.text = "You survived until rescue!\n\nThe team broke through. You made it out.\n\nClick to play again"
		_:
			if label: label.text = "You escaped!\n\nClick to play again"
