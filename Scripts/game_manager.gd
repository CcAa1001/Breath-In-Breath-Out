extends Node

signal oxygen_updated(player_o2: float, car_o2: float)
signal breath_prompt_show()
signal breath_prompt_hide()
signal breath_progress(amount: float)
signal breath_taken()
signal game_over(reason: String)
signal item_picked(item_name: String)
signal item_dropped(item_name: String)
signal dialogue_requested(text: String)
signal choice_requested(prompt: String, options: Array)
signal panic_updated(value: float)
signal battery_updated(value: float)
signal escape_step_changed(step: int)
signal phone_message_received(sender: String, message: String)
signal player_blacked_out(is_out: bool)
signal soil_speed_changed(multiplier: float)
signal pov_switch_requested(target: String)

# ---- MASTER SETTINGS (press M in game to open panel) ----
var player_drain_rate: float    = 10
var car_drain_rate: float       = 0.0
var breath_cost: float          = 10.0
var waste_penalty: float        = 3.0
var breath_hold_required: float = 1.5
var breath_cooldown_max: float  = 10.0
var breath_restore: float       = 180.0
var battery_drain_rate: float   = 0.833
var panic_build_rate: float     = 5.0
var panic_decay_rate: float     = 2.0
# ---------------------------------------------------------

# oxygen
var player_o2: float    = 100.0
var car_o2: float       = 100.0
var is_breathing: bool  = false
var breath_hold_time: float = 0.0
var breath_cooldown: float  = 0.0
var prompt_active: bool = false
var blacked_out: bool   = false   # true when breath hits 0

# battery
var battery: float          = 100.0
var flashlight_active: bool = false

# panic
var panic: float = 0.0

# soil speed multiplier — duct tape reduces this
var soil_multiplier: float = 1.0

# inventory
var inventory: Array[String] = []
var max_slots: int = 2
var item_nodes: Dictionary = {}

# car jack progress
var jack_progress: float   = 0.0
var jack_required: float   = 3.0   # hold E for 3 seconds
var jack_complete: bool    = false

# escape steps
# 0 = find phone
# 1 = find key
# 2 = use key → glove box → get screwdriver
# 3 = use screwdriver → force door open
# 4 = go back seat → find shovel
# 5 = dig out → WIN
var escape_step: int = 0

# state
var game_running: bool = false
var is_dead: bool      = false

# phone messages
var messages: Array[Dictionary] = []
var message_elapsed: float = 0.0
var message_index: int = 0
var message_timers: Array[float] = [15.0, 35.0, 60.0, 90.0]
var _message_pool: Array[Dictionary] = [
	{"sender": "Mom",  "message": "Hey, are you coming for dinner tonight?"},
	{"sender": "Mom",  "message": "You're not answering... is everything ok?"},
	{"sender": "Jake", "message": "Dude where are you?? You were supposed to be here an hour ago"},
	{"sender": "Mom",  "message": "I'm worried. Please call me back. ❤️"},
]

func _process(delta: float) -> void:
	if not game_running or is_dead:
		return

	# passive drains
	#car_o2 -= car_drain_rate * delta * soil_multiplier
	if not is_breathing:
		player_o2 -= player_drain_rate * delta
	car_o2    = clamp(car_o2,    0.0, 100.0)
	player_o2 = clamp(player_o2, 0.0, 100.0)
	emit_signal("oxygen_updated", player_o2, car_o2)

	# blackout when breath hits 0
	if player_o2 <= 0.0 and not blacked_out:
		blacked_out = true
		emit_signal("player_blacked_out", true)
	elif player_o2 > 5.0 and blacked_out:
		blacked_out = false
		emit_signal("player_blacked_out", false)

	# battery drain when flashlight on
	if flashlight_active:
		battery -= battery_drain_rate * delta
		battery = clamp(battery, 0.0, 100.0)
		emit_signal("battery_updated", battery)
		if battery <= 0.0:
			flashlight_active = false
			emit_signal("battery_updated", 0.0)
			show_dialogue("My phone died... complete darkness.")

	# panic meter — builds when both are critical
	var both_critical = player_o2 < 30.0 and car_o2 < 30.0
	if both_critical:
		panic += panic_build_rate * delta
	else:
		panic -= panic_decay_rate * delta
	panic = clamp(panic, 0.0, 100.0)
	emit_signal("panic_updated", panic)

	# breath cooldown
	if breath_cooldown > 0.0:
		breath_cooldown -= delta

	# breath prompt when low
	if player_o2 < 40.0 and breath_cooldown <= 0.0 and not blacked_out:
		if not prompt_active:
			prompt_active = true
			emit_signal("breath_prompt_show")
	elif player_o2 > 55.0 and prompt_active and not is_breathing:
		prompt_active = false
		emit_signal("breath_prompt_hide")

	# phone messages
	if message_index < _message_pool.size() and message_index < message_timers.size():
		message_elapsed += delta
		if message_elapsed >= message_timers[message_index]:
			var msg = _message_pool[message_index]
			messages.append(msg)
			emit_signal("phone_message_received", msg["sender"], msg["message"])
			show_dialogue("📱 New message from " + msg["sender"])
			message_index += 1

	# death
	if player_o2 <= 0.0 and blacked_out:
		# give player 5 seconds to breathe before dying
		pass  # blacked_out handles the lockout, death comes from car_o2
	if car_o2 <= 0.0:
		_die("The air in the car ran out...")

func hold_space(delta: float) -> void:
	if is_dead or not game_running or blacked_out:
		return
	if is_breathing:
		breath_hold_time += delta
		var progress = clamp(breath_hold_time / breath_hold_required, 0.0, 1.0)
		player_o2 = clamp(player_o2 + (breath_restore / breath_hold_required) * delta, 0.0, 100.0)
		car_o2    = clamp(car_o2 - (breath_cost / breath_hold_required) * delta, 0.0, 100.0)
		emit_signal("breath_progress", progress)
		emit_signal("oxygen_updated", player_o2, car_o2)
		if breath_hold_time >= breath_hold_required:
			_complete_breath()
	else:
		if breath_cooldown > 0.0:
			car_o2 = clamp(car_o2 - (breath_cost / breath_hold_required) * delta, 0.0, 100.0)
			emit_signal("oxygen_updated", player_o2, car_o2)
		else:
			is_breathing = true
			breath_hold_time = 0.0

func hold_jack(delta: float) -> void:
	# called from main.gd when E is held and car jack is in inventory
	if is_dead or not game_running or blacked_out:
		return
	if not has_item("car_jack"):
		show_dialogue("I don't have the car jack.")
		return
	if jack_complete:
		show_dialogue("The jack is already in place.")
		return
	jack_progress += delta
	show_dialogue("Rolling the jack... " + str(int((jack_progress / jack_required) * 100)) + "%")
	if jack_progress >= jack_required:
		jack_complete = true
		if escape_step == 3:
			advance_escape_step("car_jack")
		show_dialogue("The car jack is in place! Now force the door.")

func release_space() -> void:
	if not is_breathing:
		return
	is_breathing    = false
	breath_hold_time = 0.0
	emit_signal("breath_progress", 0.0)

func _complete_breath() -> void:
	is_breathing    = false
	breath_hold_time = 0.0
	breath_cooldown  = breath_cooldown_max
	prompt_active    = false
	if blacked_out:
		blacked_out = false
		emit_signal("player_blacked_out", false)
	emit_signal("breath_prompt_hide")
	emit_signal("breath_taken")
	emit_signal("breath_progress", 0.0)
	emit_signal("oxygen_updated", player_o2, car_o2)

func apply_duct_tape() -> void:
	if not has_item("duct_tape"):
		show_dialogue("I need duct tape to seal the cracks.")
		return
	soil_multiplier = 0.4
	emit_signal("soil_speed_changed", soil_multiplier)
	show_dialogue("I sealed the cracks with duct tape. That should slow things down.")
	remove_item("duct_tape")

func advance_escape_step(required_item: String) -> bool:
	if not has_item(required_item):
		show_dialogue("I need something to do this...")
		return false
	escape_step += 1
	emit_signal("escape_step_changed", escape_step)
	return true

func show_choice(prompt: String, options: Array) -> void:
	emit_signal("choice_requested", prompt, options)

func set_flashlight(on: bool) -> void:
	if battery <= 0.0 and on:
		show_dialogue("Battery dead. Can't turn it on.")
		return
	flashlight_active = on

func show_dialogue(text: String) -> void:
	emit_signal("dialogue_requested", text)

func _die(reason: String) -> void:
	if is_dead:
		return
	is_dead      = true
	game_running = false
	emit_signal("game_over", reason)

func pick_item(item_name: String, node: Node) -> void:
	if item_name in inventory:
		return
	item_nodes[item_name] = node
	if inventory.size() >= max_slots:
		var dropped = inventory.pop_front()
		emit_signal("item_dropped", dropped)
		if item_nodes.has(dropped):
			item_nodes[dropped].on_dropped()
	inventory.append(item_name)
	emit_signal("item_picked", item_name)

func has_item(item_name: String) -> bool:
	return item_name in inventory

func remove_item(item_name: String) -> void:
	inventory.erase(item_name)
	emit_signal("item_dropped", item_name)

func request_pov_switch(target: String) -> void:
	emit_signal("pov_switch_requested", target)

func reset() -> void:
	player_o2        = 100.0
	car_o2           = 100.0
	battery          = 100.0
	panic            = 0.0
	soil_multiplier  = 1.0
	is_breathing     = false
	breath_hold_time = 0.0
	breath_cooldown  = 0.0
	prompt_active    = false
	flashlight_active = false
	blacked_out      = false
	escape_step      = 0
	jack_progress    = 0.0
	jack_complete    = false
	game_running     = false
	is_dead          = false
	message_index    = 0
	message_elapsed  = 0.0
	messages.clear()
	inventory.clear()
	item_nodes.clear()
