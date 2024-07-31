class_name Weapon
extends Node3D

@export var behavior: WeaponBehavior

var root_node: Node3D = null
var fire_timer := 0.0

func _ready():
	root_node = get_tree().current_scene.get_node(".")

func _process(delta):
	fire_timer += delta

func shoot() -> void:
	if not behavior or fire_timer < behavior.fire_rate:
		return

	if behavior.ammo <= 0:
		return

	behavior.shoot(self, root_node)
	behavior.ammo -= 1
	fire_timer = 0.0
