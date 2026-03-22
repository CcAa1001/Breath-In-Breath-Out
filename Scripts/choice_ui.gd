extends Panel

var _buttons: Array = []

func _ready() -> void:
	GameManager.choice_requested.connect(_on_choice_requested)
	visible      = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# high process priority so it runs before clickable items
	process_priority = 100

func _input(event: InputEvent) -> void:
	# when visible, eat ALL input so nothing below fires
	if not visible: return
	get_viewport().set_input_as_handled()

func _on_choice_requested(prompt: String, options: Array) -> void:
	for b in _buttons:
		if is_instance_valid(b): b.queue_free()
	_buttons.clear()

	var prompt_label  = get_node_or_null("PromptLabel")
	var btn_container = get_node_or_null("ButtonContainer")
	if prompt_label: prompt_label.text = prompt
	if not btn_container:
		print("ERROR: ButtonContainer not found in ChoicePanel")
		return

	for opt in options:
		var btn = Button.new()
		btn.text                = opt
		btn.custom_minimum_size = Vector2(400, 50)
		btn.mouse_filter        = Control.MOUSE_FILTER_STOP
		var opt_copy = opt
		btn.pressed.connect(func():
			get_viewport().set_input_as_handled()
			_on_choice_selected(opt_copy))
		btn_container.add_child(btn)
		_buttons.append(btn)

	visible = true
	move_to_front()

func _on_choice_selected(option: String) -> void:
	visible = false
	for b in _buttons:
		if is_instance_valid(b): b.queue_free()
	_buttons.clear()
	GameManager.handle_choice(option)
