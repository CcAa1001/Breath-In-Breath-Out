extends Node2D

var darkness   = null
var pov_manager = null
var camera: Camera2D = null
var shake_amount: float = 0.0
var is_transitioning: bool = false

func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.item_picked.connect(_on_item_picked)
	GameManager.item_dropped.connect(_on_item_dropped)
	GameManager.panic_updated.connect(_on_panic)
	GameManager.escape_step_changed.connect(_on_escape_step)
	GameManager.pov_switch_requested.connect(_switch_pov_with_fade)
	GameManager.player_blacked_out.connect(_on_blackout)

	darkness    = find_child("DarknessOverlay", true, false)
	pov_manager = find_child("POVManager",      true, false)
	camera      = find_child("GameCamera",      true, false)

	if darkness:    print("DarknessOverlay OK")
	else:           print("ERROR: DarknessOverlay missing")
	if pov_manager: print("POVManager OK")
	else:           print("ERROR: POVManager missing")

func _process(delta: float) -> void:
	if GameManager.is_dead: return

	# F = toggle flashlight
	if Input.is_action_just_pressed("flashlight"):
		if GameManager.has_item("phone"):
			var turning_on = not GameManager.flashlight_active
			GameManager.set_flashlight(turning_on)
			# FIX: only toggle visual if state actually changed
			if darkness and GameManager.flashlight_active == turning_on:
				darkness.toggle_light()
		else:
			GameManager.show_dialogue("I need to find my phone first.")
			
	# Space = hold to breathe
	if Input.is_action_pressed("breathe"):
		GameManager.hold_space(delta)
	if Input.is_action_just_released("breathe"):
		GameManager.release_space()

	# E = hold to roll car jack
	if Input.is_action_pressed("use_jack"):
		GameManager.hold_jack(delta)

	# P = open phone
	if Input.is_action_just_pressed("open_phone"):
		_open_phone()

	# M = toggle master panel
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

func trigger_shake(amount: float) -> void:
	shake_amount = max(shake_amount, amount)

func _open_phone() -> void:
	if not GameManager.has_item("phone"):
		GameManager.show_dialogue("I don't have my phone.")
		return
	var phone_ui = find_child("PhoneScreen", true, false)
	if phone_ui:
		phone_ui.visible = not phone_ui.visible
	else:
		print("ERROR: PhoneScreen node not found")

func _switch_pov_with_fade(target: String) -> void:
	if is_transitioning: return
	is_transitioning = true

	# fade to black
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.size = Vector2(1920, 1080)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 100
	add_child(overlay)

	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.4)
	await tween.finished

	# do the actual switch
	if pov_manager:
		pov_manager.switch_to(target)

	# brief pause at black
	await get_tree().create_timer(0.3).timeout

	# fade back in
	var tween2 = create_tween()
	tween2.tween_property(overlay, "color:a", 0.0, 0.4)
	await tween2.finished

	overlay.queue_free()
	is_transitioning = false

func _on_blackout(is_out: bool) -> void:
	# blur/vignette effect when player blacks out
	var overlay = get_node_or_null("UI/BlackoutOverlay")
	if overlay:
		var tween = create_tween()
		tween.tween_property(overlay, "modulate:a",
			0.85 if is_out else 0.0, 0.5)
	if is_out:
		GameManager.show_dialogue("Everything is going dark... I need to breathe...")

func _on_panic(value: float) -> void:
	if value > 80.0:
		trigger_shake(randf_range(0.0, 5.0))

func _on_escape_step(step: int) -> void:
	match step:
		1: GameManager.show_dialogue("Got the phone. Now I need to find a way out.")
		2: GameManager.show_dialogue("The glove box is open! I found a screwdriver.")
		3: GameManager.show_dialogue("I can try to force the door now.")
		4: GameManager.show_dialogue("I'm in the back seat. There's a shovel back here!")
		5: _trigger_win()

func _trigger_win() -> void:
	GameManager.game_running = false
	var screen = get_node_or_null("UI/GameOverScreen")
	var label  = get_node_or_null("UI/GameOverScreen/ReasonLabel")
	if screen: screen.show()
	if label:  label.text = "You escaped!\n\nClick to play again"

func _on_game_over(reason: String) -> void:
	var screen = get_node_or_null("UI/GameOverScreen")
	var label  = get_node_or_null("UI/GameOverScreen/ReasonLabel")
	if screen: screen.show()
	if label:  label.text = reason + "\n\nClick to restart"

func _on_item_picked(_item: String) -> void:
	_update_inventory_label()

func _on_item_dropped(_item: String) -> void:
	_update_inventory_label()

func _update_inventory_label() -> void:
	var label = get_node_or_null("UI/InventoryLabel")
	if label:
		label.text = "Inventory: " + (
			", ".join(GameManager.inventory) if GameManager.inventory.size() > 0
			else "empty")
