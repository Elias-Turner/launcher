extends Control

signal actualizar 

@onready var empty_title: Label = $EmptyState/EmptyPanel/EmptyVBox/EmptyTitle
@onready var empty_subtitle: Label = $EmptyState/EmptyPanel/EmptyVBox/EmptySubtitle

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_empty_btn_pressed() -> void:
	actualizar.emit()
