@tool
extends Node2D
class_name GeneratedLevel

@export var rooms: Array[Dictionary] = []


func room_data() -> Array[Dictionary]:
	return rooms
