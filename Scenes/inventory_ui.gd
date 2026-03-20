extends Control

# item name → icon texture path
var item_icons: Dictionary = {
	"cutter":           "res://assets/cutter.png",
	"duct_tape":        "res://assets/DuctTape.png",
	"screwdriver":      "res://assets/screwdriver.png",
	"hammer":           "res://assets/hammer.png",
	"car_jack":         "res://assets/carjack.png",
	"shovel":           "res://assets/shovel.png",
	"emergency_number": "res://assets/number.png",
}

var slot1_icon:  TextureRect
var slot1_label: Label
var slot2_icon:  TextureRect
var slot2_label: Label
var phone_icon:  TextureRect
var phone_label: Label

var empty_texture: Texture2D = null

func _ready() -> void:
	slot1_icon  = get_node_or_null("Slot1/Slot1Icon")
	slot1_label = get_node_or_null("Slot1/Slot1Label")
	slot2_icon  = get_node_or_null("Slot2/Slot2Icon")
	slot2_label = get_node_or_null("Slot2/Slot2Label")
	phone_icon  = get_node_or_null("PhoneSlot/PhoneIcon")
	phone_label = get_node_or_null("PhoneSlot/PhoneLabel")

	GameManager.item_picked.connect(_refresh)
	GameManager.item_dropped.connect(_refresh)

	# set phone icon
	if phone_icon:
		var tex = load("res://assets/phone.png")
		if tex: phone_icon.texture = tex
	if phone_label:
		phone_label.text = "PHONE"
		phone_label.visible = false  # hide until collected

	_refresh("")

func _refresh(_item: String) -> void:
	var inv = GameManager.inventory

	# slot 1
	_set_slot(slot1_icon, slot1_label,
		inv[0] if inv.size() > 0 else "")

	# slot 2
	_set_slot(slot2_icon, slot2_label,
		inv[1] if inv.size() > 1 else "")

	# phone slot
	if phone_label:
		phone_label.visible = GameManager.phone_collected
	if phone_icon:
		phone_icon.modulate.a = 1.0 if GameManager.phone_collected else 0.3

func _set_slot(icon: TextureRect, label: Label, item: String) -> void:
	if not icon or not label:
		return
	if item == "":
		icon.texture  = null
		label.text    = ""
		icon.modulate.a = 0.3
	else:
		if item_icons.has(item):
			var tex = load(item_icons[item])
			icon.texture = tex
		else:
			icon.texture = null
		label.text      = item.replace("_", " ").to_upper()
		icon.modulate.a = 1.0
