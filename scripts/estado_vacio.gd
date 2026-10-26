extends Control

signal actualizar

@onready var empty_title: Label = $EmptyState/EmptyPanel/EmptyVBox/EmptyTitle
@onready var empty_subtitle: Label = $EmptyState/EmptyPanel/EmptyVBox/EmptySubtitle

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

## funcion cuando se presiona el boton de actualizado
# @params ninguno
# @pre-condiciones: el boton tiene que existir y estar conectado
# @post-condiciones: se emitira la señal de actualizar para la interfaz  
func _on_empty_btn_pressed() -> void:
	actualizar.emit()
