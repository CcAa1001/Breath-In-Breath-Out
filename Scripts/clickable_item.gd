extends Area2D

@export var item_name: String = "item"
@export var description: String = "..."
@export var dialogue: String = ""
@export var collectible: bool = true
@export var pov_target: String = ""
@export var starts_hidden: bool = false
@export var use_choice: bool = false
@export var choice_prompt: String = ""
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
			highlight.visible = true)
	mouse_exited.connect(func():
		is_hovered = false
		if highlight:
			highlight.visible = false)
	_make_highlight()

func _make_highlight() -> void:
	highlight = ColorRect.new()
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.color = Color(1, 1, 0, 0.15)
	var s = get_node_or_null("Shape")
	if s == null:
		print("WARNING: No 'Shape' child on ", item_name)
		return
	if s.shape is RectangleShape2D:
		var shape = s.shape as RectangleShape2D
		highlight.size = shape.size
		highlight.position = -shape.size / 2
	elif s.shape is CircleShape2D:
		var shape = s.shape as CircleShape2D
		var r = shape.radius
		highlight.size = Vector2(r * 2, r * 2)
		highlight.position = Vector2(-r, -r)
	highlight.visible = false
	add_child(highlight)

func on_dropped() -> void:
	visible = true
	if highlight:
		highlight.visible = false

func return_to_world() -> void:
	visible = true
	if highlight:
		highlight.visible = false

func _input(event: InputEvent) -> void:
	# --- GUARDS ---
	if not visible:
		return
	if not is_hovered:
		return
	if GameManager.is_dead:
		return

	# block ALL interaction when blacked out except breathing
	if GameManager.blacked_out:
		if event is InputEventMouseButton and event.pressed:
			GameManager.show_dialogue("I can't... I need to breathe first...")
		return

	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# consume the click — nothing else gets it
	get_viewport().set_input_as_handled()

	# --- POV SWITCH ---
	if pov_target != "":
		GameManager.request_pov_switch(pov_target)
		return

	# --- DIALOGUE CHOICE ---
	if use_choice and choice_options.size() > 0:
		var prompt = choice_prompt if choice_prompt != "" else description
		GameManager.show_choice(prompt, choice_options)
		return

	# --- SHOW DIALOGUE ---
	var line = dialogue if dialogue != "" else description
	if line != "":
		GameManager.show_dialogue(line)

	# --- COLLECTIBLE ---
	if collectible:
		visible = false
		GameManager.pick_item(item_name, self)
		_on_collected()
		return

	# --- NON-COLLECTIBLE INTERACTION ---
	_handle_interaction()

# called right after picking up an item
func _on_collected() -> void:
	match item_name:
		"phone":
			if GameManager.escape_step == 0:
				GameManager.escape_step = 1
				GameManager.emit_signal("escape_step_changed", 1)

		"key":
			GameManager.show_dialogue("A key! Maybe this opens the glove box.")

		"duct_tape":
			GameManager.show_choice(
				"Found duct tape! What do you want to do?",
				["Seal the window cracks", "Save it for later"])

		"car_jack":
			GameManager.show_dialogue("A car jack! Hold E near the door to use it.")

		"screwdriver":
			GameManager.show_dialogue("A screwdriver. I can use this on the door.")

		"shovel":
			GameManager.show_dialogue("A folding shovel. This is my way out!")

# called when clicking non-collectible items
func _handle_interaction() -> void:
	match item_name:

		"glove_box":
			if GameManager.escape_step < 1:
				GameManager.show_dialogue("It's locked shut.")
			elif GameManager.escape_step == 1:
				if GameManager.has_item("key"):
					# unlock it — advance step and open the close-up view
					GameManager.advance_escape_step("key")
					GameManager.show_dialogue("The glove box is open!")
					GameManager.request_pov_switch("glovebox")
				else:
					GameManager.show_dialogue("It's locked. I need the car key.")
			else:
				# already unlocked — just open the view
				GameManager.request_pov_switch("glovebox")

		"door":
			if GameManager.escape_step < 2:
				GameManager.show_dialogue("It won't move. The soil is pressing against it.")
			elif GameManager.escape_step == 2:
				if GameManager.has_item("screwdriver"):
					GameManager.show_choice(
						"I have a screwdriver. What should I do?",
						["Force the door hinges", "Look for another way"])
				else:
					GameManager.show_dialogue("It won't budge. I need a tool to force it.")
			elif GameManager.escape_step == 3:
				if GameManager.jack_complete:
					GameManager.advance_escape_step("screwdriver")
					GameManager.show_dialogue("The door is open! Now I need to dig out.")
				else:
					GameManager.show_dialogue("I need to get the car jack in place first. Hold E.")
			else:
				GameManager.show_dialogue("The door is already forced open.")

		"exit":
			if GameManager.escape_step < 4:
				GameManager.show_dialogue("There's packed soil above me.")
			elif GameManager.escape_step == 4:
				if GameManager.has_item("shovel"):
					GameManager.show_choice(
						"Packed soil above me. I have the shovel.",
						["Start digging", "Rest for a moment"])
				else:
					GameManager.show_dialogue("I need something to dig with.")
			elif GameManager.escape_step == 5:
				GameManager.show_dialogue("Keep digging! I'm almost out!")
			else:
				GameManager.show_dialogue("There's packed soil above me.")

		"window_crack":
			if GameManager.has_item("duct_tape"):
				GameManager.apply_duct_tape()
			else:
				GameManager.show_dialogue("The crack is spreading. I need something to seal it.")

		"steering_wheel":
			GameManager.show_dialogue("Completely jammed. The car isn't going anywhere.")

		"center_console":
			GameManager.show_choice(
				"The center console.",
				["Check the radio", "Search for anything useful", "Never mind"])

		"back_window":
			GameManager.show_dialogue("The rear window. Maybe I could break through here...")

		_:
			# fallback for any item without specific logic
			if dialogue == "" and description != "...":
				GameManager.show_dialogue(description)

# reveals a hidden node by searching all known POV paths
func _reveal_node(node_name: String) -> void:
	var paths = [
		"/root/Main/POVManager/FrontRow/" + node_name,
		"/root/Main/POVManager/GloveBoxView/" + node_name,
		"/root/Main/POVManager/BackRow/" + node_name,
		"/root/Main/POVManager/TrunkView/" + node_name,
	]
	for p in paths:
		var n = get_node_or_null(p)
		if n:
			n.visible = true
			print("Revealed: ", p)
			return
	print("WARNING: Could not find node to reveal: ", node_name)
