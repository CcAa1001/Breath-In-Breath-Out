extends Control

var dial_display:    Control   # container showing typed numbers as images
var status_label:   Label
var current_number: String = ""
var is_calling:     bool   = false

const EMERGENCY_NUMBER = "112"

# number images — loaded once
var num_textures: Dictionary = {}

func _ready() -> void:
	dial_display = get_node_or_null("DialDisplay")
	status_label = get_node_or_null("StatusLabel")

	# preload all number images
	_load_textures()

	# connect number buttons
	for i in range(1, 10):
		var btn = get_node_or_null("NumberGrid/Btn" + str(i))
		if btn:
			var num = str(i)
			btn.pressed.connect(func(): _press_key(num))

	var btn0     = get_node_or_null("NumberGrid/Btn0")
	var btn_star = get_node_or_null("NumberGrid/BtnStar")
	var btn_hash = get_node_or_null("NumberGrid/BtnHash")
	var call_btn = get_node_or_null("CallBtn")
	var del_btn  = get_node_or_null("DeleteBtn")
	var back_btn = get_node_or_null("BackBtn")

	if btn0:     btn0.pressed.connect(func():     _press_key("0"))
	if btn_star: btn_star.pressed.connect(func(): _press_key("*"))
	if btn_hash: btn_hash.pressed.connect(func(): _press_key("#"))
	if call_btn:
		call_btn.pressed.connect(_try_call)
	if del_btn:  del_btn.pressed.connect(_press_delete)
	if back_btn: back_btn.pressed.connect(_go_back)

	_update_display()

func _load_textures() -> void:
	var keys = ["0","1","2","3","4","5","6","7","8","9","*","#"]
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
	for key in keys:
		if ResourceLoader.exists(files[key]):
			num_textures[key] = load(files[key])
		else:
			print("WARNING: missing number image: ", files[key])

func _press_key(key: String) -> void:
	if is_calling: return
	if current_number.length() >= 12: return
	current_number += key
	_update_display()
	var audio = get_node_or_null("/root/Main/AudioManager")
	if audio: audio.play("phone_click")

func _press_delete() -> void:
	if is_calling: return
	if current_number.length() > 0:
		current_number = current_number.left(current_number.length() - 1)
	_update_display()

func _update_display() -> void:
	if not dial_display: return

	# clear existing display children
	for child in dial_display.get_children():
		child.queue_free()

	if current_number == "":
		# show placeholder
		var placeholder = Label.new()
		placeholder.text = "_ _ _"
		placeholder.add_theme_font_size_override("font_size", 24)
		placeholder.modulate = Color(0.5, 0.5, 0.5)
		dial_display.add_child(placeholder)
		return

	# show each digit as an image
	for ch in current_number:
		if num_textures.has(ch):
			var img = TextureRect.new()
			img.texture = num_textures[ch]
			img.custom_minimum_size = Vector2(40, 50)
			img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			dial_display.add_child(img)
		else:
			# fallback for * and # if no image
			var lbl = Label.new()
			lbl.text = ch
			lbl.add_theme_font_size_override("font_size", 28)
			dial_display.add_child(lbl)

func _try_call() -> void:
	if is_calling: return
	if current_number == "":
		if status_label: status_label.text = "Enter a number first."
		return
	if GameManager.phone_is_dead or GameManager.battery <= 0.0:
		if status_label: status_label.text = "Phone battery dead."
		return
	if current_number == EMERGENCY_NUMBER:
		if GameManager.rescue_called:
			if status_label:
				status_label.text = "Already called. Rescue in " + \
					str(int(GameManager.rescue_timer)) + "s"
			return
		if not GameManager.has_emergency_number:
			if status_label:
				status_label.text = "Find the emergency number first."
			return
		_start_emergency_call()
	else:
		if status_label:
			status_label.text = "No signal. Try 112 for emergency."

func _start_emergency_call() -> void:
	is_calling = true
	if status_label: status_label.text = "Calling 112..."
	var audio = get_node_or_null("/root/Main/AudioManager")
	if audio: audio.play("phone_calling")
	await get_tree().create_timer(2.5).timeout
	if status_label: status_label.text = "Connected!"
	is_calling = false
	await get_tree().create_timer(0.5).timeout
	# close phone
	var phone = get_node_or_null("/root/Main/UI/PhoneScreen")
	if phone: phone.hide()
	# open emergency call dialogue
	var call_screen = get_node_or_null("/root/Main/UI/EmergencyCallScreen")
	if call_screen:
		call_screen.open_call()
	else:
		GameManager.call_emergency()

func _go_back() -> void:
	current_number = ""
	_update_display()
	if status_label: status_label.text = ""
	var phone = get_node_or_null("/root/Main/UI/PhoneScreen")
	if phone and phone.has_method("_open_screen"):
		phone._open_screen("home")
