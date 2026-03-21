extends Node2D

var screen_w: float = 1920.0
var screen_h: float = 1080.0
var max_intrusion: float = 300.0
var soil_color: Color = Color(0.24, 0.13, 0.03)
var elapsed: float = 0.0
var total_time: float = 180.0   # soil fully closes in 3 minutes

func _ready() -> void:
	$TopSoil.color = soil_color
	$TopSoil.position = Vector2(0, 0)
	$TopSoil.size = Vector2(screen_w, 0)
	$TopSoil.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not GameManager.game_running:
		return
	elapsed += delta
	var pressure = clamp(elapsed / total_time, 0.0, 1.0)
	var amount = pressure * max_intrusion
	$TopSoil.size.y = amount
