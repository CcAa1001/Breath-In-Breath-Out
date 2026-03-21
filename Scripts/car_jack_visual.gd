extends Sprite2D

var bar: ProgressBar
var is_placed: bool = false

func _ready() -> void:
	bar = get_node_or_null("JackSlotBar")
	visible = false
	if bar: bar.visible = false
	GameManager.jack_progress_updated.connect(_on_progress)
	GameManager.escape_step_changed.connect(_on_step)
	GameManager.item_picked.connect(_on_item_picked)

func _on_item_picked(item_name: String) -> void:
	if item_name == "car_jack":
		# show hint label
		GameManager.show_dialogue("I have the car jack. Go to the door and hold E to place it.")

func place_jack() -> void:
	if is_placed: return
	is_placed = true
	visible   = true
	if bar: bar.visible = true
	# pop animation
	scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.3)\
		.set_trans(Tween.TRANS_BOUNCE)

func _on_progress(amount: float) -> void:
	if not is_placed and amount > 0.0:
		place_jack()
	if bar:
		bar.visible = is_placed and amount > 0.0 and amount < 1.0
		bar.value   = amount
	# shake the jack sprite as it pushes
	if is_placed and amount > 0.0 and amount < 1.0:
		rotation = randf_range(-0.05, 0.05)
	else:
		rotation = 0.0

func _on_step(step: int) -> void:
	if step >= 6:
		# jack done — freeze in place, hide bar
		if bar: bar.visible = false
		rotation = 0.0
