extends ColorRect

var mat: ShaderMaterial = null
var flash_on: bool = false
var has_phone: bool = false
var phone_uv: Vector2 = Vector2(1310.0 / 1920.0, 920.0 / 1080.0)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	mat = material as ShaderMaterial
	if mat == null or mat.shader == null:
		print("ERROR: Assign ShaderMaterial + flashlight.gdshader to DarknessOverlay!")
		return
	print("Shader OK!")
	_reset_shader()
	GameManager.item_picked.connect(_on_item_picked)
	_run_intro()

func _reset_shader() -> void:
	mat.set_shader_parameter("notif_on", false)
	mat.set_shader_parameter("flash_on", false)
	mat.set_shader_parameter("light_pos", phone_uv)
	mat.set_shader_parameter("notif_inner", 0.03)
	mat.set_shader_parameter("notif_outer", 0.065)
	mat.set_shader_parameter("flash_inner", 0.07)
	mat.set_shader_parameter("flash_outer", 0.12)
	mat.set_shader_parameter("flash_glow",  0.20)

func _run_intro() -> void:
	await get_tree().create_timer(1.5).timeout
	_pulse_notification()

func _pulse_notification() -> void:
	if mat == null: return
	mat.set_shader_parameter("light_pos", phone_uv)
	# 3 short pulses — tight notification light only
	for i in range(3):
		mat.set_shader_parameter("notif_on", true)
		await get_tree().create_timer(0.25).timeout
		mat.set_shader_parameter("notif_on", false)
		await get_tree().create_timer(0.25).timeout
	# leave notification glow on so player can find phone
	mat.set_shader_parameter("notif_on", true)
	GameManager.game_running = true
	print("Game started!")

func _on_item_picked(item_name: String) -> void:
	if item_name != "phone": return
	has_phone = true
	mat.set_shader_parameter("notif_on", false)
	print("Phone collected! Press F for flashlight.")

func toggle_light() -> void:
	if mat == null or mat.shader == null:
		print("ERROR: mat or shader is null!")
		return
	flash_on = !flash_on
	mat.set_shader_parameter("flash_on", flash_on)
	print("Flashlight: " + ("ON" if flash_on else "OFF"))

func _process(_delta: float) -> void:
	if mat == null: return
	if flash_on:
		var m = get_viewport().get_mouse_position()
		mat.set_shader_parameter("light_pos",
			Vector2(m.x / 1920.0, m.y / 1080.0))
	elif not has_phone:
		mat.set_shader_parameter("light_pos", phone_uv)
