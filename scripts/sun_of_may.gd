@tool
class_name SunOfMay
extends Control

## Sol de Mayo representativo de la Bandera Argentina
## Dibuja proceduralmente el Sol de Mayo con sus 32 rayos alternados
## (16 rectos y 16 ondulados/flamígeros) y rasgos tradicionales serenos.

@export var radius: float = 80.0:
	set(val):
		radius = max(10.0, val)
		queue_redraw()

@export var primary_gold: Color = Color("#F6B40E") # Amarillo dorado principal
@export var highlight_gold: Color = Color("#FED156") # Brillo superior
@export var shadow_gold: Color = Color("#D49500") # Detalle de rasgos y sombras
@export var ray_length_factor: float = 0.55: # Longitud de los rayos relativa al radio
	set(val):
		ray_length_factor = val
		queue_redraw()

@export var draw_face: bool = true:
	set(val):
		draw_face = val
		queue_redraw()

@export var auto_rotate: bool = false
@export var rotation_speed: float = 0.05 # Radianes por segundo

var _current_angle: float = 0.0

func _process(delta: float) -> void:
	if auto_rotate:
		_current_angle += rotation_speed * delta
		queue_redraw()

func _draw() -> void:
	var center = size * 0.5
	var ray_outer_radius = radius * (1.0 + ray_length_factor)
	var ray_inner_radius = radius * 0.96
	
	# Dibujar los 32 rayos (16 rectos y 16 flamígeros alternados)
	var total_rays = 32
	var step_angle = TAU / float(total_rays)
	
	for i in range(total_rays):
		var ray_angle = _current_angle + i * step_angle
		var is_straight = (i % 2 == 0)
		
		if is_straight:
			_draw_straight_ray(center, ray_angle, ray_inner_radius, ray_outer_radius, step_angle * 0.45)
		else:
			_draw_flame_ray(center, ray_angle, ray_inner_radius, ray_outer_radius, step_angle * 0.5)

	# Disco central del Sol
	# Sombra suave exterior
	draw_circle(center, radius + 2.0, shadow_gold.lerp(primary_gold, 0.4))
	# Base dorada
	draw_circle(center, radius, primary_gold)
	# Gradiente interior simulado con círculos concéntricos de brillo
	draw_circle(center, radius * 0.82, highlight_gold)
	draw_circle(center, radius * 0.65, primary_gold.lerp(highlight_gold, 0.6))
	
	# Borde exterior del disco
	draw_arc(center, radius, 0.0, TAU, 64, shadow_gold, 2.5, true)

	# Rasgos del rostro (Ojos, cejas, nariz y boca serena)
	if draw_face:
		_draw_sun_face(center, radius)

func _draw_straight_ray(c: Vector2, angle: float, inner_r: float, outer_r: float, half_w: float) -> void:
	var tip = c + Vector2(cos(angle), sin(angle)) * outer_r
	var base_left = c + Vector2(cos(angle - half_w), sin(angle - half_w)) * inner_r
	var base_right = c + Vector2(cos(angle + half_w), sin(angle + half_w)) * inner_r
	
	var points = PackedVector2Array([tip, base_left, base_right])
	var colors = PackedColorArray([highlight_gold, primary_gold, shadow_gold])
	draw_polygon(points, colors)
	
	# Línea central de resalte en el rayo recto
	draw_line(c + Vector2(cos(angle), sin(angle)) * inner_r, tip, highlight_gold, 1.2, true)

func _draw_flame_ray(c: Vector2, angle: float, inner_r: float, outer_r: float, half_w: float) -> void:
	# Rayo ondulado/flamígero simétrico y elegante
	var tip = c + Vector2(cos(angle), sin(angle)) * (outer_r * 0.96)
	var base_left = c + Vector2(cos(angle - half_w), sin(angle - half_w)) * inner_r
	var base_right = c + Vector2(cos(angle + half_w), sin(angle + half_w)) * inner_r
	
	# Puntos intermedios con sutil curvatura flamígera
	var mid_r = inner_r * 0.55 + outer_r * 0.45
	var wave_offset = half_w * 0.45
	
	var mid_left = c + Vector2(cos(angle - half_w * 0.35 + wave_offset), sin(angle - half_w * 0.35 + wave_offset)) * mid_r
	var mid_right = c + Vector2(cos(angle + half_w * 0.35 + wave_offset), sin(angle + half_w * 0.35 + wave_offset)) * mid_r
	
	var polygon = PackedVector2Array([base_left, mid_left, tip, mid_right, base_right])
	draw_colored_polygon(polygon, primary_gold)
	draw_polyline(polygon, shadow_gold, 1.0, true)

func _draw_sun_face(c: Vector2, r: float) -> void:
	var eye_offset_x = r * 0.32
	var eye_y = c.y - r * 0.12
	var eye_r = r * 0.085
	
	# Cejas estilizadas
	var left_brow_start = Vector2(c.x - eye_offset_x - eye_r * 1.4, eye_y - eye_r * 1.8)
	var left_brow_mid = Vector2(c.x - eye_offset_x, eye_y - eye_r * 2.2)
	var left_brow_end = Vector2(c.x - eye_offset_x + eye_r * 1.4, eye_y - eye_r * 1.5)
	draw_polyline(PackedVector2Array([left_brow_start, left_brow_mid, left_brow_end]), shadow_gold, 2.0, true)
	
	var right_brow_start = Vector2(c.x + eye_offset_x - eye_r * 1.4, eye_y - eye_r * 1.5)
	var right_brow_mid = Vector2(c.x + eye_offset_x, eye_y - eye_r * 2.2)
	var right_brow_end = Vector2(c.x + eye_offset_x + eye_r * 1.4, eye_y - eye_r * 1.8)
	draw_polyline(PackedVector2Array([right_brow_start, right_brow_mid, right_brow_end]), shadow_gold, 2.0, true)
	
	# Ojos (almendrados)
	_draw_eye_ellipse(Vector2(c.x - eye_offset_x, eye_y), eye_r * 1.3, eye_r * 0.7, shadow_gold)
	_draw_eye_ellipse(Vector2(c.x + eye_offset_x, eye_y), eye_r * 1.3, eye_r * 0.7, shadow_gold)
	# Pupilas
	draw_circle(Vector2(c.x - eye_offset_x, eye_y), eye_r * 0.45, shadow_gold)
	draw_circle(Vector2(c.x + eye_offset_x, eye_y), eye_r * 0.45, shadow_gold)
	
	# Nariz tradicional
	var nose_top = Vector2(c.x, eye_y + eye_r * 0.5)
	var nose_left = Vector2(c.x - r * 0.09, c.y + r * 0.16)
	var nose_tip = Vector2(c.x, c.y + r * 0.19)
	var nose_right = Vector2(c.x + r * 0.09, c.y + r * 0.16)
	draw_polyline(PackedVector2Array([nose_top, nose_left, nose_tip, nose_right]), shadow_gold, 2.0, true)
	
	# Mejillas sonrosadas suaves
	draw_circle(Vector2(c.x - eye_offset_x * 1.1, c.y + r * 0.18), r * 0.12, Color(primary_gold.r, primary_gold.g * 0.9, primary_gold.b * 0.8, 0.45))
	draw_circle(Vector2(c.x + eye_offset_x * 1.1, c.y + r * 0.18), r * 0.12, Color(primary_gold.r, primary_gold.g * 0.9, primary_gold.b * 0.8, 0.45))

	# Boca serena
	var mouth_y = c.y + r * 0.40
	var mouth_left = Vector2(c.x - r * 0.22, mouth_y)
	var mouth_mid = Vector2(c.x, mouth_y + r * 0.06)
	var mouth_right = Vector2(c.x + r * 0.22, mouth_y)
	draw_polyline(PackedVector2Array([mouth_left, mouth_mid, mouth_right]), shadow_gold, 2.5, true)
	# Labio inferior
	var lip_bot = Vector2(c.x, mouth_y + r * 0.11)
	draw_polyline(PackedVector2Array([Vector2(c.x - r * 0.12, mouth_y + r * 0.04), lip_bot, Vector2(c.x + r * 0.12, mouth_y + r * 0.04)]), shadow_gold, 1.8, true)

func _draw_eye_ellipse(center_pos: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts = PackedVector2Array()
	var segs = 16
	for i in range(segs + 1):
		var th = float(i) / float(segs) * TAU
		pts.append(center_pos + Vector2(cos(th) * rx, sin(th) * ry))
	draw_polyline(pts, col, 2.0, true)
