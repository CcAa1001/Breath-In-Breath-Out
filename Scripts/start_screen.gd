extends CanvasLayer

func _ready() -> void:
	# make sure credit is hidden
	var credit = get_node_or_null("Credit")
	if credit: credit.visible = false

	# connect buttons
	var play_btn   = get_node_or_null("MenuContainer/PlayBtn")
	var credit_btn = get_node_or_null("MenuContainer/CreditBtn")
	var exit_btn   = get_node_or_null("MenuContainer/ExitBtn")
	var close_btn  = get_node_or_null("Credit/CloseBtn")

	if play_btn:   play_btn.pressed.connect(_on_play)
	if credit_btn: credit_btn.pressed.connect(_on_credit)
	if exit_btn:   exit_btn.pressed.connect(_on_exit)
	if close_btn:  close_btn.pressed.connect(_on_close_credit)

	print("StartScreen ready")
	print("PlayBtn: ",   play_btn   != null)
	print("CreditBtn: ", credit_btn != null)
	print("ExitBtn: ",   exit_btn   != null)

func _on_play() -> void:
	print("Play pressed")
	var overlay = ColorRect.new()
	overlay.color           = Color(0, 0, 0, 0)
	overlay.z_index         = 100
	overlay.mouse_filter    = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 1.0)
	await tween.finished
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_credit() -> void:
	var credit = get_node_or_null("Credit")
	if credit: credit.visible = true

func _on_close_credit() -> void:
	var credit = get_node_or_null("Credit")
	if credit: credit.visible = false

func _on_exit() -> void:
	get_tree().quit()
