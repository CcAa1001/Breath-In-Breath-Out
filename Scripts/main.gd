extends Node2D

var darkness = null

func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.item_picked.connect(_on_item_picked)
	GameManager.item_dropped.connect(_on_item_dropped)

	darkness = get_node_or_null("DarknessOverlay")
	if darkness == null:
		darkness = find_child("DarknessOverlay", true, false)
	if darkness:
		print("DarknessOverlay found!")
	else:
		print("ERROR: DarknessOverlay not found!")

func _process(delta: float) -> void:
	# F = toggle flashlight (tap only)
	if Input.is_action_just_pressed("flashlight"):
		if darkness and GameManager.has_item("phone"):
			darkness.toggle_light()
		elif not GameManager.has_item("phone"):
			print("You need the phone first!")

	# Space = hold to breathe
	if Input.is_action_pressed("breathe"):
		GameManager.hold_space(delta)
	if Input.is_action_just_released("breathe"):
		GameManager.release_space()

func _on_game_over(reason: String) -> void:
	var screen = get_node_or_null("UI/GameOverScreen")
	if screen:
		screen.show()
	var label = get_node_or_null("UI/GameOverScreen/ReasonLabel")
	if label:
		label.text = reason + "\n\nClick to restart"

func _on_item_picked(_item: String) -> void:
	var label = get_node_or_null("UI/InventoryLabel")
	if label:
		label.text = "Inventory: " + ", ".join(GameManager.inventory)

func _on_item_dropped(_item: String) -> void:
	var label = get_node_or_null("UI/InventoryLabel")
	if label:
		label.text = "Inventory: " + ", ".join(GameManager.inventory)
