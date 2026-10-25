class_name GameScanner
extends RefCounted

## GameScanner: Responsable de explorar el sistema de archivos de Windows
## y detectar automáticamente las carpetas de videojuegos y sus ejecutables (.exe).

# Lista de nombres de carpetas que deben ser ignoradas siempre (en minúsculas)
const IGNORED_DIRECTORIES: Array[String] = [
	".godot",
	".git",
	".import",
	"launcher_argentino_data",
	"godotgamedata",
	"system volume information",
	"$recycle.bin",
	"assets",
	"scenes",
	"scripts",
	"logs"
]

# Palabras clave en ejecutables que corresponden a instaladores, desinstaladores o utilidades
const AUXILIARY_EXE_KEYWORDS: Array[String] = [
	"unins",
	"uninstall",
	"crash",
	"unitycrash",
	"setup",
	"installer",
	"install",
	"update",
	"updater",
	"patch",
	"dxsetup",
	"vcredist",
	"dotnet",
	"config",
	"settings",
	"helper"
]

const MAX_SEARCH_DEPTH: int = 3

## Normaliza separadores de ruta y simplifica segmentos relativos
static func _clean_path(path: String) -> String:
	return path.simplify_path().replace("\\", "/")

## Obtiene el directorio base dinámicamente según el entorno (Editor vs Exportado)
static func get_base_directory() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://")
	return OS.get_executable_path().get_base_dir()

## Obtiene la ruta de la carpeta donde se ubican los juegos.
## Prioridad de resolución:
## 1. custom_path (parámetro explícito para pruebas y sandbox)
## 2. launcher_config.json -> clave "games_folder" o "games_directory"
## 3. Carpetas hermanas al mismo nivel del launcher (../games, ../juegos, ../Games, ../Juegos)
## 4. Subcarpetas internas (games, juegos)
## 5. Valor predeterminado: ../games
static func get_games_directory(custom_path: String = "", config_overrides: Dictionary = {}) -> String:
	if not custom_path.is_empty():
		return _clean_path(custom_path)

	var base_dir = get_base_directory()

	# 1. Configuración explícita en launcher_config.json
	# var config_folder = config_overrides.get("games_folder", config_overrides.get("games_directory", ""))
	# if not config_folder.is_empty():
		# var path = config_folder if config_folder.is_absolute_path() else base_dir.path_join(config_folder)
		# var cleaned = _clean_path(path)
		# if DirAccess.dir_exists_absolute(cleaned):
			# return cleaned

	# 2. Búsqueda automática en carpetas hermanas e internas comunes
	# var candidate_names = ["../games", "../juegos", "../Games", "../Juegos", "games", "juegos"]
	# for candidate in candidate_names:
		# var candidate_path = _clean_path(base_dir.path_join(candidate))
		 #if DirAccess.dir_exists_absolute(candidate_path):
			# return candidate_path

	# 3. Predeterminado si aún no existe
	return _clean_path(base_dir.path_join("../Juegos"))

## Escanea el directorio de juegos buscando las sub-carpetas de cada juego
static func scan_games(custom_base_path: String = "", config_overrides: Dictionary = {}) -> Array[Dictionary]:
	var target_dir = get_games_directory(custom_base_path, config_overrides)
	var games: Array[Dictionary] = []
	var launcher_exe = OS.get_executable_path().replace("\\", "/").to_lower()
	var games_map = config_overrides.get("games", config_overrides)

	# Crear carpeta destino si no existe
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)

	# Escaneo directo de subdirectorios usando la API nativa de Godot 4
	for folder_name in DirAccess.get_directories_at(target_dir):
		if folder_name.begins_with(".") or folder_name.to_lower() in IGNORED_DIRECTORIES:
			continue

		var folder_override = games_map.get(folder_name, {})
		if folder_override.get("exclude", false):
			continue

		var full_path = _clean_path(target_dir.path_join(folder_name))
		var game_entry = _process_game_folder(folder_name, full_path, launcher_exe, folder_override)
		if not game_entry.is_empty():
			games.append(game_entry)

	# Ordenar los juegos alfabéticamente por su nombre visible (insensible a mayúsculas)
	games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["name"].naturalnocasecmp_to(b["name"]) < 0
	)

	return games

## Procesa una carpeta candidata para encontrar el ejecutable principal y registrar el juego
static func _process_game_folder(folder_name: String, folder_path: String, launcher_exe_path: String, folder_override: Dictionary) -> Dictionary:
	# 1. Si la configuración define un ejecutable explícito, verificarlo primero
	var custom_exe = folder_override.get("executable", "")
	if not custom_exe.is_empty():
		var explicit_path = _clean_path(folder_path.path_join(custom_exe))
		if FileAccess.file_exists(explicit_path):
			return _build_game_dict(folder_name, folder_path, explicit_path, folder_override)

	# 2. Buscar recursivamente todos los archivos .exe dentro de la carpeta (hasta MAX_SEARCH_DEPTH)
	var found_exes: Array[String] = []
	_find_executables_recursive(folder_path, 0, found_exes, launcher_exe_path)
	if found_exes.is_empty():
		return {}

	# 3. Filtrar ejecutables auxiliares (desinstaladores, utilidades, crash handlers)
	var valid_exes: Array[String] = []
	for exe in found_exes:
		var file_base = exe.get_file().get_basename().to_lower()
		var is_auxiliary = AUXILIARY_EXE_KEYWORDS.any(func(kw): return kw in file_base)
		if not is_auxiliary:
			valid_exes.append(exe)

	var candidate_list = valid_exes if not valid_exes.is_empty() else found_exes
	var chosen_exe = _select_primary_executable(folder_name, folder_path, candidate_list)
	if chosen_exe.is_empty():
		return {}

	return _build_game_dict(folder_name, folder_path, chosen_exe, folder_override)

## Busca archivos .exe de forma recursiva con límite de profundidad seguro
static func _find_executables_recursive(current_path: String, depth: int, out_exes: Array[String], launcher_exe_path: String) -> void:
	if depth > MAX_SEARCH_DEPTH or not DirAccess.dir_exists_absolute(current_path):
		return

	# Buscar archivos .exe en el directorio actual
	for file_name in DirAccess.get_files_at(current_path):
		if file_name.get_extension().to_lower() == "exe":
			var full_exe_path = _clean_path(current_path.path_join(file_name))
			if full_exe_path.to_lower() != launcher_exe_path:
				out_exes.append(full_exe_path)

	# Explorar subdirectorios válidos recursivamente
	for sub_folder in DirAccess.get_directories_at(current_path):
		if not sub_folder.begins_with(".") and not sub_folder.to_lower() in IGNORED_DIRECTORIES:
			var sub_path = _clean_path(current_path.path_join(sub_folder))
			_find_executables_recursive(sub_path, depth + 1, out_exes, launcher_exe_path)

## Selecciona el ejecutable principal mediante regla determinista
static func _select_primary_executable(folder_name: String, folder_path: String, exes: Array[String]) -> String:
	if exes.is_empty():
		return ""
	else:
		return exes[0]

	# var clean_folder = folder_name.replace(" ", "").replace("_", "").replace("-", "").to_lower()

	# Prioridad 1: Coincidencia de nombre entre el .exe y la carpeta del juego
	# for exe in exes:
	# 	var base_exe = exe.get_file().get_basename().replace(" ", "").replace("_", "").replace("-", "").to_lower()
	# 	if base_exe == clean_folder:
	# 		return exe

	# Prioridad 2: Ejecutable situado directamente en la raíz de la carpeta del juego
	# for exe in exes:
	# 	if exe.get_base_dir() == folder_path:
	# 		return exe

	# Prioridad 3: Ejecutable con la ruta relativa más corta (menor profundidad de anidamiento)
	# var best_exe = exes[0]
	# var min_slashes = best_exe.count("/")
	# for i in range(1, exes.size()):
	# 	var slashes = exes[i].count("/")
	# 	if slashes < min_slashes:
	#		min_slashes = slashes
	# 		best_exe = exes[i]

	# return best_exe

## Construye el diccionario estructurado para el catálogo del launcher
static func _build_game_dict(folder_name: String, folder_path: String, exe_path: String, folder_override: Dictionary) -> Dictionary:
	return {
		"id": folder_name.to_lower().validate_node_name(),
		"name": folder_override.get("display_name", folder_name),
		"folder_name": folder_name,
		"folder_path": folder_path,
		"executable_path": exe_path,
		"working_directory": folder_override.get("working_directory", exe_path.get_base_dir()),
		"explicit_icon": folder_override.get("icon", "")
	}
