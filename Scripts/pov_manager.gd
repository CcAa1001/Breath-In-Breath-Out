extends Node2D

var current_pov: String = "front"

var pov_nodes: Dictionary = {}

func _ready() -> void:
	# register all pov nodes
	pov_nodes["front"]      = get_node_or_null("FrontRow")
	pov_nodes["glovebox"]   = get_node_or_null("GloveBoxView")
	pov_nodes["back"]       = get_node_or_null("BackRow")
	pov_nodes["trunk"]      = get_node_or_null("TrunkView")

	# start with only front visible
	for key in pov_nodes:
		var node = pov_nodes[key]
		if node:
			node.visible = (key == "front")

	print("POVManager ready. Starting at: front")

func switch_to(target: String) -> void:
	if not pov_nodes.has(target):
		print("ERROR: Unknown POV target: ", target)
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

	# update location label if it exists
	var label = get_node_or_null("/root/Main/UI/LocationLabel")
	if label:
		var names = {
			"front":    "Front Seat",
			"glovebox": "Glove Box",
			"back":     "Back Seat",
			"trunk":    "Trunk"
		}
		label.text = "[ " + names.get(target, target) + " ]"
