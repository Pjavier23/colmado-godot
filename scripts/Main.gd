extends Node
## Main.gd - Entry point scene controller.
## Handles initial loading and scene transition to Menu.

func _ready() -> void:
	# Small delay to let the engine initialize fully, then go to menu
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/MenuScene.tscn")
