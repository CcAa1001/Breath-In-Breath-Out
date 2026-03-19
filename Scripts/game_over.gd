extends CanvasLayer

func _ready() -> void:
	hide()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		GameManager.reset()
		get_tree().reload_current_scene()
