class_name Level
extends Node2D

## The rectangle the camera clamps to; owned by the level, copied onto the
## player camera's limits by main.gd on scene load.
@export var bounds: Rect2
