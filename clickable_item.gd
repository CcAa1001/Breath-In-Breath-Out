extends Area2D

@export var item_name: String = "item"
@export var description: String = "..."
@export var collectible: bool = true
@export var pov_target: String = ""  # fill this for BackSeatBtn → "back"

var highlight: ColorRect

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	input_event.connect(_on_input_event)
	_build_highlight()

func _build_highlight() -> void:
	highlight = ColorRect.new()
	var shape = $Shape.shape as RectangleShape2D
	highlight.size = shape.size
	highlight.position = -shape.size / 2
	highlight.color = Color(1, 1, 1, 0.08)
	highlight.visible = false
	add_child(highlight)

func _on_hover() -> void:
	highlight.visible = true

func _on_unhover() -> void:
	highlight.visible = false

func _on_input_event(_viewport, event, _shape_idx) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if GameManager.is_game_over:
		return
	if pov_target != "":
		get_node("/root/Main/POVManager").switch_to(pov_target)
		return
	print("[CLICK] " + item_name + ": " + description)
	if collectible:
		GameManager.collect_item(item_name)
		queue_free()
