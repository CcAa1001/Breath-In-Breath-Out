extends ProgressBar

func _ready() -> void:
	max_value = 100.0
	value = 100.0
	GameManager.oxygen_changed.connect(_on_oxygen_changed)

func _on_oxygen_changed(new_value: float) -> void:
	value = new_value
	# Turn bar red when low
	if new_value < 25.0:
		modulate = Color(1, 0.3, 0.3)
	else:
		modulate = Color(1, 1, 1)
