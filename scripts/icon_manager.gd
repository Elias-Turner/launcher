class_name IconManager
extends RefCounted

## IconManager: Administrador de iconos de videojuegos para el launcher.
##
## NOTA TÉCNICA SOBRE GODOT Y ARCHIVOS .EXE DE WINDOWS:
## Godot Engine 4 (GDScript nativo) no incluye un decodificador de recursos binarios PE
## (Portable Executable) para extraer la sección de recursos .rsrc/.ico embebida dentro de
## binarios compilados de Windows sin requerir bibliotecas nativas de C++ o herramientas externas.
##
## Conforme a la especificación del proyecto, este módulo implementa la estrategia oficial:
## 1. Icono configurado explícitamente en launcher_config.json.
## 2. Icono convencional en la carpeta del juego (launcher_icon.png, icon.png, etc.).
## 3. Icono en subcarpetas de recursos del juego (recursos/, assets/).
## 4. Icono temático predeterminado oficial del launcher (SVG vectorial celeste y dorado).

const CONVENTIONAL_ICON_NAMES: Array[String] = [
	"launcher_icon.png",
	"launcher_icon.jpg",
	"launcher_icon.webp",
	"icon.png",
	"icon.jpg",
	"icon.webp",
	"icono.png",
	"icono.jpg",
	"logo.png",
	"cover.png"
]

const SUBDIRECTORY_ICON_PATHS: Array[String] = [
	"recursos/launcher_icon.png",
	"recursos/icon.png",
	"recursos/icono.png",
	"assets/launcher_icon.png",
	"assets/icon.png",
	"assets/logo.png"
]

const DEFAULT_ICON_PATH: String = "res://assets/icons/default_game_icon.svg"

# Caché de texturas para evitar relecturas innecesarias de disco
static var _texture_cache: Dictionary = {}
static var _default_icon_texture: Texture2D = null

## Obtiene la textura del icono para una tarjeta de juego según la jerarquía de prioridad
static func get_game_icon(game_info: Dictionary) -> Texture2D:
	var folder_path: String = game_info.get("folder_path", "")
	var explicit_icon: String = game_info.get("explicit_icon", "")

	# 1. Icono explícito configurado
	if not explicit_icon.is_empty():
		var explicit_full_path = explicit_icon
		if not explicit_icon.is_absolute_path() and not folder_path.is_empty():
			explicit_full_path = folder_path.path_join(explicit_icon).replace("\\", "/")
		
		var explicit_tex = _load_image_from_disk(explicit_full_path)
		if explicit_tex:
			return explicit_tex

	# 2. Búsqueda de archivo convencional directamente en la carpeta del juego
	if not folder_path.is_empty():
		for icon_name in CONVENTIONAL_ICON_NAMES:
			var candidate_path = folder_path.path_join(icon_name).replace("\\", "/")
			if FileAccess.file_exists(candidate_path):
				var tex = _load_image_from_disk(candidate_path)
				if tex:
					return tex

		# 3. Búsqueda en subcarpetas de recursos
		for sub_path in SUBDIRECTORY_ICON_PATHS:
			var candidate_sub_path = folder_path.path_join(sub_path).replace("\\", "/")
			if FileAccess.file_exists(candidate_sub_path):
				var tex = _load_image_from_disk(candidate_sub_path)
				if tex:
					return tex

	# 4. Icono predeterminado de reserva (Joystick temático argentino)
	return get_default_icon()

## Carga el icono vectorial predeterminado con soporte de caché y fallback procedural
static func get_default_icon() -> Texture2D:
	if _default_icon_texture != null:
		return _default_icon_texture

	# 1. Intentar cargar si el recurso ya está importado
	if ResourceLoader.exists(DEFAULT_ICON_PATH):
		_default_icon_texture = load(DEFAULT_ICON_PATH)
		if _default_icon_texture != null:
			return _default_icon_texture

	# 2. Cargar directamente desde el archivo en disco
	var global_svg_path = ProjectSettings.globalize_path(DEFAULT_ICON_PATH)
	if FileAccess.file_exists(global_svg_path):
		var img = Image.load_from_file(global_svg_path)
		if img != null and not img.is_empty():
			_default_icon_texture = ImageTexture.create_from_image(img)
			return _default_icon_texture

	# 3. Generar icono temático procedural (96x96 celeste y dorado)
	_default_icon_texture = _generate_procedural_icon()
	return _default_icon_texture

## Genera un icono procedural argentino garantizado de 96x96 píxeles
static func _generate_procedural_icon() -> Texture2D:
	var img = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var color_celeste = Color("#75AADB")
	var color_blanco = Color("#FFFFFF")
	var color_dorado = Color("#F6B40E")
	var color_azul = Color("#1C3B57")
	
	# Franjas bandera argentina
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

## Carga un archivo de imagen (PNG, JPG, WebP) desde una ruta del sistema de archivos
static func _load_image_from_disk(file_path: String) -> Texture2D:
	var normalized_path = file_path.replace("\\", "/")

	# Verificar si ya está en caché
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

## Limpia la caché de iconos en caso de refresco de la biblioteca
static func clear_cache() -> void:
	_texture_cache.clear()
