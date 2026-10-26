class_name GameScanner
extends RefCounted

## GameScanner: Responsable de explorar el sistema de archivos
## y detectar automáticamente las carpetas de videojuegos y su ejecutable (.exe).

# Carpetas del sistema o internas que se ignoran siempre
const IGNORED_DIRECTORIES: Array[String] = [
	".godot",
	".git",
	".import",
	"system volume information",
	"$recycle.bin",
	"assets",
	"scenes",
	"scripts",
	"logs"
]

## Normaliza separadores de ruta y simplifica segmentos relativos
static func _clean_path(path: String) -> String:
	return path.simplify_path().replace("\\", "/")

## Obtiene el directorio base (en editor res://, en exportado la carpeta del ejecutable)
## @params: ninguno
## @pre-condiciones: ninguna
## @post-condiciones: retorna el directorio base donde esta el launcher
static func get_base_directory() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://")
	return OS.get_executable_path().get_base_dir()

## Obtiene la ruta de la carpeta donde se ubican los juegos.
## @params: custom_path: String = "" - ruta personalizada de la carpeta de juegos
## @pre-condiciones: ninguna
## @post-condiciones: retorna la ruta de la carpeta donde se ubican los juegos.
## Se busca en la carpeta hermana ../Juegos y en la carpeta local ./Juegos
static func get_games_directory(custom_path: String = "") -> String:
	if not custom_path.is_empty():
		return _clean_path(custom_path)

	var base_dir = get_base_directory()

	# 1. Carpeta hermana ../Juegos (entorno de producción Kiosco)
	var sibling_path = _clean_path(base_dir.path_join("../Juegos"))
	if DirAccess.dir_exists_absolute(sibling_path):
		return sibling_path

	# 2. Carpeta local ./Juegos (entorno de pruebas/desarrollo)
	var local_path = _clean_path(base_dir.path_join("Juegos"))
	if DirAccess.dir_exists_absolute(local_path):
		return local_path

	return sibling_path

## Escanea el directorio de juegos buscando subcarpetas (una por juego)
## @params: custom_base_path: String = "" - ruta personalizada de la carpeta de juegos
## @pre-condiciones: ninguna
## @post-condiciones: retorna un array de diccionarios con la información de los juegos encontrados
static func scan_games(custom_base_path: String = "") -> Array[Dictionary]:
	var target_dir = get_games_directory(custom_base_path)
	var games: Array[Dictionary] = []

	# Crear carpeta si aún no existe
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)

	for folder_name in DirAccess.get_directories_at(target_dir):
		if folder_name.begins_with(".") or folder_name.to_lower() in IGNORED_DIRECTORIES:
			continue

		var folder_path = _clean_path(target_dir.path_join(folder_name))
		var game_entry = _process_game_folder(folder_name, folder_path)
		if not game_entry.is_empty():
			games.append(game_entry)

	# Ordenar los juegos alfabéticamente por su nombre visible (nombre de la carpeta)
	games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["name"].naturalnocasecmp_to(b["name"]) < 0
	)

	return games

## Procesa una carpeta de juego individual buscando su ejecutable directo (.exe)
# @params: folder_name: String - nombre de la carpeta del juego
# @params: folder_path: String - ruta de la carpeta del juego
# @pre-condiciones: ninguna
# @post-condiciones: retorna un diccionario con la información del juego si se encuentra su ejecutable, 
# en caso contrario retorna un diccionario vacío
static func _process_game_folder(folder_name: String, folder_path: String) -> Dictionary:
	var juego_info: Dictionary = {}
	var exe_path = ""
	var encontrado := false
	for file_name in DirAccess.get_files_at(folder_path):
		if not encontrado:
			var lower = file_name.to_lower()
			# Ignorar wrappers de consola de depuración generados por Godot (*.console.exe)
			if lower.ends_with(".console.exe") or lower.ends_with(".console"):
				continue

			if lower.ends_with(".exe"):
				exe_path = _clean_path(folder_path.path_join(file_name))
				encontrado = true

	if exe_path.is_empty():
		juego_info = {}
	else:
		# El nombre mostrado en la tarjeta viene dado DIRECTAMENTE por el nombre de la carpeta
		juego_info = {
			"id": folder_name.to_lower().validate_node_name(),
			"name": folder_name,
			"folder_name": folder_name,
			"folder_path": folder_path,
			"executable_path": exe_path,
			"working_directory": folder_path
		}
	return juego_info
