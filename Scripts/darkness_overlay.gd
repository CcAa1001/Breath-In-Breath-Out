extends ColorRect

var flashlight_on: bool = false
var has_phone: bool = false
var mat: ShaderMaterial
var intro_done: bool = false

func _ready() -> void:
	mat = material as ShaderMaterial
	if mat == null:
		print("ERROR: No ShaderMaterial on DarknessOverlay")
		return

	# start fully black
	mat.set_shader_parameter("flashlight_on", false)
	mat.set_shader_parameter("ambient_light", 0.0)
	mat.set_shader_parameter("inner_radius", 0.15)
	mat.set_shader_parameter("outer_radius", 0.35)

	GameManager.item_collected.connect(_on_item_collected)

	# begin intro sequence
	_start_intro()

func _start_intro() -> void:
	# wait 2 seconds in total darkness, then phone notification lights up
	await get_tree().create_timer(2.0).timeout
	_phone_notification()

func _phone_notification() -> void:
	print("*bzzt* — your phone lights up")
	# fade in a tiny bit of ambient so player can SEE the phone
	var tween = create_tween()
	tween.tween_method(
		func(v: float): mat.set_shader_parameter("ambient_light", v),
		0.0, 0.36, 2.0
	)
	await tween.finished
	intro_done = true
	# show a UI hint
	get_node("/root/Main/UI/OxygenLabel").text = "OXYGEN  |  Find your phone..."
	# flash the inventory label as a hint
	var label = get_node("/root/Main/UI/InventoryLabel")
	label.text = "[ Something is glowing nearby... ]"

func _on_item_collected(item_name: String) -> void:
	if item_name == "phone":
		has_phone = true
		get_node("/root/Main/UI/OxygenLabel").text = "OXYGEN  |  Press F to turn on flashlight"

func _process(_delta: float) -> void:
	if mat == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var uv := Vector2(mouse.x / 1920.0, mouse.y / 1080.0)
	mat.set_shader_parameter("mouse_pos", uv)

func _unhandled_key_input(event: InputEvent) -> void:
	if not has_phone:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_toggle()

func _toggle() -> void:
	flashlight_on = !flashlight_on
	mat.set_shader_parameter("flashlight_on", flashlight_on)
	# when turning on for first time, restore normal ambient
	if flashlight_on:
		mat.set_shader_parameter("ambient_light", 0.04)
	print("Phone flashlight: " + ("ON" if flashlight_on else "OFF"))
