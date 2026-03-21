extends Node2D

var current_pov: String = "front"
var pov_nodes: Dictionary = {}

func _ready() -> void:
	# find all views — add or remove names here as you add new views
	var view_names = ["FrontRow", "GloveBoxView", "BackRow", "TrunkView"]
	for name in view_names:
		var node = get_node_or_null(name)
		if node:
			pov_nodes[name.to_lower().replace("row", "").replace("view", "")] = node
			print("POVManager found: ", name)
		else:
			print("POVManager WARNING: could not find ", name)

	# manually map names to match pov_target values
	pov_nodes["front"]    = get_node_or_null("FrontRow")
	pov_nodes["glovebox"] = get_node_or_null("GloveBoxView")
	pov_nodes["back"]     = get_node_or_null("BackRow")
	pov_nodes["trunk"]    = get_node_or_null("TrunkView")

	# start with only front visible
	for key in pov_nodes:
		var node = pov_nodes[key]
		if node:
			node.visible = (key == "front")

	_update_location_label()
	print("POVManager ready — starting at: front")

func switch_to(target: String) -> void:
	if not pov_nodes.has(target):
		print("ERROR: Unknown POV target: '", target, "' — valid targets: ", pov_nodes.keys())
		return

	# hide all
	for key in pov_nodes:
		var node = pov_nodes[key]
		if node:
			node.visible = false

	# show target
	var target_node = pov_nodes[target]
	if target_node:
		target_node.visible = true
		current_pov = target
		print("POV switched to: ", target)
	else:
		print("ERROR: Node for '", target, "' is null!")

	_update_location_label()

func _update_location_label() -> void:
	var label = get_node_or_null("/root/Main/UI/LocationLabel")
	if not label:
		return
	var names = {
		"front":    "Front Seat",
		"glovebox": "Glove Box",
		"back":     "Back Seat",
		"trunk":    "Trunk"
	}
	label.text = "[ " + names.get(current_pov, current_pov) + " ]"
