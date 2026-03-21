extends Node

# ---- audio players ----
var music:     AudioStreamPlayer
var sfx:       AudioStreamPlayer
var heartbeat: AudioStreamPlayer
var creak:     AudioStreamPlayer
var glass_sfx: AudioStreamPlayer
var voice:     AudioStreamPlayer

# ---- sound map ----
var sounds: Dictionary = {
	"breath_start":    "res://assets/audio/breath_start.mp3",
	"breath_complete": "res://assets/audio/breath_complete.mp3",
	"heartbeat":       "res://assets/audio/heartbeat.mp3",
	"seatbelt":        "res://assets/audio/seatbelt.mp3",
	"cut":             "res://assets/audio/cut.mp3",
	"duct_tape":       "res://assets/audio/duct_tape.mp3",
	"glove_box":       "res://assets/audio/glove_box.mp3",
	"item_pickup":     "res://assets/audio/item_pickup.mp3",
	"phone_pickup":    "res://assets/audio/phone_pickup.mp3",
	"phone_click":     "res://assets/audio/phone_click.mp3",
	"flashlight":      "res://assets/audio/flashlight.mp3",
	"shovel":          "res://assets/audio/shovel.mp3",
	"window_crack":    "res://assets/audio/window_crack.mp3",
	"window_shatter":  "res://assets/audio/window_shatter.mp3",
	"metal_screech":   "res://assets/audio/metal_screech.mp3",
	"stone_first":     "res://assets/audio/stone_first.mp3",
	"stone_second":    "res://assets/audio/stone_second.mp3",
	"rock_fall":       "res://assets/audio/rock_fall.mp3",
	"car_horn":        "res://assets/audio/honk.mp3",        # your file
	"car_door":        "res://assets/audio/car_door.mp3",
	"car_door_open":   "res://assets/audio/car_door_open.mp3",
	"phone_calling":   "res://assets/audio/phone_calling.mp3",
	"police_siren":    "res://assets/audio/police_siren.mp3",
	"notification":    "res://assets/audio/notification.mp3",
	"ambient":         "res://assets/audio/ambient.mp3",
	"ambient_intense": "res://assets/audio/ambient_intense.mp3",
}

var last_oxygen: float  = 100.0
var heartbeat_playing: bool = false

func _ready() -> void:
	music     = get_node_or_null("/root/Main/MusicPlayer")
	sfx       = get_node_or_null("/root/Main/SFXPlayer")
	heartbeat = get_node_or_null("/root/Main/HeartbeatPlayer")
	creak     = get_node_or_null("/root/Main/CreakPlayer")
	glass_sfx = get_node_or_null("/root/Main/GlassPlayer")
	voice     = get_node_or_null("/root/Main/VoicePlayer")

	# start ambient music
	_play_on(music, "ambient", true)

	# connect all game events
	GameManager.item_picked.connect(_on_item_picked)
	GameManager.oxygen_updated.connect(_on_oxygen)
	GameManager.glass_cracked.connect(_on_glass)
	GameManager.escape_step_changed.connect(_on_escape_step)
	GameManager.breath_progress.connect(_on_breath_progress)
	GameManager.breath_taken.connect(_on_breath_taken)
	GameManager.rescue_timer_updated.connect(_on_rescue_timer)
	GameManager.game_won.connect(_on_game_won)
	GameManager.phone_message_received.connect(_on_message)
	GameManager.panic_updated.connect(_on_panic)

# -------------------------------------------------------
# CORE PLAY FUNCTIONS
# -------------------------------------------------------
func play(sound_name: String) -> void:
	_play_on(sfx, sound_name, false)

func _play_on(player: AudioStreamPlayer, sound_name: String, loop: bool) -> void:
	if player == null: return
	if not sounds.has(sound_name):
		print("AudioManager: sound not found: ", sound_name)
		return
	var stream = load(sounds[sound_name])
	if stream == null:
		print("AudioManager: could not load: ", sounds[sound_name])
		return
	if loop:
		if stream is AudioStreamMP3:
			stream.loop = true
		elif stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	player.stream = stream
	player.play()

# -------------------------------------------------------
# ITEM SOUNDS
# -------------------------------------------------------
func _on_item_picked(item_name: String) -> void:
	match item_name:
		"phone":        _play_on(sfx, "phone_pickup",  false)
		"cutter":       _play_on(sfx, "item_pickup",   false)
		"duct_tape":    _play_on(sfx, "item_pickup",   false)
		"screwdriver":  _play_on(sfx, "item_pickup",   false)
		"hammer":       _play_on(sfx, "item_pickup",   false)
		"car_jack":     _play_on(sfx, "item_pickup",   false)
		"shovel":       _play_on(sfx, "item_pickup",   false)
		"emergency_number": _play_on(sfx, "item_pickup", false)
		_:              _play_on(sfx, "item_pickup",   false)

# -------------------------------------------------------
# BREATHING SOUNDS
# -------------------------------------------------------
func _on_breath_progress(amount: float) -> void:
	# play breath start sound when breathing begins
	if amount > 0.0 and amount < 0.1:
		_play_on(voice, "breath_start", false)

func _on_breath_taken() -> void:
	_play_on(voice, "breath_complete", false)

# -------------------------------------------------------
# HEARTBEAT — speeds up as oxygen drops
# -------------------------------------------------------
func _on_oxygen(p_o2: float, _c: float) -> void:
	last_oxygen = p_o2
	if heartbeat == null: return

	if p_o2 > 60.0:
		# safe — no heartbeat
		if heartbeat.playing:
			heartbeat.stop()
			heartbeat_playing = false
	elif p_o2 > 30.0:
		# slow heartbeat
		if not heartbeat.playing:
			_play_on(heartbeat, "heartbeat", true)
			heartbeat_playing = true
		heartbeat.pitch_scale = 1.0
	else:
		# fast panicked heartbeat
		if not heartbeat.playing:
			_play_on(heartbeat, "heartbeat", true)
			heartbeat_playing = true
		# pitch goes from 1.0 to 1.8 as o2 drops from 30 to 0
		heartbeat.pitch_scale = lerp(1.0, 1.8, 1.0 - (p_o2 / 30.0))

# -------------------------------------------------------
# GLASS SOUNDS
# -------------------------------------------------------
func _on_glass(window_id: String, phase: int) -> void:
	if glass_sfx == null: return
	match phase:
		1: _play_on(glass_sfx, "window_crack",   false)
		2: _play_on(glass_sfx, "window_crack",   false)
		3: _play_on(glass_sfx, "metal_screech",  false)
		4: _play_on(glass_sfx, "window_shatter", false)
		-1: _play_on(sfx, "duct_tape", false)  # taped

# -------------------------------------------------------
# ESCAPE STEP SOUNDS
# -------------------------------------------------------
func _on_escape_step(step: int) -> void:
	match step:
		1: _play_on(sfx, "seatbelt",     false)  # seatbelt cut
		2: _play_on(sfx, "item_pickup",  false)  # screwdriver
		3: _play_on(sfx, "glove_box",    false)  # glove box opened
		5: _play_on(sfx, "phone_calling",false)  # emergency called
		6: _play_on(sfx, "car_door_open",false)  # door forced open

# -------------------------------------------------------
# RESCUE TIMER SOUNDS
# -------------------------------------------------------
func _on_rescue_timer(seconds_left: float) -> void:
	# play siren when rescue is very close
	if seconds_left <= 10.0 and sfx and not sfx.playing:
		_play_on(sfx, "police_siren", false)

func _on_game_won(ending: String) -> void:
	if heartbeat: heartbeat.stop()
	if music: music.stop()
	match ending:
		"rescue": _play_on(sfx, "police_siren", false)
		"dig":    _play_on(sfx, "shovel",       false)

# -------------------------------------------------------
# PHONE SOUNDS
# -------------------------------------------------------
func _on_message(_sender: String, _msg: String) -> void:
	_play_on(sfx, "notification", false)

# -------------------------------------------------------
# PANIC — switch music intensity
# -------------------------------------------------------
func _on_panic(value: float) -> void:
	if music == null: return
	if value > 70.0:
		# switch to intense music if not already playing
		if music.stream and music.stream.resource_path.contains("ambient_intense"):
			return
		_play_on(music, "ambient_intense", true)
	else:
		if music.stream and music.stream.resource_path.contains("ambient."):
			return
		_play_on(music, "ambient", true)

# -------------------------------------------------------
# CALLED FROM OTHER SCRIPTS
# -------------------------------------------------------
func play_honk() -> void:
	_play_on(sfx, "car_horn", false)

func play_flashlight() -> void:
	_play_on(sfx, "flashlight", false)

func play_phone_click() -> void:
	_play_on(sfx, "phone_click", false)

func play_door() -> void:
	_play_on(sfx, "car_door", false)

func play_stone() -> void:
	var stones = ["stone_first", "stone_second", "rock_fall"]
	var pick = stones[randi() % stones.size()]
	_play_on(creak, pick, false)
