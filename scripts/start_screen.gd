extends Control

const MAIN_SCENE_PATH := "res://scenes/main.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start_game()


func _start_game() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
