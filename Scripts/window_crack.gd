@tool
extends Node2D

@export var window_id: String = "front"
@export var spawn_width: float = 400.0 :
	set(v): spawn_width = v; queue_redraw()
@export var spawn_height: float = 150.0 :
	set(v): spawn_height = v; queue_redraw()
@export var show_preview: bool = true :
	set(v): show_preview = v; queue_redraw()
@export var preview_color: Color = Color(0, 1, 1, 0.25) :
	set(v): preview_color = v; queue_redraw()

var crack_textures: Dictionary = {}
var tape_texture:   Texture2D  = null
var crack_sprites:  Array      = []
var tape_sprites:   Array      = []
var current_phase:  int        = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_load_textures()
	GameManager.glass_cracked.connect(_on_crack)
	GameManager.game_over.connect(func(_r): _reset())
	GameManager.game_won.connect(func(_e):  _reset())

func _draw() -> void:
	if not show_preview: return
	var hw   = spawn_width  / 2.0
	var hh   = spawn_height / 2.0
	var rect = Rect2(Vector2(-hw, -hh), Vector2(spawn_width, spawn_height))
	draw_rect(rect, preview_color, true)
	draw_rect(rect, Color(0, 1, 1, 1.0), false, 3.0)
	draw_circle(Vector2.ZERO, 8.0, Color(1, 1, 0, 1.0))
	draw_circle(Vector2(-hw, -hh), 5.0, Color(1, 0, 0, 1.0))
	draw_circle(Vector2( hw, -hh), 5.0, Color(1, 0, 0, 1.0))
	draw_circle(Vector2(-hw,  hh), 5.0, Color(1, 0, 0, 1.0))
	draw_circle(Vector2( hw,  hh), 5.0, Color(1, 0, 0, 1.0))

func _load_textures() -> void:
	var paths = {
		1: "res://assets/crack_1.png",
		2: "res://assets/crack_2.png",
		3: "res://assets/crack_3.png",
		4: "res://assets/crack_4.png",
	}
	for phase in paths:
		if ResourceLoader.exists(paths[phase]):
			crack_textures[phase] = load(paths[phase])
		else:
			print("MISSING crack: ", paths[phase])
	if ResourceLoader.exists("res://assets/crack_tape.png"):
		tape_texture = load("res://assets/crack_tape.png")
	else:
		print("MISSING: crack_tape.png")

func _on_crack(id: String, phase: int) -> void:
	if Engine.is_editor_hint(): return
	if id != window_id: return
	if phase == -1: return  # tape visual handled by stamp_tape
	current_phase = phase
	_show_crack(phase)

func _show_crack(phase: int) -> void:
	# clear old crack sprites only
	for s in crack_sprites:
		if is_instance_valid(s): s.queue_free()
	crack_sprites.clear()

	var tex = crack_textures.get(phase, null)
	if tex == null:
		print("No texture for phase: ", phase)
		return

	for i in phase:
		var sprite      = Sprite2D.new()
		sprite.texture  = tex
		sprite.z_index  = 8
		# LOCAL position relative to THIS node
		# since this node sits on top of the window, cracks appear on the window
		sprite.position = Vector2(
			randf_range(-spawn_width  / 2.0 + 20, spawn_width  / 2.0 - 20),
			randf_range(-spawn_height / 2.0 + 20, spawn_height / 2.0 - 20))
		sprite.rotation = randf_range(-0.3, 0.3)

		var s: float
		match phase:
			1: s = 0.2
			2: s = 0.1
			3: s = 0.1
			4: s = 0.1
			_: s = 0.1
		sprite.scale = Vector2(s, s)


		if phase == 4:
			sprite.modulate = Color(0.8, 0.7, 0.6, 0.95)
		add_child(sprite)
		crack_sprites.append(sprite)

# world_pos comes from get_global_mouse_position() in tape_placement.gd
func stamp_tape(world_pos: Vector2, rot: float, scl: Vector2) -> void:
	if tape_texture == null:
		print("No tape texture!")
		return
	var sprite      = Sprite2D.new()
	sprite.texture  = tape_texture
	sprite.z_index  = 10
	# convert world pos to LOCAL position of this node
	# this makes the tape a child that moves WITH the window node
	sprite.position = to_local(world_pos)
	sprite.rotation = rot
	sprite.scale    = scl
	add_child(sprite)
	tape_sprites.append(sprite)
	print("Tape stamped on: ", window_id)

func _reset() -> void:
	for s in crack_sprites:
		if is_instance_valid(s): s.queue_free()
	crack_sprites.clear()
	for s in tape_sprites:
		if is_instance_valid(s): s.queue_free()
	tape_sprites.clear()
	current_phase = 0
