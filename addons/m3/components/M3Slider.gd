@tool
class_name M3Slider
extends Control

const M3Units = preload("res://addons/m3/M3Units.gd")

## Material 3 Expressive Slider Component
## Uses native HSlider for input, custom rendering for M3 styling
##
## Architecture:
##   - HSlider: handles all input (dragging, clicking, stepping, focus)
##   - Overlay: custom draws everything M3-specific on top
##   - Range hitbox: captures input for range slider's second handle

enum Variant { STANDARD, CENTERED, RANGE }
enum Size { EXTRA_SMALL, SMALL, MEDIUM, LARGE, EXTRA_LARGE }
enum LabelBehavior { ALWAYS, WHILE_DRAGGING, NEVER }

# ============================================
# EXPORTS
# ============================================

@export var slider_variant: Variant = Variant.STANDARD:
	set(value):
		slider_variant = value
		_update_theme()
		if _range_hitbox:
			_range_hitbox.mouse_filter = Control.MOUSE_FILTER_PASS if slider_variant == Variant.RANGE else Control.MOUSE_FILTER_IGNORE
		if _overlay:
			_overlay.queue_redraw()

@export var slider_size: Size = Size.MEDIUM:
	set(value):
		slider_size = value
		_update_size()
		_update_theme()
		if _overlay:
			_overlay.queue_redraw()

@export var label_behavior: LabelBehavior = LabelBehavior.WHILE_DRAGGING:
	set(value):
		label_behavior = value
		_update_bubble()

@export var label_formatter: String = "%.0f"

@export var show_stops: bool = true:
	set(value):
		show_stops = value
		if _overlay:
			_overlay.queue_redraw()

@export var start_icon_name: String = "":
	set(value):
		start_icon_name = value
		_update_icons()

@export var end_icon_name: String = "":
	set(value):
		end_icon_name = value
		_update_icons()

@export var range_value: float = 0.0:
	set(value):
		range_value = clamp(value, _effective_min, _effective_max)
		if _overlay:
			_overlay.queue_redraw()

# Proxy properties
@export var min_value: float = 0.0:
	get: return _slider.min_value if _slider else _effective_min
	set(v):
		_effective_min = v
		if _slider:
			_slider.min_value = v
			if _overlay:
				_overlay.queue_redraw()

@export var max_value: float = 100.0:
	get: return _slider.max_value if _slider else _effective_max
	set(v):
		_effective_max = v
		if _slider:
			_slider.max_value = v
			if _overlay:
				_overlay.queue_redraw()

@export var step: float = 1.0:
	get: return _slider.step if _slider else 1.0
	set(v):
		if _slider:
			_slider.step = v
			if _overlay:
				_overlay.queue_redraw()

@export var value: float = 0.0:
	get: return _slider.value if _slider else 0.0
	set(v):
		if _slider:
			_slider.value = v
			if _overlay:
				_overlay.queue_redraw()

# ============================================
# INTERNAL
# ============================================

var _slider: HSlider
var _overlay: Control
var _range_hitbox: Control
var _bubble: PanelContainer
var _bubble_label: Label
var _start_icon: FontIcon
var _end_icon: FontIcon
var _is_dragging: bool = false
var _is_dragging_range: bool = false

var _effective_min: float = 0.0
var _effective_max: float = 100.0

# ============================================
# M3 EXPRESSIVE SIZE SPECS (all values in dp)
# ============================================

const SIZE_SPECS = {
	Size.EXTRA_SMALL: {
		"track_h": 16,
		"handle_w": 4,
		"handle_h": 44,
		"track_radius": 8,
		"stop_size": 8,
		"icon_size": 0,  # No inset icons for XS
	},
	Size.SMALL: {
		"track_h": 24,
		"handle_w": 4,
		"handle_h": 44,
		"track_radius": 8,
		"stop_size": 8,
		"icon_size": 0,  # No inset icons for S
	},
	Size.MEDIUM: {
		"track_h": 40,
		"handle_w": 4,
		"handle_h": 52,
		"track_radius": 12,
		"stop_size": 12,
		"icon_size": 24,
	},
	Size.LARGE: {
		"track_h": 56,
		"handle_w": 4,
		"handle_h": 68,
		"track_radius": 16,
		"stop_size": 16,
		"icon_size": 24,
	},
	Size.EXTRA_LARGE: {
		"track_h": 96,
		"handle_w": 4,
		"handle_h": 108,
		"track_radius": 28,
		"stop_size": 28,
		"icon_size": 32,
	},
}

const LABEL_WIDTH := 48
const LABEL_HEIGHT := 44

signal value_changed(value: float)
signal range_value_changed(value: float)
signal drag_started
signal drag_ended(value_changed: bool)



# ============================================
# LIFECYCLE
# ============================================

func _ready():
	_create_all_children()
	_update_size()
	_update_theme()
	_connect_signals()
	
	# Size children to fill initial parent size
	if _slider:
		_slider.size = size
	if _overlay:
		_overlay.size = size
	if _range_hitbox:
		_range_hitbox.size = size
	
	if _overlay:
		_overlay.queue_redraw()

func _create_all_children():
	# Create all nodes
	_slider = HSlider.new()
	_overlay = Control.new()
	_range_hitbox = Control.new()
	_bubble = PanelContainer.new()
	_bubble_label = Label.new()
	_start_icon = FontIcon.new()
	_end_icon = FontIcon.new()
	
	# ============================================
	# Configure nodes
	# ============================================
	
	# HSlider - handles all native input but is visually hidden
	# We draw everything custom in the overlay
	_slider.modulate = Color.TRANSPARENT
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Overlay - draws custom visuals on top. IGNORE input.
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 1
	_overlay.draw.connect(_on_overlay_draw)
	
	# Range hitbox - captures input for range slider's second handle
	_range_hitbox.mouse_filter = Control.MOUSE_FILTER_PASS if slider_variant == Variant.RANGE else Control.MOUSE_FILTER_IGNORE
	_range_hitbox.z_index = 2
	_range_hitbox.gui_input.connect(_on_range_hitbox_input)
	
	# Bubble - M3 value label
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.z_index = 10
	
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bubble_label.add_theme_font_override("font", M3Theme.load_fonts()["bold"])
	_bubble_label.add_theme_font_size_override("font_size", M3Theme.TYPE_LABEL_MEDIUM)
	
	_bubble.add_child(_bubble_label)
	
	_update_label_theme()
	
	# Icons
	_start_icon.visible = false
	_start_icon.icon_settings = FontIconSettings.new()
	
	_end_icon.visible = false
	_end_icon.icon_settings = FontIconSettings.new()
	
	# ============================================
	# Add children in render/input order
	# ============================================
	
	add_child(_overlay)      # Draws on top, ignores input
	add_child(_slider)       # Handles all input
	add_child(_range_hitbox) # Handles range second handle input
	add_child(_bubble)       # Label tooltip
	add_child(_start_icon)   # Start icon
	add_child(_end_icon)     # End icon
	
	_update_icons()

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		if _slider:
			_slider.size = size
		if _overlay:
			_overlay.size = size
		if _range_hitbox:
			_range_hitbox.size = size
		_update_bubble()

# ============================================
# UPDATES
# ============================================

func _update_icons():
	if not _start_icon or not _end_icon:
		return
	
	var icon_size = SIZE_SPECS[slider_size]["icon_size"]
	
	if icon_size > 0 and start_icon_name:
		_start_icon.visible = true
		_start_icon.icon_settings.icon_name = start_icon_name
		_start_icon.icon_settings.icon_size = icon_size
		_start_icon.icon_settings.icon_color = M3Theme.get_on_surface()
	else:
		_start_icon.visible = false
	
	if icon_size > 0 and end_icon_name:
		_end_icon.visible = true
		_end_icon.icon_settings.icon_name = end_icon_name
		_end_icon.icon_settings.icon_size = icon_size
		_end_icon.icon_settings.icon_color = M3Theme.get_on_surface()
	else:
		_end_icon.visible = false

func _update_size():
	if not _slider:
		return
	
	var spec = SIZE_SPECS[slider_size]
	# Component height = handle height (handle extends above/below track)
	custom_minimum_size.y = M3Units.dpi(spec["handle_h"])
	_update_icons()

func refresh_theme():
	"""Refresh all theme-dependent styling. Called by parent when dark mode changes."""
	_update_label_theme()
	if _overlay:
		_overlay.queue_redraw()

func _update_label_theme():
	if not _bubble:
		return
	
	# M3 value label: dark surface background, light text, fully rounded
	var label_style = M3Theme.make_flat(
		M3Theme.get_on_surface(),
		int(M3Units.dp(22)),
		0, Color.TRANSPARENT,
		int(M3Units.dp(12)), int(M3Units.dp(12))
	)
	_bubble.add_theme_stylebox_override("panel", label_style)
	
	if _bubble_label:
		_bubble_label.add_theme_color_override("font_color", M3Theme.get_surface())

func _update_theme():
	if not _slider:
		return
	
	# HSlider needs to be visible but not draw anything native
	# We handle all rendering in the overlay
	pass

func _connect_signals():
	_slider.value_changed.connect(_on_value_changed)
	_slider.drag_started.connect(_on_drag_started)
	_slider.drag_ended.connect(_on_drag_ended)

# ============================================
# SIGNAL HANDLERS
# ============================================

func _on_value_changed(new_value: float):
	value_changed.emit(new_value)
	if _overlay:
		_overlay.queue_redraw()
	_update_bubble()

func _on_drag_started():
	_is_dragging = true
	drag_started.emit()
	if _overlay:
		_overlay.queue_redraw()
	_update_bubble()

func _on_drag_ended(_value_changed: bool):
	_is_dragging = false
	drag_ended.emit(_value_changed)
	if _overlay:
		_overlay.queue_redraw()
	_update_bubble()

# ============================================
# BUBBLE / LABEL
# ============================================

func _update_bubble():
	if not _bubble or not _bubble_label:
		return
	
	var should_show = false
	match label_behavior:
		LabelBehavior.ALWAYS:
			should_show = true
		LabelBehavior.WHILE_DRAGGING:
			should_show = _is_dragging
		LabelBehavior.NEVER:
			should_show = false
	
	if not should_show:
		_bubble.visible = false
		return
	
	_bubble.visible = true
	_bubble_label.text = label_formatter % value
	_position_bubble.call_deferred()

func _position_bubble():
	if not _bubble:
		return
	var handle_pos = _get_handle_position(value)
	var handle_h = _get_handle_h()
	var bubble_w = M3Units.dp(LABEL_WIDTH)
	var bubble_h = M3Units.dp(LABEL_HEIGHT)
	
	# Position 4dp above the handle (centered horizontally on handle)
	_bubble.position = Vector2(
		handle_pos.x - bubble_w / 2,
		handle_pos.y - handle_h / 2 - bubble_h - M3Units.dp(4)
	)
	_bubble.size = Vector2(bubble_w, bubble_h)

# ============================================
# GEOMETRY HELPERS
# ============================================

func _get_handle_w() -> float:
	return M3Units.dp(SIZE_SPECS[slider_size]["handle_w"])

func _get_handle_h() -> float:
	return M3Units.dp(SIZE_SPECS[slider_size]["handle_h"])

func _get_track_h() -> float:
	return M3Units.dp(SIZE_SPECS[slider_size]["track_h"])

func _get_track_radius() -> float:
	return M3Units.dp(SIZE_SPECS[slider_size]["track_radius"])

func _get_stop_size() -> float:
	return M3Units.dp(SIZE_SPECS[slider_size]["stop_size"])

## Godot's native grabber position: ratio * areasize + handle_w/2
## areasize = width - handle_w (when not center_grabber)
func _get_handle_center_x(for_value: float) -> float:
	var handle_w = _get_handle_w()
	var areasize = size.x - handle_w
	var ratio = (for_value - min_value) / (max_value - min_value)
	return ratio * areasize + handle_w / 2.0

func _get_handle_center_y() -> float:
	return size.y / 2.0

func _get_handle_position(for_value: float) -> Vector2:
	return Vector2(_get_handle_center_x(for_value), _get_handle_center_y())

func _get_track_rect() -> Rect2:
	var track_h = _get_track_h()
	var y = (size.y - track_h) / 2.0
	# Track spans full width of component
	return Rect2(
		Vector2(0, y),
		Vector2(size.x, track_h)
	)

func _get_stop_positions() -> Array[float]:
	var stops: Array[float] = []
	if not show_stops or step <= 0:
		return stops
	
	var range_val = max_value - min_value
	if range_val <= 0:
		return stops
	
	var count = int(range_val / step)
	if count > 50:
		return stops  # Too many stops
	
	for i in range(count + 1):
		stops.append(min_value + i * step)
	
	return stops

# ============================================
# CUSTOM DRAWING
# ============================================

func _on_overlay_draw():
	if not _slider:
		return
	
	_draw_track()
	_draw_stops()
	
	if slider_variant == Variant.STANDARD:
		_draw_standard_active_track()
	elif slider_variant == Variant.CENTERED:
		_draw_centered_active_track()
		_draw_zero_mark()
	elif slider_variant == Variant.RANGE:
		_draw_range_active_track()
		_draw_range_handle()
	
	_draw_primary_handle()
	_draw_icons()

const THUMB_TRACK_GAP := 6.0  # dp
const INSIDE_CORNER_SIZE := 2.0  # dp

func _draw_track():
	var track_rect = _get_track_rect()
	var track_h = track_rect.size.y
	var out_radius = _get_track_radius()
	var in_radius = M3Units.dp(INSIDE_CORNER_SIZE)
	var gap = M3Units.dp(THUMB_TRACK_GAP)
	var color = M3Theme.get_surface_variant()
	var handle_x = _get_handle_center_x(value)
	
	# Left inactive segment: from track start to handle - gap
	var left_w = handle_x - gap - track_rect.position.x
	if left_w > 0:
		var left_rect = Rect2(
			Vector2(track_rect.position.x, track_rect.position.y),
			Vector2(left_w, track_rect.size.y)
		)
		_draw_rounded_rect_asymmetric(left_rect, color, out_radius, in_radius, out_radius, in_radius)
	
	# Right inactive segment: from handle + gap to track end
	var right_start = handle_x + gap
	var right_w = track_rect.end.x - right_start
	if right_w > 0:
		var right_rect = Rect2(
			Vector2(right_start, track_rect.position.y),
			Vector2(right_w, track_rect.size.y)
		)
		_draw_rounded_rect_asymmetric(right_rect, color, in_radius, out_radius, in_radius, out_radius)

func _draw_standard_active_track():
	var track_rect = _get_track_rect()
	var out_radius = _get_track_radius()
	var in_radius = M3Units.dp(INSIDE_CORNER_SIZE)
	var gap = M3Units.dp(THUMB_TRACK_GAP)
	var color = M3Theme.get_primary()
	var handle_x = _get_handle_center_x(value)
	
	# Active segment: from track start to handle - gap
	var active_w = handle_x - gap - track_rect.position.x
	if active_w > 0:
		var active_rect = Rect2(
			Vector2(track_rect.position.x, track_rect.position.y),
			Vector2(active_w, track_rect.size.y)
		)
		_draw_rounded_rect_asymmetric(active_rect, color, out_radius, in_radius, out_radius, in_radius)

func _draw_centered_active_track():
	var track_rect = _get_track_rect()
	var out_radius = _get_track_radius()
	var in_radius = M3Units.dp(INSIDE_CORNER_SIZE)
	var gap = M3Units.dp(THUMB_TRACK_GAP)
	var color = M3Theme.get_primary()
	var zero_x = _get_handle_center_x(0.0)
	var handle_x = _get_handle_center_x(value)
	
	# Active segment from zero to handle, with gap on both sides
	var start_x = min(zero_x, handle_x) + gap
	var end_x = max(zero_x, handle_x) - gap
	var active_w = end_x - start_x
	
	if active_w > 0:
		var active_rect = Rect2(
			Vector2(start_x, track_rect.position.y),
			Vector2(active_w, track_rect.size.y)
		)
		# Small radius on both ends (both face handles)
		_draw_rounded_rect_asymmetric(active_rect, color, in_radius, in_radius, in_radius, in_radius)

func _draw_zero_mark():
	var zero_value = 0.0
	if zero_value < min_value or zero_value > max_value:
		return
	
	var pos = _get_handle_center_x(zero_value)
	var track_rect = _get_track_rect()
	var stop_size = _get_stop_size()
	var y = track_rect.position.y + track_rect.size.y / 2.0
	var color = M3Theme.get_on_surface()
	
	_overlay.draw_circle(Vector2(pos, y), stop_size / 2.0, color)

func _draw_range_active_track():
	var track_rect = _get_track_rect()
	var out_radius = _get_track_radius()
	var in_radius = M3Units.dp(INSIDE_CORNER_SIZE)
	var gap = M3Units.dp(THUMB_TRACK_GAP)
	var color = M3Theme.get_primary()
	
	var val1 = _get_handle_center_x(value)
	var val2 = _get_handle_center_x(range_value)
	
	var start_x = min(val1, val2) + gap
	var end_x = max(val1, val2) - gap
	var active_w = end_x - start_x
	
	if active_w > 0:
		var active_rect = Rect2(
			Vector2(start_x, track_rect.position.y),
			Vector2(active_w, track_rect.size.y)
		)
		# Small radius on both ends (both face handles)
		_draw_rounded_rect_asymmetric(active_rect, color, in_radius, in_radius, in_radius, in_radius)

func _draw_stops():
	if not show_stops:
		return
	
	var stops = _get_stop_positions()
	if stops.size() <= 2:
		return
	
	var track_rect = _get_track_rect()
	var stop_size = _get_stop_size()
	var active_color = M3Theme.get_on_primary()
	var inactive_color = M3Theme.get_on_surface_variant()
	
	for stop in stops:
		var pos = _get_handle_center_x(stop)
		var is_active = false
		
		if slider_variant == Variant.CENTERED:
			is_active = (stop >= min(value, 0.0) and stop <= max(value, 0.0))
		elif slider_variant == Variant.RANGE:
			is_active = (stop >= min(value, range_value) and stop <= max(value, range_value))
		else:
			is_active = stop <= value
		
		var color = active_color if is_active else inactive_color
		var y = track_rect.position.y + track_rect.size.y / 2.0
		_overlay.draw_circle(Vector2(pos, y), stop_size / 2.0, color)

func _draw_primary_handle():
	var handle_pos = _get_handle_position(value)
	var handle_w = _get_handle_w()
	var handle_h = _get_handle_h()
	var color = M3Theme.get_primary()
	
	var rect = Rect2(
		Vector2(handle_pos.x - handle_w / 2, handle_pos.y - handle_h / 2),
		Vector2(handle_w, handle_h)
	)
	
	# M3 handle: thin vertical bar with rounded caps
	var radius = handle_w / 2.0
	_draw_rounded_rect(rect, color, radius)

func _draw_range_handle():
	var handle_pos = _get_handle_position(range_value)
	var handle_w = _get_handle_w()
	var handle_h = _get_handle_h()
	var prim = M3Theme.get_primary()
	var surf = M3Theme.get_surface()
	
	# Range handle: thin vertical bar with hollow center
	var rect = Rect2(
		Vector2(handle_pos.x - handle_w / 2, handle_pos.y - handle_h / 2),
		Vector2(handle_w, handle_h)
	)
	
	var radius = handle_w / 2.0
	
	# Draw border/outer
	_draw_rounded_rect(rect, prim, radius)
	
	# Draw inner (hollow)
	var inner_w = max(1, handle_w - 2)
	var inner_rect = Rect2(
		Vector2(handle_pos.x - inner_w / 2, handle_pos.y - handle_h / 2 + 2),
		Vector2(inner_w, handle_h - 4)
	)
	_draw_rounded_rect(inner_rect, surf, inner_w / 2.0)

func _draw_rounded_rect(rect: Rect2, color: Color, radius: float):
	"""Draw a rounded rectangle with uniform corner radius."""
	_draw_rounded_rect_asymmetric(rect, color, radius, radius, radius, radius)

func _draw_rounded_rect_asymmetric(rect: Rect2, color: Color, 
								   tl: float, tr: float, bl: float, br: float):
	"""Draw a rounded rectangle with per-corner radius control.
	Args:
		rect: The rectangle to draw
		color: Fill color
		tl: Top-left corner radius
		tr: Top-right corner radius
		bl: Bottom-left corner radius
		br: Bottom-right corner radius
	"""
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(tl)
	style.corner_radius_top_right = int(tr)
	style.corner_radius_bottom_left = int(bl)
	style.corner_radius_bottom_right = int(br)
	_overlay.draw_style_box(style, rect)

func _draw_icons():
	if not _start_icon or not _end_icon:
		return
	
	var track_rect = _get_track_rect()
	var icon_y = track_rect.position.y + track_rect.size.y / 2.0
	
	if _start_icon.visible:
		_start_icon.position = Vector2(0, icon_y - _start_icon.size.y / 2)
	
	if _end_icon.visible:
		_end_icon.position = Vector2(size.x - _end_icon.size.x, icon_y - _end_icon.size.y / 2)

# ============================================
# RANGE INPUT HANDLING
# ============================================

func _on_range_hitbox_input(event: InputEvent):
	if slider_variant != Variant.RANGE:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var range_handle_pos = _get_handle_position(range_value)
				var hit_w = _get_handle_w() * 3  # Generous hit area
				var hit_h = _get_handle_h() * 1.5
				var hit_rect = Rect2(
					Vector2(range_handle_pos.x - hit_w / 2, range_handle_pos.y - hit_h / 2),
					Vector2(hit_w, hit_h)
				)
				if hit_rect.has_point(event.position):
					_is_dragging_range = true
					accept_event()
			else:
				if _is_dragging_range:
					_is_dragging_range = false
					accept_event()
	
	elif event is InputEventMouseMotion:
		if _is_dragging_range:
			var track = _get_track_rect()
			var ratio = clamp((event.position.x - track.position.x) / track.size.x, 0.0, 1.0)
			var new_val = lerpf(min_value, max_value, ratio)
			if step > 0:
				new_val = snappedf(new_val, step)
			range_value = clamp(new_val, min_value, max_value)
			range_value_changed.emit(range_value)
			if _overlay:
				_overlay.queue_redraw()
			accept_event()
