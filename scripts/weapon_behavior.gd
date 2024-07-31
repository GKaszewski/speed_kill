class_name WeaponBehavior
extends Resource

@export var fire_rate: float = 0.5
@export var ammo: int = 10

func shoot(_owner: Node3D, _root_node: Node3D) -> void:
    pass

func modify_damage(_damage_multiplier: float) -> void:
    pass