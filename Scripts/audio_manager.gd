extends Node

# -------------------------------------------------------
# AUDIO PLAYERS — add these nodes under AudioManager in editor
# -------------------------------------------------------
var music_player:     AudioStreamPlayer  # looping ambient
var sfx_player:       AudioStreamPlayer  # one-shot effects
var breath_player:    AudioStreamPlayer  # breathing loop
var heartbeat_player: AudioStreamPlayer  # heartbeat loop
var siren_player:     AudioStreamPlayer  # siren with pitch/volume ramp
var groan_player:     AudioStreamPlayer  # metallic groans

# siren state
var siren_active:     bool  = false
var _groan_timer:     float = 0.0
var _groan_interval:  float = 0.0
var _heavy_breath_played: bool = false

# -------------------------------------------------------
# SOUND MAP — auto detects mp3 or wav
# -------------------------------------------------------
var sounds: Dictionary = {
	# breathing
	#"rubble": [
	#"res://assets/Audio/metal.mp3",
	#"res://assets/Audio/door.mp3",
	#"res://assets/Audio/door2.mp3",
	#"res://assets/Audio/glass.mp3",
	#],
	"talk": ["res://assets/Audio/talk.mp3", "res://assets/Audio/talk.wav"],
	"rubble": ["res://assets/Audio/crash.mp3", "res://assets/Audio/metal.mp3",],
	#"breath_start":    ["res://assets/Audio/breath_start.mp3"],
	#"breath_complete": ["res://assets/Audio/breath_complete.mp3"],
	"heavy_breath":    ["res://assets/Audio/freesound_community-heavy-breath-male-63980.mp3"],

	# phone
	"click":           ["res://assets/Audio/click.mp3"],
	"call":            ["res://assets/Audio/call.mp3"],
	"phone_pickup":    ["res://assets/Audio/phone_pickup.mp3"],
	"notification":    ["res://assets/Audio/notification.mp3", "res://assets/Audio/notification.wav"],

	# items
	"item_pickup":     ["res://assets/Audio/item_pickup.mp3"],
	"cut":             ["res://assets/Audio/cut.mp3", "res://assets/Audio/Cut.wav"],
	"seatbelt":        ["res://assets/Audio/seatbelt.mp3"],
	"seatbelt_stuck":  ["res://assets/Audio/seatbelt.mp3"],
	"flash":           ["res://assets/Audio/flash.mp3"],
	"duct_tape":       ["res://assets/Audio/duct_tape.mp3", "res://assets/Audio/tape.mp3", "res://assets/Audio/tape.wav"],
	"dig":             ["res://assets/Audio/dig.mp3"],

	# car
	"honk":            ["res://assets/Audio/honk.mp3"],
	"door":            ["res://assets/Audio/door.mp3"],
	"door_stuck":      ["res://assets/Audio/door2.mp3"],
	"glove_open":      ["res://assets/Audio/glove_box.mp3"],
	"glove_close":     ["res://assets/Audio/glove_box.mp3"],
	"metal":           ["res://assets/Audio/metal.mp3"],

	# glass
	"glass":           ["res://assets/Audio/glass.mp3"],

	# ambient/loops
	"heartbeat":       ["res://assets/Audio/heartbeat.mp3"],
	"sirene":          ["res://assets/Audio/sirene.mp3"],

	# cues
	"cue1":            ["res://assets/Audio/cue1.mp3", "res://assets/Audio/cue1.wav"],
	"cue2":            ["res://assets/Audio/cue2.mp3", "res://assets/Audio/cue2.wav"],
}
func _ready() -> void:
	music_player     = get_node_or_null("MusicPlayer")
	sfx_player       = get_node_or_null("SFXPlayer")
	breath_player    = get_node_or_null("BreathPlayer")
	heartbeat_player = get_node_or_null("HeartbeatPlayer")
	siren_player     = get_node_or_null("SirenPlayer")
	groan_player     = get_node_or_null("GroanPlayer")

	GameManager.breath_prompt_show.connect(_on_breath_prompt)
	GameManager.breath_taken.connect(_on_breath_taken)
	GameManager.player_blacked_out.connect(_on_blackout)
	GameManager.panic_updated.connect(_on_panic)
	GameManager.rescue_timer_updated.connect(_on_rescue_timer)
	GameManager.glass_cracked.connect(_on_glass_crack)
	GameManager.item_picked.connect(_on_item_picked)
	GameManager.escape_step_changed.connect(_on_escape_step)
	GameManager.cue_changed.connect(_on_cue_changed)
	GameManager.game_won.connect(_on_game_won)
	GameManager.game_over.connect(_on_game_over)
	GameManager.hammer_banged.connect(func(): play("honk"))

	_reset_groan_timer()

func _process(delta: float) -> void:
	if not GameManager.game_running: return

	# metallic groan at random intervals
	_groan_timer -= delta
	if _groan_timer <= 0.0:
		play_on(groan_player, "metal", false)
		_reset_groan_timer()

	# heartbeat pitch scales with panic
	if heartbeat_player and heartbeat_player.playing:
		var p = GameManager.panic
		heartbeat_player.pitch_scale = remap(p, 0.0, 100.0, 0.8, 1.6)

	# siren volume/pitch ramps as rescue timer counts down
	if siren_active and siren_player and siren_player.playing:
		var t = GameManager.rescue_timer
		var total = GameManager.rescue_arrival_time
		var progress = 1.0 - clamp(t / total, 0.0, 1.0)
		# volume: starts at -30db (muffled) → 0db (clear)
		siren_player.volume_db = lerpf(-30.0, 0.0, progress)
		# pitch: slightly rises as it gets closer
		siren_player.pitch_scale = lerpf(0.85, 1.0, progress)

# -------------------------------------------------------
# CORE PLAY FUNCTIONS
# -------------------------------------------------------
func _load_sound(key: String) -> AudioStream:
	if not sounds.has(key):
		print("AudioManager: unknown sound: ", key)
		return null
	for path in sounds[key]:
		if ResourceLoader.exists(path):
			return load(path)
	print("AudioManager: no file found for: ", key)
	return null

func play(key: String) -> void:
	if not sfx_player: return
	var stream = _load_sound(key)
	if stream:
		sfx_player.stream = stream
		sfx_player.play()

func play_on(player: AudioStreamPlayer, key: String, loop: bool) -> void:
	if not player: return
	var stream = _load_sound(key)
	if not stream: return
	if stream is AudioStreamMP3:
		stream.loop = loop
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	player.stream = stream
	player.play()

func stop_on(player: AudioStreamPlayer) -> void:
	if player and player.playing:
		player.stop()

# -------------------------------------------------------
# NAMED PLAY FUNCTIONS — called from other scripts
# -------------------------------------------------------
func play_phone_click() -> void:  play("click")
func play_flashlight()  -> void:  play("flash")
func play_honk()        -> void:  play("honk")
func play_item_pickup() -> void:  play("item_pickup")
func play_duct_tape()   -> void:  play("duct_tape")
func play_dig()         -> void:  play("dig")
func play_glass()       -> void:  play("glass")
func play_notification() -> void: play("notification")
func play_call()        -> void:  play("call")
func play_door_stuck()  -> void:  play("door_stuck")
func play_glove_open()  -> void:  play("glove_open")
func play_glove_close() -> void:  play("glove_close")

func play_heavy_breath() -> void:
	if _heavy_breath_played: return
	_heavy_breath_played = true
	play_on(breath_player, "heavy_breath", false)

func play_breath_start() -> void:
	play_on(breath_player, "breath_start", false)

func play_breath_complete() -> void:
	play("breath_complete")
	stop_on(breath_player)

func _reset_groan_timer() -> void:
	_groan_timer = randf_range(15.0, 45.0)

# -------------------------------------------------------
# SIGNAL HANDLERS
# -------------------------------------------------------
func _on_breath_prompt() -> void:
	play_breath_start()

func _on_breath_taken() -> void:
	play_breath_complete()

func _on_blackout(is_out: bool) -> void:
	if is_out:
		_heavy_breath_played = false
		play_heavy_breath()

func _on_panic(value: float) -> void:
	if not heartbeat_player: return
	if value >= 40.0:
		if not heartbeat_player.playing:
			play_on(heartbeat_player, "heartbeat", true)
	else:
		stop_on(heartbeat_player)

func _on_rescue_timer(seconds_left: float) -> void:
	if not siren_active and seconds_left <= GameManager.rescue_arrival_time:
		siren_active = true
		if siren_player:
			siren_player.volume_db  = -30.0
			siren_player.pitch_scale = 0.85
			play_on(siren_player, "sirene", true)

func _on_glass_crack(window_id: String, phase: int) -> void:
	if phase > 0 and phase <= 4:
		play("glass")
	elif phase == -1:
		play("duct_tape")

func _on_item_picked(item_name: String) -> void:
	match item_name:
		"phone":
			play("phone_pickup")
		"cutter":
			play("item_pickup")
		"screwdriver", "hammer", "car_jack", "shovel", \
		"duct_tape", "emergency_number":
			play("item_pickup")
		_:
			play("item_pickup")

func _on_escape_step(step: int) -> void:
	match step:
		1: play("cut")        # seatbelt cut
		3: play("glove_open") # glovebox opens

func _on_cue_changed(cue: int) -> void:
	print("Cue changed to: ", cue)
	match cue:
		1:
			play_on(music_player, "cue1", true)
		2:
			# stop cue1, start cue2
			stop_on(music_player)
			await get_tree().create_timer(0.3).timeout
			play_on(music_player, "cue2", true)
			# play metallic crack sound for the jack unlock moment
			play("metal")

func _on_game_won(ending: String) -> void:
	stop_on(heartbeat_player)
	stop_on(siren_player)
	if ending == "dig": play("dig")

func _on_game_over(_reason: String) -> void:
	stop_on(heartbeat_player)
	stop_on(siren_player)
	stop_on(breath_player)
	stop_on(music_player)

# -------------------------------------------------------
# CALLED FROM CLICKABLE_ITEM / MAIN
# -------------------------------------------------------
func play_seatbelt_stuck() -> void:
	play("seatbelt_stuck")

func play_door_wont_budge() -> void:
	play("door_stuck")
