extends Control

func _ready() -> void:
	var retry = get_node_or_null("RetryBtn")
	var menu  = get_node_or_null("MenuBtn")
	if retry: retry.pressed.connect(_on_retry)
	if menu:  menu.pressed.connect(_on_menu)

func _on_retry() -> void:
	GameManager.reset()                          # reset state FIRST
	get_tree().paused = false                    # unpause if paused
	get_tree().reload_current_scene()

func _on_menu() -> void:
	GameManager.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/start_screen.tscn")
