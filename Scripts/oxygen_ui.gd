extends CanvasLayer

var player_bar: ProgressBar
var car_bar: ProgressBar
var prompt: Label
var breath_hold_bar: ProgressBar
var dialogue_box: Label        # ← change Panel to Label
var dialogue_text: Label       # ← change Label to Label (keep same)
var dialogue_tween: Tween

func _ready() -> void:
	# replace dialogue_box and dialogue_text with single label
	player_bar      = find_child("PlayerOxygenBar", true, false)
	car_bar         = find_child("CarOxygenBar", true, false)
	prompt          = find_child("BreathPrompt", true, false)
	breath_hold_bar = find_child("BreathHoldBar", true, false)
	dialogue_box    = find_child("DialogueLabel", true, false)  # now just a Label
	dialogue_text   = dialogue_box  # same node

	print("PlayerOxygenBar found: ", player_bar != null)
	print("CarOxygenBar found: ", car_bar != null)
	print("DialogueLabel found: ", dialogue_box != null)

	GameManager.oxygen_updated.connect(_on_oxygen)
	GameManager.breath_prompt_show.connect(_on_prompt_show)
	GameManager.breath_prompt_hide.connect(_on_prompt_hide)
	GameManager.breath_progress.connect(_on_breath_progress)
	GameManager.breath_taken.connect(_on_breath_taken)
	GameManager.dialogue_requested.connect(_on_dialogue)
	GameManager.game_over.connect(_on_game_over)

	if prompt: prompt.visible = false
	if dialogue_box: dialogue_box.visible = false
	if breath_hold_bar: breath_hold_bar.value = 0.0

func _on_oxygen(p_o2: float, c_o2: float) -> void:
	if player_bar:
		player_bar.value = p_o2
		if p_o2 > 60.0:   player_bar.modulate = Color.WHITE
		elif p_o2 > 30.0: player_bar.modulate = Color(1, 0.7, 0)
		else:              player_bar.modulate = Color(1, 0.25, 0.25)
	if car_bar:
		car_bar.value = c_o2
		if c_o2 > 50.0:   car_bar.modulate = Color(0.4, 0.85, 1.0)
		elif c_o2 > 25.0: car_bar.modulate = Color(1, 0.7, 0)
		else:              car_bar.modulate = Color(1, 0.25, 0.25)

func _on_prompt_show() -> void:
	if not prompt: return
	prompt.visible = true
	var tween = create_tween().set_loops()
	tween.tween_property(prompt, "modulate:a", 0.15, 0.2)
	tween.tween_property(prompt, "modulate:a", 1.0, 0.2)
	prompt.set_meta("flash", tween)

func _on_prompt_hide() -> void:
	if not prompt: return
	prompt.visible = false
	if prompt.has_meta("flash"):
		prompt.get_meta("flash").kill()
		prompt.remove_meta("flash")
	prompt.modulate.a = 1.0

func _on_breath_progress(amount: float) -> void:
	if breath_hold_bar:
		breath_hold_bar.value = amount

func _on_breath_taken() -> void:
	if breath_hold_bar: breath_hold_bar.value = 0.0
	_on_prompt_hide()

func _on_dialogue(text: String) -> void:
	print("Dialogue fired: ", text)
	if not dialogue_box:
		print("ERROR: DialogueLabel not found!")
		return

	# cast to Label directly
	var lbl = dialogue_box as Label
	if lbl: lbl.text = text

	if dialogue_tween and dialogue_tween.is_valid():
		dialogue_tween.kill()

	dialogue_box.modulate.a = 1.0
	dialogue_box.visible = true

	dialogue_tween = create_tween()
	dialogue_tween.tween_interval(3.0)
	dialogue_tween.tween_property(dialogue_box, "modulate:a", 0.0, 0.6)
	dialogue_tween.tween_callback(func(): dialogue_box.visible = false)
func _on_game_over(reason: String) -> void:
	var screen = find_child("GameOverScreen", true, false)
	if screen: screen.show()
	var label = find_child("ReasonLabel", true, false)
	if label: label.text = reason + "\n\nClick to restart"
