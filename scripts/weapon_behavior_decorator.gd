class_name WeaponBehaviorDecorator
extends WeaponBehavior

var wrapped_behavior: WeaponBehavior

func _init(wrapped_behavior: WeaponBehavior) -> void:
    self.wrapped_behavior = wrapped_behavior

func shoot(owner: Node3D) -> void:
    wrapped_behavior.shoot(owner)