class_name IconManager
extends RefCounted

## IconManager: Gestor simplificado de carátulas para el Lanzador.
##
## ESTRATEGIA:
## 1. Busca en la carpeta del juego cualquier imagen que termine en '_caratula'
##    (ej. 'Trivia_caratula.png', 'Juego_caratula.jpg') o que se llame simplemente 'caratula.<ext>'.
## 2. Si no encuentra ninguna carátula, carga el icono temático predeterminado.

const VALID_IMAGE_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]
const DEFAULT_ICON_PATH: String = "res://assets/icons/default_game_icon.svg"

# Caché de texturas en memoria para optimizar rendimiento y evitar lecturas repetidas de disco
static var _texture_cache: Dictionary = {}
static var _default_icon_texture: Texture2D = null

## Obtiene la textura de la carátula para una tarjeta de juego
static func get_game_icon(game_info: Dictionary) -> Texture2D:
	var folder_path: String = game_info.get("folder_path", "").replace("\\", "/")

	if not folder_path.is_empty() and DirAccess.dir_exists_absolute(folder_path):
		for file_name in DirAccess.get_files_at(folder_path):
			var ext = file_name.get_extension().to_lower()
			if ext in VALID_IMAGE_EXTENSIONS:
				var base_name = file_name.get_basename().to_lower()
				if base_name.ends_with("_caratula") or base_name == "caratula":
					var candidate = folder_path.path_join(file_name).replace("\\", "/")
					var textura = _load_image_from_disk(candidate)
					if textura:
						return textura

	# Si no se encontró carátula, devolver icono por defecto
	return get_default_icon()

## Carga el icono vectorial predeterminado con soporte de caché
static func get_default_icon() -> Texture2D:
	if _default_icon_texture != null:
		return _default_icon_texture

	if ResourceLoader.exists(DEFAULT_ICON_PATH):
		_default_icon_texture = load(DEFAULT_ICON_PATH)
		if _default_icon_texture != null:
			return _default_icon_texture

	var global_svg = ProjectSettings.globalize_path(DEFAULT_ICON_PATH)
	if FileAccess.file_exists(global_svg):
		var img = Image.load_from_file(global_svg)
		if img != null and not img.is_empty():
			_default_icon_texture = ImageTexture.create_from_image(img)
			return _default_icon_texture

	return null

## Carga un archivo de imagen desde disco con caché en memoria
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

## Limpia la memoria caché al recargar la biblioteca
static func clear_cache() -> void:
	_texture_cache.clear()
