class_name QuadDamageDecorator
extends WeaponBehaviorDecorator

@export var damage_multiplier: float = 4.0

func shoot(owner: Node3D) -> void:
    if wrapped_behavior:
        wrapped_behavior.modify_damage(damage_multiplier)
        wrapped_behavior.shoot(owner)
        wrapped_behavior.modify_damage(1.0 / damage_multiplier)