class_name Weapon
extends Node3D

@export var damage: float = 10.0
@export var fire_rate: float = 0.5
@export var is_projectile: bool = false
@export var ammo: int = 10

@export var projectile_scene: PackedScene
@export var decal_scene: PackedScene

var last_shot_frame: int = 0

func get_time_from_frame(frame: int) -> float:
	return frame / Engine.get_frames_per_second()

func shoot_hitscan() -> void:
	var raycast: RayCast3D = %WeaponRayCast3D

	var collision_point := raycast.get_collision_point()
	var normal := raycast.get_collision_normal()
	var target := raycast.get_collider() as Node3D
	
	if not target:
		return
	
	var health_component := target.find_child("HealthComponent") as HealthComponent
	if health_component:
		health_component.decrease_health(damage)
	else:
		var decal_instance = decal_scene.instantiate()
		target.add_child(decal_instance)
		decal_instance.global_transform.origin = collision_point
		if normal == Vector3(1, 0, 0):
			decal_instance.rotation_degrees.z = 90

func shoot_projectile() -> void:
	pass

func shoot() -> void:
	var current_frame := Engine.get_physics_frames()
	var time_since_last_shot := get_time_from_frame(current_frame - last_shot_frame)
	
	if time_since_last_shot < fire_rate:
		return

	if ammo <= 0:
		return

	if is_projectile:
		shoot_projectile()
	else:
		shoot_hitscan()

	ammo -= 1
	last_shot_frame = current_frame
