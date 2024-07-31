class_name Projectile
extends RigidBody3D

@export var speed: float = 20.0
@export var damage: float = 10.0

@export var camera: Camera3D = null

func _ready():
	if not camera:
		camera = get_tree().current_scene.get_node("CharacterBody3D/HeadOriginalPosition/Head/CameraSmooth/Camera3D") as Camera3D

		# set the projectile velocity
		var direction = -camera.global_transform.basis.z
		linear_velocity = direction * speed

func deal_damage(body: Node3D):
	var health_component = body.find_child("HealthComponent") as HealthComponent
	if health_component:
		health_component.decrease_health(damage)

func cleanup():
	queue_free()

func _on_impact(body: Node) -> void:
	deal_damage(body)
	cleanup()
