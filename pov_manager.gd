extends Node2D

var current_pov: String = "front"

func _ready() -> void:
	$FrontRow.visible = true
	$BackRow.visible = false
	_update_label()

func switch_to(pov: String) -> void:
	current_pov = pov
	$FrontRow.visible = (pov == "front")
	$BackRow.visible = (pov == "back")
	_update_label()

func _update_label() -> void:
	var label = get_node("/root/Main/UI/LocationLabel")
	label.text = "[ " + ("Front Seat" if current_pov == "front" else "Back Seat") + " ]"
