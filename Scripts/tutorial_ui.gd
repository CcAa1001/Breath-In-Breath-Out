extends Control

var pages = [
	"res://assets/tutorial_1.png",
	"res://assets/tutorial_2.png",
	"res://assets/tutorial_3.png",
]
var current_page: int = 0
var on_finished: Callable

func _ready() -> void:
	visible = false
	var next_btn  = get_node_or_null("NextBtn")
	var close_btn = get_node_or_null("CloseBtn")
	if next_btn:  next_btn.pressed.connect(_on_next)
	if close_btn: close_btn.pressed.connect(_on_close)

func show_tutorial(finished_callback: Callable) -> void:
	on_finished   = finished_callback
	current_page  = 0
	visible       = true
	get_tree().paused = true
	_show_page(0)

func _show_page(idx: int) -> void:
	var img = get_node_or_null("TutorialImage")
	if img and ResourceLoader.exists(pages[idx]):
		img.texture = load(pages[idx])
	var next_btn = get_node_or_null("NextBtn")
	if next_btn:
		next_btn.text = ">" if idx < pages.size() - 1 else "Start!"

func _on_next() -> void:
	current_page += 1
	if current_page >= pages.size():
		_on_close()
	else:
		_show_page(current_page)

func _on_close() -> void:
	visible = false
	get_tree().paused = false
	if on_finished.is_valid():
		on_finished.call()
