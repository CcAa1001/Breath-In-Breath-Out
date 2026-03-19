# game_manager.gd
extends Node

signal game_over_triggered(reason: String)
signal item_collected(item_name: String)
signal item_returned(item_name: String)
signal oxygen_changed(value: float)
signal soil_changed(value: float)

var oxygen: float = 100.0
var oxygen_drain_rate: float = 3.0
var soil_pressure: float = 0.0
var soil_rate: float = 1.5

var inventory: Array[String] = []
var max_inventory: int = 2
var is_game_over: bool = false

# stores original positions for items that can be returned
var item_registry: Dictionary = {}

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

func register_item(item_name: String, node: Node) -> void:
	item_registry[item_name] = node

func collect_item(item_name: String) -> void:
	if item_name in inventory:
		return

	if inventory.size() >= max_inventory:
		# drop the oldest item back into the world
		var dropped = inventory[0]
		inventory.remove_at(0)
		if item_registry.has(dropped):
			item_registry[dropped].return_to_world()
		emit_signal("item_returned", dropped)

	inventory.append(item_name)
	emit_signal("item_collected", item_name)

func has_item(item_name: String) -> bool:
	return item_name in inventory

func remove_item(item_name: String) -> void:
	inventory.erase(item_name)
