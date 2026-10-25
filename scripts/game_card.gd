class_name GameCard
extends Control

## GameCard: Representa visualmente un juego en la biblioteca del Lanzador.
## Maneja animaciones suaves al enfocar/apuntar y soporte completo para ratón y teclado.

signal card_pressed(game_info: Dictionary)
signal card_focused(game_info: Dictionary)

@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var aspect_ratio_container: AspectRatioContainer = $VBoxContainer/AspectRatioContainer

var game_info: Dictionary = {}
var _is_hovered: bool = false
var _is_focused: bool = false
var _tween: Tween

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(350, 350)
	pivot_offset = custom_minimum_size * 0.5

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	gui_input.connect(_on_gui_input)

## Configura la tarjeta con los datos del juego y su carátula
func setup(p_game_info: Dictionary, p_icon: Texture2D) -> void:
	game_info = p_game_info

	if name_label:
		name_label.text = game_info.get("name", "Juego")

	if icon_rect and p_icon:
		icon_rect.texture = p_icon
		if p_icon.get_height() > 0:
			var proporcion = float(p_icon.get_width()) / float(p_icon.get_height())
			aspect_ratio_container.ratio = proporcion

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5

func _on_mouse_entered() -> void:
	_is_hovered = true
	_animate_card(1.04)

func _on_mouse_exited() -> void:
	_is_hovered = false
	if not _is_focused:
		_animate_card(1.0)

func _on_focus_entered() -> void:
	_is_focused = true
	_animate_card(1.04)
	card_focused.emit(game_info)

func _on_focus_exited() -> void:
	_is_focused = false
	if not _is_hovered:
		_animate_card(1.0)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_trigger_selection()
			accept_event()
	elif event.is_action_pressed("ui_accept"):
		_trigger_selection()
		accept_event()

func _trigger_selection() -> void:
	# Animación de confirmación
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.08)
	_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.12)

	card_pressed.emit(game_info)

func _animate_card(target_scale: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(target_scale, target_scale), 0.15)
