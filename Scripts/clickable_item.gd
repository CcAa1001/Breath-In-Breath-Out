extends Area2D

@export var item_name: String = "item"
@export var description: String = "..."
@export var dialogue: String = ""    # what the character says when interacting
@export var collectible: bool = true
@export var pov_target: String = ""

var is_hovered: bool = false
var highlight: ColorRect

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(func():
		is_hovered = true
		if highlight: highlight.visible = true)
	mouse_exited.connect(func():
		is_hovered = false
		if highlight: highlight.visible = false)
	_make_highlight()

func _make_highlight() -> void:
	highlight = ColorRect.new()
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.color = Color(1, 1, 0, 0.18)
	var s = $Shape
	if s.shape is RectangleShape2D:
		highlight.size = s.shape.size
		highlight.position = -s.shape.size / 2
	elif s.shape is CircleShape2D:
		var r = s.shape.radius
		highlight.size = Vector2(r * 2, r * 2)
		highlight.position = Vector2(-r, -r)
	highlight.visible = false
	add_child(highlight)

func on_dropped() -> void:
	visible = true
	if highlight: highlight.visible = false

func _input(event: InputEvent) -> void:
	if not is_hovered: return
	if not event is InputEventMouseButton: return
	if not event.pressed: return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if GameManager.is_dead: return
	get_viewport().set_input_as_handled()

	if pov_target != "":
		get_node("/root/Main/POVManager").switch_to(pov_target)
		return

	# show dialogue if set
	var line = dialogue if dialogue != "" else description
	GameManager.show_dialogue(line)

	if collectible:
		visible = false
		GameManager.pick_item(item_name, self)
