extends Node2D

var darkness:     Node     = null
var pov_manager:  Node     = null
var camera:       Camera2D = null
var shake_amount: float    = 0.0
var tape_preview: Node     = null

func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_won.connect(_on_game_won)
	GameManager.item_picked.connect(_on_item_picked)
	GameManager.item_dropped.connect(_on_item_dropped)
	GameManager.panic_updated.connect(_on_panic)
	GameManager.pov_switch_requested.connect(_switch_pov_with_fade)
	GameManager.player_blacked_out.connect(_on_blackout)

	darkness     = find_child("DarknessOverlay",       true, false)
	pov_manager  = find_child("POVManager",            true, false)
	camera       = find_child("GameCamera",            true, false)
	tape_preview = find_child("TapePlacementPreview",  true, false)

	if darkness:     print("DarknessOverlay OK")
	else:            print("ERROR: DarknessOverlay missing")
	if pov_manager:  print("POVManager OK")
	else:            print("ERROR: POVManager missing")
	if camera:       print("GameCamera OK")
	else:            print("WARNING: GameCamera missing")
	if tape_preview: print("TapePlacementPreview OK")
	else:            print("WARNING: TapePlacementPreview missing")

func _process(delta: float) -> void:
	if GameManager.is_dead: return

	# SPACE = breathe
	if Input.is_action_pressed("breathe"):
		GameManager.hold_space(delta)
	if Input.is_action_just_released("breathe"):
		GameManager.release_space()

	# E = car jack
	if Input.is_action_pressed("use_jack"):
		GameManager.hold_jack(delta)

	# F = flashlight only
	if Input.is_action_just_pressed("flashlight"):
		_toggle_flashlight()

	# P = phone
	if Input.is_action_just_pressed("open_phone"):
		_open_phone()

	# M = master panel
	if Input.is_action_just_pressed("toggle_panel"):
		var panel = find_child("Panel", true, false)
		if panel: panel.visible = !panel.visible

	# screen shake
	if shake_amount > 0.0:
		shake_amount = max(shake_amount - delta * 3.0, 0.0)
		if camera:
			camera.offset = Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount))
	elif camera:
		camera.offset = Vector2.ZERO

# -------------------------------------------------------
# LEFT CLICK = use active item
# -------------------------------------------------------
func _input(event: InputEvent) -> void:
	if GameManager.is_dead: return
	if not event is InputEventMouseButton: return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if not event.pressed: return

	var inv_ui = find_child("InventoryPanel", true, false)
	if not inv_ui or not inv_ui.has_method("get_active_item"): return
	var item = inv_ui.get_active_item()
	if item == "": return

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
			GameManager.show_dialogue("Hold E near the door to place the car jack.")
		_:
			GameManager.show_dialogue("Can't use " + item.replace("_", " ") + " here.")

# -------------------------------------------------------
# TAPE PLACEMENT
# -------------------------------------------------------
func _use_tape_at(world_pos: Vector2) -> void:
	if not GameManager.has_item("duct_tape"):
		GameManager.show_dialogue("I don't have duct tape.")
		return

	# if preview already active — this click = PLACE the tape
	if tape_preview and tape_preview.get("active") == true:
		_place_tape_at_preview()
		return

	# first click — check we're over a cracked window zone
	var crack_nodes = _get_crack_nodes()
	for crack_node in crack_nodes:
		if not crack_node.visible: continue
		var rect = _get_crack_rect(crack_node)
		if rect.has_point(world_pos):
			var wid   = crack_node.get("window_id")
			var phase = GameManager.glass_phases.get(wid, 0)
			if phase == 0:
				GameManager.show_dialogue("This window is fine — save the tape.")
				return
			elif phase >= 4:
				GameManager.show_dialogue("Too late — already shattered!")
				return
			# activate preview ghost
			if tape_preview:
				tape_preview.reset_transform()
				tape_preview.activate()
				GameManager.show_dialogue(
					"Scroll = rotate  |  +/- = resize  |  Left click = place  |  Esc = cancel")
			return

	GameManager.show_dialogue("Click on a cracked window area first.")

func _place_tape_at_preview() -> void:
	if not tape_preview: return
	var crack_nodes = _get_crack_nodes()

	for crack_node in crack_nodes:
		if not crack_node.visible: continue
		var rect = _get_crack_rect(crack_node)

		# use tape_preview.global_position — this is world space
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

			# pass global_position — crack_node.stamp_tape converts to local
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
	for id in ["front", "left", "right"]:
		var n = get_node_or_null("POVManager/FrontRow/WindowCrack_" + id)
		if n and n.get("spawn_width") != null:
			nodes.append(n)
	var rear = get_node_or_null("POVManager/BackRow/WindowCrack_rear")
	if rear and rear.get("spawn_width") != null:
		nodes.append(rear)
	# group fallback
	if nodes.is_empty():
		for n in get_tree().get_nodes_in_group("window_crack"):
			if n.get("spawn_width") != null:
				nodes.append(n)
	return nodes

func _get_crack_rect(crack_node: Node) -> Rect2:
	var hw = float(crack_node.get("spawn_width"))  / 2.0
	var hh = float(crack_node.get("spawn_height")) / 2.0
	return Rect2(
		crack_node.global_position - Vector2(hw, hh),
		Vector2(hw * 2.0, hh * 2.0))

# -------------------------------------------------------
# OTHER ITEM FUNCTIONS
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
	if audio: audio.play("seatbelt")

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
	if audio: audio.play("glove_box")
	await get_tree().create_timer(0.8).timeout
	GameManager.request_pov_switch("glovebox")

func _use_hammer() -> void:
	if GameManager.rescue_called:
		GameManager.use_hammer_for_noise()
	else:
		GameManager.show_choice("Use the hammer?", [
			"Bang on car for noise",
			"Break a window (BAD IDEA)",
			"Put it away"])

func _use_shovel() -> void:
	var pov = str(pov_manager.get("current_pov")) if pov_manager else ""
	if GameManager.jack_complete and pov == "trunk":
		GameManager.show_choice("Dig out?", [
			"Start digging!",
			"Wait for rescue instead"])
	elif not GameManager.jack_complete:
		GameManager.show_dialogue("Force the door open first.")
	else:
		GameManager.show_dialogue("Go to the trunk to dig out.")

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
	if audio: audio.play_flashlight()

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
		if audio: audio.play_phone_click()
	else:
		print("ERROR: PhoneScreen not found")

# -------------------------------------------------------
# SHAKE
# -------------------------------------------------------
func trigger_shake(amount: float) -> void:
	shake_amount = max(shake_amount, amount)

# -------------------------------------------------------
# POV FADE
# -------------------------------------------------------
func _switch_pov_with_fade(target: String) -> void:
	if pov_manager == null: return
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
	if value > 80.0:
		trigger_shake(randf_range(0.0, 5.0))

func _on_game_over(reason: String) -> void:
	var screen = get_node_or_null("UI/GameOverScreen")
	var label  = get_node_or_null("UI/GameOverScreen/ReasonLabel")
	if screen: screen.show()
	if label:  label.text = reason + "\n\nClick to restart"

func _on_game_won(ending: String) -> void:
	var screen = get_node_or_null("UI/GameOverScreen")
	var label  = get_node_or_null("UI/GameOverScreen/ReasonLabel")
	if screen: screen.show()
	if label:
		match ending:
			"rescue":
				label.text = "You survived until rescue!\n\nThe team broke through. You made it out.\n\nClick to play again"
			"dig":
				label.text = "You dug your way out!\n\nFresh air. You're free.\n\nClick to play again"
			_:
				label.text = "You escaped!\n\nClick to play again"

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
