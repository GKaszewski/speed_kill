class_name ExplosiveProjectile
extends Projectile

@export var explosion_radius: float = 5.0


#TODO: fix this and create proper implementation
func explode(collision_point: Vector3) -> void:
	print("Explosion at: ", collision_point)
	var area = Area3D.new()
	area.global_transform.origin = collision_point
	add_child(area)
	var shape = SphereShape3D.new()
	shape.radius = explosion_radius
	var shape_instance = CollisionShape3D.new()
	shape_instance.shape = shape
	area.add_child(shape_instance)
	area.connect("body_entered", _on_area_entered)

	area.queue_free()

func _on_area_entered(body: Node) -> void:
	print("Explosion hit: ", body)
	deal_damage(body)

func _on_impact(_body: Node) -> void:
	explode(global_transform.origin)
	cleanup()
