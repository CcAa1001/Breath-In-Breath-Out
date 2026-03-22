extends Node2D

var darkness:          Node     = null
var pov_manager:       Node     = null
var camera:            Camera2D = null
var shake_amount:      float    = 0.0
var tape_preview:      Node     = null
var panic_shake_amount: float   = 0.0
# FIX 5: lock prevents POV spam
var is_switching_pov:  bool     = false

func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_won.connect(_on_game_won)
	GameManager.item_picked.connect(_on_item_picked)
	GameManager.item_dropped.connect(_on_item_dropped)
	GameManager.panic_updated.connect(_on_panic)
	GameManager.pov_switch_requested.connect(_switch_pov_with_fade)
	GameManager.player_blacked_out.connect(_on_blackout)
	GameManager.panic_shake.connect(_on_panic_shake)
	# FIX 1: connect phone_dead to kill flashlight visual
	GameManager.phone_dead.connect(_on_phone_dead)
	
	var intro    = find_child("IntroScreen",   true, false)
	var tutorial = find_child("TutorialScreen", true, false)

	if intro:
		intro.show_intro(func():
			if tutorial:
				tutorial.show_tutorial(func():
					# game starts — play heavy breath
					var audio = get_node_or_null("AudioManager")
					if audio: audio.play_heavy_breath()
					var a2 = get_node_or_null("AudioManager")
					if a2: a2._on_cue_changed(1))
			else:
				var audio = get_node_or_null("AudioManager")
				if audio: audio.play_heavy_breath())
	elif tutorial:
		tutorial.show_tutorial(func():
			var audio = get_node_or_null("AudioManager")
			if audio: audio.play_heavy_breath())

	darkness     = find_child("DarknessOverlay",      true, false)
	pov_manager  = find_child("POVManager",           true, false)
	camera       = find_child("GameCamera",           true, false)
	tape_preview = find_child("TapePlacementPreview", true, false)

	if darkness:     print("DarknessOverlay OK")
	else:            print("ERROR: DarknessOverlay missing")
	if pov_manager:  print("POVManager OK")
	else:            print("ERROR: POVManager missing")
	if camera:       print("GameCamera OK")
	else:            print("WARNING: GameCamera missing")

	# start cue 1
	await get_tree().create_timer(1.0).timeout
	var audio = get_node_or_null("AudioManager")
	if audio: audio._on_cue_changed(1)
func _start_intro() -> void:
	var intro    = find_child("IntroScreen",    true, false)
	var tutorial = find_child("TutorialScreen", true, false)

	if intro:
		intro.show_intro(func():
			if tutorial:
				tutorial.show_tutorial(func():
					# heavy breath plays here — after tutorial, when game actually starts
					var audio = get_node_or_null("AudioManager")
					if audio:
						audio.play_heavy_breath()
						audio._on_cue_changed(1))
			else:
				var audio = get_node_or_null("AudioManager")
				if audio:
					audio.play_heavy_breath()
					audio._on_cue_changed(1))
	elif tutorial:
		tutorial.show_tutorial(func():
			var audio = get_node_or_null("AudioManager")
			if audio:
				audio.play_heavy_breath()
				audio._on_cue_changed(1))
				
func _on_panic_shake(amount: float) -> void:
	panic_shake_amount = amount

# FIX 1: kill flashlight visual when phone dies
func _on_phone_dead() -> void:
	if darkness and darkness.has_method("toggle_light"):
		if GameManager.flashlight_active == false:
			darkness.toggle_light()

func _process(delta: float) -> void:
	if GameManager.is_dead: return

	# panic shake
	if panic_shake_amount > 0.0 and camera:
		camera.offset += Vector2(
			randf_range(-panic_shake_amount, panic_shake_amount),
			randf_range(-panic_shake_amount, panic_shake_amount)) * delta * 10.0

	if Input.is_action_pressed("breathe"):
		GameManager.hold_space(delta)
	if Input.is_action_just_released("breathe"):
		GameManager.release_space()

	if Input.is_action_pressed("use_jack"):
		var pov = str(pov_manager.get("current_pov")) if pov_manager else ""
		if pov == "front" or pov == "":
			GameManager.hold_jack(delta)
		elif Input.is_action_just_pressed("use_jack"):
			GameManager.show_dialogue("I need to be at the front door.")

	if Input.is_action_just_pressed("flashlight"):
		_toggle_flashlight()
	if Input.is_action_just_pressed("open_phone"):
		_open_phone()
	if Input.is_action_just_pressed("toggle_panel"):
		var panel = find_child("Panel", true, false)
		if panel: panel.visible = !panel.visible

	# ESC — check tape first then go to menu
	if Input.is_action_just_pressed("ui_cancel"):
		if GameManager.is_dead: return
		if tape_preview and tape_preview.get("active") == true:
			tape_preview.deactivate()
			GameManager.show_dialogue("Tape placement cancelled.")
		else:
			GameManager.reset()
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

	if shake_amount > 0.0:
		shake_amount = max(shake_amount - delta * 3.0, 0.0)
		if camera:
			camera.offset = Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount))
	elif panic_shake_amount <= 0.0 and camera:
		camera.offset = Vector2.ZERO

# -------------------------------------------------------
# LEFT CLICK = use active item
# -------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_dead: return
	if not event is InputEventMouseButton: return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if not event.pressed: return

	# block if choice panel open
	var choice_panel = get_node_or_null("UI/ChoicePanel")
	if choice_panel and choice_panel.visible: return

	# block if phone open
	var phone = find_child("PhoneScreen", true, false)
	if phone and phone.visible: return

	var inv_ui = find_child("InventoryPanel", true, false)
	if not inv_ui or not inv_ui.has_method("get_active_item"): return
	var item = inv_ui.get_active_item()
	if item == "": return

	# consume immediately — nothing else fires after this
	get_viewport().set_input_as_handled()

	var world_pos = get_canvas_transform().affine_inverse() * event.position

	match item:
		"duct_tape":        _use_tape_at(world_pos)
		"cutter":           _use_cutter()
		"screwdriver":      _use_screwdriver()
		"hammer":           _use_hammer()
		"shovel":           _use_shovel()
		"emergency_number": _use_emergency_number()
		"car_jack":
			GameManager.show_dialogue("Hold E near the front door to use the jack.")
		_:
			GameManager.show_dialogue("Can't use " + item.replace("_", " ") + " here.")
			
# -------------------------------------------------------
# TAPE PLACEMENT
# -------------------------------------------------------
func _use_tape_at(world_pos: Vector2) -> void:
	if not GameManager.has_item("duct_tape"):
		GameManager.show_dialogue("I don't have duct tape.")
		return

	if tape_preview and tape_preview.get("active") == true:
		_place_tape_at_preview()
		return

	var crack_nodes = _get_crack_nodes()

	for crack_node in crack_nodes:
		# ONLY check is_visible_in_tree — no pov string checks at all
		if not crack_node.is_visible_in_tree(): continue

		var rect = _get_crack_rect(crack_node)
		if rect.has_point(world_pos):
			var wid   = crack_node.get("window_id")
			var phase = GameManager.glass_phases.get(wid, 0)
			if phase == 0:
				GameManager.show_dialogue("This window is fine.")
				return
			elif phase >= 4:
				GameManager.show_dialogue("Too late — already shattered!")
				return
			if tape_preview:
				tape_preview.reset_transform()
				tape_preview.activate()
				GameManager.show_dialogue(
					"Scroll = rotate  |  Left click = place  |  Esc = cancel")
			return

	GameManager.show_dialogue("Click on a cracked window area first.")
	
func _place_tape_at_preview() -> void:
	if not tape_preview: return
	var crack_nodes = _get_crack_nodes()

	for crack_node in crack_nodes:
		# FIX 3: use is_visible_in_tree() to prevent cross-POV taping
		if not crack_node.is_visible_in_tree(): continue
		var rect = _get_crack_rect(crack_node)
		if rect.has_point(tape_preview.global_position):
			var wid   = crack_node.get("window_id")
			var phase = GameManager.glass_phases.get(wid, 0)
			if phase == 0:
				GameManager.show_dialogue("No crack here.")
				tape_preview.deactivate()
				return
			elif phase >= 4:
				GameManager.show_dialogue("Too late — already shattered!")
				tape_preview.deactivate()
				return
			crack_node.stamp_tape(
				tape_preview.global_position,
				tape_preview.rotation,
				tape_preview.scale)
			GameManager.apply_tape_to_window(wid)
			tape_preview.deactivate()
			return

	GameManager.show_dialogue("Move the tape over a cracked window zone first.")

func _get_crack_nodes() -> Array:
	var nodes: Array = []
	var all_paths = [
		"POVManager/FrontRow/WindowCrack_front",
		"POVManager/FrontRow/WindowCrack_left",
		"POVManager/FrontRow/WindowCrack_right",
		"POVManager/BackRow/WindowCrack_rear",
	]
	for path in all_paths:
		var n = get_node_or_null(path)
		if n and n.get("spawn_width") != null:
			nodes.append(n)
	return nodes

func _get_crack_rect(crack_node: Node) -> Rect2:
	var hw = float(crack_node.get("spawn_width"))  / 2.0
	var hh = float(crack_node.get("spawn_height")) / 2.0
	return Rect2(
		crack_node.global_position - Vector2(hw, hh),
		Vector2(hw * 2.0, hh * 2.0))

# -------------------------------------------------------
# ITEM FUNCTIONS
# -------------------------------------------------------
func _use_cutter() -> void:
	if GameManager.seatbelt_cut:
		GameManager.show_dialogue("Already cut the seatbelt.")
		return
	var pov = str(pov_manager.get("current_pov")) if pov_manager else ""
	if pov == "back" or pov == "trunk" or pov == "glovebox":
		GameManager.show_dialogue("Go to the front seat to cut the seatbelt.")
		return
	GameManager.cut_seatbelt()
	var audio = get_node_or_null("AudioManager")
	if audio: audio.play("cut")
	_swap_front_seat_image()

func _swap_front_seat_image() -> void:
	var car_image = get_node_or_null("POVManager/FrontRow/CarImage")
	if not car_image: return
	var tex = load("res://assets/front_seat_cut.png")
	if tex: car_image.texture = tex

func _use_screwdriver() -> void:
	var pov = str(pov_manager.get("current_pov")) if pov_manager else ""
	if GameManager.escape_step >= 3:
		GameManager.request_pov_switch("glovebox")
		return
	if pov == "back" or pov == "trunk":
		GameManager.show_dialogue("Go to the front seat to use the screwdriver.")
		return
	if GameManager.escape_step < 2:
		GameManager.show_dialogue("Nothing to pry open yet.")
		return
	GameManager.show_dialogue("Prying the glove box open...")
	GameManager.escape_step = max(GameManager.escape_step, 3)
	GameManager.emit_signal("escape_step_changed", GameManager.escape_step)
	var audio = get_node_or_null("AudioManager")
	if audio: audio.play("glove_open")
	await get_tree().create_timer(0.8).timeout
	GameManager.request_pov_switch("glovebox")

func _use_hammer() -> void:
	var inv_ui = find_child("InventoryPanel", true, false)
	if inv_ui and inv_ui.has_method("deselect_all"):
		inv_ui.deselect_all()

	if GameManager.rescue_called:
		GameManager.use_hammer_for_noise()
	else:
		GameManager.show_choice("Use the hammer?", [
			"Bang on car — signal rescue",
			"Break a window (BAD IDEA)",
			"Keep it for now"])

func _use_shovel() -> void:
	if not GameManager.jack_complete:
		GameManager.show_dialogue("Force the door open first with the car jack.")
		return

	# deselect item so choice panel works cleanly
	var inv_ui = find_child("InventoryPanel", true, false)
	if inv_ui and inv_ui.has_method("deselect_all"):
		inv_ui.deselect_all()

	if not GameManager.cue_2_started and not GameManager.rescue_called:
		GameManager.show_choice(
			"The door is open. What do you do?",
			["Start digging!", "Wait for rescue"])
	else:
		GameManager.show_choice(
			"Rescue is coming. What do you do?",
			["Start digging!", "Wait for rescue instead"])

func _use_emergency_number() -> void:
	if not GameManager.has_emergency_number:
		GameManager.has_emergency_number = true
	GameManager.show_dialogue("The number is 112. Open my phone and call it.")

# -------------------------------------------------------
# FLASHLIGHT
# -------------------------------------------------------
func _toggle_flashlight() -> void:
	if not GameManager.phone_collected:
		GameManager.show_dialogue("I need to find my phone first.")
		return
	if GameManager.battery <= 0.0 or GameManager.phone_is_dead:
		GameManager.show_dialogue("My phone is dead. No flashlight.")
		return
	var turning_on = not GameManager.flashlight_active
	GameManager.set_flashlight(turning_on)
	if darkness and GameManager.flashlight_active == turning_on:
		darkness.toggle_light()
	var audio = get_node_or_null("AudioManager")
	if audio: audio.play("flash")

# -------------------------------------------------------
# PHONE
# -------------------------------------------------------
func _open_phone() -> void:
	if not GameManager.phone_collected:
		GameManager.show_dialogue("I don't have my phone.")
		return
	if GameManager.phone_is_dead or GameManager.battery <= 0.0:
		GameManager.show_dialogue("My phone is dead.")
		return
	var phone_ui = find_child("PhoneScreen", true, false)
	if phone_ui:
		phone_ui.open_phone()
		var audio = get_node_or_null("AudioManager")
		if audio: audio.play("click")
	else:
		print("ERROR: PhoneScreen not found")

# -------------------------------------------------------
# SHAKE
# -------------------------------------------------------
func trigger_shake(amount: float) -> void:
	shake_amount = max(shake_amount, amount)

# -------------------------------------------------------
# POV FADE — FIX 5: lock prevents spam
# -------------------------------------------------------
func _switch_pov_with_fade(target: String) -> void:
	if pov_manager == null or is_switching_pov: return
	is_switching_pov = true

	var overlay = ColorRect.new()
	overlay.color        = Color(0, 0, 0, 0)
	overlay.size         = Vector2(1920, 1080)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index      = 100
	add_child(overlay)
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.3)
	await tween.finished
	pov_manager.switch_to(target)
	await get_tree().create_timer(0.2).timeout
	var tween2 = create_tween()
	tween2.tween_property(overlay, "color:a", 0.0, 0.3)
	await tween2.finished
	overlay.queue_free()
	is_switching_pov = false

# -------------------------------------------------------
# SIGNALS
# -------------------------------------------------------
func _on_blackout(is_out: bool) -> void:
	var overlay = get_node_or_null("UI/BlackoutOverlay")
	if overlay:
		var tween = create_tween()
		tween.tween_property(overlay, "modulate:a",
			0.7 if is_out else 0.0, 0.3)
	if is_out:
		GameManager.show_dialogue("I can't breathe... hold SPACE NOW!")

func _on_panic(value: float) -> void:
	if value > 50.0:
		trigger_shake(randf_range(0.0, (value - 50.0) / 10.0))

func _on_game_over(reason: String) -> void:
	# force close phone
	var phone_ui = find_child("PhoneScreen", true, false)
	if phone_ui and phone_ui.visible:
		phone_ui.hide()
		var blocker = phone_ui.get("click_blocker")
		if blocker: blocker.visible = false

	var screen = get_node_or_null("UI/GameOverScreen")
	var label  = get_node_or_null("UI/GameOverScreen/ReasonLabel")
	var bg     = get_node_or_null("UI/GameOverScreen/EndingBG")
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
	print("GAME WON: ", ending)
	# force close phone
	var phone_ui = find_child("PhoneScreen", true, false)
	if phone_ui and phone_ui.visible:
		phone_ui.hide()
		var blocker = phone_ui.get("click_blocker")
		if blocker: blocker.visible = false

	# try multiple paths for the screen
	var screen = get_node_or_null("UI/GameOverScreen")
	if not screen: screen = find_child("GameOverScreen", true, false)
	var label  = get_node_or_null("UI/GameOverScreen/ReasonLabel")
	if not label: label = find_child("ReasonLabel", true, false)
	var bg     = get_node_or_null("UI/GameOverScreen/EndingBG")
	if not bg: bg = find_child("EndingBG", true, false)

	print("Screen: ", screen != null, " Label: ", label != null, " BG: ", bg != null)

	if screen: screen.show()

	match ending:
		"dig":
			if bg and ResourceLoader.exists("res://assets/ending_dig.png"):
				bg.texture  = load("res://assets/ending_dig.png")
				bg.visible  = true
				if label: label.visible = false
			else:
				print("ending_dig.png NOT FOUND at res://assets/ending_dig.png")
				if label:
					label.visible = true
					label.text    = "You dug your way out!\n\nFresh air. You're free.\n\nClick to play again"
		"rescue":
			if bg and ResourceLoader.exists("res://assets/ending_dig.png"):
				bg.texture = load("res://assets/ending_dig.png")
				bg.visible = true
				if label: label.visible = false
			else:
				if label:
					label.visible = true
					label.text    = "Rescue arrived!\n\nYou survived.\n\nClick to play again"
		_:
			if bg: bg.visible = false
			if label:
				label.visible = true
				label.text    = "You escaped!\n\nClick to play again"

func _on_item_picked(_item: String) -> void:
	_update_inventory()

func _on_item_dropped(_item: String) -> void:
	_update_inventory()

func _update_inventory() -> void:
	var label = get_node_or_null("UI/InventoryLabel")
	if label:
		var items = GameManager.inventory.duplicate()
		if GameManager.phone_collected:
			items.append("phone")
		label.text = "Inventory: " + (", ".join(items) if items.size() > 0 else "empty")
