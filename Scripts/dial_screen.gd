extends Control

var dial_display:   Control
var status_label:   Label
var current_number: String = ""
var is_calling:     bool   = false

const EMERGENCY_NUMBER = "112"

var num_textures: Dictionary = {}

func _ready() -> void:
	# be explicit about paths
	dial_display = get_node_or_null("DialDisplay")
	status_label = get_node_or_null("StatusLabel")

	# verify types
	if dial_display and not (dial_display is HBoxContainer or dial_display is Control):
		print("ERROR: DialDisplay wrong type: ", dial_display.get_class())
	if status_label and not status_label is Label:
		print("ERROR: StatusLabel wrong type: ", status_label.get_class())
		status_label = null  # prevent crash

	print("DialDisplay: ", dial_display.get_class() if dial_display else "NOT FOUND")
	print("StatusLabel: ", status_label.get_class() if status_label else "NOT FOUND")

	_load_textures()
	_connect_buttons()
	_update_display()

func _load_textures() -> void:
	var files = {
		"0": "res://assets/num_0.png",
		"1": "res://assets/num_1.png",
		"2": "res://assets/num_2.png",
		"3": "res://assets/num_3.png",
		"4": "res://assets/num_4.png",
		"5": "res://assets/num_5.png",
		"6": "res://assets/num_6.png",
		"7": "res://assets/num_7.png",
		"8": "res://assets/num_8.png",
		"9": "res://assets/num_9.png",
		"*": "res://assets/num_star.png",
		"#": "res://assets/num_hash.png",
	}
	for key in files:
		if ResourceLoader.exists(files[key]):
			num_textures[key] = load(files[key])
		else:
			print("WARNING missing number image: ", files[key])
	print("Loaded ", num_textures.size(), " number textures")

func _connect_buttons() -> void:
	# connect by exact node names from your scene tree
	var grid = get_node_or_null("NumberGrid")
	if not grid:
		print("ERROR: NumberGrid not found!")
		return

	for child in grid.get_children():
		var n = child.name
		# map button name to digit
		var digit = ""
		match n:
			"Btn0", "Button0": digit = "0"
			"Btn1", "Button1": digit = "1"
			"Btn2", "Button2": digit = "2"
			"Btn3", "Button3": digit = "3"
			"Btn4", "Button4": digit = "4"
			"Btn5", "Button5": digit = "5"
			"Btn6", "Button6": digit = "6"
			"Btn7", "Button7": digit = "7"
			"Btn8", "Button8": digit = "8"
			"Btn9", "Button9": digit = "9"
			"BtnStar", "ButtonStar": digit = "*"
			"BtnHash", "ButtonHash": digit = "#"
		if digit != "" and child.has_signal("pressed"):
			var d = digit
			child.pressed.connect(func(): _press_key(d))
			print("Connected: ", n, " → ", digit)

	# connect delete and call
	var del_btn  = get_node_or_null("DeleteBtn")
	var call_btn = get_node_or_null("CallBtn")
	var back_btn = get_node_or_null("BackBtn")
	if del_btn:  del_btn.pressed.connect(_press_delete)
	if call_btn: call_btn.pressed.connect(_try_call)
	if back_btn: back_btn.pressed.connect(_go_back)

func _press_key(key: String) -> void:
	if is_calling: return
	if current_number.length() >= 12: return
	current_number += key
	_update_display()
	print("Dialed: ", current_number)

func _press_delete() -> void:
	if is_calling: return
	if current_number.length() > 0:
		current_number = current_number.left(current_number.length() - 1)
	_update_display()

func _update_display() -> void:
	if not dial_display: return
	# clear existing children
	for child in dial_display.get_children():
		child.queue_free()

	if current_number == "":
		var placeholder = Label.new()
		placeholder.text = "_ _ _"
		placeholder.add_theme_font_size_override("font_size", 28)
		placeholder.modulate = Color(0.5, 0.5, 0.5)
		dial_display.add_child(placeholder)
		return

	# add image for each digit
	for ch in current_number:
		if num_textures.has(ch):
			var img = TextureRect.new()
			img.texture    = num_textures[ch]
			img.custom_minimum_size = Vector2(45, 55)
			img.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			dial_display.add_child(img)
		else:
			var lbl = Label.new()
			lbl.text = ch
			lbl.add_theme_font_size_override("font_size", 32)
			dial_display.add_child(lbl)

func _try_call() -> void:
	if is_calling: return
	if current_number == "":
		if status_label: status_label.text = "Enter a number."
		return
	if GameManager.phone_is_dead or GameManager.battery <= 0.0:
		if status_label: status_label.text = "Phone battery dead."
		return
	if current_number == EMERGENCY_NUMBER:
		if not GameManager.has_emergency_number:
			if status_label: status_label.text = "Find the emergency number first."
			return
		if GameManager.rescue_called:
			if status_label:
				status_label.text = "Already called. Rescue in " + \
					str(int(GameManager.rescue_timer)) + "s"
			return
		_start_emergency_call()
	else:
		if status_label: status_label.text = "No signal. Try 112 for emergency."

func _start_emergency_call() -> void:
	is_calling = true
	if status_label: status_label.text = "Calling 112..."
	await get_tree().create_timer(PhoneContent.call_connecting_time).timeout
	if not is_calling: return
	if status_label: status_label.text = "✓ Connected!"
	GameManager.call_emergency()
	is_calling = false
	await get_tree().create_timer(1.5).timeout
	var phone = get_node_or_null("/root/Main/UI/PhoneScreen")
	if phone: phone.hide()
	var call_screen = get_node_or_null("/root/Main/UI/EmergencyCallScreen")
	if call_screen: call_screen.open_call()

func _go_back() -> void:
	current_number = ""
	_update_display()
	if status_label: status_label.text = ""
	var phone = get_node_or_null("/root/Main/UI/PhoneScreen")
	if phone and phone.has_method("_open_screen"):
		phone._open_screen("home")
