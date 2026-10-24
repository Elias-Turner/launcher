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

## Obtiene el directorio base dinámicamente según el entorno (Editor vs Exportado)
static func get_base_directory() -> String:
	if OS.has_feature("editor"):
		# En el editor de Godot, usamos la raíz del proyecto
		return ProjectSettings.globalize_path("res://")
	else:
		# En la distribución exportada, la carpeta donde reside el Launcher.exe
		return OS.get_executable_path().get_base_dir()

## Obtiene el directorio donde residen las carpetas de los videojuegos.
## Por especificación, el launcher y la carpeta de los juegos deben estar al mismo nivel (carpetas hermanas).
## Prioridad de búsqueda:
## 1. custom_path (si se pasa explícitamente, ej. suite de pruebas)
## 2. launcher_config.json -> campo "games_folder" o "games_directory"
## 3. Carpeta hermana al mismo nivel que el launcher (../games, ../juegos, ../Games, ../Juegos)
## 4. Carpeta interna de compatibilidad (./games, ./juegos)
## 5. Directorio base del launcher como fallback
static func get_games_directory(custom_path: String = "", config_overrides: Dictionary = {}) -> String:
	if not custom_path.is_empty():
		return custom_path.simplify_path().replace("\\", "/")

	var base_dir = get_base_directory().replace("\\", "/")

	# 1. Configuración explícita en launcher_config.json
	var config_folder = config_overrides.get("games_folder", config_overrides.get("games_directory", ""))
	if not config_folder.is_empty():
		var explicit_path = config_folder
		if not config_folder.is_absolute_path():
			explicit_path = base_dir.path_join(config_folder)
		explicit_path = explicit_path.simplify_path().replace("\\", "/")
		if DirAccess.dir_exists_absolute(explicit_path):
			return explicit_path

	# 2. Carpeta hermana al mismo nivel que el launcher
	for sibling_name in ["../games", "../juegos", "../Games", "../Juegos"]:
		var sibling_path = base_dir.path_join(sibling_name).simplify_path().replace("\\", "/")
		if DirAccess.dir_exists_absolute(sibling_path):
			return sibling_path

	# 3. Carpeta interna como alternativa
	for internal_name in ["games", "juegos", "sample_games"]:
		var internal_path = base_dir.path_join(internal_name).simplify_path().replace("\\", "/")
		if DirAccess.dir_exists_absolute(internal_path):
			return internal_path

	# 4. Por defecto: retorna la carpeta hermana ../games (creándola si no existe)
	var default_sibling = base_dir.path_join("../games").simplify_path().replace("\\", "/")
	return default_sibling

## Escanea el directorio de juegos buscando las sub-carpetas de cada juego
static func scan_games(custom_base_path: String = "", config_overrides: Dictionary = {}) -> Array[Dictionary]:
	var target_dir_path = get_games_directory(custom_base_path, config_overrides)
	var games: Array[Dictionary] = []
	var launcher_exe_path = OS.get_executable_path().replace("\\", "/").to_lower()
	var games_map = config_overrides.get("games", config_overrides)

	# Si la carpeta hermana no existe aún, crearla automáticamente para facilidad del usuario
	if not DirAccess.dir_exists_absolute(target_dir_path):
		DirAccess.make_dir_recursive_absolute(target_dir_path)

	var dir = DirAccess.open(target_dir_path)
	if not dir:
		push_warning("GameScanner: No se pudo abrir el directorio de juegos: " + target_dir_path)
		return games

	dir.list_dir_begin()
	var item_name = dir.get_next()

	# Recorrer las sub-carpetas en el directorio de juegos (cada sub-carpeta es un juego)
	while not item_name.is_empty():
		if dir.current_is_dir() and not item_name.begins_with("."):
			var lower_name = item_name.to_lower()
			
			# Verificar si la carpeta está excluida por lista negra o por configuración
			if not lower_name in IGNORED_DIRECTORIES:
				var folder_override = games_map.get(item_name, {})
				var is_excluded = folder_override.get("exclude", false)
				
				if not is_excluded:
					var full_folder_path = target_dir_path.path_join(item_name).replace("\\", "/")
					var game_entry = _process_game_folder(item_name, full_folder_path, launcher_exe_path, folder_override)
					if not game_entry.is_empty():
						games.append(game_entry)

		item_name = dir.get_next()
	dir.list_dir_end()

	# Si no se encontraron juegos en la carpeta principal de juegos y estamos usando la ruta predeterminada,
	# verificar también si hay carpetas de juegos de prueba directamente en el entorno de desarrollo
	if games.is_empty() and custom_base_path.is_empty() and OS.has_feature("editor"):
		var base_dir = get_base_directory().replace("\\", "/")
		for test_subfolder in ["sample_games", "juegos", "games"]:
			var test_dir_path = base_dir.path_join(test_subfolder).replace("\\", "/")
			if DirAccess.dir_exists_absolute(test_dir_path) and test_dir_path != target_dir_path:
				var sub_dir = DirAccess.open(test_dir_path)
				if sub_dir:
					sub_dir.list_dir_begin()
					var sub_item = sub_dir.get_next()
					while not sub_item.is_empty():
						if sub_dir.current_is_dir() and not sub_item.begins_with("."):
							var full_sub_path = test_dir_path.path_join(sub_item).replace("\\", "/")
							var folder_override = games_map.get(sub_item, {})
							if not folder_override.get("exclude", false):
								var game_entry = _process_game_folder(sub_item, full_sub_path, launcher_exe_path, folder_override)
								if not game_entry.is_empty():
									var already_exists = false
									for g in games:
										if g["name"].to_lower() == game_entry["name"].to_lower():
											already_exists = true
											break
									if not already_exists:
										games.append(game_entry)
						sub_item = sub_dir.get_next()
					sub_dir.list_dir_end()

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
		var explicit_path = folder_path.path_join(custom_exe).replace("\\", "/")
		if FileAccess.file_exists(explicit_path):
			return _build_game_dict(folder_name, folder_path, explicit_path, folder_override)

	# 2. Buscar recursivamente todos los archivos .exe dentro de la carpeta (hasta MAX_SEARCH_DEPTH)
	var found_exes: Array[String] = []
	_find_executables_recursive(folder_path, 0, found_exes, launcher_exe_path)

	if found_exes.is_empty():
		# La carpeta no contiene ningún ejecutable; se ignora silenciosamente
		return {}

	# 3. Filtrar ejecutables auxiliares (desinstaladores, utilidades, crash handlers)
	var valid_exes: Array[String] = []
	for exe in found_exes:
		var file_name = exe.get_file().get_basename().to_lower()
		var is_auxiliary = false
		for keyword in AUXILIARY_EXE_KEYWORDS:
			if keyword in file_name:
				is_auxiliary = true
				break
		if not is_auxiliary:
			valid_exes.append(exe)

	# Si todos parecían auxiliares, no descartar por completo: usar la lista completa encontrada
	var candidate_list = valid_exes if not valid_exes.is_empty() else found_exes

	# 4. Seleccionar el ejecutable principal mediante regla determinista
	var chosen_exe = _select_primary_executable(folder_name, folder_path, candidate_list)
	if chosen_exe.is_empty():
		return {}

	return _build_game_dict(folder_name, folder_path, chosen_exe, folder_override)

## Busca archivos .exe de forma recursiva con límite de profundidad seguro
static func _find_executables_recursive(current_path: String, depth: int, out_exes: Array[String], launcher_exe_path: String) -> void:
	if depth > MAX_SEARCH_DEPTH:
		return

	var dir = DirAccess.open(current_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while not file_name.is_empty():
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				var sub_folder_lower = file_name.to_lower()
				if not sub_folder_lower in IGNORED_DIRECTORIES:
					var sub_path = current_path.path_join(file_name).replace("\\", "/")
					_find_executables_recursive(sub_path, depth + 1, out_exes, launcher_exe_path)
		else:
			if file_name.get_extension().to_lower() == "exe":
				var full_exe_path = current_path.path_join(file_name).replace("\\", "/")
				# Nunca registrar el propio launcher como juego
				if full_exe_path.to_lower() != launcher_exe_path:
					out_exes.append(full_exe_path)

		file_name = dir.get_next()
	dir.list_dir_end()

## Selecciona el ejecutable principal con regla determinista
static func _select_primary_executable(folder_name: String, folder_path: String, exes: Array[String]) -> String:
	if exes.is_empty():
		return ""
	if exes.size() == 1:
		return exes[0]

	var clean_folder = folder_name.replace(" ", "").replace("_", "").replace("-", "").to_lower()

	# Prioridad 1: Coincidencia de nombre entre el .exe y la carpeta del juego
	for exe in exes:
		var base_exe = exe.get_file().get_basename().replace(" ", "").replace("_", "").replace("-", "").to_lower()
		if base_exe == clean_folder:
			return exe

	# Prioridad 2: Ejecutable situado directamente en la raíz de la carpeta del juego
	for exe in exes:
		if exe.get_base_dir() == folder_path:
			return exe

	# Prioridad 3: Ejecutable con la ruta relativa más corta (menor profundidad de anidamiento)
	var best_exe = exes[0]
	var min_slashes = best_exe.count("/")
	for i in range(1, exes.size()):
		var slashes = exes[i].count("/")
		if slashes < min_slashes:
			min_slashes = slashes
			best_exe = exes[i]

	return best_exe

## Construye el diccionario estructurado para el catálogo del launcher
static func _build_game_dict(folder_name: String, folder_path: String, exe_path: String, folder_override: Dictionary) -> Dictionary:
	var visible_name = folder_override.get("display_name", folder_name)
	var working_dir = folder_override.get("working_directory", exe_path.get_base_dir())
	var explicit_icon = folder_override.get("icon", "")

	return {
		"id": folder_name.to_lower().validate_node_name(),
		"name": visible_name,
		"folder_name": folder_name,
		"folder_path": folder_path,
		"executable_path": exe_path,
		"working_directory": working_dir,
		"explicit_icon": explicit_icon
	}
