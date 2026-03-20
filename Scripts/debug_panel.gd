extends CanvasLayer

var panel: Panel

func _ready() -> void:
	panel = get_node_or_null("Panel")
	if panel:
		panel.visible = false
		_build_ui()

func _build_ui() -> void:
	var y = 10
	_add_label("MASTER CONTROL PANEL", y); y += 28
	_add_label("Press M to close", y);     y += 32
	y = _add_slider("Player drain rate",    "player_drain_rate",    0.0,  20.0, y)
	y = _add_slider("Car drain rate",       "car_drain_rate",       0.0,  5.0,  y)
	y = _add_slider("Breath cost",          "breath_cost",          0.0,  50.0, y)
	y = _add_slider("Waste penalty",        "waste_penalty",        0.0,  15.0, y)
	y = _add_slider("Hold time (s)",        "breath_hold_required", 0.5,  4.0,  y)
	y = _add_slider("Breath cooldown",      "breath_cooldown_max",  2.0,  20.0, y)
	y = _add_slider("Breath restore",       "breath_restore",       10.0, 100.0,y)
	y = _add_slider("Battery drain rate",   "battery_drain_rate",   0.0,  10.0, y)
	panel.size.y = y + 20

func _add_label(text: String, y: int) -> void:
	var l = Label.new()
	l.text = text
	l.position = Vector2(10, y)
	l.add_theme_font_size_override("font_size", 11)
	panel.add_child(l)

func _add_slider(lbl_text: String, prop: String, mn: float, mx: float, y: int) -> int:
	var lbl = Label.new()
	lbl.text = lbl_text
	lbl.position = Vector2(10, y)
	lbl.add_theme_font_size_override("font_size", 11)
	panel.add_child(lbl)

	var val_lbl = Label.new()
	val_lbl.position = Vector2(255, y)
	val_lbl.add_theme_font_size_override("font_size", 11)

	# safely get the value — convert to float before snapping
	var current_val = GameManager.get(prop)
	if current_val == null:
		print("WARNING: Property not found on GameManager: ", prop)
		val_lbl.text = "?"
	else:
		val_lbl.text = "%.1f" % float(current_val)

	panel.add_child(val_lbl)

	var slider = HSlider.new()
	slider.min_value = mn
	slider.max_value = mx
	slider.value     = float(current_val) if current_val != null else mn
	slider.step      = 0.1
	slider.position  = Vector2(10, y + 16)
	slider.size      = Vector2(300, 20)
	slider.value_changed.connect(func(v: float):
		GameManager.set(prop, v)
		val_lbl.text = "%.1f" % v)
	panel.add_child(slider)
	return y + 48
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			if panel: panel.visible = !panel.visible
