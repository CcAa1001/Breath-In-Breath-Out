extends Panel

# screens
var home_screen:    Control
var berita_screen:  Control
var pesan_screen:   Control
var telepon_screen: Control

# home
var notif_container: VBoxContainer

# pesan
var message_list: VBoxContainer

# telepon
var contact_list:    VBoxContainer
var status_label:    Label
var is_calling:      bool = false
var calling_contact: Dictionary = {}

# berita
var article_list: VBoxContainer

# navigation
var close_btn: Button
var home_btn:  Button

# time
var time_label: Label

var click_blocker: ColorRect

func _ready() -> void:
	hide()

	home_screen    = get_node_or_null("HomeScreen")
	berita_screen  = get_node_or_null("HomeScreen/NewsScreen")
	pesan_screen   = get_node_or_null("HomeScreen/MessageScreen")
	telepon_screen = get_node_or_null("HomeScreen/CallScreen")

	notif_container = get_node_or_null("HomeScreen/NotifContainer")
	message_list    = get_node_or_null("HomeScreen/MessageScreen/MessageList")
	article_list    = get_node_or_null("HomeScreen/NewsScreen/ArticleList")
	time_label      = get_node_or_null("TimeLabel")
	close_btn       = get_node_or_null("CloseBtn")
	home_btn        = get_node_or_null("HomeBtn")
	
	var mom_btn  = get_node_or_null("HomeScreen/MessageScreen/MomBtn")
	var jake_btn = get_node_or_null("HomeScreen/MessageScreen/JakeBtn")
	print("MomBtn: ",  mom_btn  != null)
	print("JakeBtn: ", jake_btn != null)
	if mom_btn:
		mom_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		mom_btn.pressed.connect(func(): _open_message_thread("mom"))
	if jake_btn:
		jake_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		jake_btn.pressed.connect(func(): _open_message_thread("jake"))

	click_blocker              = ColorRect.new()
	click_blocker.color        = Color(0, 0, 0, 0)
	click_blocker.size         = Vector2(1920, 1080)
	click_blocker.position     = Vector2(0, 0)
	click_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	click_blocker.z_index      = 1
	click_blocker.visible      = false
	get_parent().add_child(click_blocker)
	z_index = 2

	if telepon_screen:
		contact_list = telepon_screen.get_node_or_null("ScrollContainer/ContactList")
		if not contact_list:
			contact_list = telepon_screen.get_node_or_null("ContactList")
		status_label = telepon_screen.get_node_or_null("StatusLabel")

	print("=== PhoneUI Init ===")
	print("HomeScreen:    ", home_screen    != null)
	print("NewsScreen:    ", berita_screen  != null)
	print("MessageScreen: ", pesan_screen   != null)
	print("CallScreen:    ", telepon_screen != null)
	print("NotifContainer:", notif_container != null)
	print("MessageList:   ", message_list   != null)
	print("ArticleList:   ", article_list   != null)
	print("ContactList:   ", contact_list   != null)
	print("StatusLabel:   ", status_label   != null)

	var btn_news = get_node_or_null("HomeScreen/AppGrid/NewsBtn")
	var btn_msg  = get_node_or_null("HomeScreen/AppGrid/MessageBtn")
	var btn_call = get_node_or_null("HomeScreen/AppGrid/CallBtn")

	print("NewsBtn: ",    btn_news != null)
	print("MessageBtn: ", btn_msg  != null)
	print("CallBtn: ",    btn_call != null)

	if btn_news: btn_news.pressed.connect(func(): _open_screen("berita"))
	if btn_msg:  btn_msg.pressed.connect(func():  _open_screen("pesan"))
	if btn_call: btn_call.pressed.connect(func(): _open_screen("telepon"))

	if berita_screen:
		var b = berita_screen.get_node_or_null("BackBtn")
		if b: b.pressed.connect(func(): _open_screen("home"))
	if pesan_screen:
		var b = pesan_screen.get_node_or_null("BackBtn")
		if b: b.pressed.connect(func(): _open_screen("home"))
	if telepon_screen:
		var b = telepon_screen.get_node_or_null("BackBtn")
		if b: b.pressed.connect(func(): _open_screen("home"))

	if close_btn: close_btn.pressed.connect(_close_phone)
	if home_btn:  home_btn.pressed.connect(func(): _open_screen("home"))

	GameManager.phone_message_received.connect(_on_message)
	GameManager.rescue_timer_updated.connect(_on_rescue_timer)

	_build_articles()
	_build_contacts()
	_open_screen("home")

# -------------------------------------------------------
# OPEN / CLOSE
# -------------------------------------------------------
func open_phone() -> void:
	if not GameManager.phone_collected:
		GameManager.show_dialogue("I don't have my phone.")
		return
	if GameManager.phone_is_dead or GameManager.battery <= 0.0:
		GameManager.show_dialogue("My phone is dead.")
		return
	visible = not visible
	if click_blocker:
		click_blocker.visible = visible
	if visible:
		_open_screen("home")
		_update_time()
		move_to_front()
		# force all mouse filters correct every time phone opens
		_fix_mouse_filters(self)

func _close_phone() -> void:
	hide()
	if click_blocker:
		click_blocker.visible = false
	var audio = get_node_or_null("/root/Main/AudioManager")
	if audio: audio.play_phone_click()

func _fix_mouse_filters(node: Node) -> void:
	if node is Button:
		(node as Button).mouse_filter = Control.MOUSE_FILTER_STOP
	elif node is Panel or node is PanelContainer:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	elif node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_fix_mouse_filters(child)

# -------------------------------------------------------
# SCREEN NAVIGATION
# -------------------------------------------------------
func _open_screen(screen: String) -> void:
	# hide all sub screens
	if berita_screen:  berita_screen.visible  = false
	if pesan_screen:   pesan_screen.visible   = false
	if telepon_screen: telepon_screen.visible = false

	var mom_screen  = get_node_or_null("/root/Main/UI/PhoneScreen/HomeScreen/MsgMomScreen")
	var jake_screen = get_node_or_null("/root/Main/UI/PhoneScreen/HomeScreen/MsgJakeScreen")
	if mom_screen:  mom_screen.visible  = false
	if jake_screen: jake_screen.visible = false

	# hide app grid when not on home — it blocks clicks otherwise
	var app_grid = get_node_or_null("HomeScreen/AppGrid")
	var notif    = get_node_or_null("HomeScreen/NotifContainer")

	match screen:
		"home":
			if home_screen:  home_screen.visible = true
			if app_grid:     app_grid.visible    = true
			if notif:        notif.visible       = true
			_update_time()
		"berita":
			if app_grid:     app_grid.visible    = false
			if notif:        notif.visible       = false
			if berita_screen: berita_screen.visible = true
			_build_articles()
		"pesan":
			if app_grid:     app_grid.visible    = false
			if notif:        notif.visible       = false
			if pesan_screen:  pesan_screen.visible = true
			_refresh_messages()
		"telepon":
			if app_grid:     app_grid.visible    = false
			if notif:        notif.visible       = false
			if telepon_screen: telepon_screen.visible = true
			var dial = telepon_screen.get_node_or_null("DialDisplay")
			if dial:
				for child in dial.get_children():
					child.queue_free()
			var st = telepon_screen.get_node_or_null("StatusLabel")
			if st and st is Label: st.text = ""

	if home_btn: home_btn.visible = (screen != "home")

# -------------------------------------------------------
# TIME
# -------------------------------------------------------
func _update_time() -> void:
	if not time_label: return
	var elapsed = int(GameManager.message_elapsed)
	var mins    = elapsed / 60
	var secs    = elapsed % 60
	time_label.text = "%02d:%02d" % [9 + mins, secs]

# -------------------------------------------------------
# BERITA
# -------------------------------------------------------
func _build_articles() -> void:
	# if image asset exists — show it instead of generated text
	var news_bg = get_node_or_null("HomeScreen/NewsScreen/NewsBG")
	if ResourceLoader.exists("res://assets/phone_news.png"):
		if news_bg:
			news_bg.texture = load("res://assets/phone_news.png")
			news_bg.visible = true
		if article_list: article_list.visible = false
		return

	if not article_list:
		print("WARNING: ArticleList not found")
		return
	for child in article_list.get_children():
		child.queue_free()

	for article in PhoneContent.news_articles:
		var card = PanelContainer.new()
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)

		var top_row = HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)

		var tag_lbl = Label.new()
		tag_lbl.text = article.get("tag", "NEWS")
		tag_lbl.add_theme_font_size_override("font_size", 10)
		tag_lbl.modulate = PhoneContent.tag_colors.get(article.get("tag", "NEWS"), Color.WHITE)

		var time_lbl = Label.new()
		time_lbl.text = article.get("time", "")
		time_lbl.add_theme_font_size_override("font_size", 10)
		time_lbl.modulate = Color(0.6, 0.6, 0.6)

		top_row.add_child(tag_lbl)
		top_row.add_child(time_lbl)

		var title_lbl = Label.new()
		title_lbl.text = article["title"]
		title_lbl.add_theme_font_size_override("font_size", 13)
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if article.get("urgent", false):
			title_lbl.modulate = Color(1.0, 0.8, 0.8)

		var body_lbl = Label.new()
		body_lbl.text = article["body"]
		body_lbl.add_theme_font_size_override("font_size", 11)
		body_lbl.modulate = Color(0.75, 0.75, 0.75)
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var sep = HSeparator.new()
		vbox.add_child(top_row)
		vbox.add_child(title_lbl)
		vbox.add_child(body_lbl)
		vbox.add_child(sep)
		card.add_child(vbox)
		article_list.add_child(card)

# -------------------------------------------------------
# PESAN
# -------------------------------------------------------
func _on_message(sender: String, message: String) -> void:
	_add_notif(sender, message)

func _add_notif(sender: String, message: String) -> void:
	if not notif_container: return
	var notif = PanelContainer.new()
	var vbox  = VBoxContainer.new()
	var lbl_s = Label.new()
	var lbl_m = Label.new()
	lbl_s.text = sender
	lbl_s.add_theme_font_size_override("font_size", 12)
	lbl_m.text = message
	lbl_m.add_theme_font_size_override("font_size", 10)
	lbl_m.modulate = Color(0.7, 0.7, 0.7)
	lbl_m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl_s)
	vbox.add_child(lbl_m)
	notif.add_child(vbox)
	notif_container.add_child(notif)
	if notif_container.get_child_count() > 3:
		notif_container.get_child(0).queue_free()

func _refresh_messages() -> void:
	# DO NOT create buttons here — they already exist in the scene
	# just update the image background
	var msg_bg = get_node_or_null("HomeScreen/MessageScreen/MessagesBG")
	if msg_bg and ResourceLoader.exists("res://assets/phone_messages.png"):
		msg_bg.texture = load("res://assets/phone_messages.png")
		msg_bg.visible = true

	var mom_btn  = get_node_or_null("/root/Main/UI/PhoneScreen/HomeScreen/MessageScreen/MomBtn")
	var jake_btn = get_node_or_null("/root/Main/UI/PhoneScreen/HomeScreen/MessageScreen/JakeBtn")
	print("MomBtn: ",  mom_btn  != null)
	print("JakeBtn: ", jake_btn != null)
	if mom_btn:
		mom_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		if not mom_btn.pressed.is_connected(func(): _open_message_thread("mom")):
			mom_btn.pressed.connect(func(): _open_message_thread("mom"))
	if jake_btn:
		jake_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		if not jake_btn.pressed.is_connected(func(): _open_message_thread("jake")):
			jake_btn.pressed.connect(func(): _open_message_thread("jake"))

func _open_message_thread(thread_sender: String) -> void:
	if pesan_screen: pesan_screen.visible = false

	# use confirmed correct paths
	var thread_screen: Node
	if thread_sender == "mom":
		thread_screen = get_node_or_null("/root/Main/UI/PhoneScreen/HomeScreen/MsgMomScreen")
	else:
		thread_screen = get_node_or_null("/root/Main/UI/PhoneScreen/HomeScreen/MsgJakeScreen")

	if not thread_screen:
		print("ERROR: Thread screen not found for: ", thread_sender)
		return

	thread_screen.visible = true

	# set background image
	var bg = thread_screen.get_node_or_null("ThreadBG")
	if bg:
		var img_path = "res://assets/phone_msg_mom.png" if thread_sender == "mom" \
			else "res://assets/phone_msg_jake.png"
		if ResourceLoader.exists(img_path):
			bg.texture = load(img_path)
			bg.visible = true

	# populate messages
	var msg_list = thread_screen.get_node_or_null("MessageList")
	if msg_list:
		for child in msg_list.get_children():
			child.queue_free()
		var found_any = false
		for msg in GameManager.messages:
			if msg["sender"].to_lower() != thread_sender: continue
			found_any = true
			var lbl = Label.new()
			lbl.text = msg["message"]
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			msg_list.add_child(lbl)
		if not found_any:
			var empty = Label.new()
			empty.text = "No messages yet..."
			empty.modulate = Color(0.5, 0.5, 0.5)
			empty.add_theme_font_size_override("font_size", 13)
			msg_list.add_child(empty)

	# back button
	var back = thread_screen.get_node_or_null("BackBtn")
	if back:
		for c in back.pressed.get_connections():
			back.pressed.disconnect(c.callable)
		back.pressed.connect(func():
			thread_screen.visible = false
			if pesan_screen: pesan_screen.visible = true)

# -------------------------------------------------------
# TELEPON
# -------------------------------------------------------
func _build_contacts() -> void:
	if not contact_list:
		print("WARNING: ContactList not found")
		return
	for child in contact_list.get_children():
		child.queue_free()

	for contact in PhoneContent.contacts:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var info     = VBoxContainer.new()
		var name_lbl = Label.new()
		var num_lbl  = Label.new()

		name_lbl.text = contact["name"]
		name_lbl.add_theme_font_size_override("font_size", 13)
		num_lbl.text = contact["number"]
		num_lbl.add_theme_font_size_override("font_size", 11)
		num_lbl.modulate = Color(0.6, 0.6, 0.6)

		if contact.get("locked", false) and not GameManager.has_emergency_number:
			name_lbl.text     = "🔒 " + contact["name"]
			name_lbl.modulate = Color(0.6, 0.6, 0.6)

		info.add_child(name_lbl)
		info.add_child(num_lbl)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var call_button = Button.new()
		call_button.text = "📞"
		call_button.custom_minimum_size = Vector2(50, 40)
		var c = contact
		call_button.pressed.connect(func(): _call_contact(c))

		row.add_child(info)
		row.add_child(call_button)
		contact_list.add_child(row)

		var sep = HSeparator.new()
		contact_list.add_child(sep)

func _refresh_contacts() -> void:
	_build_contacts()

func _call_contact(contact: Dictionary) -> void:
	if is_calling: return

	if contact.get("locked", false) and not GameManager.has_emergency_number:
		if status_label:
			status_label.text = "🔒 Need emergency number first."
		return

	match contact.get("type", "personal"):
		"emergency":
			if GameManager.rescue_called:
				if status_label:
					status_label.text = "Already called. Rescue in " + \
						str(int(GameManager.rescue_timer)) + "s"
				return
			_close_phone()
			await get_tree().create_timer(0.3).timeout
			var call_screen = get_node_or_null("/root/Main/UI/EmergencyCallScreen")
			if call_screen:
				call_screen.open_call()
			else:
				print("ERROR: EmergencyCallScreen not found")
		"personal":
			if status_label:
				status_label.text = contact.get("note", "No signal underground.")
		"unavailable":
			if status_label:
				status_label.text = contact.get("note", "Cannot connect.")

func _start_calling(contact: Dictionary) -> void:
	is_calling      = true
	calling_contact = contact

	if status_label:
		status_label.text = "Calling " + contact["name"] + "..."

	var audio = get_node_or_null("/root/Main/AudioManager")
	if audio: audio.play("phone_calling")

	await get_tree().create_timer(PhoneContent.call_connecting_time).timeout
	if not is_calling: return

	if status_label:
		status_label.text = "✓ Connected! Help is on the way!"

	GameManager.call_emergency()
	is_calling = false
	_refresh_contacts()

	await get_tree().create_timer(2.0).timeout
	_close_phone()

func _on_rescue_timer(seconds_left: float) -> void:
	if not telepon_screen or not telepon_screen.visible: return
	if not status_label: return
	if seconds_left > 0:
		status_label.text = "🚨 Rescue arriving in " + str(int(seconds_left)) + "s..."
	else:
		status_label.text = "🚨 Rescue is here!"
