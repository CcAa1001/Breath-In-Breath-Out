extends Panel

var messages_label: RichTextLabel
var all_messages: String = ""

func _ready() -> void:
	hide()
	messages_label = get_node_or_null("PhoneMessages")
	var close_btn  = get_node_or_null("PhoneCloseBtn")
	if close_btn:
		close_btn.pressed.connect(func(): hide())
	if messages_label:
		messages_label.bbcode_enabled = true
		messages_label.text = "[i]No messages yet...[/i]"
	GameManager.phone_message_received.connect(_on_message)

func _on_message(sender: String, message: String) -> void:
	all_messages += "[b]" + sender + ":[/b] " + message + "\n\n"
	if messages_label:
		messages_label.text = all_messages
