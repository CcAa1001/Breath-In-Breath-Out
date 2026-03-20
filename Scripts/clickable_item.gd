extends Area2D

@export var item_name: String         = "item"
@export var description: String       = "..."
@export var dialogue: String          = ""
@export var collectible: bool         = true
@export var pov_target: String        = ""
@export var starts_hidden: bool       = false
@export var use_choice: bool          = false
@export var choice_prompt: String     = ""
@export var choice_options: Array[String] = []

var is_hovered: bool  = false
var highlight: ColorRect

func _ready() -> void:
	if starts_hidden:
		visible = false
	input_pickable = true
	mouse_entered.connect(func():
		is_hovered = true
		if highlight and visible: highlight.visible = true)
	mouse_exited.connect(func():
		is_hovered = false
		if highlight: highlight.visible = false)
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

	# blacked out — player can only breathe
	if GameManager.blacked_out:
		if event is InputEventMouseButton and event.pressed:
			GameManager.show_dialogue("Everything is going dark... hold Space to breathe!")
		return

	if not event is InputEventMouseButton: return
	if not event.pressed:                  return
	if event.button_index != MOUSE_BUTTON_LEFT: return

	get_viewport().set_input_as_handled()

	# POV switch
	if pov_target != "":
		# back seat and trunk require seatbelt to be cut first
		if pov_target == "back" or pov_target == "trunk":
			if not GameManager.seatbelt_cut:
				GameManager.show_dialogue("I'm still buckled in. I need to cut the seatbelt first!")
				return
		GameManager.request_pov_switch(pov_target)
		return

	# dialogue choice
	if use_choice and choice_options.size() > 0:
		GameManager.show_choice(
			choice_prompt if choice_prompt != "" else description,
			choice_options)
		return

	# show dialogue
	var line = dialogue if dialogue != "" else description
	if line != "":
		GameManager.show_dialogue(line)

	# collectible item
	if collectible:
		visible = false
		GameManager.pick_item(item_name, self)
		_on_collected()
		return

	# non-collectible interaction
	_handle_interaction()

func _on_collected() -> void:
	match item_name:
		"phone":
			GameManager.show_dialogue("My phone! Press F for flashlight, P to open messages.")

		"cutter":
			GameManager.show_dialogue("A seatbelt cutter! Now I can free myself.")

		"screwdriver":
			GameManager.show_dialogue("A screwdriver. I can use this to open the glove box.")
			# mark that we have the tool — glove box step advances on use
			if GameManager.escape_step < 2:
				GameManager.escape_step = 2
				GameManager.emit_signal("escape_step_changed", 2)

		"duct_tape":
			GameManager.show_dialogue("Duct tape! I can seal the cracked windows with this.")

		"emergency_number":
			GameManager.has_emergency_number = true
			GameManager.show_dialogue("An emergency number! I can call this on my phone.")
			GameManager.escape_step = max(GameManager.escape_step, 4)
			GameManager.emit_signal("escape_step_changed", GameManager.escape_step)

		"hammer":
			GameManager.show_choice(
				"I found a hammer. What do I do with it?",
				["Bang on the car for rescue", "Keep it for now"])

		"car_jack":
			GameManager.show_dialogue("A car jack! Hold E near the door to use it.")

		"shovel":
			GameManager.show_dialogue("A shovel! This is my way out.")
			GameManager.escape_step = max(GameManager.escape_step, 6)
			GameManager.emit_signal("escape_step_changed", GameManager.escape_step)

func _handle_interaction() -> void:
	match item_name:

		# ---- FRONT SEAT ----
		"seatbelt":
			if GameManager.seatbelt_cut:
				GameManager.show_dialogue("Already cut free.")
			elif GameManager.has_item("cutter"):
				GameManager.cut_seatbelt()
			else:
				GameManager.show_dialogue("I'm strapped in tight. I need something sharp to cut it.")

		"glove_box":
			if GameManager.escape_step < 2:
				GameManager.show_dialogue("It's locked shut. I need a tool — maybe in the back seat.")
			elif GameManager.escape_step == 2:
				if GameManager.has_item("screwdriver"):
					GameManager.advance_escape_step("screwdriver")
					GameManager.show_dialogue("Got it open with the screwdriver!")
					GameManager.request_pov_switch("glovebox")
				else:
					GameManager.show_dialogue("Locked. I need a screwdriver — check the back seat.")
			else:
				# already unlocked — just open the view
				GameManager.request_pov_switch("glovebox")

		"steering_wheel":
			GameManager.show_dialogue("Completely jammed. The car isn't going anywhere.")

		"honk":
			if GameManager.rescue_called:
				GameManager.use_hammer_for_noise()
				GameManager.show_dialogue("*HOOOONK* — They might hear that!")
			else:
				GameManager.show_dialogue("*HONK* — No one can hear me this deep underground...")

		"front_window":
			_handle_window("front")

		"left_window":
			_handle_window("left")

		"right_window":
			_handle_window("right")

		"door":
			if not GameManager.seatbelt_cut:
				GameManager.show_dialogue("I'm still in the seatbelt. I can't force the door like this.")
			elif not GameManager.has_item("car_jack"):
				GameManager.show_dialogue("The door is jammed solid. I need a car jack from the trunk.")
			elif not GameManager.jack_complete:
				GameManager.show_dialogue("I need to set the car jack first. Hold E to roll it in place.")
			else:
				GameManager.show_dialogue("The door is giving way! Now I need the shovel to dig out.")
				GameManager.escape_step = max(GameManager.escape_step, 6)
				GameManager.emit_signal("escape_step_changed", GameManager.escape_step)

		"call_button":
			GameManager.call_emergency()

		# ---- BACK SEAT ----
		"hammer_use":
			GameManager.show_choice(
				"What do you want to do with the hammer?",
				["Bang for rescue", "Break a window (bad idea)", "Put it away"])

		"rear_window":
			_handle_window("rear")

		# ---- TRUNK ----
		"dirt_exit":
			if not GameManager.jack_complete:
				GameManager.show_dialogue("The door isn't open yet. I need the car jack first.")
			elif not GameManager.has_item("shovel"):
				GameManager.show_dialogue("I need the shovel to dig through.")
			else:
				GameManager.show_choice(
					"I can see packed soil above me. The shovel is ready.",
					["Start digging!", "Wait for rescue instead"])

		_:
			pass

func _handle_window(window_id: String) -> void:
	var phase  = GameManager.glass_phases.get(window_id, 0)
	var taped  = GameManager.glass_taped.get(window_id, false)

	if taped:
		GameManager.show_dialogue("The " + window_id + " window is taped. It should hold.")
		return

	match phase:
		0:
			GameManager.show_dialogue("The " + window_id + " window looks intact... for now.")
		1, 2, 3:
			var severity = ["", "a small crack", "a spreading crack", "about to shatter!"]
			if GameManager.has_item("duct_tape"):
				GameManager.show_choice(
					"The " + window_id + " window has " + severity[phase],
					["Tape it now", "Leave it for now"])
			else:
				GameManager.show_dialogue(
					"The " + window_id + " window has " + severity[phase] + ". I need duct tape!")
		4:
			GameManager.show_dialogue(
				"The " + window_id + " window is shattered. Soil is seeping in.")

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
			print("Revealed: ", p)
			return
	print("WARNING: Could not reveal node: ", node_name)
