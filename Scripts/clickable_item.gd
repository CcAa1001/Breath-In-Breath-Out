extends Area2D

const CURSOR_NORMAL = preload("res://assets/cursor_normal.png")
const CURSOR_HOVER  = preload("res://assets/cursor_hover.png")

@export var item_name: String             = "item"
@export var description: String           = "..."
@export var dialogue: String              = ""
@export var collectible: bool             = true
@export var pov_target: String            = ""
@export var starts_hidden: bool           = false
@export var use_choice: bool              = false
@export var choice_prompt: String         = ""
@export var choice_options: Array[String] = []

var is_hovered: bool = false
var highlight: ColorRect

func _ready() -> void:
	if starts_hidden:
		visible = false
	input_pickable = true

	mouse_entered.connect(func():
		is_hovered = true
		if highlight and visible:
			highlight.visible = true
		if visible:
			Input.set_custom_mouse_cursor(
				CURSOR_HOVER, Input.CURSOR_ARROW, Vector2(0, 0)))

	mouse_exited.connect(func():
		is_hovered = false
		if highlight:
			highlight.visible = false
		Input.set_custom_mouse_cursor(
			CURSOR_NORMAL, Input.CURSOR_ARROW, Vector2(0, 0)))

	_make_highlight()

func _make_highlight() -> void:
	highlight = ColorRect.new()
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.color = Color(1, 1, 0, 0.15)
	var s = get_node_or_null("Shape")
	if s == null:
		print("WARNING: No Shape child on: ", item_name)
		return
	if s.shape is RectangleShape2D:
		var shape = s.shape as RectangleShape2D
		highlight.size     = shape.size
		highlight.position = -shape.size / 2
	elif s.shape is CircleShape2D:
		var shape = s.shape as CircleShape2D
		var r = shape.radius
		highlight.size     = Vector2(r * 2, r * 2)
		highlight.position = Vector2(-r, -r)
	highlight.visible = false
	add_child(highlight)

func on_dropped() -> void:
	visible = true
	if highlight: highlight.visible = false

func return_to_world() -> void:
	visible = true
	if highlight: highlight.visible = false

func _input(event: InputEvent) -> void:
	if not visible:         return
	if not is_hovered:      return
	if GameManager.is_dead: return

	if GameManager.blacked_out:
		if event is InputEventMouseButton and event.pressed:
			GameManager.show_dialogue("Everything is going dark... hold Space to breathe!")
		return

	if not event is InputEventMouseButton: return
	if not event.pressed:                  return
	if event.button_index != MOUSE_BUTTON_LEFT: return

	# FIX — if player has an item selected, let main.gd handle the click
	# do NOT consume the event here
	var inv_ui = get_node_or_null("/root/Main/UI/InventoryPanel")
	if inv_ui and inv_ui.has_method("get_active_item"):
		var active = inv_ui.get_active_item()
		if active != "":
			return  # pass through to main.gd _input

	# no item selected — consume and handle normally
	get_viewport().set_input_as_handled()

	# POV switch
	if pov_target != "":
		if pov_target == "back" or pov_target == "trunk":
			if not GameManager.seatbelt_cut:
				GameManager.show_dialogue("I'm still buckled in. Cut the seatbelt first!")
				return
		GameManager.request_pov_switch(pov_target)
		return

	# choice
	if use_choice and choice_options.size() > 0:
		GameManager.show_choice(
			choice_prompt if choice_prompt != "" else description,
			choice_options)
		return

	# show dialogue
	var line = dialogue if dialogue != "" else description
	if line != "":
		GameManager.show_dialogue(line)

	# collectible
	if collectible:
		visible = false
		GameManager.pick_item(item_name, self)
		_on_collected()
		return

	# non-collectible
	_handle_interaction()

func _on_collected() -> void:
	match item_name:
		"phone":
			GameManager.show_dialogue("My phone! Press F for flashlight, P to open messages.")
		"cutter":
			GameManager.show_dialogue("A seatbelt cutter! Select it then left click to use.")
		"screwdriver":
			GameManager.show_dialogue("A screwdriver. Select it then left click to open the glove box.")
			if GameManager.escape_step < 2:
				GameManager.escape_step = 2
				GameManager.emit_signal("escape_step_changed", 2)
		"duct_tape":
			GameManager.show_dialogue("Duct tape! Select it then left click on a crack.")
		"emergency_number":
			if not GameManager.has_emergency_number:
				GameManager.has_emergency_number = true
				GameManager.escape_step = max(GameManager.escape_step, 4)
				GameManager.emit_signal("escape_step_changed", GameManager.escape_step)
				GameManager.show_dialogue("An emergency number! I memorised it — 112. Call it on my phone.")
			else:
				GameManager.show_dialogue("I already know the number — 112.")
		"hammer":
			GameManager.show_dialogue("A hammer! Select it then left click to use.")
		"car_jack":
			GameManager.show_dialogue("A car jack! Hold E near the door to use it.")
		"shovel":
			GameManager.show_dialogue("A shovel! This is my way out.")
			GameManager.escape_step = max(GameManager.escape_step, 6)
			GameManager.emit_signal("escape_step_changed", GameManager.escape_step)


func _handle_interaction() -> void:
	match item_name:
		"seatbelt":
			if GameManager.seatbelt_cut:
				GameManager.show_dialogue("Already cut.")
			elif GameManager.has_item("cutter"):
				GameManager.show_dialogue("Select cutter then left click.")
			else:
				GameManager.show_dialogue("I'm strapped in tight.")
				var audio = get_node_or_null("/root/Main/AudioManager")
				if audio: audio.play_seatbelt_stuck()
		"door":
			if GameManager.jack_complete:
				GameManager.show_dialogue("The door is forced open!")
			elif GameManager.jack_placed:
				GameManager.show_dialogue("Keep holding E.")
			elif GameManager.has_item("car_jack"):
				GameManager.show_dialogue("Hold E to place the jack.")
			else:
				GameManager.show_dialogue("The door won't budge!")
				var audio = get_node_or_null("/root/Main/AudioManager")
				if audio: audio.play_door_wont_budge()
				
		"emergency_number":
			print("Emergency number clicked! Current has_number: ", GameManager.has_emergency_number)
			if not GameManager.has_emergency_number:
				GameManager.has_emergency_number = true
				GameManager.escape_step = max(GameManager.escape_step, 4)
				GameManager.emit_signal("escape_step_changed", GameManager.escape_step)
				GameManager.show_dialogue("An emergency number! I memorised it — 112. Call it on my phone.")
				print("has_emergency_number is now TRUE")
			else:
				GameManager.show_dialogue("I already know the number — 112.")
				
		"glove_box":
			if GameManager.escape_step >= 3:
				GameManager.request_pov_switch("glovebox")
			elif GameManager.has_item("screwdriver"):
				GameManager.show_dialogue("Select the screwdriver (1 or 2) then left click.")
			else:
				GameManager.show_dialogue("It's locked. I need a tool.")
				
		"dirt_exit":
			if GameManager.has_item("shovel") and GameManager.jack_complete:
				GameManager.show_dialogue("Select the shovel then left click to dig out.")
			elif not GameManager.jack_complete:
				GameManager.show_dialogue("Force the door open first.")
			else:
				GameManager.show_dialogue("I need the shovel from the trunk.")

		"honk":
			if GameManager.honk_broken:
				GameManager.show_dialogue("*click* — The horn is broken. The impact must have damaged it.")
			elif GameManager.rescue_called:
				GameManager.show_dialogue("*HONK* — Maybe they'll hear that!")
				GameManager.use_hammer_for_noise()
			else:
				GameManager.show_dialogue("*HONK* — No one can hear me this deep underground...")
			var audio = get_node_or_null("/root/Main/AudioManager")
			if audio and not GameManager.honk_broken: audio.play_honk()

		"steering_wheel":
			GameManager.show_dialogue("Completely jammed.")

		"rearview_mirror":
			GameManager.show_dialogue("Just darkness outside. We're deep underground.")

		"center_console":
			GameManager.show_dialogue("Just some change and an old receipt.")

		"front_window":
			_handle_window("front")
		"left_window":
			_handle_window("left")
		"right_window":
			_handle_window("right")
		"rear_window":
			_handle_window("rear")

		_:
			if dialogue != "":
				GameManager.show_dialogue(dialogue)

func _handle_window(window_id: String) -> void:
	var phase = GameManager.glass_phases.get(window_id, 0)
	var taped = GameManager.glass_taped.get(window_id, false)

	if taped:
		GameManager.show_dialogue("The " + window_id + " window is taped.")
		return

	match phase:
		0:
			GameManager.show_dialogue("The " + window_id + " window looks intact... for now.")
		1, 2, 3:
			var severity = ["", "a small crack", "a spreading crack", "about to shatter!"]
			if GameManager.has_item("duct_tape"):
				GameManager.show_dialogue("The " + window_id + " window has " +
					severity[phase] + ". Select tape then left click here.")
			else:
				GameManager.show_dialogue("The " + window_id + " window has " +
					severity[phase] + ". I need duct tape!")
		4:
			GameManager.show_dialogue("The " + window_id + " window is shattered. Soil is seeping in.")

func _reveal_node(node_name: String) -> void:
	var paths = [
		"/root/Main/POVManager/FrontRow/"     + node_name,
		"/root/Main/POVManager/GloveBoxView/" + node_name,
		"/root/Main/POVManager/BackRow/"      + node_name,
		"/root/Main/POVManager/TrunkView/"    + node_name,
	]
	for p in paths:
		var n = get_node_or_null(p)
		if n:
			n.visible = true
			return
