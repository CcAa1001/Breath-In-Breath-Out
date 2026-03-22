extends Panel

var questions = [
	{
		"question": "Emergency services, what is your emergency?",
		"answers":  ["I'm trapped in a car underground!", "Car accident", "I need help"],
		"correct":  0
	},
	{
		"question": "What road were you on?",
		"answers":  ["Linden Street", "Main Street", "I don't know"],
		"correct":  0
	},
	{
		"question": "Are you injured?",
		"answers":  ["No but I can't breathe much longer", "Yes badly", "I'm fine"],
		"correct":  0
	},
	{
		"question": "How long have you been trapped?",
		"answers":  ["I don't know — please hurry!", "A few minutes", "An hour"],
		"correct":  0
	},
	{
		"question": "Stay on the line. We are dispatching rescue. Can you make noise?",
		"answers":  ["Yes I have a hammer!", "No", "I'll try"],
		"correct":  0
	},
]

var current_q:   int  = 0
var wrong_count: int  = 0
var _active:     bool = false

func _ready() -> void:
	visible      = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func open_call() -> void:
	current_q   = 0
	wrong_count = 0
	_active     = true
	visible     = true
	move_to_front()
	_show_question(0)

func _show_question(idx: int) -> void:
	var q_label       = get_node_or_null("QuestionLabel")
	var btn_container = get_node_or_null("AnswerContainer")
	if not q_label or not btn_container:
		print("ERROR: EmergencyCallScreen missing QuestionLabel or AnswerContainer")
		return

	for child in btn_container.get_children():
		child.queue_free()

	q_label.text = "Operator: " + questions[idx]["question"]

	for i in questions[idx]["answers"].size():
		var btn                   = Button.new()
		btn.text                  = questions[idx]["answers"][i]
		btn.custom_minimum_size   = Vector2(600, 50)
		btn.mouse_filter          = Control.MOUSE_FILTER_STOP
		var idx_copy              = i
		btn.pressed.connect(func(): _on_answer(idx_copy))
		btn_container.add_child(btn)

func _on_answer(answer_idx: int) -> void:
	if not _active: return
	if answer_idx == questions[current_q]["correct"]:
		current_q += 1
		if current_q >= questions.size():
			_finish_call()
		else:
			_show_question(current_q)
	else:
		wrong_count += 1
		var q_label = get_node_or_null("QuestionLabel")
		if q_label:
			q_label.text = "Operator: I'm sorry, could you repeat that?\n" + \
				questions[current_q]["question"]

func _finish_call() -> void:
	_active = false
	var q_label       = get_node_or_null("QuestionLabel")
	var btn_container = get_node_or_null("AnswerContainer")
	if q_label:
		q_label.text = "Operator: Help is on the way! Rescue in " + \
			str(int(GameManager.rescue_arrival_time)) + " seconds!"
	if btn_container:
		for child in btn_container.get_children():
			child.queue_free()
	await get_tree().create_timer(3.0).timeout
	if not GameManager.is_dead:
		visible = false
		GameManager.call_emergency()

func _input(event: InputEvent) -> void:
	if not visible: return
	get_viewport().set_input_as_handled()
