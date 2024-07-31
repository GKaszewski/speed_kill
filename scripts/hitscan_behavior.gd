class_name HitScanBehavior
extends WeaponBehavior

@export var damage: float = 10.0
@export var decal_scene: PackedScene

var raycast: RayCast3D = null

func shoot(owner: Node3D) -> void:
	if not raycast:
		raycast = owner.get_parent().get_node("WeaponRayCast3D") as RayCast3D
	
	if not raycast:
		return

	var collision_point := raycast.get_collision_point()
	var normal := raycast.get_collision_normal()
	var target := raycast.get_collider() as Node3D

	if not target:
		return

	var health_component := target.find_child("HealthComponent") as HealthComponent
	if health_component:
		health_component.decrease_health(damage)
	else:
		var decal_instance = decal_scene.instance()
		target.add_child(decal_instance)
		decal_instance.global_transform.origin = collision_point
		if normal == Vector3(1, 0, 0):
			decal_instance.rotation_degrees.z = 90

func modify_damage(damage_multiplier: float) -> void:
	damage *= damage_multiplier
