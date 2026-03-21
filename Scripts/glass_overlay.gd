extends Node2D

var crack_textures: Dictionary = {}
var tape_texture:   Texture2D  = null
var crack_sprites:  Dictionary = {}
var glass_zones:    Dictionary = {}

func _ready() -> void:
	_load_textures()
	GameManager.glass_cracked.connect(_on_crack)
	GameManager.game_over.connect(func(_r): _clear_all())
	GameManager.game_won.connect(func(_e): _clear_all())
	call_deferred("_find_zones")

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
			print("MISSING: ", paths[phase])
	if ResourceLoader.exists("res://assets/crack_tape.png"):
		tape_texture = load("res://assets/crack_tape.png")
	else:
		print("MISSING: crack_tape.png")

func _find_zones() -> void:
	var zone_paths = {
		"front": "/root/Main/POVManager/FrontRow/GlassZone_front",
		"left":  "/root/Main/POVManager/FrontRow/GlassZone_left",
		"right": "/root/Main/POVManager/FrontRow/GlassZone_right",
		"rear":  "/root/Main/POVManager/BackRow/GlassZone_rear",
	}
	for id in zone_paths:
		var node = get_node_or_null(zone_paths[id])
		if node:
			glass_zones[id] = node
			print("Zone: ", id, " local_pos: ", node.position, " parent: ", node.get_parent().name)
		else:
			print("WARNING: Zone missing: ", id)

func _get_zone_rect(zone: Node) -> Rect2:
	# use LOCAL position within the zone's parent
	# this keeps coordinates in the same space as the car image
	var shape_node = zone.get_node_or_null("Shape")
	if shape_node and shape_node.shape is RectangleShape2D:
		var rect_shape = shape_node.shape as RectangleShape2D
		var center     = zone.position  # LOCAL position, not global
		var half       = rect_shape.size / 2.0
		return Rect2(center - half, rect_shape.size)
	return Rect2(zone.position - Vector2(100, 60), Vector2(200, 120))

func _on_crack(window_id: String, phase: int) -> void:
	if phase == -1:
		_apply_tape(window_id)
		return

	_clear_window(window_id)

	if not glass_zones.has(window_id): return
	var tex = crack_textures.get(phase, null)
	if tex == null: return

	var zone      = glass_zones[window_id]
	var zone_rect = _get_zone_rect(zone)

	# get the parent node to add sprites to
	# this keeps cracks in the same coordinate space as the car image
	var parent_node = zone.get_parent()

	print("Spawning in parent: ", parent_node.name, " rect: ", zone_rect)

	var count   = phase
	var sprites: Array = []

	for i in count:
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.z_index = 8

		# position within parent local space
		sprite.position = Vector2(
			randf_range(zone_rect.position.x + 30, zone_rect.end.x - 30),
			randf_range(zone_rect.position.y + 30, zone_rect.end.y - 30))

		sprite.rotation = randf_range(-0.25, 0.25)
		var s = lerp(0.4, 1.1, float(phase) / 4.0) + randf_range(-0.05, 0.1)
		sprite.scale = Vector2(s, s)

		if phase == 4:
			sprite.modulate = Color(0.8, 0.7, 0.6, 0.9)

		# add to parent of zone, NOT to GlassOverlay
		parent_node.add_child(sprite)
		sprites.append(sprite)

	crack_sprites[window_id] = sprites
	print("Crack spawned: ", window_id, " phase=", phase)

func _apply_tape(window_id: String) -> void:
	_clear_window(window_id)
	if not glass_zones.has(window_id): return
	if tape_texture == null: return

	var zone        = glass_zones[window_id]
	var zone_rect   = _get_zone_rect(zone)
	var center      = zone_rect.get_center()
	var parent_node = zone.get_parent()

	var sprites:  Array = []
	var offsets   = [Vector2(-15, -10), Vector2(10, 15)]
	var rotations = [-0.3, 0.2]

	for i in 2:
		var sprite = Sprite2D.new()
		sprite.texture  = tape_texture
		sprite.z_index  = 9
		sprite.position = center + offsets[i]
		sprite.rotation = rotations[i]
		sprite.scale    = Vector2(0.5, 0.5)
		parent_node.add_child(sprite)
		sprites.append(sprite)

	crack_sprites[window_id] = sprites
	print("Tape applied: ", window_id)

func _clear_window(window_id: String) -> void:
	if not crack_sprites.has(window_id): return
	for s in crack_sprites[window_id]:
		if is_instance_valid(s):
			s.queue_free()
	crack_sprites.erase(window_id)

func _clear_all() -> void:
	for id in crack_sprites.keys():
		_clear_window(id)
	crack_sprites.clear()
