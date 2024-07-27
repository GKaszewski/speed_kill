class_name HealthComponent
extends Node3D

signal health_changed(health: float)
signal died

var health: float
@export var max_health: float = 3.0

func _ready():
    health = max_health

func _process(_delta):
    if health <= 0:
        emit_signal("died")

        if get_parent():
            get_parent().queue_free()
        else:
            queue_free()

func decrease_health(amount: float):
    health -= amount
    emit_signal("health_changed", health)

func increase_health(amount: float):
    health += amount
    emit_signal("health_changed", health)