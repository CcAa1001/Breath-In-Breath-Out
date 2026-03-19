# game_manager.gd
extends Node

signal game_over_triggered(reason: String)
signal item_collected(item_name: String)
signal oxygen_changed(value: float)
signal soil_changed(value: float)

var oxygen: float = 100.0
var oxygen_drain_rate: float = 3.0   # per second — tune this later
var soil_pressure: float = 0.0
var soil_rate: float = 1.5           # per second

var inventory: Array[String] = []
var is_game_over: bool = false

func _process(delta: float) -> void:
	if is_game_over:
		return

	oxygen -= oxygen_drain_rate * delta
	oxygen = clamp(oxygen, 0.0, 100.0)
	emit_signal("oxygen_changed", oxygen)

	soil_pressure += soil_rate * delta
	soil_pressure = clamp(soil_pressure, 0.0, 100.0)
	emit_signal("soil_changed", soil_pressure)

	if oxygen <= 0.0:
		trigger_game_over("You ran out of oxygen...")
	elif soil_pressure >= 100.0:
		trigger_game_over("The soil crushed the car...")

func trigger_game_over(reason: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	emit_signal("game_over_triggered", reason)

func collect_item(item_name: String) -> void:
	if item_name not in inventory:
		inventory.append(item_name)
		emit_signal("item_collected", item_name)

func has_item(item_name: String) -> bool:
	return item_name in inventory
