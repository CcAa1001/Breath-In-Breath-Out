extends CanvasLayer

func _ready() -> void:
	hide()

func _input(event) -> void:
	if visible and event is InputEventMouseButton and event.pressed:
		GameManager.is_game_over = false
		GameManager.oxygen = 100.0
		GameManager.soil_pressure = 0.0
		GameManager.inventory.clear()
		get_tree().reload_current_scene()
