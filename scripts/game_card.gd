class_name GameCard
extends PanelContainer

## GameCard: Representa visualmente un juego en la biblioteca del launcher.
## Maneja los estados normal, hover y seleccionado con estética argentina,
## animaciones suaves y soporte completo para ratón y teclado.

signal card_pressed(game_info: Dictionary)
signal card_focused(game_info: Dictionary)

@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var aspectRatio: AspectRatioContainer = $AspectRatioContainer

var game_info: Dictionary = {}
var _is_hovered: bool = false
var _is_focused: bool = false
var _tween: Tween

var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_focused: StyleBoxFlat

# Paleta argentina
const COLOR_CELESTE: Color = Color("#75AADB")
const COLOR_CELESTE_LIGHT: Color = Color("#D9EEFF")
const COLOR_BLANCO: Color = Color("#FFFFFF")
const COLOR_DORADO: Color = Color("#F6B40E")
const COLOR_DORADO_BRIGHT: Color = Color("#FED156")
const COLOR_AZUL_PROFUNDO: Color = Color("#1C3B57")
const COLOR_SOMBRA: Color = Color(0.086, 0.196, 0.31, 0.28)

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(300, 290)
	pivot_offset = custom_minimum_size * 0.5
	
	_init_cached_styles()

	# Conexión de eventos de entrada y foco
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	gui_input.connect(_on_gui_input)

	_update_style(false, false)

func _init_cached_styles() -> void:
	_style_normal = _create_card_style(COLOR_BLANCO, COLOR_CELESTE, 2, 4)
	_style_hover = _create_card_style(COLOR_CELESTE_LIGHT, COLOR_DORADO, 3, 8)
	_style_focused = _create_card_style(COLOR_CELESTE_LIGHT, COLOR_DORADO_BRIGHT, 4, 12)

func _create_card_style(bg: Color, border: Color, border_width: int, shadow: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = COLOR_SOMBRA
	style.shadow_offset = Vector2(0, 5)
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.shadow_size = shadow
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	
	return style


## Configura la tarjeta con los datos de un juego detectado
func setup(p_game_info: Dictionary, p_icon: Texture2D) -> void:
	game_info = p_game_info
	
	if name_label:
		name_label.text = game_info.get("name", "Juego")
	
	if icon_rect:
		icon_rect.texture = p_icon
		var proporcion = float(icon_rect.texture.get_width()/float(icon_rect.texture.get_height())) 
		aspectRatio.ratio = proporcion

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5

func _on_mouse_entered() -> void:
	_is_hovered = true
	_animate_card(1.04)
	_update_style(true, _is_focused)

func _on_mouse_exited() -> void:
	_is_hovered = false
	if not _is_focused:
		_animate_card(1.0)
	_update_style(false, _is_focused)

func _on_focus_entered() -> void:
	_is_focused = true
	_animate_card(1.04)
	_update_style(_is_hovered, true)
	card_focused.emit(game_info)

func _on_focus_exited() -> void:
	_is_focused = false
	if not _is_hovered:
		_animate_card(1.0)
	_update_style(_is_hovered, false)

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
	# Animación de presión rápida (rebote de confirmación)
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

func _update_style(hovered: bool, focused: bool) -> void:
	if focused:
		add_theme_stylebox_override("panel", _style_focused)
	elif hovered:
		add_theme_stylebox_override("panel", _style_hover)
	else:
		add_theme_stylebox_override("panel", _style_normal)
