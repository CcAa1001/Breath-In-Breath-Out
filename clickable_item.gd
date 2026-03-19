extends Area2D

@export var item_name: String = "item"
@export var description: String = "You found something."
@export var collectible: bool = true   # false = just shows text, doesn't go to inventory

func _ready() -> void:
	input_pickable = true
	connect("input_event", _on_input_event)

func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed:
		if GameManager.is_game_over:
			return
		print(description)   # replace with a proper dialogue box later
		if collectible:
			GameManager.collect_item(item_name)
			queue_free()     # remove from scene once picked up
