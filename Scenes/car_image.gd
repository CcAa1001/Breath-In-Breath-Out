extends Sprite2D

@export var texture_normal: Texture2D
@export var texture_cut:    Texture2D

func _ready() -> void:
	if texture_normal: texture = texture_normal
	if not texture_cut: print("WARNING: texture_cut not assigned!")

	# check current state immediately in case step already advanced
	if GameManager.escape_step >= 1 and texture_cut:
		texture = texture_cut
		print("CarImage: already cut on load")
	
	GameManager.escape_step_changed.connect(_on_step)

func _on_step(step: int) -> void:
	print("Step changed: ", step)
	if step >= 1 and texture_cut:
		texture = texture_cut
