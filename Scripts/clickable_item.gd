extends Area2D

@export var item_name: String = "item"
@export var description: String = "..."
@export var collectible: bool = true
@export var pov_target: String = ""

var highlight: ColorRect
var is_hovered: bool = false
var original_position: Vector2

func _ready() -> void:
	original_position = global_position
	input_pickable = true

	# register with game manager so it can be returned
	if collectible:
		GameManager.register_item(item_name, self)
		GameManager.item_returned.connect(_on_item_returned)

	mouse_entered.connect(func(): 
		is_hovered = true
		if highlight: highlight.visible = true)
	mouse_exited.connect(func(): 
		is_hovered = false
		if highlight: highlight.visible = false)

	_build_highlight()

func _on_item_returned(returned_name: String) -> void:
	if returned_name == item_name:
		return_to_world()

func return_to_world() -> void:
	# make the item visible and clickable again
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = original_position
	if highlight:
		highlight.visible = false

func _build_highlight() -> void:
	highlight = ColorRect.new()
	var col = $Shape

	if col.shape is RectangleShape2D:
		var shape = col.shape as RectangleShape2D
		highlight.size = shape.size
		highlight.position = -shape.size / 2
	elif col.shape is CircleShape2D:
		var shape = col.shape as CircleShape2D
		var diameter = shape.radius * 2
		highlight.size = Vector2(diameter, diameter)
		highlight.position = Vector2(-shape.radius, -shape.radius)

	highlight.color = Color(1, 1, 1, 0.08)
	highlight.visible = false
	add_child(highlight)

func _unhandled_input(event: InputEvent) -> void:
	if not is_hovered:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if GameManager.is_game_over:
		return
	get_viewport().set_input_as_handled()

	if pov_target != "":
		get_node("/root/Main/POVManager").switch_to(pov_target)
		return

	print("[CLICK] " + item_name + ": " + description)
	if collectible:
		visible = false
		GameManager.collect_item(item_name)
