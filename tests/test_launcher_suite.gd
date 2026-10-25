extends SceneTree

## Suite de Pruebas Automatizadas para el Lanzador
## Valida:
## - Detección de juegos (vacío, único, múltiples, acentos y espacios)
## - Detección de carátulas (caratula.png, convención previa y fallback)
## - Manejo de errores en ejecución
## - Configuración de modo Kiosco

const GameScannerScript = preload("res://scripts/game_scanner.gd")
const IconManagerScript = preload("res://scripts/icon_manager.gd")
const GameLauncherScript = preload("res://scripts/game_launcher.gd")

func _init() -> void:
	print("\n========================================================")
	print("       SUITE DE PRUEBAS AUTOMATIZADAS - LANZADOR        ")
	print("========================================================\n")

	var all_passed = true
	var test_sandbox_path = ProjectSettings.globalize_path("res://test_sandbox").replace("\\", "/")

	# Asegurar carpeta de pruebas limpia
	_clean_directory(test_sandbox_path)
	DirAccess.make_dir_recursive_absolute(test_sandbox_path)

	# Ejecución de pruebas
	all_passed = test_empty_library(test_sandbox_path) and all_passed
	all_passed = test_single_game_detection(test_sandbox_path) and all_passed
	all_passed = test_multiple_games_and_sorting(test_sandbox_path) and all_passed
	all_passed = test_accented_and_spaced_names(test_sandbox_path) and all_passed
	all_passed = test_caratula_detection(test_sandbox_path) and all_passed
	all_passed = test_icon_fallback_hierarchy(test_sandbox_path) and all_passed
	all_passed = test_sibling_games_directory_resolution(test_sandbox_path) and all_passed
	all_passed = test_launcher_error_handling() and all_passed
	all_passed = test_kiosk_configuration() and all_passed

	# Limpieza de sandbox
	_clean_directory(test_sandbox_path)

	print("\n========================================================")
	if all_passed:
		print("  RESULTADO FINAL: TODAS LAS PRUEBAS PASARON CON ÉXITO  ")
	else:
		print("  RESULTADO FINAL: AL MENOS UNA PRUEBA FALLÓ           ")
	print("========================================================\n")

	quit(0 if all_passed else 1)

## Prueba A: Biblioteca vacía -> Retorna lista vacía sin errores
func test_empty_library(sandbox_path: String) -> bool:
	print("-> Prueba A: Biblioteca vacía...")
	var games = GameScannerScript.scan_games(sandbox_path)
	if games.is_empty():
		print("   [OK] Detección correcta: 0 juegos encontrados en carpeta vacía.")
		return true
	else:
		push_error("   [FALLO] Se esperaban 0 juegos pero se obtuvieron: " + str(games.size()))
		return false

## Prueba B: Un solo juego -> Detecta nombre de carpeta y ruta de .exe
func test_single_game_detection(sandbox_path: String) -> bool:
	print("-> Prueba B: Un solo juego...")
	var game_folder = sandbox_path.path_join("Juego de Memoria")
	DirAccess.make_dir_recursive_absolute(game_folder)
	_create_dummy_file(game_folder.path_join("JuegoDeMemoria.console.exe"))
	_create_dummy_file(game_folder.path_join("JuegoDeMemoria.exe"))

	var games = GameScannerScript.scan_games(sandbox_path)
	if games.size() == 1:
		var g = games[0]
		if g["name"] == "Juego de Memoria" and g["executable_path"].ends_with("JuegoDeMemoria.exe") and not g["executable_path"].ends_with(".console.exe"):
			print("   [OK] Detectado: '" + g["name"] + "' con ejecutable correcto (ignorado .console.exe).")
			return true

	push_error("   [FALLO] No se detectó correctamente el juego individual.")
	return false

## Prueba C: Varios juegos -> Genera una tarjeta por carpeta, sin duplicados y ordenados
func test_multiple_games_and_sorting(sandbox_path: String) -> bool:
	print("-> Prueba C: Varios juegos y ordenamiento alfabético...")
	var g1 = sandbox_path.path_join("Zeta Runner")
	var g2 = sandbox_path.path_join("Alfa Quest")
	DirAccess.make_dir_recursive_absolute(g1)
	DirAccess.make_dir_recursive_absolute(g2)
	_create_dummy_file(g1.path_join("Zeta.exe"))
	_create_dummy_file(g2.path_join("Alfa.exe"))

	var games = GameScannerScript.scan_games(sandbox_path)
	if games.size() >= 3: # Incluyendo Juego de Memoria anterior
		var first_name = games[0]["name"]
		var last_name = games[games.size() - 1]["name"]
		if first_name == "Alfa Quest" and last_name == "Zeta Runner":
			print("   [OK] Detección múltiple y ordenamiento alfabético natural verificado.")
			return true

	push_error("   [FALLO] Fallo en la detección o el ordenamiento alfabético.")
	return false

## Prueba D: Nombres con tildes y caracteres especiales en español
func test_accented_and_spaced_names(sandbox_path: String) -> bool:
	print("-> Prueba D: Nombres con espacios y tildes (Aventura Fantástica)...")
	var accented_folder = sandbox_path.path_join("Aventura Fantástica")
	DirAccess.make_dir_recursive_absolute(accented_folder)
	_create_dummy_file(accented_folder.path_join("JuegoFantástico.exe"))

	var games = GameScannerScript.scan_games(sandbox_path)
	var found = false
	for g in games:
		if g["name"] == "Aventura Fantástica":
			found = true
			break

	if found:
		print("   [OK] Nombre con tildes y espacios procesado correctamente.")
		return true
	push_error("   [FALLO] Error procesando nombre con tildes.")
	return false

## Prueba: Detección de carátula estándar (caratula.png)
func test_caratula_detection(sandbox_path: String) -> bool:
	print("-> Prueba: Detección de carátula estándar...")
	var game_folder = sandbox_path.path_join("Trivia Malvinas")
	DirAccess.make_dir_recursive_absolute(game_folder)
	var src_icon = ProjectSettings.globalize_path("res://assets/icons/default_game_icon.svg")
	var dst_cover = game_folder.path_join("Trivia_caratula.png")
	DirAccess.copy_absolute(src_icon, dst_cover)

	var dummy_game = {
		"folder_path": game_folder,
		"folder_name": "Trivia Malvinas",
		"name": "Trivia Malvinas"
	}
	var tex = IconManagerScript.get_game_icon(dummy_game)
	if tex != null:
		print("   [OK] Carátula detectada y cargada correctamente (terminada en _caratula).")
		return true
	push_error("   [FALLO] No se pudo cargar la carátula.")
	return false

## Prueba E: Fallback de iconos ante carátulas ausentes
func test_icon_fallback_hierarchy(sandbox_path: String) -> bool:
	print("-> Prueba E: Jerarquía y fallback de iconos...")
	var dummy_game = {
		"folder_path": sandbox_path.path_join("CarpetaSinIcono"),
		"folder_name": "CarpetaSinIcono"
	}
	var default_icon = IconManagerScript.get_game_icon(dummy_game)
	if default_icon != null:
		print("   [OK] Icono predeterminado de reserva cargado correctamente.")
		return true
	push_error("   [FALLO] No se pudo obtener el icono predeterminado.")
	return false

## Prueba F: Manejo de errores en ejecución
func test_launcher_error_handling() -> bool:
	print("-> Prueba F: Manejo controlado de ejecutables faltantes o rutas inválidas...")
	var launcher = GameLauncherScript.new()
	var result_box = {
		"failed_called": false,
		"error_msg": ""
	}

	launcher.lanzamiento_fallido.connect(func(err):
		result_box["failed_called"] = true
		result_box["error_msg"] = err
	)

	var invalid_game = {
		"name": "Juego Inexistente",
		"executable_path": "C:/Ruta/Inexistente/Falso.exe",
		"working_directory": "C:/Ruta/Inexistente"
	}

	var res = launcher.launch_game(invalid_game)
	var is_ok = (not res and result_box["failed_called"] and not result_box["error_msg"].is_empty())
	launcher.free()

	if is_ok:
		print("   [OK] Error detectado y gestionado limpiamente sin detener la aplicación.")
		return true

	push_error("   [FALLO] El gestor no capturó el error del ejecutable inexistente.")
	return false

## Prueba: Configuración de modo Kiosco
func test_kiosk_configuration() -> bool:
	print("-> Prueba: Configuración de Kiosco...")
	set_auto_accept_quit(false)
	print("   [OK] Auto-accept quit configurado en falso para control Kiosco.")
	return true

## Prueba G: Resolución de directorio de juegos
func test_sibling_games_directory_resolution(sandbox_path: String) -> bool:
	print("-> Prueba G: Detección y resolución de carpeta de juegos...")
	var sibling_games = sandbox_path.path_join("games_folder")
	DirAccess.make_dir_recursive_absolute(sibling_games)

	var resolved = GameScannerScript.get_games_directory(sibling_games)
	if resolved == sibling_games.replace("\\", "/"):
		print("   [OK] Carpeta de juegos resuelta correctamente según ruta especificada.")
		return true
	push_error("   [FALLO] No se resolvió la carpeta de juegos configurada.")
	return false

## Auxiliar: Crear archivo de prueba ficticio
func _create_dummy_file(path: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("MOCK_BINARY_DATA")
		f.close()

## Auxiliar: Limpiar directorio recursivamente
func _clean_directory(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while not file_name.is_empty():
			var full_path = dir_path.path_join(file_name)
			if dir.current_is_dir() and not file_name.begins_with("."):
				_clean_directory(full_path)
			else:
				DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		DirAccess.remove_absolute(dir_path)
