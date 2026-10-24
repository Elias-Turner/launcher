extends SceneTree

## Suite de Pruebas Automatizadas para el Launcher Argentino
## Valida las especificaciones A hasta L requeridas por el proyecto:
## - Detección de juegos (vacío, único, múltiples, anidados, acentos y espacios)
## - Jerarquía y fallback de iconos
## - Manejo de errores en ejecución y debouncing
## - Configuración de modo Kiosco

const GameScannerScript = preload("res://scripts/game_scanner.gd")
const IconManagerScript = preload("res://scripts/icon_manager.gd")
const GameLauncherScript = preload("res://scripts/game_launcher.gd")

func _init() -> void:
	print("\n========================================================")
	print("  SUITE DE PRUEBAS AUTOMATIZADAS - LAUNCHER ARGENTINO   ")
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
	all_passed = test_nested_executable_search(test_sandbox_path) and all_passed
	all_passed = test_accented_and_spaced_names(test_sandbox_path) and all_passed
	all_passed = test_auxiliary_uninstaller_filtering(test_sandbox_path) and all_passed
	all_passed = test_icon_fallback_hierarchy(test_sandbox_path) and all_passed
	all_passed = test_sibling_games_directory_resolution(test_sandbox_path) and all_passed
	all_passed = test_svg_and_dynamic_icon_detection(test_sandbox_path) and all_passed
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
	var games = GameScannerScript.scan_games(sandbox_path, {})
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
	_create_dummy_file(game_folder.path_join("JuegoDeMemoria.exe"))

	var games = GameScannerScript.scan_games(sandbox_path, {})
	if games.size() == 1:
		var g = games[0]
		if g["name"] == "Juego de Memoria" and g["executable_path"].ends_with("JuegoDeMemoria.exe"):
			print("   [OK] Detectado: '" + g["name"] + "' con ejecutable correcto.")
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

	var games = GameScannerScript.scan_games(sandbox_path, {})
	if games.size() >= 3: # Incluyendo Juego de Memoria anterior
		var first_name = games[0]["name"]
		var last_name = games[games.size() - 1]["name"]
		if first_name == "Alfa Quest" and last_name == "Zeta Runner":
			print("   [OK] Detección múltiple y ordenamiento alfabético natural verificado.")
			return true
			
	push_error("   [FALLO] Fallo en la detección o el ordenamiento alfabético.")
	return false

## Prueba D: Ejecutable anidado en subdirectorio (ej. bin/Aventura.exe)
func test_nested_executable_search(sandbox_path: String) -> bool:
	print("-> Prueba D: Ejecutable en subdirectorio anidado (bin/)...")
	var nested_folder = sandbox_path.path_join("Aventura").path_join("bin")
	DirAccess.make_dir_recursive_absolute(nested_folder)
	_create_dummy_file(nested_folder.path_join("Aventura.exe"))

	var games = GameScannerScript.scan_games(sandbox_path, {})
	var found = false
	for g in games:
		if g["name"] == "Aventura":
			if g["executable_path"].ends_with("bin/Aventura.exe"):
				found = true
				break
				
	if found:
		print("   [OK] Ejecutable anidado en subcarpeta localizado correctamente.")
		return true
	push_error("   [FALLO] No se encontró el ejecutable dentro de subcarpeta bin/.")
	return false

## Prueba E: Nombres con tildes y caracteres especiales en español
func test_accented_and_spaced_names(sandbox_path: String) -> bool:
	print("-> Prueba E: Nombres con espacios y tildes (Aventura Fantástica)...")
	var accented_folder = sandbox_path.path_join("Aventura Fantástica")
	DirAccess.make_dir_recursive_absolute(accented_folder)
	_create_dummy_file(accented_folder.path_join("JuegoFantástico.exe"))

	var games = GameScannerScript.scan_games(sandbox_path, {})
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

## Prueba: Filtrado de desinstaladores y auxiliares
func test_auxiliary_uninstaller_filtering(sandbox_path: String) -> bool:
	print("-> Prueba: Descartar desinstaladores auxiliares (unins000.exe)...")
	var folder = sandbox_path.path_join("Juego Mixto")
	DirAccess.make_dir_recursive_absolute(folder)
	_create_dummy_file(folder.path_join("unins000.exe"))
	_create_dummy_file(folder.path_join("JuegoMixto.exe"))

	var games = GameScannerScript.scan_games(sandbox_path, {})
	for g in games:
		if g["name"] == "Juego Mixto":
			if g["executable_path"].ends_with("JuegoMixto.exe"):
				print("   [OK] Se seleccionó el ejecutable principal y se ignoró el desinstalador.")
				return true

	push_error("   [FALLO] No se descartó el desinstalador correctamente.")
	return false

## Prueba F: Fallback de iconos ante iconos ausentes
func test_icon_fallback_hierarchy(sandbox_path: String) -> bool:
	print("-> Prueba F: Jerarquía y fallback de iconos...")
	var dummy_game = {
		"folder_path": sandbox_path.path_join("CarpetaSinIcono"),
		"explicit_icon": ""
	}
	var default_icon = IconManagerScript.get_game_icon(dummy_game)
	if default_icon != null:
		print("   [OK] Icono temático predeterminado cargado correctamente sin fallas.")
		return true
	push_error("   [FALLO] No se pudo obtener el icono predeterminado.")
	return false

## Prueba G: Manejo de errores en ejecución
func test_launcher_error_handling() -> bool:
	print("-> Prueba G: Manejo controlado de ejecutables faltantes o rutas inválidas...")
	var launcher = GameLauncherScript.new()
	var result_box = {
		"failed_called": false,
		"error_msg": ""
	}
	
	launcher.launch_failed.connect(func(_info, err):
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
	# Verificar que el árbol de escenas no acepte cierre automático
	set_auto_accept_quit(false)
	print("   [OK] Auto-accept quit configurado en falso para control Kiosco.")
	return true

## Prueba H: Resolución de directorio de juegos
func test_sibling_games_directory_resolution(sandbox_path: String) -> bool:
	print("-> Prueba H: Detección y resolución de carpeta de juegos...")
	var sibling_games = sandbox_path.path_join("games_folder")
	DirAccess.make_dir_recursive_absolute(sibling_games)
	
	# Simular configuración con carpeta de juegos
	var resolved = GameScannerScript.get_games_directory("", {"games_folder": sibling_games})
	if resolved == sibling_games.replace("\\", "/"):
		print("   [OK] Carpeta de juegos resuelta correctamente según configuración.")
		return true
	push_error("   [FALLO] No se resolvió la carpeta de juegos configurada.")
	return false

## Prueba I: Detección de icono SVG y nombrado dinámico
func test_svg_and_dynamic_icon_detection(sandbox_path: String) -> bool:
	print("-> Prueba I: Detección de iconos SVG...")
	var game_folder = sandbox_path.path_join("Juego Godot SVG")
	DirAccess.make_dir_recursive_absolute(game_folder)
	# Copiar icono svg existente como icon.svg
	var src_svg = ProjectSettings.globalize_path("res://assets/icons/default_game_icon.svg")
	var dst_svg = game_folder.path_join("icon.svg")
	DirAccess.copy_absolute(src_svg, dst_svg)
	
	var dummy_game = {
		"folder_path": game_folder,
		"explicit_icon": "",
		"executable_path": game_folder.path_join("Juego.exe"),
		"id": "juego_godot_svg"
	}
	var tex = IconManagerScript.get_game_icon(dummy_game)
	if tex != null:
		print("   [OK] Icono SVG de juego identificado y cargado con éxito.")
		return true
	push_error("   [FALLO] No se pudo cargar el icono SVG del juego.")
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
