extends Label

func _ready() -> void:
	visible = false
	GameManager.escape_step_changed.connect(_on_escape_step)

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	self.text = text
	modulate   = color
	visible    = true
	modulate.a = 1.0

	# animate: pop in then fade out
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(1.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false)

func _on_escape_step(step: int) -> void:
	match step:
		1: show_notification("✓ Seatbelt cut! You can move freely.", Color(0.4, 1.0, 0.4))
		2: show_notification("✓ Screwdriver found!", Color(0.4, 0.8, 1.0))
		3: show_notification("✓ Glove box opened!", Color(0.4, 0.8, 1.0))
		4: show_notification("✓ Emergency number found!", Color(1.0, 0.8, 0.2))
		5: show_notification("🚨 Emergency called! Rescue in 2 min.", Color(1.0, 0.4, 0.4))
		6: show_notification("✓ Door forced open!", Color(0.4, 1.0, 0.4))
