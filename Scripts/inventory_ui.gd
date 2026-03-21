extends Control

var slot1_panel: Panel
var slot1_icon:  TextureRect
var slot1_label: Label
var slot2_panel: Panel
var slot2_icon:  TextureRect
var slot2_label: Label
var phone_panel: Panel
var phone_icon:  TextureRect
var phone_label: Label

var active_slot: int = -1  # -1 = none, 0 = slot1, 1 = slot2

var item_icons: Dictionary = {
	"cutter":           "res://assets/cutter.png",
	"duct_tape":        "res://assets/DuctTape.png",
	"screwdriver":      "res://assets/screwdriver.png",
	"hammer":           "res://assets/hammer.png",
	"car_jack":         "res://assets/carjack.png",
	"shovel":           "res://assets/shovel.png",
	"emergency_number": "res://assets/Number.png",
	"phone":            "res://assets/phone.png",
}

# style colors
const COLOR_NORMAL   = Color(1, 1, 1, 1)
const COLOR_ACTIVE   = Color(1, 1, 0, 1)    # yellow = selected
const COLOR_EMPTY    = Color(1, 1, 1, 0.2)

func _ready() -> void:
	slot1_panel = get_node_or_null("Slot1")
	slot1_icon  = get_node_or_null("Slot1/Slot1Icon")
	slot1_label = get_node_or_null("Slot1/Slot1Label")
	slot2_panel = get_node_or_null("Slot2")
	slot2_icon  = get_node_or_null("Slot2/Slot2Icon")
	slot2_label = get_node_or_null("Slot2/Slot2Label")
	phone_panel = get_node_or_null("PhoneSlot")
	phone_icon  = get_node_or_null("PhoneSlot/PhoneIcon")
	phone_label = get_node_or_null("PhoneSlot/PhoneLabel")

	GameManager.item_picked.connect(func(_i): _refresh())
	GameManager.item_dropped.connect(func(_i): _refresh())

	_refresh()

func _process(_delta: float) -> void:
	# slot selection
	if Input.is_action_just_pressed("slot_1"):
		_toggle_slot(0)
	if Input.is_action_just_pressed("slot_2"):
		_toggle_slot(1)

func _toggle_slot(slot: int) -> void:
	if active_slot == slot:
		# pressing same slot again = deselect
		active_slot = -1
		GameManager.show_dialogue("Item deselected.")
	else:
		active_slot = slot
		var item = _get_item_in_slot(slot)
		if item != "":
			GameManager.show_dialogue(
				"[" + str(slot + 1) + "] " + item.replace("_", " ").to_upper() + " selected. Left click to use.")
		else:
			GameManager.show_dialogue("Slot " + str(slot + 1) + " is empty.")
			active_slot = -1
	_refresh()

func get_active_item() -> String:
	if active_slot == -1: return ""
	return _get_item_in_slot(active_slot)

func _get_item_in_slot(slot: int) -> String:
	if GameManager.inventory.size() > slot:
		return GameManager.inventory[slot]
	return ""

func _refresh() -> void:
	_set_slot(slot1_panel, slot1_icon, slot1_label,
		_get_item_in_slot(0), active_slot == 0, "1")
	_set_slot(slot2_panel, slot2_icon, slot2_label,
		_get_item_in_slot(1), active_slot == 1, "2")
	# phone slot
	if phone_icon:
		phone_icon.modulate = COLOR_NORMAL if GameManager.phone_collected else COLOR_EMPTY
	if phone_label:
		phone_label.text = "PHONE"

func _set_slot(panel: Panel, icon: TextureRect,
			   label: Label, item: String,
			   is_active: bool, key_hint: String) -> void:
	if not panel or not icon or not label: return

	# highlight active slot
	if is_active:
		panel.modulate = COLOR_ACTIVE
	else:
		panel.modulate = COLOR_NORMAL

	if item == "":
		icon.texture     = null
		icon.modulate    = COLOR_EMPTY
		label.text       = "[" + key_hint + "] EMPTY"
		label.modulate   = Color(0.4, 0.4, 0.4)
	else:
		var path = item_icons.get(item, "")
		if path != "" and ResourceLoader.exists(path):
			icon.texture = load(path)
		else:
			icon.texture = null
		icon.modulate    = COLOR_NORMAL
		label.text       = "[" + key_hint + "] " + item.replace("_", " ").to_upper()
		label.modulate   = COLOR_ACTIVE if is_active else COLOR_NORMAL
