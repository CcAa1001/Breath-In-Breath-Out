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
signal glass_progress_updated(window_id: String, progress: float)
signal rescue_timer_updated(seconds_left: float)
signal game_won(ending: String)
signal phone_dead()
signal jack_progress_updated(amount: float)
signal panic_shake(amount: float)
signal cue_changed(cue: int)
signal hammer_banged()

# ---- MASTER SETTINGS ----
var player_drain_rate: float    = 0.556
var car_drain_rate: float       = 0.3
var breath_cost: float          = 10.0
var breath_hold_required: float = 1.5
var breath_cooldown_max: float  = 10.0
var breath_restore: float       = 100.0
var battery_drain_rate: float   = 0.833
var panic_build_rate: float     = 3.0
var panic_decay_rate: float     = 1.5
var blackout_death_time: float  = 5.0
var glass_crack_interval: float = 30.0
var glass_fill_rate: float      = 100.0 / 30.0
var rescue_arrival_time: float  = 120.0
# -------------------------

# oxygen
var player_o2: float        = 100.0
var car_o2: float           = 100.0
var is_breathing: bool      = false
var breath_hold_time: float = 0.0
var breath_cooldown: float  = 0.0
var prompt_active: bool     = false
var blacked_out: bool       = false
var blackout_timer: float   = 0.0

# battery
var battery: float          = 100.0
var flashlight_active: bool = false
var phone_is_dead: bool     = false

# panic + soil
var panic: float           = 0.0
var soil_multiplier: float = 1.0

# seatbelt
var seatbelt_cut: bool = false

# glass
var glass_points:     Dictionary = {"front": 0.0,  "left": 0.0,  "right": 0.0,  "rear": 0.0}
var glass_phases:     Dictionary = {"front": 0,    "left": 0,    "right": 0,    "rear": 0}
var glass_taped:      Dictionary = {"front": false, "left": false, "right": false, "rear": false}
var glass_tape_count: Dictionary = {"front": 0,    "left": 0,    "right": 0,    "rear": 0}
var glass_timers:     Dictionary = {"front": 0.0,  "left": 0.0,  "right": 0.0,  "rear": 0.0}
var duct_tape_uses:   int        = 6

# rescue
var rescue_called: bool        = false
var rescue_timer: float        = 0.0
var has_emergency_number: bool = false

# hammer cooldown — FIX: prevents spam exploit
var hammer_cooldown: float = 0.0

# car jack
var jack_progress: float  = 0.0
var jack_required: float  = 3.0
var jack_complete: bool   = false
var jack_placed: bool     = false
var _jack_msg_shown: bool = false

# escape steps
var escape_step: int = 0

# inventory
var inventory: Array[String] = []
var max_slots: int            = 2
var item_nodes: Dictionary    = {}
var phone_collected: bool     = false

# state
var game_running: bool = true
var is_dead: bool      = false
var honk_broken: bool  = false

# cue system
var current_cue: int    = 1
var game_elapsed: float = 0.0
var cue_2_started: bool = false
var cue_2_time: float   = 120.0

# phone messages
var messages: Array[Dictionary]      = []
var message_elapsed: float           = 0.0
var message_index: int               = 0
var message_timers: Array[float]     = []
var _message_pool: Array[Dictionary] = []

# -------------------------------------------------------
# READY
# -------------------------------------------------------
func _ready() -> void:
	_message_pool  = PhoneContent.scheduled_messages
	message_timers = []
	for msg in PhoneContent.scheduled_messages:
		message_timers.append(msg["time"])
	rescue_arrival_time = PhoneContent.rescue_arrival_time

	# FIX 3: Apply random offsets to glass_points, not glass_timers
	# glass_timers was never used — this actually staggers the windows
	glass_points["front"] = 0.0
	glass_points["left"]  = randf_range(0.0, 50.0)
	glass_points["right"] = randf_range(0.0, 50.0)
	glass_points["rear"]  = randf_range(0.0, 30.0)

# -------------------------------------------------------
# PROCESS
# -------------------------------------------------------
func _process(delta: float) -> void:
	if not game_running or is_dead:
		return

	# cue timer
	game_elapsed += delta
	if not cue_2_started and game_elapsed >= cue_2_time:
		cue_2_started = true
		emit_signal("cue_changed", 2)
		show_dialogue("*distant rumbling* — Something is happening above...")

	# passive breath drain
	if not is_breathing:
		player_o2 -= player_drain_rate * delta

	# passive car drain
	car_o2 -= car_drain_rate * delta * soil_multiplier
	player_o2 = clamp(player_o2, 0.0, 100.0)
	car_o2    = clamp(car_o2,    0.0, 100.0)
	emit_signal("oxygen_updated", player_o2, car_o2)

	# blackout
	if player_o2 <= 0.0 and not blacked_out:
		blacked_out    = true
		blackout_timer = 0.0
		emit_signal("player_blacked_out", true)

	# FIX 4: removed early wake-up check from here
	# _complete_breath() handles waking up properly
	if blacked_out:
		blackout_timer += delta
		if blackout_timer >= blackout_death_time:
			_die_suffocated()
			return

	# car air empty
	if car_o2 <= 0.0:
		_die_suffocated()
		return

	# battery
	if flashlight_active:
		battery -= battery_drain_rate * delta
		battery  = clamp(battery, 0.0, 100.0)
		emit_signal("battery_updated", battery)
		if battery <= 0.0 and not phone_is_dead:
			battery           = 0.0
			flashlight_active = false
			phone_is_dead     = true
			emit_signal("battery_updated", 0.0)
			emit_signal("phone_dead")
			show_dialogue("My phone battery died. Complete darkness.")

	# panic meter
	var panic_delta: float = 0.0
	if player_o2 < 30.0:    panic_delta += 4.0 * delta
	if car_o2 < 30.0:       panic_delta += 3.0 * delta
	if blacked_out:          panic_delta += 8.0 * delta
	for w in glass_phases.keys():
		if glass_phases[w] >= 3: panic_delta += 1.0 * delta
	if player_o2 > 70.0:    panic_delta -= panic_decay_rate * delta
	if rescue_called:        panic_delta -= 1.0 * delta
	panic = clamp(panic + panic_delta, 0.0, 100.0)
	emit_signal("panic_updated", panic)

	# FIX 2: always emit panic_shake — sends 0 when calm so camera resets
	if panic >= 50.0:
		emit_signal("panic_shake", remap(panic, 50.0, 100.0, 0.0, 8.0))
	else:
		emit_signal("panic_shake", 0.0)

	# extra O2 drain at high panic
	if panic >= 70.0:
		player_o2 -= 0.5 * delta
		player_o2 = clamp(player_o2, 0.0, 100.0)

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

	# FIX 2: hammer cooldown tick
	if hammer_cooldown > 0.0:
		hammer_cooldown -= delta

	_update_glass(delta)

	if rescue_called:
		rescue_timer -= delta
		emit_signal("rescue_timer_updated", rescue_timer)
		if rescue_timer <= 0.0:
			_trigger_rescue_win()

	if message_index < _message_pool.size():
		message_elapsed += delta
		if message_elapsed >= _message_pool[message_index]["time"]:
			var msg = _message_pool[message_index]
			messages.append(msg)
			emit_signal("phone_message_received", msg["sender"], msg["message"])
			show_dialogue("📱 " + msg["sender"] + ": " + msg["message"])
			message_index += 1

# -------------------------------------------------------
# GLASS
# -------------------------------------------------------
func _get_tape_reduction(count: int) -> float:
	match count:
		0: return 1.0
		1: return 0.4
		2: return 0.24
		_: return 0.192

func _update_glass(delta: float) -> void:
	for window in glass_points.keys():
		if glass_phases[window] >= 4: continue
		var rate = glass_fill_rate * soil_multiplier * _get_tape_reduction(glass_tape_count[window])
		glass_points[window] += rate * delta
		glass_points[window]  = clamp(glass_points[window], 0.0, 100.0)
		emit_signal("glass_progress_updated", window, glass_points[window])
		if glass_points[window] >= 100.0:
			glass_points[window]     = 0.0
			glass_tape_count[window] = 0
			glass_taped[window]      = false
			_advance_crack(window)

func _advance_crack(window: String) -> void:
	glass_phases[window] += 1
	emit_signal("glass_cracked", window, glass_phases[window])
	match glass_phases[window]:
		1: show_dialogue("*CRACK* — The " + window + " window has a small crack! Use tape to slow it.")
		2: show_dialogue("*CRACK* — The " + window + " crack is spreading! Re-apply tape!")
		3: show_dialogue("*CRACK* — The " + window + " window is about to break!")
		4: _on_glass_broken(window)

func _on_glass_broken(window: String) -> void:
	show_dialogue("*SHATTER* — The " + window + " window broke! Soil is flooding in!")
	soil_multiplier += 0.5
	emit_signal("soil_speed_changed", soil_multiplier)
	emit_signal("glass_cracked", window, 4)
	var all_broken = true
	for w in glass_phases.keys():
		if glass_phases[w] < 4:
			all_broken = false
			break
	if all_broken:
		await get_tree().create_timer(2.0).timeout
		_die_buried()

func apply_tape_to_window(window: String) -> void:
	if not has_item("duct_tape"):
		show_dialogue("I don't have duct tape.")
		return
	if glass_phases[window] >= 4:
		show_dialogue("Too late — already shattered!")
		return
	if glass_phases[window] == 0:
		show_dialogue("This window is fine — save the tape.")
		return
	if duct_tape_uses <= 0:
		show_dialogue("I'm out of duct tape!")
		return
	glass_tape_count[window] += 1
	glass_taped[window]       = true
	duct_tape_uses            -= 1
	var pct_slow = 0
	match glass_tape_count[window]:
		1: pct_slow = 60
		2: pct_slow = 40
		_: pct_slow = 20
	show_dialogue("Tape on " + window + " window. +" + str(pct_slow) +
		"% slower. " + str(duct_tape_uses) + " strips left.")
	emit_signal("glass_cracked", window, -1)
	if duct_tape_uses <= 0:
		remove_item("duct_tape")
		show_dialogue("Used the last tape strip!")

func use_duct_tape_on(window: String) -> void:
	apply_tape_to_window(window)

func apply_duct_tape() -> void:
	show_dialogue("Select duct tape (1 or 2), then left click on a cracked window.")

# -------------------------------------------------------
# RESCUE
# -------------------------------------------------------
func call_emergency() -> void:
	if not phone_collected:
		show_dialogue("I need my phone.")
		return
	if phone_is_dead:
		show_dialogue("My phone is dead.")
		return
	if not has_emergency_number:
		show_dialogue("I don't have the emergency number. Check the glove box.")
		return
	if rescue_called:
		show_dialogue("Already called. " + str(int(rescue_timer)) + "s remaining.")
		return
	rescue_called = true
	rescue_timer  = rescue_arrival_time
	current_cue   = 2
	show_dialogue("I got through! They're coming in " + str(int(rescue_arrival_time)) + "s!")
	escape_step = max(escape_step, 5)
	emit_signal("escape_step_changed", escape_step)

func use_hammer_for_noise() -> void:
	if not has_item("hammer"):
		show_dialogue("I need the hammer.")
		return
	if not rescue_called:
		show_dialogue("*BANG* — No one can hear me. Call for help first.")
		return
	# FIX 2: hammer cooldown prevents spam exploit
	if hammer_cooldown > 0.0:
		show_dialogue("I need to recover before banging again...")
		return
	hammer_cooldown = 3.0
	player_o2       = clamp(player_o2 - 5.0, 0.0, 100.0)
	rescue_timer    = max(rescue_timer - 20.0, 1.0)
	show_dialogue("*BANG BANG BANG* — " + str(int(rescue_timer)) + "s until rescue!")
	emit_signal("hammer_banged")

func use_hammer_on_glass() -> void:
	show_choice("Break the window with the hammer?",
		["Yes — smash it!", "No, that's a bad idea"])

func trigger_buried_ending() -> void:
	if is_dead: return
	_die_buried()

# -------------------------------------------------------
# SEATBELT
# -------------------------------------------------------
func cut_seatbelt() -> void:
	seatbelt_cut = true
	show_dialogue("I cut the seatbelt. Now I can move around freely.")
	escape_step  = max(escape_step, 1)
	emit_signal("escape_step_changed", escape_step)

# -------------------------------------------------------
# BREATHING
# -------------------------------------------------------
func hold_space(delta: float) -> void:
	if is_dead or not game_running: return
	if breath_cooldown > 0.0: return
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
	# FIX 4: blackout cleared HERE after full breath — not in _process
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
	if is_dead or not game_running or blacked_out: return
	if jack_complete: return
	if not has_item("car_jack") and not jack_placed:
		if not _jack_msg_shown:
			show_dialogue("I need the car jack from the trunk.")
			_jack_msg_shown = true
		return
	if not jack_placed:
		jack_placed     = true
		_jack_msg_shown = false
		remove_item("car_jack")
		show_dialogue("Jack placed! Keep holding E...")
		emit_signal("jack_progress_updated", 0.01)
		return
	jack_progress += delta
	jack_progress  = min(jack_progress, jack_required)
	emit_signal("jack_progress_updated", jack_progress / jack_required)
	var pct     = int((jack_progress / jack_required) * 4)
	var old_pct = int(((jack_progress - delta) / jack_required) * 4)
	if pct != old_pct and jack_progress < jack_required:
		show_dialogue("Rolling the jack... " + str(pct * 25) + "%")
	if jack_progress >= jack_required:
		jack_complete = true
		show_dialogue("The door is giving way! Now I can escape!")
		escape_step = max(escape_step, 6)
		emit_signal("escape_step_changed", escape_step)
		emit_signal("jack_progress_updated", 1.0)

# -------------------------------------------------------
# WIN / LOSE
# -------------------------------------------------------
func _trigger_rescue_win() -> void:
	rescue_called = false
	_win("rescue")

func _win(ending: String) -> void:
	is_dead      = true   # ADD — prevents further input
	game_running = false
	emit_signal("game_won", ending)

func _die(reason: String) -> void:
	if is_dead: return
	is_dead      = true
	game_running = false
	emit_signal("game_over", reason)

func _die_suffocated() -> void:
	_die("suffocated")

func _die_buried() -> void:
	_die("buried")

# -------------------------------------------------------
# INVENTORY
# -------------------------------------------------------
func pick_item(item_name: String, node: Node) -> void:
	item_nodes[item_name] = node

	if item_name == "phone":
		if not phone_collected:
			phone_collected = true
			emit_signal("item_picked", item_name)
		return

	# FIX 5: emergency number never takes a slot — just unlocks mechanic
	if item_name == "emergency_number":
		if not has_emergency_number:
			has_emergency_number = true
			emit_signal("item_picked", item_name)
		return

	if item_name in inventory: return
	if inventory.size() >= max_slots:
		var dropped = inventory.pop_front()
		emit_signal("item_dropped", dropped)
		if item_nodes.has(dropped):
			item_nodes[dropped].on_dropped()
	inventory.append(item_name)
	emit_signal("item_picked", item_name)

func has_item(item_name: String) -> bool:
	if item_name == "phone": return phone_collected
	if item_name == "emergency_number": return has_emergency_number
	return item_name in inventory

func remove_item(item_name: String) -> void:
	if item_name == "phone":
		phone_collected = false
	elif item_name == "emergency_number":
		has_emergency_number = false
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
	if (battery <= 0.0 or phone_is_dead) and on:
		show_dialogue("Battery dead.")
		return
	flashlight_active = on

func show_dialogue(text: String) -> void:
	emit_signal("dialogue_requested", text)

func request_pov_switch(target: String) -> void:
	emit_signal("pov_switch_requested", target)
	
func handle_choice(option: String) -> void:
	print("Choice selected: ", option)
	match option:
		# --- SHOVEL ---
		"Start digging!":
			show_dialogue("I'm digging through the soil... almost there!")
			game_running = false  # stop systems during win sequence
			await get_tree().create_timer(2.0).timeout
			_win("dig")

		"Wait and see", "Wait for rescue instead":
			show_dialogue("I'll hold on... rescue is coming.")
			# if rescue already called, they just wait — no action needed
			# if not called yet, remind them
			if not rescue_called:
				show_dialogue("I should call for help first before waiting.")

		# --- HAMMER ---
		"Bang on car — signal rescue":
			use_hammer_for_noise()
		"Keep it for now":
			show_dialogue("I'll save it for later.")

		"Break a window (BAD IDEA)":
			# show second confirmation
			show_choice("Really break the window? Soil will flood in.",
				["Yes, smash it!", "No, stop!"])

		"Yes, smash it!":
			show_dialogue("*SMASH* — Soil pours in instantly!")
			# break the most cracked window
			var worst_window = ""
			var worst_phase  = 0
			for w in glass_phases.keys():
				if glass_phases[w] > worst_phase and glass_phases[w] < 4:
					worst_phase  = glass_phases[w]
					worst_window = w
			if worst_window != "":
				glass_phases[worst_window] = 3
				emit_signal("glass_cracked", worst_window, 3)
				await get_tree().create_timer(0.5).timeout
				_advance_crack(worst_window)
			else:
				soil_multiplier += 1.5
				emit_signal("soil_speed_changed", soil_multiplier)
			await get_tree().create_timer(3.0).timeout
			_die_buried()

		"No, stop!", "No, that's a bad idea", "Put it away", "Keep it for now":
			show_dialogue("Better not risk it.")

		# --- HONK ---
		"Honk the horn":
			show_dialogue("*HONK HONK* — No one can hear me down here...")

		_:
			show_dialogue("...")

# -------------------------------------------------------
# RESET
# -------------------------------------------------------
func reset() -> void:
	player_o2 = 100.0; car_o2 = 100.0; battery = 100.0; panic = 0.0
	soil_multiplier = 1.0; seatbelt_cut = false
	is_breathing = false; breath_hold_time = 0.0; breath_cooldown = 0.0
	prompt_active = false; flashlight_active = false
	blacked_out = false; blackout_timer = 0.0; phone_is_dead = false
	rescue_called = false; rescue_timer = 0.0; has_emergency_number = false
	jack_progress = 0.0; jack_complete = false; jack_placed = false
	_jack_msg_shown = false; escape_step = 0; hammer_cooldown = 0.0
	duct_tape_uses = 6; phone_collected = false
	current_cue = 1; game_elapsed = 0.0; cue_2_started = false
	honk_broken = false
	for w in glass_points.keys():
		glass_points[w]     = 0.0
		glass_phases[w]     = 0
		glass_taped[w]      = false
		glass_tape_count[w] = 0
		glass_timers[w]     = 0.0
	game_running = true; is_dead = false
	message_index = 0; message_elapsed = 0.0
	messages.clear(); inventory.clear(); item_nodes.clear()
	_message_pool  = PhoneContent.scheduled_messages
	message_timers = []
	for msg in PhoneContent.scheduled_messages:
		message_timers.append(msg["time"])
	rescue_arrival_time = PhoneContent.rescue_arrival_time
	# stagger glass again on reset
	glass_points["front"] = 0.0
	glass_points["left"]  = randf_range(0.0, 50.0)
	glass_points["right"] = randf_range(0.0, 50.0)
	glass_points["rear"]  = randf_range(0.0, 30.0)
