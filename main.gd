extends Node2D

func _ready() -> void:
	GameManager.game_over_triggered.connect(_on_game_over)
	GameManager.item_collected.connect(_on_item_collected)
	$GameOverScreen.hide() # Removed UI/

func _on_game_over(reason: String) -> void:
	$GameOverScreen.show() # Removed UI/
	$GameOverScreen/ReasonLabel.text = reason + "\n\nClick anywhere to restart" # Removed UI/

func _on_item_collected(item_name: String) -> void:
	$InventoryLabel.text = "Inventory: " + ", ".join(GameManager.inventory) # Removed UI/
