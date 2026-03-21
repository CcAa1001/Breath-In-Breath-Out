extends Node

var active: bool = false
var indicator: Control = null

func _ready() -> void:
	# create a visual cursor indicator
	indicator = ColorRect.new()
	indicator.size = Vector2(40, 40)
	indicator.color = Color(0.7, 0.7, 0.7, 0.5)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.visible = false
	indicator.z_index = 50
	get_node("/root/Main/UI").add_child(indicator)

func _process(_delta: float) -> void:
	# follow mouse when active
	if active and indicator:
		var m = get_viewport().get_mouse_position()
		indicator.position = m - Vector2(20, 20)

func enter_tape_mode() -> void:
	if not GameManager.has_item("duct_tape"):
		GameManager.show_dialogue("I don't have duct tape.")
		return
	active = true
	if indicator: indicator.visible = true
	var hint = get_node_or_null("/root/Main/UI/TapeModeHint")
	if hint: hint.visible = true
	print("Tape mode ON")

func exit_tape_mode() -> void:
	active = false
	if indicator: indicator.visible = false
	var hint = get_node_or_null("/root/Main/UI/TapeModeHint")
	if hint: hint.visible = false
	print("Tape mode OFF")
