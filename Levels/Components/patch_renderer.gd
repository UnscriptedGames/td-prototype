@tool
extends Node2D

var patches: Array[PackedVector2Array] = []
var color: Color = Color.WHITE

func _draw() -> void:
	for poly in patches:
		draw_colored_polygon(poly, color)
