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

# ---- MASTER SETTINGS (your friend edits these) ----
var player_drain_rate: float    = 10.0    # breath depletes X% per second
var car_drain_rate: float       = 0.83    # car air leaks X% per second
var breath_restore: float = 100.0     # full refill per breath
var breath_cost: float = 10.0         # small chunk of car air per breath
var waste_penalty: float = 3.0        # penalty for spamming space
var breath_hold_required: float = 1.5 # hold space 1.5s to breathe
var breath_cooldown_max: float = 8.0  # can breathe every 8 seconds
# ---------------------------------------------------

var player_o2: float = 100.0
var car_o2: float = 100.0
var is_breathing: bool = false
var breath_hold_time: float = 0.0
var breath_cooldown: float = 0.0
var prompt_active: bool = false
var inventory: Array[String] = []
var max_slots: int = 2
var item_nodes: Dictionary = {}
var game_running: bool = false
var is_dead: bool = false

func _process(delta: float) -> void:
	if not game_running or is_dead:
		return

	car_o2 -= car_drain_rate * delta
	if not is_breathing:
		player_o2 -= player_drain_rate * delta

	car_o2 = clamp(car_o2, 0.0, 100.0)
	player_o2 = clamp(player_o2, 0.0, 100.0)

	# TEMP DEBUG — remove after confirmed working
	if Engine.get_process_frames() % 60 == 0:
		print("car_o2=", snapped(car_o2,1), " player_o2=", snapped(player_o2,1), " running=", game_running)

	emit_signal("oxygen_updated", player_o2, car_o2)

	if breath_cooldown > 0.0:
		breath_cooldown -= delta

	if player_o2 < 40.0 and breath_cooldown <= 0.0:
		if not prompt_active:
			prompt_active = true
			emit_signal("breath_prompt_show")
	elif player_o2 > 55.0 and prompt_active and not is_breathing:
		prompt_active = false
		emit_signal("breath_prompt_hide")

	if player_o2 <= 0.0:
		_die("You suffocated...")
	elif car_o2 <= 0.0:
		_die("The air in the car ran out...")

func hold_space(delta: float) -> void:
	if is_dead or not game_running:
		return
	if is_breathing:
		# progress the breath — restore o2 gradually while holding
		breath_hold_time += delta
		var progress = clamp(breath_hold_time / breath_hold_required, 0.0, 1.0)
		# gradual restore as you hold
		player_o2 = clamp(player_o2 + (breath_restore / breath_hold_required) * delta, 0.0, 100.0)
		# gradual car drain as you breathe
		car_o2 = clamp(car_o2 - (breath_cost / breath_hold_required) * delta, 0.0, 100.0)
		emit_signal("breath_progress", progress)
		emit_signal("oxygen_updated", player_o2, car_o2)
		if breath_hold_time >= breath_hold_required:
			_complete_breath()
	else:
		if breath_cooldown > 0.0:
			# spamming on cooldown — waste car air as penalty
			car_o2 = clamp(car_o2 - waste_penalty * delta, 0.0, 100.0)
			emit_signal("oxygen_updated", player_o2, car_o2)
		else:
			# start breathing
			is_breathing = true
			breath_hold_time = 0.0

func release_space() -> void:
	if not is_breathing:
		return
	is_breathing = false
	breath_hold_time = 0.0
	emit_signal("breath_progress", 0.0)

func _complete_breath() -> void:
	is_breathing = false
	breath_hold_time = 0.0
	breath_cooldown = breath_cooldown_max
	prompt_active = false
	emit_signal("breath_prompt_hide")
	emit_signal("breath_taken")
	emit_signal("breath_progress", 0.0)
	emit_signal("oxygen_updated", player_o2, car_o2)
	print("Breath complete!")

func show_dialogue(text: String) -> void:
	emit_signal("dialogue_requested", text)

func _die(reason: String) -> void:
	if is_dead: return
	is_dead = true
	game_running = false
	emit_signal("game_over", reason)

func pick_item(item_name: String, node: Node) -> void:
	if item_name in inventory: return
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

func reset() -> void:
	player_o2 = 100.0
	car_o2 = 100.0
	is_breathing = false
	breath_hold_time = 0.0
	breath_cooldown = 0.0
	prompt_active = false
	game_running = false
	is_dead = false
	inventory.clear()
	item_nodes.clear()
