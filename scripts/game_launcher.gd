class_name GameLauncher
extends Node

## GameLauncher: Administra la ejecución de los videojuegos en Windows (.exe),
## garantizando que solo se ejecute un juego a la vez, optimizando recursos
## mientras el juego está activo y restaurando el foco del Lanzador al finalizar.

# Señales que emite el GameLauncher
signal juego_iniciado
signal juego_finalizado(exit_code: int)
signal lanzamiento_fallido(error_message: String)

# Indica si actualmente hay un juego ejecutándose
var _is_game_running: bool = false
# PID del proceso del juego actual
var _current_pid: int = 0
# Información del juego actual
var _current_game: Dictionary = {}
# Timer para monitorear el estado del proceso del juego
var _monitor_timer: Timer

func _ready() -> void:
	_monitor_timer = Timer.new()
	_monitor_timer.wait_time = 0.2
	_monitor_timer.one_shot = false
	_monitor_timer.autostart = false
	_monitor_timer.timeout.connect(_on_monitor_timer_timeout)
	add_child(_monitor_timer)

## Indica si actualmente hay un juego ejecutándose
# @params ninguno
# @pre-condiciones: ninguna
# @post-condiciones: retorna true si el juego está corriendo, false en caso contrario
func is_running() -> bool:
	return _is_game_running

## Retorna la información del juego actualmente en ejecución
# @params ninguno
# @pre-condiciones: ninguna
# @post-condiciones: retorna la información del juego que se está ejecutando
func get_current_game() -> Dictionary:
	return _current_game

## Ejecuta el videojuego a partir de su información
# @params game_info: diccionario con la información del juego
# @pre-condiciones: el juego no debe estar corriendo
# @post-condiciones: el juego se inicia y se monitorea su estado, las variables del lanzador se actualizan
func launch_game(game_info: Dictionary) -> bool:
	var salida := true
	# 1. Prevención estricta de ejecuciones simultáneas
	if _is_game_running:
		var running_name = _current_game.get("name", "otro juego")
		lanzamiento_fallido.emit("Ya hay un juego en ejecución (" + running_name + "). Esperá a que termine.")
		salida = false

	var exe_path = game_info.get("executable_path", "").strip_edges().replace("/", "\\")
	var game_name = game_info.get("name", "Juego desconocido")
	var working_dir = game_info.get("working_directory", exe_path.get_base_dir()).replace("/", "\\")

	# 2. Validaciones de archivo
	if exe_path.is_empty():
		lanzamiento_fallido.emit("No se ha especificado la ruta del ejecutable.")
		salida = false

	if not FileAccess.file_exists(exe_path):
		lanzamiento_fallido.emit("El archivo ejecutable '" + exe_path.get_file() + "' no existe o fue eliminado.")
		salida = false

	print("Lanzador: Iniciando '" + game_name + "' -> " + exe_path)

	# 3. Iniciar el proceso fijando el directorio de trabajo
	var pid: int = 0
	if OS.has_feature("windows"):
		# En Windows utilizamos cmd.exe con start /wait para asegurar que el proceso
		# inicie en su propia carpeta (para encontrar .pck, DLLs y assets) y esperar a que termine.
		var cmd_args = PackedStringArray([
			"/c",
			"cd /d \"" + working_dir + "\" && start \"\" /wait \"" + exe_path + "\""
		])
		pid = OS.create_process("cmd.exe", cmd_args, false)
	else:
		pid = OS.create_process(exe_path, PackedStringArray([]), false)

	if pid <= 0:
		lanzamiento_fallido.emit("Error del sistema al crear el proceso para '" + game_name + "'.")
		salida = false

	_is_game_running = true
	_current_pid = pid
	_current_game = game_info

	# 4. Modo de bajo consumo para ahorrar recursos mientras el juego está activo
	Engine.max_fps = 5
	OS.low_processor_usage_mode = true

	# 5. Iniciar monitoreo del proceso
	_monitor_timer.start()
	juego_iniciado.emit()
	return salida

## Monitorea periódicamente el estado del proceso del juego
# @params ninguno
# @pre-condiciones: el timer debe estar corriendo
# @post-condiciones: el timer se detiene si el proceso del juego termina
func _on_monitor_timer_timeout() -> void:
	if not _is_game_running or _current_pid <= 0:
		_monitor_timer.stop()
		return

	if not OS.is_process_running(_current_pid):
		_monitor_timer.stop()
		var exit_code = OS.get_process_exit_code(_current_pid)
		var finished_game = _current_game

		print("Lanzador: El juego '" + finished_game.get("name", "") + "' ha finalizado con código: ", exit_code)

		_is_game_running = false
		_current_pid = 0
		_current_game = {}

		# Restaurar rendimiento y devolver el foco a la ventana del Lanzador
		Engine.max_fps = 60
		OS.low_processor_usage_mode = false
		DisplayServer.window_move_to_foreground()

		juego_finalizado.emit(exit_code)
