class_name Lanzador
extends Control

## Lanzador: Controlador principal de la interfaz de usuario en modo Kiosco para totems.
## Administra la cuadrícula de tarjetas de juegos, carga dinámica de fondo,
## prevención de salidas no deseadas a Windows y ejecución exclusiva de un juego a la vez.

const GameScannerScript = preload("res://scripts/game_scanner.gd")
const IconManagerScript = preload("res://scripts/icon_manager.gd")
const GameLauncherScript = preload("res://scripts/game_launcher.gd")
const GameCardScript = preload("res://scripts/game_card.gd")

@export var card_scene: PackedScene = preload("res://scenes/game_card.tscn")

# Nodos de la interfaz
@onready var flag_background: TextureRect = $FlagBackground
@onready var grid_container: GridContainer = %GridContainer
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var estado_vacio: Control = $CanvasLayer/EstadoVacio
@onready var toast_panel: PanelContainer = %ToastPanel
@onready var toast_label: Label = %ToastLabel
@onready var status_label: Label = get_node_or_null("%StatusLabel")
@onready var games_count_label: Label = get_node_or_null("%GamesCountLabel")

var game_launcher: Node
var _detected_games: Array[Dictionary] = []
var _card_nodes: Array[Control] = []
var _last_launched_game: Dictionary = {}
var _toast_tween: Tween

func _ready() -> void:
	# 1. Configurar pantalla completa para modo Kiosco
	_setup_window_mode()

	# 2. Cargar fondo personalizado si existe junto al ejecutable
	_load_custom_background()

	# 3. Instanciar gestor de ejecución de juegos
	game_launcher = GameLauncherScript.new()
	game_launcher.name = "GameLauncherNode"
	game_launcher.juego_iniciado.connect(_on_game_started)
	game_launcher.juego_finalizado.connect(_on_game_finished)
	game_launcher.lanzamiento_fallido.connect(_on_launch_failed)
	estado_vacio.actualizar.connect(refrescar_libreria)
	add_child(game_launcher)

	# 4. Conectar responsividad de la cuadrícula
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# 5. Ocultar inicialmente el toast de notificación
	if toast_panel:
		toast_panel.modulate.a = 0.0
		toast_panel.visible = false

	# 6. Escanear biblioteca de juegos
	refrescar_libreria()

## Configura la ventana del lanzador para modo Kiosco
func _setup_window_mode() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_tree().set_auto_accept_quit(false)
	print("Lanzador: Modo Kiosco iniciado en pantalla completa.")

## Intercepta notificaciones del sistema operativo
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Lanzador: Solicitud de cierre recibida.")
		_close_launcher()

## Cierra limpiamente el lanzador (solo administradores)
func _close_launcher() -> void:
	print("Lanzador: Cerrando aplicación...")
	get_tree().quit()

## Carga dinámicamente una imagen de fondo si se encuentra al lado del ejecutable
func _load_custom_background() -> void:
	if not flag_background:
		return

	var base_dir = GameScannerScript.get_base_directory()
	var background_filenames = [
		"fondo_lanzador.png",
		"fondo_lanzador.jpg",
		"fondo_lanzador.jpeg",
		"fondo_lanzador.webp",
		"fondo.png",
		"fondo.jpg",
		"fondo.webp"
	]

	for filename in background_filenames:
		var bg_path = base_dir.path_join(filename).replace("\\", "/")
		if FileAccess.file_exists(bg_path):
			var img = Image.load_from_file(bg_path)
			if img != null and not img.is_empty():
				flag_background.texture = ImageTexture.create_from_image(img)
				print("Lanzador: Fondo personalizado cargado desde: ", bg_path)
				return

## Captura de eventos de teclado (modo Kiosco seguro)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed:
			# Alt+F4: Permitido únicamente para que administradores cierren el totem
			if key_event.keycode == KEY_F4 and key_event.alt_pressed:
				get_viewport().set_input_as_handled()
				_close_launcher()
				return

			# Escape: En un totem de museo, Escape NO debe cerrar al escritorio de Windows
			if key_event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				return

			# Tecla F5: Actualizar biblioteca (solo si no hay un juego corriendo)
			if key_event.keycode == KEY_F5:
				get_viewport().set_input_as_handled()
				if not game_launcher.is_running():
					refrescar_libreria()
					show_toast("Biblioteca actualizada.")
				return

## Escanea carpetas y regenera las tarjetas de la interfaz
func refrescar_libreria() -> void:
	print("Lanzador: Escaneando biblioteca de juegos...")
	IconManagerScript.clear_cache()
	_detected_games = GameScannerScript.scan_games()
	_reconstruir_cartas()

## Construye las tarjetas en la cuadrícula
func _reconstruir_cartas() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	_card_nodes.clear()

	var total_count = _detected_games.size()

	if games_count_label:
		games_count_label.text = "Juegos disponibles: %d" % total_count
	if status_label:
		status_label.text = "Sistema listo"

	if total_count == 0:
		if estado_vacio:
			estado_vacio.visible = true
		if grid_container:
			grid_container.visible = false
		return

	if estado_vacio:
		estado_vacio.visible = false
	if grid_container:
		grid_container.visible = true

	_ajustar_columnas_grilla()

	for game_data in _detected_games:
		var card = card_scene.instantiate()
		grid_container.add_child(card)

		var icon_tex = IconManagerScript.get_game_icon(game_data)
		card.setup(game_data, icon_tex)

		card.card_pressed.connect(_on_card_pressed)
		_card_nodes.append(card)

	_setup_card_focus_neighbors()

	if not _card_nodes.is_empty():
		_card_nodes[0].grab_focus()

## Ajusta el número de columnas de la cuadrícula dinámicamente según la resolución
func _ajustar_columnas_grilla() -> void:
	if not is_inside_tree() or not grid_container:
		return

	var width = get_viewport_rect().size.x
	var columnas = 4

	if width >= 1800:
		columnas = 4
	elif width >= 1350:
		columnas = 3
	elif width >= 950:
		columnas = 2
	else:
		columnas = 1

	grid_container.columns = columnas

func _on_viewport_size_changed() -> void:
	_ajustar_columnas_grilla()
	_setup_card_focus_neighbors()

## Configura los vecinos de foco para navegación fluida
func _setup_card_focus_neighbors() -> void:
	var total = _card_nodes.size()
	var columnas = grid_container.columns
	if total == 0 or columnas <= 0:
		return

	for i in range(total):
		var card = _card_nodes[i]
		if i % columnas > 0:
			card.focus_neighbor_left = _card_nodes[i - 1].get_path()
		if i % columnas < columnas - 1 and (i + 1) < total:
			card.focus_neighbor_right = _card_nodes[i + 1].get_path()
		if i - columnas >= 0:
			card.focus_neighbor_top = _card_nodes[i - columnas].get_path()
		if i + columnas < total:
			card.focus_neighbor_bottom = _card_nodes[i + columnas].get_path()

## Al pulsar una tarjeta de juego
func _on_card_pressed(game_info: Dictionary) -> void:
	if game_launcher.is_running():
		show_toast("Ya hay un juego en ejecución. Esperá a que termine.")
		return

	_last_launched_game = game_info
	var game_name = game_info.get("name", "Juego")
	show_toast("Iniciando " + game_name + "...")
	if status_label:
		status_label.text = "Iniciando: " + game_name

	game_launcher.launch_game(game_info)

## Eventos de GameLauncher
func _on_game_started() -> void:
	var name_str = _last_launched_game.get("name", "")
	print("Lanzador: Juego en ejecución: ", name_str)
	if status_label:
		status_label.text = "En ejecución: " + name_str

func _on_game_finished(exit_code: int) -> void:
	var name_str = _last_launched_game.get("name", "")
	print("Lanzador: Juego concluido: ", name_str, " (Código: ", exit_code, ")")
	if status_label:
		status_label.text = "Sistema listo"
	show_toast("¡Bienvenido de vuelta! Seleccioná tu próximo juego.")

	# Devolver foco a la tarjeta del juego terminado
	for card in _card_nodes:
		if card.game_info.get("name", "") == name_str:
			card.grab_focus()
			break

func _on_launch_failed(error_message: String) -> void:
	push_warning("Lanzador: Fallo de inicio: " + error_message)
	if status_label:
		status_label.text = "Error al iniciar juego"
	show_toast("Error: " + error_message)

## Muestra un mensaje flotante temporal (Toast)
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
