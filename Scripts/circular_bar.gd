extends Control

@export var value: float = 0.7        # 0.0 to 1.0
@export var color: Color = Color.WHITE
@export var bg_color: Color = Color(0.2, 0.2, 0.2)
@export var thickness: float = 8.0
@export var radius: float = 30.0

func _draw() -> void:
	var center = Vector2(radius + thickness, radius + thickness)
	# background ring
	draw_arc(center, radius, 0, TAU, 64, bg_color, thickness)
	# fill ring — clockwise from top
	if value > 0.0:
		draw_arc(center, radius, -PI/2, -PI/2 + TAU * value,
			64, color, thickness)

func set_value(v: float) -> void:
	value = clamp(v, 0.0, 1.0)
	queue_redraw()
