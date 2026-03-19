extends Node2D

func _ready() -> void:
	GameManager.game_over_triggered.connect(_on_game_over)
	GameManager.item_collected.connect(_on_item_collected)
	$UI/GameOverScreen.hide() # Added UI/ back

func _on_game_over(reason: String) -> void:
	$UI/GameOverScreen.show() # Added UI/ back
	$UI/GameOverScreen/ReasonLabel.text = reason + "\n\nClick anywhere to restart" # Added UI/ back

func _on_item_collected(item_name: String) -> void:
	$UI/InventoryLabel.text = "Inventory: " + ", ".join(GameManager.inventory)
	if item_name == "flashlight":
		$UI/OxygenLabel.text = "OXYGEN  |  F or Right-click to toggle flashlight"
