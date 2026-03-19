extends Node2D

var screen_w: float = 1152.0
var screen_h: float = 648.0
var max_intrusion: float = 250.0
var soil_color: Color = Color(0.25, 0.15, 0.05)

func _ready() -> void:
	GameManager.soil_changed.connect(_on_soil_changed)

	$TopSoil.color = soil_color
	$LeftSoil.color = soil_color
	$RightSoil.color = soil_color

	# Start with zero size
	$TopSoil.position = Vector2(0, 0)
	$TopSoil.size = Vector2(screen_w, 0)

	$LeftSoil.position = Vector2(0, 0)
	$LeftSoil.size = Vector2(0, screen_h)

	$RightSoil.position = Vector2(screen_w, 0)
	$RightSoil.size = Vector2(0, screen_h)

func _on_soil_changed(pressure: float) -> void:
	var amount = (pressure / 100.0) * max_intrusion
	$TopSoil.size.y = amount
	$LeftSoil.size.x = amount * 0.6
	$RightSoil.size.x = amount * 0.6
	$RightSoil.position.x = screen_w - (amount * 0.6)
