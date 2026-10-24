class_name Launcher
extends Control

## Launcher: Controlador principal de la interfaz de usuario en modo Kiosco.
## Administra la cuadrícula de tarjetas, la navegación por teclado y ratón,
## la prevención de cierres no deseados y la interacción con GameScanner y GameLauncher.

const GameScannerScript = preload("res://scripts/game_scanner.gd")
const IconManagerScript = preload("res://scripts/icon_manager.gd")
const GameLauncherScript = preload("res://scripts/game_launcher.gd")
const GameCardScript = preload("res://scripts/game_card.gd")

@export var card_scene: PackedScene = preload("res://scenes/game_card.tscn")

# Nodos de la interfaz (con resolución segura para permitir personalizaciones visuales de la escena)
@onready var grid_container: GridContainer = %GridContainer
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var empty_state: Control = %EmptyState
@onready var toast_panel: PanelContainer = %ToastPanel
@onready var toast_label: Label = %ToastLabel
@onready var status_label: Label = get_node_or_null("%StatusLabel")
@onready var games_count_label: Label = get_node_or_null("%GamesCountLabel")
@onready var background_sun: Control = get_node_or_null("%BackgroundSun")

var game_launcher: Node
var _detected_games: Array[Dictionary] = []
var _card_nodes: Array[Control] = []
var _config_overrides: Dictionary = {}
var _toast_tween: Tween

func _ready() -> void:
	# 1. Configurar modo de ventana y permitir cierre limpio desde la barra de tareas o Alt+F4
	_setup_window_mode()

	# 2. Instanciar gestor de ejecución de juegos
	game_launcher = GameLauncherScript.new()
	game_launcher.name = "GameLauncherNode"
	game_launcher.game_started.connect(_on_game_started)
	game_launcher.game_finished.connect(_on_game_finished)
	game_launcher.launch_failed.connect(_on_launch_failed)
	add_child(game_launcher)

	# 3. Conectar señal de cambio de tamaño para responsividad de la cuadrícula
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# 4. Ocultar inicialmente el toast de notificación
	if toast_panel:
		toast_panel.modulate.a = 0.0
		toast_panel.visible = false

	# 5. Cargar configuración opcional y escanear biblioteca
	_load_optional_config()
	refresh_library()

## Configura la ventana del launcher permitiendo cierre ordenado desde el sistema operativo
func _setup_window_mode() -> void:
	# Establecer modo de pantalla completa estándar para una experiencia de arcade inmersiva
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	# Manejar NOTIFICATION_WM_CLOSE_REQUEST manualmente para cerrar ordenadamente
	get_tree().set_auto_accept_quit(false)
	
	print("Launcher: Ventana iniciada en pantalla completa. Cierre habilitado (Alt+F4 o Barra de Tareas).")

## Intercepta notificaciones del sistema operativo
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Permite cerrar desde la barra de tareas (clic derecho -> Cerrar ventana) o Alt+F4
		print("Launcher: Solicitud de cierre de ventana recibida (Barra de tareas / Alt+F4).")
		_close_launcher()

## Cierra limpiamente el launcher
func _close_launcher() -> void:
	print("Launcher: Cerrando aplicación...")
	get_tree().quit()

## Captura de eventos de teclado
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed:
			# Alt+F4: Cerrar el launcher inmediatamente
			if key_event.keycode == KEY_F4 and key_event.alt_pressed:
				get_viewport().set_input_as_handled()
				_close_launcher()
				return

			# Tecla Escape: Permite salir del launcher
			if key_event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_close_launcher()
				return
			
			# Tecla F5: Actualizar biblioteca
			if key_event.keycode == KEY_F5:
				get_viewport().set_input_as_handled()
				refresh_library()
				show_toast("Biblioteca actualizada.")
				return

## Carga el archivo de configuración opcional launcher_config.json si existe
func _load_optional_config() -> void:
	_config_overrides.clear()
	var base_dir = GameScannerScript.get_base_directory()
	var config_path = base_dir.path_join("launcher_config.json").replace("\\", "/")
	
	if not FileAccess.file_exists(config_path):
		# Probar también en res:// si estamos en el editor
		if OS.has_feature("editor") and FileAccess.file_exists("res://launcher_config.json"):
			config_path = "res://launcher_config.json"
		else:
			return

	var file = FileAccess.open(config_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var parsed = JSON.parse_string(json_text)
		if parsed is Dictionary:
			_config_overrides = parsed
			print("Launcher: Configuración opcional cargada exitosamente.")

## Escanea carpetas y regenera las tarjetas de la interfaz
func refresh_library() -> void:
	print("Launcher: Escaneando biblioteca de juegos...")
	IconManagerScript.clear_cache()
	
	_detected_games = GameScannerScript.scan_games("", _config_overrides)
	_rebuild_cards()

## Construye las tarjetas en la cuadrícula
func _rebuild_cards() -> void:
	# Limpiar tarjetas anteriores
	for child in grid_container.get_children():
		child.queue_free()
	_card_nodes.clear()

	var total_count = _detected_games.size()
	
	# Actualizar etiquetas de pie de pantalla
	if games_count_label:
		games_count_label.text = "Juegos disponibles: %d" % total_count
	if status_label:
		status_label.text = "Sistema listo"

	if total_count == 0:
		if empty_state:
			empty_state.visible = true
		if grid_container:
			grid_container.visible = false
		return

	if empty_state:
		empty_state.visible = false
	if grid_container:
		grid_container.visible = true

	# Calcular columnas según el ancho disponible
	_adjust_grid_columns()

	# Instanciar cada tarjeta
	for game_data in _detected_games:
		var card = card_scene.instantiate()
		grid_container.add_child(card)
		
		# Obtener textura del icono mediante la jerarquía de prioridad
		var icon_tex = IconManagerScript.get_game_icon(game_data)
		card.setup(game_data, icon_tex)
		
		# Conectar señal de clic
		card.card_pressed.connect(_on_card_pressed)
		card.card_focused.connect(_on_card_focused)
		_card_nodes.append(card)

	# Configurar navegación bidimensional fluida por teclado
	_setup_card_focus_neighbors()

	# Seleccionar la primera tarjeta con el foco
	if not _card_nodes.is_empty():
		_card_nodes[0].grab_focus()

## Ajusta el número de columnas de la cuadrícula dinámicamente según la resolución
func _adjust_grid_columns() -> void:
	if not is_inside_tree() or not grid_container:
		return
		
	var width = get_viewport_rect().size.x
	var cols = 4
	
	if width >= 1800:
		cols = 5
	elif width >= 1350:
		cols = 4
	elif width >= 950:
		cols = 3
	else:
		cols = 2
		
	grid_container.columns = cols

func _on_viewport_size_changed() -> void:
	_adjust_grid_columns()
	_setup_card_focus_neighbors()

## Configura los vecinos de foco (arriba, abajo, izquierda, derecha) para navegación por teclado
func _setup_card_focus_neighbors() -> void:
	var total = _card_nodes.size()
	var cols = grid_container.columns
	if total == 0 or cols <= 0:
		return

	for i in range(total):
		var card = _card_nodes[i]
		
		# Vecino izquierdo
		if i % cols > 0:
			card.focus_neighbor_left = _card_nodes[i - 1].get_path()
		# Vecino derecho
		if i % cols < cols - 1 and (i + 1) < total:
			card.focus_neighbor_right = _card_nodes[i + 1].get_path()
		# Vecino arriba
		if i - cols >= 0:
			card.focus_neighbor_top = _card_nodes[i - cols].get_path()
		# Vecino abajo
		if i + cols < total:
			card.focus_neighbor_bottom = _card_nodes[i + cols].get_path()

## Al hacer clic en cualquier parte de una tarjeta
func _on_card_pressed(game_info: Dictionary) -> void:
	var game_name = game_info.get("name", "Juego")
	show_toast("Iniciando " + game_name + "...")
	if status_label:
		status_label.text = "Iniciando: " + game_name
	
	game_launcher.launch_game(game_info)

func _on_card_focused(game_info: Dictionary) -> void:
	# Asegurar que la tarjeta enfocada sea visible desplazando el ScrollContainer si es necesario
	# (Godot maneja el scroll automático al enfocar nodos hijos de un ScrollContainer)
	pass

## Eventos emitidos por GameLauncher
func _on_game_started(game_info: Dictionary) -> void:
	var name_str = game_info.get("name", "")
	print("Launcher: Juego en ejecución: ", name_str)
	if status_label:
		status_label.text = "En ejecución: " + name_str

func _on_game_finished(game_info: Dictionary, exit_code: int) -> void:
	var name_str = game_info.get("name", "")
	print("Launcher: Juego concluido: ", name_str, " (Código: ", exit_code, ")")
	if status_label:
		status_label.text = "Sistema listo"
	show_toast("¡Bienvenido de vuelta! Seleccioná tu próximo juego.")

	# Reenfocar la tarjeta del juego recién terminado
	for card in _card_nodes:
		if card.game_info.get("name", "") == name_str:
			card.grab_focus()
			break

func _on_launch_failed(game_info: Dictionary, error_message: String) -> void:
	push_warning("Launcher: Fallo de inicio: " + error_message)
	if status_label:
		status_label.text = "Error al iniciar juego"
	show_toast("Error: " + error_message)

## Muestra un mensaje flotante temporal (Toast) con animación
func show_toast(message: String) -> void:
	if not toast_panel or not toast_label:
		return

	toast_label.text = message
	toast_panel.visible = true

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func(): toast_panel.visible = false)
