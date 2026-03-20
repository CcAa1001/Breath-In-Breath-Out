extends Node2D

var heartbeat_overlay: ColorRect
var crack_timer: float = 0.0
var heartbeat_timer: float = 0.0
var current_interval: float = 1.2
var is_beating: bool = false

func _ready() -> void:
	heartbeat_overlay = get_node_or_null("/root/Main/UI/HeartbeatOverlay")
	if not heartbeat_overlay:
		print("WARNING: HeartbeatOverlay not found")
	GameManager.oxygen_updated.connect(_on_oxygen)
	GameManager.panic_updated.connect(_on_panic)

func _process(delta: float) -> void:
	if not GameManager.game_running:
		return

	# heartbeat
	heartbeat_timer += delta
	if heartbeat_timer >= current_interval and is_beating:
		heartbeat_timer = 0.0
		_do_heartbeat()

	# cracks — appear more often as car air drops
	crack_timer += delta
	var crack_interval = lerp(25.0, 4.0, 1.0 - (GameManager.car_o2 / 100.0))
	if crack_timer >= crack_interval:
		crack_timer = 0.0
		_spawn_crack()
		get_node("/root/Main").trigger_shake(3.0)

func _on_oxygen(p_o2: float, _c: float) -> void:
	if p_o2 > 60.0:
		current_interval = 1.2
		is_beating = false
	elif p_o2 > 40.0:
		current_interval = 0.9
		is_beating = true
	elif p_o2 > 20.0:
		current_interval = 0.6
		is_beating = true
	else:
		current_interval = 0.3
		is_beating = true

func _on_panic(value: float) -> void:
	# extra shakes at high panic
	if value > 85.0:
		get_node("/root/Main").trigger_shake(randf_range(2.0, 6.0))

func _do_heartbeat() -> void:
	if not heartbeat_overlay:
		return
	var tween = create_tween()
	tween.tween_property(heartbeat_overlay, "modulate:a", 0.3, 0.06)
	tween.tween_property(heartbeat_overlay, "modulate:a", 0.0, 0.25)

func _spawn_crack() -> void:
	var crack = ColorRect.new()
	crack.color = Color(0.08, 0.04, 0.0, 0.9)
	crack.position = Vector2(
		randf_range(100, 1820),
		randf_range(50, 980))
	crack.size = Vector2(
		randf_range(2, 5),
		randf_range(50, 180))
	crack.rotation = randf_range(-0.4, 0.4)
	crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("/root/Main/UI").add_child(crack)

	var tween = create_tween()
	tween.tween_interval(randf_range(10.0, 25.0))
	tween.tween_property(crack, "modulate:a", 0.0, 2.0)
	tween.tween_callback(crack.queue_free)
