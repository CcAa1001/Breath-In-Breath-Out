extends TextureRect

var tex_3: Texture2D
var tex_2: Texture2D
var tex_1: Texture2D
var tex_dead: Texture2D

func _ready() -> void:
	# load all 4 images
	tex_3    = load("res://assets/battery_3.png")
	tex_2    = load("res://assets/battery_2.png")
	tex_1    = load("res://assets/battery_1.png")
	tex_dead = load("res://assets/battery_dead.png")

	if not tex_3:    print("ERROR: battery_3.png not found")
	if not tex_2:    print("ERROR: battery_2.png not found")
	if not tex_1:    print("ERROR: battery_1.png not found")
	if not tex_dead: print("ERROR: battery_dead.png not found")

	# set starting image
	texture = tex_3

	# connect to game manager
	GameManager.battery_updated.connect(_on_battery)

func _on_battery(value: float) -> void:
	if value <= 0.0:
		texture = tex_dead
	elif value <= 25.0:
		texture = tex_1
	elif value <= 60.0:
		texture = tex_2
	else:
		texture = tex_3
