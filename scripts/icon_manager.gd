class_name IconManager
extends RefCounted

## IconManager: Administrador avanzado de iconos de videojuegos para el launcher.
##
## ESTRATEGIA INTEGRAL DE IDENTIFICACIÓN DE ICONOS:
## 1. Icono configurado explícitamente en launcher_config.json ("icon").
## 2. Iconos convencionales en la carpeta raíz del juego (PNG, SVG, WEBP, JPG, ICO).
## 3. Icono con el mismo nombre de la carpeta o del ejecutable (ej. "SopaDeLetras.png", "juego.svg").
## 4. Icono configurado en proyectos de Godot (leyendo config/icon de project.godot).
## 5. Búsqueda en subcarpetas habituales (assets/, recursos/, img/, etc.).
## 6. Extracción directa del icono embebido dentro del ejecutable (.exe de Windows) mediante System.Drawing.
## 7. Icono temático predeterminado oficial del launcher (SVG vectorial celeste y dorado).

const CONVENTIONAL_ICON_NAMES: Array[String] = [
	"launcher_icon.png",
	"launcher_icon.svg",
	"launcher_icon.webp",
	"launcher_icon.jpg",
	"icon.png",
	"icon.svg",
	"icon.webp",
	"icon.jpg",
	"icon.ico",
	"icono.png",
	"icono.svg",
	"icono.webp",
	"icono.jpg",
	"icono.ico",
	"logo.png",
	"logo.svg",
	"cover.png",
	"cover.jpg",
	"banner.png"
]

const SUBDIRECTORY_ICON_PATHS: Array[String] = [
	"recursos/launcher_icon.png",
	"recursos/icon.png",
	"recursos/icon.svg",
	"recursos/icono.png",
	"assets/launcher_icon.png",
	"assets/icon.png",
	"assets/icon.svg",
	"assets/logo.png",
	"icons/icon.png",
	"icons/icon.ico",
	"img/icon.png",
	"img/logo.png"
]

const DEFAULT_ICON_PATH: String = "res://assets/icons/default_game_icon.svg"

# Caché de texturas en memoria para optimizar rendimiento y evitar lecturas repetidas de disco
static var _texture_cache: Dictionary = {}
static var _default_icon_texture: Texture2D = null

## Obtiene la textura del icono para una tarjeta de juego según la jerarquía de prioridad
static func get_game_icon(game_info: Dictionary) -> Texture2D:
	var folder_path: String = game_info.get("folder_path", "").replace("\\", "/")
	var explicit_icon: String = game_info.get("explicit_icon", "").strip_edges()
	var exe_path: String = game_info.get("executable_path", "").replace("\\", "/")
	var game_id: String = game_info.get("id", folder_path.get_file().to_lower().validate_node_name())

	# 1. Icono explícito configurado
	if not explicit_icon.is_empty():
		var explicit_full_path = explicit_icon
		if not explicit_icon.is_absolute_path() and not folder_path.is_empty():
			explicit_full_path = folder_path.path_join(explicit_icon).replace("\\", "/")
		
		var explicit_tex = _load_image_from_disk_or_ico(explicit_full_path, game_id)
		if explicit_tex:
			return explicit_tex

	# 2. Búsqueda de archivo convencional directamente en la carpeta del juego
	if not folder_path.is_empty() and DirAccess.dir_exists_absolute(folder_path):
		for icon_name in CONVENTIONAL_ICON_NAMES:
			var candidate_path = folder_path.path_join(icon_name).replace("\\", "/")
			if FileAccess.file_exists(candidate_path):
				var tex = _load_image_from_disk_or_ico(candidate_path, game_id)
				if tex:
					return tex

		# 3. Búsqueda con el nombre de la carpeta o del ejecutable (ej. MiJuego.png, Juego.svg)
		var folder_name = folder_path.get_file() + "_caratula"
		var exe_base = exe_path.get_file().get_basename()
		var dynamic_names = [folder_name, exe_base, folder_name.to_lower(), exe_base.to_lower()]
		for base_name in dynamic_names:
			if base_name.is_empty():
				continue
			for ext in [".png", ".svg", ".webp", ".jpg", ".ico"]:
				var candidate_path = folder_path.path_join(base_name + ext).replace("\\", "/")
				if FileAccess.file_exists(candidate_path):
					var tex = _load_image_from_disk_or_ico(candidate_path, game_id)
					if tex:
						return tex

		# 4. Detección de icono en proyectos Godot (project.godot)
		var godot_icon = _detect_godot_project_icon(folder_path, game_id)
		if godot_icon:
			return godot_icon

		# 5. Búsqueda en subcarpetas de recursos
		for sub_path in SUBDIRECTORY_ICON_PATHS:
			var candidate_sub_path = folder_path.path_join(sub_path).replace("\\", "/")
			if FileAccess.file_exists(candidate_sub_path):
				var tex = _load_image_from_disk_or_ico(candidate_sub_path, game_id)
				if tex:
					return tex

	# 6. Extracción directa del icono embebido dentro del .exe en Windows
	if not exe_path.is_empty() and exe_path.get_extension().to_lower() == "exe":
		if FileAccess.file_exists(exe_path):
			var exe_icon = _extract_exe_icon(exe_path, game_id)
			if exe_icon:
				return exe_icon

	# 7. Icono predeterminado de reserva (Joystick temático argentino)
	return get_default_icon()

## Detecta el icono configurado en project.godot si la carpeta es un proyecto o paquete Godot
static func _detect_godot_project_icon(folder_path: String, game_id: String) -> Texture2D:
	var project_file = folder_path.path_join("project.godot").replace("\\", "/")
	if not FileAccess.file_exists(project_file):
		return null

	var f = FileAccess.open(project_file, FileAccess.READ)
	if not f:
		return null

	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line.begins_with("config/icon="):
			var parts = line.split("=", true, 1)
			if parts.size() == 2:
				var raw_icon_path = parts[1].strip_edges().replace("\"", "")
				if raw_icon_path.begins_with("res://"):
					var relative_path = raw_icon_path.substr(6)
					var icon_path = folder_path.path_join(relative_path).replace("\\", "/")
					if FileAccess.file_exists(icon_path):
						f.close()
						return _load_image_from_disk_or_ico(icon_path, game_id)
	f.close()
	return null

## Extrae el icono nativo embebido en el binario ejecutable (.exe de Windows)
## y lo almacena en la caché de usuario (user://icon_cache/) para carga instantánea
static func _extract_exe_icon(exe_path: String, game_id: String) -> Texture2D:
	if not OS.has_feature("windows"):
		return null

	var cache_dir = ProjectSettings.globalize_path("user://icon_cache").replace("/", "\\")
	if not DirAccess.dir_exists_absolute(cache_dir):
		DirAccess.make_dir_recursive_absolute(cache_dir)

	var cached_png = cache_dir + "\\" + game_id + ".png"
	var global_exe = ProjectSettings.globalize_path(exe_path).replace("/", "\\")

	# Si ya existe en caché, cargarlo directamente
	if FileAccess.file_exists(cached_png):
		return _load_image_from_disk(cached_png)

	# Si no existe, invocar extracción de System.Drawing de forma silenciosa
	var ps_cmd = "Add-Type -AssemblyName System.Drawing; try { [System.Drawing.Icon]::ExtractAssociatedIcon('" + global_exe + "').ToBitmap().Save('" + cached_png + "', [System.Drawing.Imaging.ImageFormat]::Png) } catch {}"
	var output = []
	OS.execute("powershell", PackedStringArray(["-NoProfile", "-NonInteractive", "-Command", ps_cmd]), output, false, false)

	if FileAccess.file_exists(cached_png):
		return _load_image_from_disk(cached_png)

	return null

## Convierte un archivo .ico a .png mediante Windows System.Drawing y lo carga en Godot
static func _convert_ico_to_png(ico_path: String, game_id: String) -> Texture2D:
	if not OS.has_feature("windows"):
		return null

	var cache_dir = ProjectSettings.globalize_path("user://icon_cache").replace("/", "\\")
	if not DirAccess.dir_exists_absolute(cache_dir):
		DirAccess.make_dir_recursive_absolute(cache_dir)

	var cached_png = cache_dir + "\\" + game_id + "_from_ico.png"
	var global_ico = ProjectSettings.globalize_path(ico_path).replace("/", "\\")

	if FileAccess.file_exists(cached_png):
		return _load_image_from_disk(cached_png)

	var ps_cmd = "Add-Type -AssemblyName System.Drawing; try { ([System.Drawing.Icon]::new('" + global_ico + "')).ToBitmap().Save('" + cached_png + "', [System.Drawing.Imaging.ImageFormat]::Png) } catch {}"
	var output = []
	OS.execute("powershell", PackedStringArray(["-NoProfile", "-NonInteractive", "-Command", ps_cmd]), output, false, false)

	if FileAccess.file_exists(cached_png):
		return _load_image_from_disk(cached_png)

	return null

## Carga imagen con soporte para formatos nativos de Godot (PNG, JPG, WebP, SVG) o conversión de .ico
static func _load_image_from_disk_or_ico(file_path: String, game_id: String) -> Texture2D:
	var normalized_path = file_path.replace("\\", "/")
	var ext = normalized_path.get_extension().to_lower()

	if ext == "ico":
		return _convert_ico_to_png(normalized_path, game_id)
	
	return _load_image_from_disk(normalized_path)

## Carga el icono vectorial predeterminado con soporte de caché y fallback procedural
static func get_default_icon() -> Texture2D:
	if _default_icon_texture != null:
		return _default_icon_texture

	if ResourceLoader.exists(DEFAULT_ICON_PATH):
		_default_icon_texture = load(DEFAULT_ICON_PATH)
		if _default_icon_texture != null:
			return _default_icon_texture

	var global_svg_path = ProjectSettings.globalize_path(DEFAULT_ICON_PATH)
	if FileAccess.file_exists(global_svg_path):
		var img = Image.load_from_file(global_svg_path)
		if img != null and not img.is_empty():
			_default_icon_texture = ImageTexture.create_from_image(img)
			return _default_icon_texture

	_default_icon_texture = _generate_procedural_icon()
	return _default_icon_texture

## Genera un icono procedural argentino garantizado de 96x96 píxeles
static func _generate_procedural_icon() -> Texture2D:
	var img = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var color_celeste = Color("#75AADB")
	var color_blanco = Color("#FFFFFF")
	var color_dorado = Color("#F6B40E")
	var color_azul = Color("#1C3B57")
	
	for y in range(96):
		var row_color = color_celeste
		if y >= 32 and y < 64:
			row_color = color_blanco
		for x in range(96):
			var dist_center = Vector2(x - 48, y - 48).length()
			if dist_center < 44.0:
				if dist_center >= 40.0:
					img.set_pixel(x, y, color_dorado)
				elif dist_center < 16.0:
					img.set_pixel(x, y, color_dorado)
				elif dist_center < 18.0:
					img.set_pixel(x, y, color_azul)
				else:
					img.set_pixel(x, y, row_color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(img)

## Carga un archivo de imagen desde disco con almacenamiento en caché en memoria
static func _load_image_from_disk(file_path: String) -> Texture2D:
	var normalized_path = file_path.replace("\\", "/")

	if _texture_cache.has(normalized_path):
		return _texture_cache[normalized_path]

	if not FileAccess.file_exists(normalized_path):
		return null

	var image = Image.load_from_file(normalized_path)
	if image != null and not image.is_empty():
		var texture = ImageTexture.create_from_image(image)
		_texture_cache[normalized_path] = texture
		return texture

	return null

## Limpia la caché de iconos en caso de refresco manual de la biblioteca
static func clear_cache() -> void:
	_texture_cache.clear()
