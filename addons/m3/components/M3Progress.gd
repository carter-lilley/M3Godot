@tool
class_name M3Progress
extends Control

## Material 3 Progress Indicator
## Linear or circular determinate progress.

enum Mode { LINEAR, CIRCULAR }
enum Size { SMALL, LARGE }

# ============================================
# EXPORTS
# ============================================

@export var mode: Mode = Mode.LINEAR:
	set(value):
		if value == mode:
			return
		mode = value
		queue_redraw()

@export var progress_size: Size = Size.SMALL:
	set(value):
		if value == progress_size:
			return
		progress_size = value
		queue_redraw()

@export var value: float = 0.0:
	set(p_value):
		value = clampf(p_value, 0.0, max_value)
		queue_redraw()

@export var max_value: float = 100.0:
	set(p_value):
		max_value = maxf(p_value, 0.001)
		value = clampf(value, 0.0, max_value)
		queue_redraw()

@export var indeterminate: bool = false:
	set(value):
		indeterminate = value
		set_process(value)
		queue_redraw()

# ============================================
# INTERNAL
# ============================================

var _track_color: Color
var _indicator_color: Color
var _indet_start: float = 0.0
var _indet_end: float = 0.0

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	refresh_theme()
	set_process(indeterminate)

func _process(_delta: float):
	if indeterminate:
		var t = Time.get_ticks_msec() / 1000.0
		var cycle = fmod(t, 2.0) / 2.0
		if cycle < 0.5:
			_indet_start = 0.0
			_indet_end = (cycle / 0.5)
		else:
			_indet_start = ((cycle - 0.5) / 0.5)
			_indet_end = 1.0
		queue_redraw()

func _draw():
	if mode == Mode.LINEAR:
		_draw_linear()
	else:
		_draw_circular()

# ============================================
# DRAWING
# ============================================

func _draw_linear():
	var track_height: float
	match progress_size:
		Size.LARGE:
			track_height = M3Units.dp(8)
		_:
			track_height = M3Units.dp(4)
	
	var radius = track_height / 2.0
	var rect = get_rect()
	var track_y = rect.size.y / 2.0 - track_height / 2.0
	var gap = M3Units.dp(4)
	
	var start_x: float
	var end_x: float
	
	if indeterminate:
		start_x = rect.size.x * _indet_start
		end_x = rect.size.x * _indet_end
	else:
		var fraction = value / max_value
		start_x = 0.0
		end_x = rect.size.x * fraction
	
	var fill_width = end_x - start_x
	
	# Draw full track behind everything
	draw_rect(Rect2(Vector2(radius, track_y), Vector2(rect.size.x - track_height, track_height)), _track_color, true)
	draw_circle(Vector2(radius, track_y + radius), radius, _track_color)
	draw_circle(Vector2(rect.size.x - radius, track_y + radius), radius, _track_color)
	
	# Endpoint indicator (right side only, 4dp dot)
	var endpoint_radius = M3Units.dp(2)
	var endpoint_color = M3Theme.get_on_surface()
	draw_circle(Vector2(rect.size.x - radius, track_y + radius), endpoint_radius, endpoint_color)
	
	# Draw fill on top of track
	if fill_width > 0:
		var fill_rect_width = fill_width - radius
		if fill_rect_width > 0:
			draw_rect(Rect2(Vector2(start_x + radius, track_y), Vector2(fill_rect_width, track_height)), _indicator_color, true)
		# Fill left cap
		draw_circle(Vector2(start_x + radius, track_y + radius), radius, _indicator_color)
		# Fill right cap (before gap) — always draw, just like track caps
		draw_circle(Vector2(end_x, track_y + radius), radius, _indicator_color)

func _draw_circular():
	var diameter: float
	var stroke: float
	match progress_size:
		Size.LARGE:
			diameter = M3Units.dp(44)
			stroke = M3Units.dp(8)
		_:
			diameter = M3Units.dp(40)
			stroke = M3Units.dp(4)
	
	var radius = diameter / 2.0
	var center = Vector2(size.x / 2.0, size.y / 2.0)
	
	# Track (full ring)
	_draw_thick_arc(center, radius, 0.0, TAU, _track_color, stroke)
	
	var start_fraction: float
	var end_fraction: float
	
	if indeterminate:
		start_fraction = _indet_start
		end_fraction = _indet_end
	else:
		start_fraction = 0.0
		end_fraction = value / max_value
	
	var fraction = end_fraction - start_fraction
	
	# Indicator with 4dp gap at start
	if fraction > 0:
		var gap_distance = M3Units.dp(4)
		var gap_angle = gap_distance / radius
		var progress_angle = TAU * fraction
		var start_angle = gap_angle + (TAU * start_fraction)
		var end_angle = start_angle + progress_angle
		
		if end_angle > start_angle:
			_draw_thick_arc(center, radius, start_angle, end_angle, _indicator_color, stroke)
			
			# Rounded caps at indicator endpoints
			var offset = -PI / 2.0
			var actual_start = start_angle + offset
			var actual_end = end_angle + offset
			
			var start_point = center + Vector2(cos(actual_start), sin(actual_start)) * radius
			var end_point = center + Vector2(cos(actual_end), sin(actual_end)) * radius
			
			draw_circle(start_point, stroke / 2.0, _indicator_color)
			draw_circle(end_point, stroke / 2.0, _indicator_color)

func _draw_thick_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float):
	# Godot angles: 0 = right, positive = counter-clockwise
	# We want 0 = top (12 o'clock), clockwise direction
	var offset = -PI / 2.0
	var actual_start = start_angle + offset
	var actual_end = end_angle + offset
	
	# Draw thick arc using Godot's draw_arc with width
	draw_arc(center, radius, actual_start, actual_end, 64, color, width, true)

# ============================================
# THEME
# ============================================

func refresh_theme():
	_track_color = M3Theme.get_elevation_surface(5)
	_indicator_color = M3Theme.get_primary()
	queue_redraw()

# ============================================
# API
# ============================================

func set_fraction(fraction: float) -> void:
	value = clampf(fraction, 0.0, 1.0) * max_value

func get_fraction() -> float:
	return value / max_value if max_value > 0 else 0.0

# ============================================
# SIZE
# ============================================

func _get_minimum_size() -> Vector2:
	if mode == Mode.LINEAR:
		var h: float
		match progress_size:
			Size.LARGE:
				h = M3Units.dp(8)
			_:
				h = M3Units.dp(4)
		return Vector2(M3Units.dp(100), h)
	else:
		var d: float
		match progress_size:
			Size.LARGE:
				d = M3Units.dp(44)
			_:
				d = M3Units.dp(40)
		return Vector2(d, d)
