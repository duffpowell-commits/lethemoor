extends Node3D
const Geometry = preload("res://scripts/prototypes/harbor_prop_geometry.gd")
func _ready() -> void:
	add_child(Geometry.make_crate())
