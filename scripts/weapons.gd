extends Node3D

var weapons: Array[Weapon] = []
var current_active_weapon_index := 0

@onready var weapons_parent_node := $"."

func _ready() -> void:
	for weapon in weapons_parent_node.get_children():
		if weapon is Weapon:
			weapons.append(weapon)

func _process(_delta):
	if Input.is_action_pressed("fire"):
		weapons[current_active_weapon_index].shoot()