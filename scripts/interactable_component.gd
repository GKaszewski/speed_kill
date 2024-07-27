class_name InteractableComponent
extends Node

signal interacted()

func interact_with():
	interacted.emit()