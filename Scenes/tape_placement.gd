extends Sprite2D

var active: bool = false

func _ready() -> void:
	visible = false

func activate() -> void:
	active  = true
	visible = true

func deactivate() -> void:
	active  = false
	visible = false

func _process(_delta: float) -> void:
	if not active: return
	# get_global_mouse_position() returns correct world space coords
	global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			rotation_degrees += 10.0
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rotation_degrees -= 10.0
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				rotation_degrees += 15.0
				get_viewport().set_input_as_handled()
			KEY_T:
				rotation_degrees -= 15.0
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				deactivate()
				get_viewport().set_input_as_handled()

func reset_transform() -> void:
	rotation = 0.0
