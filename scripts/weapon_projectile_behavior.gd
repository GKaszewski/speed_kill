class_name WeaponProjectileBehavior
extends WeaponBehavior

@export var projectile_scene: PackedScene
@export var spawn_point: NodePath

var spawn_point_node: Node3D = null

func shoot(owner: Node3D, root_node: Node3D) -> void:
	var projectile_instance = projectile_scene.instantiate()
	root_node.add_child(projectile_instance)
	if not spawn_point_node:
		spawn_point_node = owner.get_node(spawn_point) as Node3D
	projectile_instance.global_transform = spawn_point_node.global_transform
