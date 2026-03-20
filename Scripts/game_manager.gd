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
signal glass_cracked(window_id: String, phase: int)
signal rescue_timer_updated(seconds_left: float)
signal game_won(ending: String)

# ---- MASTER SETTINGS ----
var player_drain_rate: float    = 0.556
var car_drain_rate: float       = 0.0
var breath_cost: float          = 10.0
var breath_hold_required: float = 1.5
var breath_cooldown_max: float  = 10.0
var breath_restore: float       = 100.0
var battery_drain_rate: float   = 0.833
var panic_build_rate: float     = 5.0
var panic_decay_rate: float     = 2.0
var blackout_death_time: float  = 8.0
var glass_crack_interval: float = 30.0
var rescue_arrival_time: float  = 120.0
# -------------------------

# oxygen
var player_o2: float      = 100.0
var car_o2: float         = 100.0
var is_breathing: bool    = false
var breath_hold_time: float = 0.0
var breath_cooldown: float  = 0.0
var prompt_active: bool   = false
var blacked_out: bool     = false
var blackout_timer: float = 0.0

# battery
var battery: float          = 100.0
var flashlight_active: bool = false

# panic + soil
var panic: float           = 0.0
var soil_multiplier: float = 1.0

# seatbelt
var seatbelt_cut: bool = false

# glass
var glass_phases: Dictionary = {"front": 0, "left": 0, "right": 0, "rear": 0}
var glass_timers: Dictionary = {"front": 0.0, "left": 0.0, "right": 0.0, "rear": 0.0}
var glass_taped: Dictionary  = {"front": false, "left": false, "right": false, "rear": false}
var duct_tape_uses: int = 3

# rescue
var rescue_called: bool        = false
var rescue_timer: float        = 0.0
var has_emergency_number: bool = false

# car jack
var jack_progress: float = 0.0
var jack_required: float = 3.0
var jack_complete: bool  = false

# escape steps:
# 0 = start, find phone
# 1 = cut seatbelt (can now explore)
# 2 = get screwdriver from back seat
# 3 = use screwdriver on glove box
# 4 = get duct tape + emergency number
# 5 = call emergency
# 6 = get car jack + shovel, force door
# 7 = WIN
var escape_step: int = 0

# inventory — phone has its OWN slot, does not count toward max_slots
var inventory: Array[String]  = []
var max_slots: int             = 2
var item_nodes: Dictionary     = {}
var phone_collected: bool      = false

# state
var game_running: bool = false
var is_dead: bool      = false

# phone messages
var messages: Array[Dictionary] = []
var message_elapsed: float = 0.0
var message_index: int     = 0
var message_timers: Array[float]     = [20.0, 45.0, 75.0, 110.0]
var _message_pool: Array[Dictionary] = [
	{"sender": "Mom",  "message": "Hey, are you coming for dinner tonight?"},
	{"sender": "Mom",  "message": "You're not answering... is everything ok?"},
	{"sender": "Jake", "message": "Dude where are you?? You were supposed to be here an hour ago"},
	{"sender": "Mom",  "message": "I'm calling the police. Something is wrong. ❤️"},
]

func _process(delta: float) -> void:
	if not game_running or is_dead:
		return

	# passive player breath drain
	if not is_breathing:
		player_o2 -= player_drain_rate * delta
	player_o2 = clamp(player_o2, 0.0, 100.0)
	car_o2    = clamp(car_o2,    0.0, 100.0)
	emit_signal("oxygen_updated", player_o2, car_o2)

	# blackout at 0 breath
	if player_o2 <= 0.0 and not blacked_out:
		blacked_out    = true
		blackout_timer = 0.0
		emit_signal("player_blacked_out", true)
	if blacked_out:
		blackout_timer += delta
		if blackout_timer >= blackout_death_time:
			_die("You couldn't breathe in time...")
	if blacked_out and player_o2 > 5.0:
		blacked_out    = false
		blackout_timer = 0.0
		emit_signal("player_blacked_out", false)

	# battery drain when flashlight on
	if flashlight_active:
		battery -= battery_drain_rate * delta
		battery  = clamp(battery, 0.0, 100.0)
		emit_signal("battery_updated", battery)
		if battery <= 0.0:
			flashlight_active = false
			emit_signal("battery_updated", 0.0)
			show_dialogue("My phone died... complete darkness.")

	# panic meter
	var both_critical = player_o2 < 30.0 and car_o2 < 30.0
	panic += (panic_build_rate if both_critical else -panic_decay_rate) * delta
	panic  = clamp(panic, 0.0, 100.0)
	emit_signal("panic_updated", panic)

	# breath cooldown
	if breath_cooldown > 0.0:
		breath_cooldown -= delta

	# breath prompt
	if player_o2 < 40.0 and breath_cooldown <= 0.0:
		if not prompt_active:
			prompt_active = true
			emit_signal("breath_prompt_show")
	elif player_o2 > 55.0 and prompt_active and not is_breathing:
		prompt_active = false
		emit_signal("breath_prompt_hide")

	# glass cracking
	_update_glass(delta)

	# rescue countdown
	if rescue_called:
		rescue_timer -= delta
		emit_signal("rescue_timer_updated", rescue_timer)
		if rescue_timer <= 0.0:
			_trigger_rescue_win()

	# phone messages
	if message_index < _message_pool.size() and message_index < message_timers.size():
		message_elapsed += delta
		if message_elapsed >= message_timers[message_index]:
			var msg = _message_pool[message_index]
			messages.append(msg)
			emit_signal("phone_message_received", msg["sender"], msg["message"])
			show_dialogue("📱 " + msg["sender"] + ": " + msg["message"])
			message_index += 1

	if car_o2 <= 0.0:
		_die("The air in the car ran out...")

# -------------------------------------------------------
# GLASS
# -------------------------------------------------------
func _update_glass(delta: float) -> void:
	for window in glass_phases.keys():
		if glass_taped[window]:  continue
		if glass_phases[window] >= 4: continue
		glass_timers[window] += delta
		if glass_timers[window] >= glass_crack_interval:
			glass_timers[window] = 0.0
			_advance_crack(window)

func _advance_crack(window: String) -> void:
	glass_phases[window] += 1
	emit_signal("glass_cracked", window, glass_phases[window])
	match glass_phases[window]:
		1: show_dialogue("*CRACK* — The " + window + " window has a small crack...")
		2: show_dialogue("*CRACK* — The " + window + " window crack is spreading!")
		3: show_dialogue("*CRACK* — The " + window + " window is about to break! Use duct tape!")
		4: _on_glass_broken(window)

func _on_glass_broken(window: String) -> void:
	show_dialogue("*SHATTER* — The " + window + " window broke! Soil is flooding in!")
	soil_multiplier += 0.5
	emit_signal("soil_speed_changed", soil_multiplier)

func use_duct_tape_on(window: String) -> void:
	if not has_item("duct_tape"):
		show_dialogue("I don't have duct tape.")
		return
	if glass_phases[window] >= 4:
		show_dialogue("It's too late — the window already broke!")
		return
	if glass_phases[window] == 0:
		show_dialogue("The window is fine. No need for tape yet.")
		return
	if glass_taped[window]:
		show_dialogue("This window is already taped.")
		return
	glass_taped[window] = true
	duct_tape_uses -= 1
	emit_signal("glass_cracked", window, -1)
	show_dialogue("I taped the " + window + " window. That should hold.")
	if duct_tape_uses <= 0:
		remove_item("duct_tape")
		show_dialogue("I used the last of the duct tape.")

# -------------------------------------------------------
# RESCUE
# -------------------------------------------------------
func call_emergency() -> void:
	if not phone_collected:
		show_dialogue("I need my phone.")
		return
	if not has_emergency_number:
		show_dialogue("I don't have the emergency number. Check the glove box.")
		return
	if rescue_called:
		show_dialogue("Already called. They're coming — " + str(int(rescue_timer)) + "s remaining.")
		return
	rescue_called = true
	rescue_timer  = rescue_arrival_time
	show_dialogue("I got through! They're coming! Hold on for " + str(int(rescue_arrival_time)) + " seconds!")
	escape_step = max(escape_step, 5)
	emit_signal("escape_step_changed", escape_step)

func use_hammer_for_noise() -> void:
	if not has_item("hammer"):
		show_dialogue("I need the hammer.")
		return
	if not rescue_called:
		show_dialogue("I'm banging on the car — but no one can hear me this deep...")
		return
	rescue_timer = max(rescue_timer - 20.0, 1.0)
	show_dialogue("*BANG BANG BANG* — That should help them find me faster!")

func use_hammer_on_glass() -> void:
	show_choice("Break the window with the hammer?",
		["Yes — smash it!", "No, that's a bad idea"])

# -------------------------------------------------------
# SEATBELT
# -------------------------------------------------------
func cut_seatbelt() -> void:
	seatbelt_cut = true
	show_dialogue("I cut the seatbelt. Now I can move around freely.")
	escape_step = max(escape_step, 1)
	emit_signal("escape_step_changed", escape_step)
	print("Seatbelt cut! Can now access back seat.")

# -------------------------------------------------------
# BREATHING
# -------------------------------------------------------
func hold_space(delta: float) -> void:
	if is_dead or not game_running:
		return
	# spam prevention — cooldown blocks new breath start
	if breath_cooldown > 0.0:
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
		if car_o2 > 0.0:
			is_breathing     = true
			breath_hold_time = 0.0

func release_space() -> void:
	if not is_breathing: return
	is_breathing     = false
	breath_hold_time = 0.0
	emit_signal("breath_progress", 0.0)

func _complete_breath() -> void:
	is_breathing     = false
	breath_hold_time = 0.0
	breath_cooldown  = breath_cooldown_max
	prompt_active    = false
	if blacked_out and player_o2 > 5.0:
		blacked_out    = false
		blackout_timer = 0.0
		emit_signal("player_blacked_out", false)
	emit_signal("breath_prompt_hide")
	emit_signal("breath_taken")
	emit_signal("breath_progress", 0.0)
	emit_signal("oxygen_updated", player_o2, car_o2)

# -------------------------------------------------------
# CAR JACK
# -------------------------------------------------------
func hold_jack(delta: float) -> void:
	if is_dead or not game_running or blacked_out:
		return
	if not has_item("car_jack"):
		show_dialogue("I need the car jack first.")
		return
	if jack_complete:
		show_dialogue("The jack is already in place.")
		return
	jack_progress += delta
	if jack_progress >= jack_required:
		jack_complete = true
		show_dialogue("The car jack is set! The door has some give now.")
		escape_step = max(escape_step, 6)
		emit_signal("escape_step_changed", escape_step)
	else:
		show_dialogue("Rolling the jack... " + str(int((jack_progress / jack_required) * 100)) + "%")

# -------------------------------------------------------
# DUCT TAPE
# -------------------------------------------------------
func apply_duct_tape() -> void:
	show_choice("Which window do you want to tape?",
		["Front window", "Left window", "Right window", "Rear window"])

# -------------------------------------------------------
# WIN / LOSE
# -------------------------------------------------------
func _trigger_rescue_win() -> void:
	rescue_called = false
	_win("rescue")

func _win(ending: String) -> void:
	game_running = false
	emit_signal("game_won", ending)

func _die(reason: String) -> void:
	if is_dead: return
	is_dead      = true
	game_running = false
	emit_signal("game_over", reason)

# -------------------------------------------------------
# INVENTORY — phone has its own slot
# -------------------------------------------------------
func pick_item(item_name: String, node: Node) -> void:
	item_nodes[item_name] = node

	# phone goes to its own permanent slot — never uses inventory space
	if item_name == "phone":
		if not phone_collected:
			phone_collected = true
			emit_signal("item_picked", item_name)
		return

	# already in inventory
	if item_name in inventory:
		return

	# normal 2-slot inventory
	if inventory.size() >= max_slots:
		var dropped = inventory.pop_front()
		emit_signal("item_dropped", dropped)
		if item_nodes.has(dropped):
			item_nodes[dropped].on_dropped()

	inventory.append(item_name)
	emit_signal("item_picked", item_name)

func has_item(item_name: String) -> bool:
	if item_name == "phone":
		return phone_collected
	return item_name in inventory

func remove_item(item_name: String) -> void:
	if item_name == "phone":
		phone_collected = false
	else:
		inventory.erase(item_name)
	emit_signal("item_dropped", item_name)

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
		show_dialogue("Battery dead.")
		return
	flashlight_active = on

func show_dialogue(text: String) -> void:
	emit_signal("dialogue_requested", text)

func request_pov_switch(target: String) -> void:
	emit_signal("pov_switch_requested", target)

func reset() -> void:
	player_o2 = 100.0; car_o2 = 100.0; battery = 100.0; panic = 0.0
	soil_multiplier = 1.0; seatbelt_cut = false
	is_breathing = false; breath_hold_time = 0.0; breath_cooldown = 0.0
	prompt_active = false; flashlight_active = false
	blacked_out = false; blackout_timer = 0.0
	rescue_called = false; rescue_timer = 0.0; has_emergency_number = false
	jack_progress = 0.0; jack_complete = false; escape_step = 0
	duct_tape_uses = 3; phone_collected = false
	for w in glass_phases.keys():
		glass_phases[w] = 0
		glass_timers[w] = 0.0
		glass_taped[w]  = false
	game_running = false; is_dead = false
	message_index = 0; message_elapsed = 0.0
	messages.clear(); inventory.clear(); item_nodes.clear()
