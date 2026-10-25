class_name GameLauncher
extends Node

## GameLauncher: Administra la ejecución de procesos externos en Windows (.exe),
## el ocultamiento temporal del launcher, la prevención de múltiples instancias
## y el restablecimiento automático de la pantalla completa al finalizar el videojuego.

signal game_started(game_info: Dictionary)
signal game_finished(game_info: Dictionary, exit_code: int)
signal launch_failed(game_info: Dictionary, error_message: String)

var _is_game_running: bool = false
var _current_pid: int = 0
var _current_game: Dictionary = {}
var _monitor_timer: Timer
var _previous_window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN

func _ready() -> void:
	# Configurar temporizador para monitoreo no bloqueante del proceso hijo
	_monitor_timer = Timer.new()
	_monitor_timer.wait_time = 0.1
	_monitor_timer.one_shot = false
	_monitor_timer.autostart = false
	_monitor_timer.timeout.connect(_on_monitor_timer_timeout)
	add_child(_monitor_timer)

## Indica si actualmente hay un juego ejecutándose
func is_running() -> bool:
	return _is_game_running

## Retorna la información del juego actualmente en ejecución
func get_current_game() -> Dictionary:
	return _current_game

## Ejecuta el videojuego a partir de su diccionario de metadatos
func launch_game(game_info: Dictionary) -> bool:
	# 1. Prevención de lanzamientos concurrentes accidentales
	if _is_game_running:
		var running_name = _current_game.get("name", "otro juego")
		launch_failed.emit(game_info, "Ya hay un juego en ejecución (" + running_name + "). Esperá a que termine.")
		return false

	var exe_path = game_info.get("executable_path", "").strip_edges().replace("/", "\\")
	var game_name = game_info.get("name", "Juego desconocido")
	var working_dir = game_info.get("working_directory", exe_path.get_base_dir()).replace("/", "\\")

	# 2. Validaciones previas de integridad
	if exe_path.is_empty():
		launch_failed.emit(game_info, "No se ha especificado la ruta del ejecutable para '" + game_name + "'.")
		return false

	if exe_path.get_extension().to_lower() != "exe":
		launch_failed.emit(game_info, "El archivo especificado no es un ejecutable de Windows (.exe): " + exe_path)
		return false

	if not FileAccess.file_exists(exe_path):
		launch_failed.emit(game_info, "El ejecutable '" + exe_path.get_file() + "' no existe o fue eliminado de la carpeta.")
		return false

	# 3. Iniciar el proceso estableciendo el directorio de trabajo correcto
	print("GameLauncher: Iniciando '" + game_name + "' -> " + exe_path)
	print("GameLauncher: Directorio de trabajo: " + working_dir)

	var pid: int = 0
	if OS.has_feature("windows"):
		# En Windows, para que los juegos encuentren sus dependencias (.pck, DLLs, assets, saves),
		# se debe cambiar el directorio de trabajo a su propia carpeta.
		# Se ejecuta a través de cmd.exe /c "cd /d "<working_dir>" && "<exe_path>"" de forma invisible (sin consola)
		var cmd_args = PackedStringArray([
			"/c",
			"cd /d \"" + working_dir + "\" && \"" + exe_path + "\""
		])
		pid = OS.create_process("cmd.exe", cmd_args, false)
	else:
		pid = OS.create_process(exe_path, PackedStringArray([]), false)

	if pid <= 0:
		launch_failed.emit(game_info, "Error del sistema al crear el proceso para '" + game_name + "' (PID inválido).")
		return false

	# 4. Proceso creado con éxito: registrar estado
	_is_game_running = true
	_current_pid = pid
	_current_game = game_info

	# 5. Ocultar o minimizar temporalmente la ventana del launcher para que el juego tome el primer plano
	# _minimize_launcher_window()
	Engine.max_fps = 5
	OS.low_processor_usage_mode = true

	# 6. Iniciar monitoreo del proceso
	_monitor_timer.start()

	# 7. Notificar inicio exitoso
	game_started.emit(game_info)
	return true

## Temporizador periódico para verificar si el juego sigue activo
func _on_monitor_timer_timeout() -> void:
	if not _is_game_running or _current_pid <= 0:
		_monitor_timer.stop()
		return

	# Comprobar estado del proceso mediante OS.is_process_running
	var running = OS.is_process_running(_current_pid)
	if not running:
		# El proceso ha concluido
		_monitor_timer.stop()
		var exit_code = OS.get_process_exit_code(_current_pid)
		var finished_game = _current_game
		
		print("GameLauncher: El juego '" + finished_game.get("name", "") + "' ha finalizado con código de salida: ", exit_code)

		# Limpiar estado interno antes de restaurar la ventana
		_is_game_running = false
		_current_pid = 0
		_current_game = {}

		# Restaurar ventana del launcher a su modo anterior y devolver foco
		# _restore_launcher_window()
		Engine.max_fps = 60
		OS.low_processor_usage_mode = false
		DisplayServer.window_move_to_foreground()

		# Notificar retorno a la interfaz
		game_finished.emit(finished_game, exit_code)

## Minimiza el launcher temporalmente para dar paso al videojuego
func _minimize_launcher_window() -> void:
	_previous_window_mode = DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

## Restaura la ventana del launcher preservando la configuración de pantalla
func _restore_launcher_window() -> void:
	var target_mode = _previous_window_mode
	if target_mode == DisplayServer.WINDOW_MODE_MINIMIZED:
		target_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(target_mode)
	DisplayServer.window_move_to_foreground()
