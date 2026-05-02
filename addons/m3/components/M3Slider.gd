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
enum SliderOrientation { HORIZONTAL, VERTICAL }

# ============================================
# EXPORTS
# ============================================

@export var slider_variant: Variant = Variant.STANDARD:
	set(value):
		slider_variant = value
		_update_theme()
		var is_range = slider_variant == Variant.RANGE
		if _track_hitbox:
			_track_hitbox.mouse_filter = Control.MOUSE_FILTER_PASS if is_range else Control.MOUSE_FILTER_IGNORE
		if _range_hitbox:
			_range_hitbox.mouse_filter = Control.MOUSE_FILTER_PASS if is_range else Control.MOUSE_FILTER_IGNORE
		if _overlay:
			_overlay.queue_redraw()

@export var orientation: SliderOrientation = SliderOrientation.HORIZONTAL:
	set(value):
		orientation = value
		# Recreate slider with correct type (HSlider vs VSlider)
		if _slider:
			_slider.queue_free()
			_slider = null
		_create_slider()
		_update_size()
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
	set(v):
		# Prevent crossing: range_value can never exceed value in RANGE mode
		var max_val = _effective_max
		if slider_variant == Variant.RANGE:
			max_val = min(max_val, value)
		range_value = clamp(v, _effective_min, max_val)
		_update_range_hitbox_position()
		if _overlay:
			_overlay.queue_redraw()

@export var editable: bool = true:
	get: return _slider.editable if _slider else true
	set(v):
		if _slider:
			_slider.editable = v
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

@export var step: float = 0.0:
	get: return _slider.step if _slider else _effective_step
	set(v):
		_effective_step = v
		if _slider:
			_slider.step = v
			if _overlay:
				_overlay.queue_redraw()

@export var value: float = 0.0:
	get: return _slider.value if _slider else 0.0
	set(v):
		if _slider:
			# Prevent crossing: value can never go below range_value in RANGE mode
			if slider_variant == Variant.RANGE:
				v = max(v, range_value)
			_slider.value = v
			if _overlay:
				_overlay.queue_redraw()

# ============================================
# INTERNAL
# ============================================

var _slider: Slider
var _overlay: Control
var _track_hitbox: Control
var _range_hitbox: Control
var _bubble: PanelContainer
var _bubble_label: Label
var _start_icon: FontIcon
var _end_icon: FontIcon
var _is_dragging: bool = false
var _is_dragging_range: bool = false
var _is_dragging_primary: bool = false
var _is_focused: bool = false
var _prev_value: float = 0.0  # Value before current drag/click interaction

var _effective_min: float = 0.0
var _effective_max: float = 100.0
var _effective_step: float = 1.0

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

const THUMB_TRACK_GAP := 6.0  # dp
const INSIDE_CORNER_SIZE := 2.0  # dp

const LABEL_WIDTH := 48
const LABEL_HEIGHT := 44

signal value_changed(value: float)
signal range_value_changed(value: float)
signal drag_started
signal drag_ended(value_changed: bool)

## Get the current range as a Vector2 (x=min, y=max)
func get_range() -> Vector2:
	if slider_variant == Variant.RANGE:
		return Vector2(min(value, range_value), max(value, range_value))
	return Vector2(value, value)



# ============================================
# LIFECYCLE
# ============================================

func _ready():
	_create_all_children()
	_update_size()
	_update_theme()
	_connect_signals()
	
	# Enable internal processing to poll HSlider focus state
	set_process_internal(true)
	
	# Apply initial values that were set before _slider existed
	if _slider:
		_slider.min_value = _effective_min
		_slider.max_value = _effective_max
		_slider.step = _effective_step
		_slider.value = value
		_slider.editable = editable
		_prev_value = value
	
	# Size children to fill initial parent size
	if _slider:
		_slider.size = size
	if _overlay:
		_overlay.size = size
	
	_update_range_hitbox_position()
	
	if _overlay:
		_overlay.queue_redraw()

func _create_all_children():
	# Create all nodes
	_overlay = Control.new()
	_range_hitbox = Control.new()
	_bubble = PanelContainer.new()
	_bubble_label = Label.new()
	_start_icon = FontIcon.new()
	_end_icon = FontIcon.new()
	
	_create_slider()
	
	# ============================================
	# Configure shared nodes
	# ============================================
	
	# Overlay - draws custom visuals on top. IGNORE input.
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 1
	_overlay.draw.connect(_on_overlay_draw)
	
	# Range hitbox - small control that follows the range handle
	# Only captures input when hovering over the range handle area
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
	_start_icon.z_index = 3
	
	_end_icon.visible = false
	_end_icon.icon_settings = FontIconSettings.new()
	_end_icon.z_index = 3
	
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

func _create_slider():
	"""Create HSlider or VSlider based on orientation."""
	if _slider:
		_slider.queue_free()
	
	if orientation == SliderOrientation.VERTICAL:
		_slider = VSlider.new()
	else:
		_slider = HSlider.new()
	
	# Slider handles all native input including keyboard/controller
	# It's visually hidden but must be focusable for input
	_slider.modulate = Color.TRANSPARENT
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		if _slider:
			_slider.size = size
		if _overlay:
			_overlay.size = size
		_update_range_hitbox_position()
		_update_bubble()
	# Check HSlider focus state each frame for controller/keyboard focus
	elif what == NOTIFICATION_INTERNAL_PROCESS:
		if _slider and _is_focused != _slider.has_focus():
			_is_focused = _slider.has_focus()
			if _overlay:
				_overlay.queue_redraw()

# ============================================
# UPDATES
# ============================================

func _update_icons():
	if not _start_icon or not _end_icon:
		return
	
	var icon_size_dp = SIZE_SPECS[slider_size]["icon_size"]
	var icon_size_px = M3Units.dpi(icon_size_dp)
	
	if icon_size_dp > 0 and start_icon_name:
		_start_icon.visible = true
		_start_icon.icon_settings.icon_name = start_icon_name
		_start_icon.icon_settings.icon_size = icon_size_px
		_start_icon.icon_settings.outline_color = Color.TRANSPARENT
		_start_icon.icon_settings.shadow_color = Color.TRANSPARENT
		_update_icon_color(_start_icon, true)
	else:
		_start_icon.visible = false
	
	if icon_size_dp > 0 and end_icon_name:
		_end_icon.visible = true
		_end_icon.icon_settings.icon_name = end_icon_name
		_end_icon.icon_settings.icon_size = icon_size_px
		_end_icon.icon_settings.outline_color = Color.TRANSPARENT
		_end_icon.icon_settings.shadow_color = Color.TRANSPARENT
		_update_icon_color(_end_icon, false)
	else:
		_end_icon.visible = false

func _update_icon_color(icon: FontIcon, is_start: bool):
	"""Update icon color based on whether it's in active or inactive track area."""
	if not icon or not icon.visible:
		return
	
	var handle_axis_pos = _get_axis_position(value)
	var track_rect = _get_track_rect()
	var padding = M3Units.dp(8)
	
	# Calculate icon center position along the slider axis
	var icon_axis_pos: float
	if _is_vertical():
		# For vertical: start icon is at bottom, end icon is at top
		if is_start:
			icon_axis_pos = track_rect.end.y - padding - icon.size.y / 2
		else:
			icon_axis_pos = track_rect.position.y + padding + icon.size.y / 2
	else:
		# For horizontal: start icon is at left, end icon is at right
		if is_start:
			icon_axis_pos = track_rect.position.x + padding + icon.size.x / 2
		else:
			icon_axis_pos = track_rect.end.x - padding - icon.size.x / 2
	
	# Determine if icon is in active or inactive track
	# For vertical: active is below handle (higher axis value)
	# For horizontal: active is left of handle (lower axis value)
	var is_active: bool
	if _is_vertical():
		is_active = icon_axis_pos > handle_axis_pos
	else:
		is_active = icon_axis_pos < handle_axis_pos
	
	# Set color based on track state (with disabled state support)
	var new_color
	if is_active:
		new_color = _get_disabled_color(M3Theme.get_on_primary())
	else:
		new_color = _get_disabled_color(M3Theme.get_on_surface())
	if icon.icon_settings.icon_color != new_color:
		icon.icon_settings.icon_color = new_color
		# Force FontIcon to refresh
		icon._on_icon_settings_changed()

func _update_size():
	if not _slider:
		return
	
	var spec = SIZE_SPECS[slider_size]
	if _is_vertical():
		# Component width = handle height (handle extends left/right of track)
		var min_w = M3Units.dp(spec["handle_h"])
		custom_minimum_size.x = max(custom_minimum_size.x, min_w)
	else:
		# Component height = handle height (handle extends above/below track)
		var min_h = M3Units.dp(spec["handle_h"])
		custom_minimum_size.y = max(custom_minimum_size.y, min_h)
	_update_icons()

func refresh_theme():
	"""Refresh all theme-dependent styling. Called by parent when dark mode changes."""
	_update_label_theme()
	_update_icons()
	if _overlay:
		_overlay.queue_redraw()

func _update_range_hitbox_position():
	if not _range_hitbox or slider_variant != Variant.RANGE:
		return
	
	var handle_pos = _get_handle_position(range_value)
	var hit_w: float
	var hit_h: float
	if _is_vertical():
		hit_w = _get_handle_h() * 2
		hit_h = _get_handle_w() * 4
	else:
		hit_w = _get_handle_w() * 4
		hit_h = _get_handle_h() * 2
	
	_range_hitbox.position = Vector2(
		handle_pos.x - hit_w / 2,
		handle_pos.y - hit_h / 2
	)
	_range_hitbox.size = Vector2(hit_w, hit_h)

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
	if slider_variant == Variant.RANGE:
		if _is_dragging_primary:
			# Primary handle drag: just constrain range_value
			if range_value > new_value:
				range_value = new_value
			value_changed.emit(new_value)
		else:
			# Track click (jump): move nearest handle using PRE-click positions
			var dist_to_primary = abs(new_value - _prev_value)
			var dist_to_range = abs(new_value - range_value)
			if dist_to_range < dist_to_primary:
				# Range handle is closer: move it, restore primary
				range_value = new_value
				# Restore HSlider to primary handle's pre-click position
				if _slider:
					_slider.set_block_signals(true)
					_slider.value = _prev_value
					_slider.set_block_signals(false)
				range_value_changed.emit(range_value)
			else:
				# Primary handle is closer or equal: move it, constrain range
				if range_value > new_value:
					range_value = new_value
				value_changed.emit(new_value)
	else:
		value_changed.emit(new_value)
	
	# Update icon colors based on new handle position
	_update_icon_color(_start_icon, true)
	_update_icon_color(_end_icon, false)
	
	if _overlay:
		_overlay.queue_redraw()
	_update_bubble()

func _on_drag_started():
	_prev_value = value
	
	# Grab focus on HSlider for keyboard/controller input
	if _slider:
		_slider.grab_focus()
	
	# Determine if user clicked on primary handle or track
	# HSlider emits drag_started BEFORE changing value, so 'value' is still old
	var mouse_local = get_global_mouse_position() - global_position
	var primary_axis = _get_axis_position(value)
	var hit_radius = _get_handle_w() * 3  # Generous hit area
	var is_on_handle: bool
	if _is_vertical():
		is_on_handle = abs(mouse_local.y - primary_axis) <= hit_radius
	else:
		is_on_handle = abs(mouse_local.x - primary_axis) <= hit_radius
	
	_is_dragging = true
	_is_dragging_primary = is_on_handle
	drag_started.emit()
	if _overlay:
		_overlay.queue_redraw()
	_update_bubble()

func _on_drag_ended(_value_changed: bool):
	_is_dragging = false
	_is_dragging_primary = false
	_prev_value = value  # Update prev_value for next interaction
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
	var handle_w = _get_handle_w()
	var handle_h = _get_handle_h()
	var bubble_w = M3Units.dp(LABEL_WIDTH)
	var bubble_h = M3Units.dp(LABEL_HEIGHT)
	
	if _is_vertical():
		# Position 4dp to the left of the handle (centered vertically on handle)
		_bubble.position = Vector2(
			handle_pos.x - handle_h / 2 - bubble_w - M3Units.dp(4),
			handle_pos.y - bubble_h / 2
		)
	else:
		# Position 4dp above the handle (centered horizontally on handle)
		_bubble.position = Vector2(
			handle_pos.x - bubble_w / 2,
			handle_pos.y - handle_h / 2 - bubble_h - M3Units.dp(4)
		)
	_bubble.size = Vector2(bubble_w, bubble_h)

# ============================================
# ORIENTATION HELPERS
# ============================================

func _is_vertical() -> bool:
	return orientation == SliderOrientation.VERTICAL

## Get slider axis size (width for horizontal, height for vertical)
func _get_slider_axis_size() -> float:
	if _is_vertical():
		return size.y
	return size.x

## Get the center position on the perpendicular axis
func _get_perp_center() -> float:
	if _is_vertical():
		return size.x / 2.0
	return size.y / 2.0

## Get position along slider axis for a given value
func _get_axis_position(for_value: float) -> float:
	var handle_size = _get_handle_w()
	var area_size = _get_slider_axis_size() - handle_size
	var ratio = (for_value - min_value) / (max_value - min_value)
	
	if _is_vertical():
		# VSlider: 0 at top, max at bottom (inverted)
		return (1.0 - ratio) * area_size + handle_size / 2.0
	else:
		# HSlider: 0 at left, max at right
		return ratio * area_size + handle_size / 2.0

## Convert a position along the axis back to a value
func _get_value_at_axis_position(pos: float) -> float:
	var handle_size = _get_handle_w()
	var area_size = _get_slider_axis_size() - handle_size
	if area_size <= 0:
		return min_value
	
	var ratio: float
	if _is_vertical():
		# Invert for vertical (top is max)
		ratio = 1.0 - (pos - handle_size / 2.0) / area_size
	else:
		ratio = (pos - handle_size / 2.0) / area_size
	
	return clamp(lerpf(min_value, max_value, ratio), min_value, max_value)

## Build a point from axis position and perpendicular center
func _make_point(axis_pos: float, perp_offset: float = 0.0) -> Vector2:
	if _is_vertical():
		return Vector2(_get_perp_center() + perp_offset, axis_pos)
	return Vector2(axis_pos, _get_perp_center() + perp_offset)

# ============================================
# GEOMETRY HELPERS
# ============================================

func _get_handle_w() -> float:
	# When dragging or focused, use thin line (2dp) for cleaner interaction
	if _is_dragging or _is_dragging_range or _is_focused:
		return M3Units.dp(2)
	return M3Units.dp(SIZE_SPECS[slider_size]["handle_w"])

func _get_handle_h() -> float:
	return M3Units.dp(SIZE_SPECS[slider_size]["handle_h"])

func _get_track_h() -> float:
	return M3Units.dp(SIZE_SPECS[slider_size]["track_h"])

func _get_track_radius() -> float:
	return M3Units.dp(SIZE_SPECS[slider_size]["track_radius"])

func _get_stop_size() -> float:
	return M3Units.dp(4)

func _get_handle_position(for_value: float) -> Vector2:
	var axis_pos = _get_axis_position(for_value)
	return _make_point(axis_pos)

func _get_track_rect() -> Rect2:
	var track_thickness = _get_track_h()
	var perp_center = _get_perp_center()
	var axis_size = _get_slider_axis_size()
	
	if _is_vertical():
		# Vertical track: spans full height, centered horizontally
		var x = perp_center - track_thickness / 2.0
		return Rect2(
			Vector2(x, 0),
			Vector2(track_thickness, axis_size)
		)
	else:
		# Horizontal track: spans full width, centered vertically
		var y = perp_center - track_thickness / 2.0
		return Rect2(
			Vector2(0, y),
			Vector2(axis_size, track_thickness)
		)

func _get_disabled_color(normal_color: Color) -> Color:
	if not _slider or _slider.editable:
		return normal_color
	return M3Theme.disabled_color(normal_color)

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
		var stop_val = min_value + i * step
		# Skip first (0%) and last (100%) stops per M3 spec
		if i == 0 or i == count:
			continue
		stops.append(stop_val)
	
	return stops

# ============================================
# CUSTOM DRAWING
# ============================================

func _on_overlay_draw():
	if not _slider:
		return
	
	_draw_track()
	
	if slider_variant == Variant.STANDARD:
		_draw_standard_active_track()
	elif slider_variant == Variant.CENTERED:
		_draw_centered_active_track()
		_draw_zero_mark()
	elif slider_variant == Variant.RANGE:
		_draw_range_active_track()
		_draw_range_handle()
	
	_draw_stops()
	_draw_end_indicator()
	_draw_primary_handle()
	_draw_icons()
	
	if _is_focused:
		_draw_focus_ring()

func _draw_track():
	var track_rect = _get_track_rect()
	var out_radius = _get_track_radius()
	var in_radius = M3Units.dp(INSIDE_CORNER_SIZE)
	var gap = M3Units.dp(THUMB_TRACK_GAP)
	var color = _get_disabled_color(M3Theme.get_surface_variant())
	var handle_axis = _get_axis_position(value)
	
	if _is_vertical():
		# Vertical: top and bottom inactive segments
		# Top inactive: from track top to handle - gap
		var top_h = handle_axis - gap - track_rect.position.y
		if top_h > 0:
			var top_rect = Rect2(
				Vector2(track_rect.position.x, track_rect.position.y),
				Vector2(track_rect.size.x, top_h)
			)
			_draw_rounded_rect_asymmetric(top_rect, color, out_radius, out_radius, in_radius, in_radius)
		
		# Bottom inactive: from handle + gap to track bottom
		var bottom_start = handle_axis + gap
		var bottom_h = track_rect.end.y - bottom_start
		if bottom_h > 0:
			var bottom_rect = Rect2(
				Vector2(track_rect.position.x, bottom_start),
				Vector2(track_rect.size.x, bottom_h)
			)
			_draw_rounded_rect_asymmetric(bottom_rect, color, in_radius, in_radius, out_radius, out_radius)
	else:
		# Horizontal: left and right inactive segments
		# Left inactive: from track start to handle - gap
		var left_w = handle_axis - gap - track_rect.position.x
		if left_w > 0:
			var left_rect = Rect2(
				Vector2(track_rect.position.x, track_rect.position.y),
				Vector2(left_w, track_rect.size.y)
			)
			_draw_rounded_rect_asymmetric(left_rect, color, out_radius, in_radius, out_radius, in_radius)
		
		# Right inactive: from handle + gap to track end
		var right_start = handle_axis + gap
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
	var color = _get_disabled_color(M3Theme.get_primary())
	var handle_axis = _get_axis_position(value)
	
	if _is_vertical():
		# Vertical: active from track bottom to handle + gap
		var active_h = track_rect.end.y - handle_axis - gap
		if active_h > 0:
			var active_rect = Rect2(
				Vector2(track_rect.position.x, handle_axis + gap),
				Vector2(track_rect.size.x, active_h)
			)
			_draw_rounded_rect_asymmetric(active_rect, color, in_radius, in_radius, out_radius, out_radius)
	else:
		# Horizontal: active from track start to handle - gap
		var active_w = handle_axis - gap - track_rect.position.x
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
	var color = _get_disabled_color(M3Theme.get_primary())
	var zero_axis = _get_axis_position(0.0)
	var handle_axis = _get_axis_position(value)
	
	# Active segment from zero to handle, with gap on both sides
	var start_axis = min(zero_axis, handle_axis) + gap
	var end_axis = max(zero_axis, handle_axis) - gap
	
	if _is_vertical():
		var active_h = end_axis - start_axis
		if active_h > 0:
			var active_rect = Rect2(
				Vector2(track_rect.position.x, start_axis),
				Vector2(track_rect.size.x, active_h)
			)
			_draw_rounded_rect_asymmetric(active_rect, color, in_radius, in_radius, in_radius, in_radius)
	else:
		var active_w = end_axis - start_axis
		if active_w > 0:
			var active_rect = Rect2(
				Vector2(start_axis, track_rect.position.y),
				Vector2(active_w, track_rect.size.y)
			)
			_draw_rounded_rect_asymmetric(active_rect, color, in_radius, in_radius, in_radius, in_radius)

func _draw_zero_mark():
	var zero_value = 0.0
	if zero_value < min_value or zero_value > max_value:
		return
	
	var pos = _get_axis_position(zero_value)
	var track_rect = _get_track_rect()
	var stop_size = _get_stop_size()
	var center = _get_perp_center()
	var color = _get_disabled_color(M3Theme.get_on_surface())
	var stop_rect: Rect2
	
	if _is_vertical():
		stop_rect = Rect2(
			Vector2(center - stop_size / 2.0, pos - stop_size / 2.0),
			Vector2(stop_size, stop_size)
		)
	else:
		stop_rect = Rect2(
			Vector2(pos - stop_size / 2.0, center - stop_size / 2.0),
			Vector2(stop_size, stop_size)
		)
	_draw_smooth_circle(stop_rect, color)

func _draw_range_active_track():
	var track_rect = _get_track_rect()
	var out_radius = _get_track_radius()
	var in_radius = M3Units.dp(INSIDE_CORNER_SIZE)
	var gap = M3Units.dp(THUMB_TRACK_GAP)
	var color = _get_disabled_color(M3Theme.get_primary())
	
	var val1 = _get_axis_position(value)
	var val2 = _get_axis_position(range_value)
	
	var start_axis = min(val1, val2) + gap
	var end_axis = max(val1, val2) - gap
	
	if _is_vertical():
		var active_h = end_axis - start_axis
		if active_h > 0:
			var active_rect = Rect2(
				Vector2(track_rect.position.x, start_axis),
				Vector2(track_rect.size.x, active_h)
			)
			_draw_rounded_rect_asymmetric(active_rect, color, in_radius, in_radius, in_radius, in_radius)
	else:
		var active_w = end_axis - start_axis
		if active_w > 0:
			var active_rect = Rect2(
				Vector2(start_axis, track_rect.position.y),
				Vector2(active_w, track_rect.size.y)
			)
			_draw_rounded_rect_asymmetric(active_rect, color, in_radius, in_radius, in_radius, in_radius)

func _draw_stops():
	if not show_stops:
		return
	
	var stops = _get_stop_positions()
	if stops.size() <= 2:
		return
	
	var track_rect = _get_track_rect()
	var stop_size = _get_stop_size()
	var active_color = _get_disabled_color(M3Theme.get_on_primary())
	var inactive_color = _get_disabled_color(M3Theme.get_on_surface_variant())
	var center = _get_perp_center()
	
	for stop in stops:
		var pos = _get_axis_position(stop)
		var is_active = false
		
		if slider_variant == Variant.CENTERED:
			is_active = (stop >= min(value, 0.0) and stop <= max(value, 0.0))
		elif slider_variant == Variant.RANGE:
			is_active = (stop >= min(value, range_value) and stop <= max(value, range_value))
		else:
			is_active = stop <= value
		
		var color = active_color if is_active else inactive_color
		var stop_rect: Rect2
		if _is_vertical():
			stop_rect = Rect2(
				Vector2(center - stop_size / 2.0, pos - stop_size / 2.0),
				Vector2(stop_size, stop_size)
			)
		else:
			stop_rect = Rect2(
				Vector2(pos - stop_size / 2.0, center - stop_size / 2.0),
				Vector2(stop_size, stop_size)
			)
		_draw_smooth_circle(stop_rect, color)

func _draw_end_indicator():
	"""Draw end-of-track indicator dot at max value position. Not shown on discrete sliders."""
	if _get_stop_positions().size() > 0:
		return
	
	var track_rect = _get_track_rect()
	var stop_size = _get_stop_size()
	var gap = M3Units.dp(4)
	var center = _get_perp_center()
	var end_value = max_value
	
	# Determine if dot is in active track (same logic as stops)
	var is_active = false
	if slider_variant == Variant.CENTERED:
		is_active = (end_value >= min(value, 0.0) and end_value <= max(value, 0.0))
	elif slider_variant == Variant.RANGE:
		is_active = (end_value >= min(value, range_value) and end_value <= max(value, range_value))
	else:
		is_active = end_value <= value
	
	var color = _get_disabled_color(M3Theme.get_on_primary() if is_active else M3Theme.get_on_surface_variant())
	
	var dot_rect: Rect2
	if _is_vertical():
		# Vertical: dot at top (max), inset from top edge
		dot_rect = Rect2(
			Vector2(center - stop_size / 2.0, track_rect.position.y + gap),
			Vector2(stop_size, stop_size)
		)
	else:
		# Horizontal: dot at right (max), inset from right edge
		dot_rect = Rect2(
			Vector2(track_rect.end.x - gap - stop_size, center - stop_size / 2.0),
			Vector2(stop_size, stop_size)
		)
	
	_draw_smooth_circle(dot_rect, color)

func _draw_smooth_circle(rect: Rect2, color: Color):
	"""Draw anti-aliased circle using StyleBoxFlat for smooth edges."""
	var radius = int(min(rect.size.x, rect.size.y) / 2.0)
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	_overlay.draw_style_box(style, rect)

func _draw_primary_handle():
	var handle_pos = _get_handle_position(value)
	var handle_w = _get_handle_w()
	var handle_h = _get_handle_h()
	var color = _get_disabled_color(M3Theme.get_primary())
	
	if _is_vertical():
		# Vertical: thin horizontal bar
		var rect = Rect2(
			Vector2(handle_pos.x - handle_h / 2, handle_pos.y - handle_w / 2),
			Vector2(handle_h, handle_w)
		)
		var radius = handle_w / 2.0
		_draw_rounded_rect(rect, color, radius)
	else:
		# Horizontal: thin vertical bar
		var rect = Rect2(
			Vector2(handle_pos.x - handle_w / 2, handle_pos.y - handle_h / 2),
			Vector2(handle_w, handle_h)
		)
		var radius = handle_w / 2.0
		_draw_rounded_rect(rect, color, radius)

func _draw_range_handle():
	var handle_pos = _get_handle_position(range_value)
	var handle_w = _get_handle_w()
	var handle_h = _get_handle_h()
	var prim = _get_disabled_color(M3Theme.get_primary())
	var surf = _get_disabled_color(M3Theme.get_surface())
	
	if _is_vertical():
		# Vertical: thin horizontal bar with hollow center
		var rect = Rect2(
			Vector2(handle_pos.x - handle_h / 2, handle_pos.y - handle_w / 2),
			Vector2(handle_h, handle_w)
		)
		var radius = handle_w / 2.0
		_draw_rounded_rect(rect, prim, radius)
		
		var inner_h = max(1, handle_w - 2)
		var inner_rect = Rect2(
			Vector2(handle_pos.x - handle_h / 2 + 2, handle_pos.y - inner_h / 2),
			Vector2(handle_h - 4, inner_h)
		)
		_draw_rounded_rect(inner_rect, surf, inner_h / 2.0)
	else:
		# Horizontal: thin vertical bar with hollow center
		var rect = Rect2(
			Vector2(handle_pos.x - handle_w / 2, handle_pos.y - handle_h / 2),
			Vector2(handle_w, handle_h)
		)
		var radius = handle_w / 2.0
		_draw_rounded_rect(rect, prim, radius)
		
		var inner_w = max(1, handle_w - 2)
		var inner_rect = Rect2(
			Vector2(handle_pos.x - inner_w / 2, handle_pos.y - handle_h / 2 + 2),
			Vector2(inner_w, handle_h - 4)
		)
		_draw_rounded_rect(inner_rect, surf, inner_w / 2.0)

func _draw_focus_ring():
	"""Draw a hollow pill-shaped focus ring around the primary handle."""
	var handle_pos = _get_handle_position(value)
	var handle_w = _get_handle_w()
	var handle_h = _get_handle_h()
	var ring_color = _get_disabled_color(M3Theme.get_on_surface())
	var border_w = M3Units.dp(2)  # 2dp border width
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = ring_color
	style.border_width_left = int(border_w)
	style.border_width_top = int(border_w)
	style.border_width_right = int(border_w)
	style.border_width_bottom = int(border_w)
	
	if _is_vertical():
		# Vertical: horizontal pill
		var ring_w = handle_h + M3Units.dp(8)
		var ring_h = M3Units.dp(12)
		style.corner_radius_top_left = int(ring_h / 2.0)
		style.corner_radius_top_right = int(ring_h / 2.0)
		style.corner_radius_bottom_left = int(ring_h / 2.0)
		style.corner_radius_bottom_right = int(ring_h / 2.0)
		var rect = Rect2(
			Vector2(handle_pos.x - ring_w / 2, handle_pos.y - ring_h / 2),
			Vector2(ring_w, ring_h)
		)
		_overlay.draw_style_box(style, rect)
	else:
		# Horizontal: vertical pill
		var ring_w = M3Units.dp(12)
		var ring_h = handle_h + M3Units.dp(8)
		style.corner_radius_top_left = int(ring_w / 2.0)
		style.corner_radius_top_right = int(ring_w / 2.0)
		style.corner_radius_bottom_left = int(ring_w / 2.0)
		style.corner_radius_bottom_right = int(ring_w / 2.0)
		var rect = Rect2(
			Vector2(handle_pos.x - ring_w / 2, handle_pos.y - ring_h / 2),
			Vector2(ring_w, ring_h)
		)
		_overlay.draw_style_box(style, rect)

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
	var padding = M3Units.dp(8)  # 8dp padding from track edge
	var center = _get_perp_center()
	
	if _is_vertical():
		# Vertical: start icon at bottom, end icon at top
		if _start_icon.visible:
			_start_icon.position = Vector2(
				center - _start_icon.size.x / 2,
				track_rect.end.y - _start_icon.size.y - padding
			)
		
		if _end_icon.visible:
			_end_icon.position = Vector2(
				center - _end_icon.size.x / 2,
				track_rect.position.y + padding
			)
	else:
		# Horizontal: start icon at left, end icon at right
		if _start_icon.visible:
			_start_icon.position = Vector2(
				track_rect.position.x + padding,
				center - _start_icon.size.y / 2
			)
		
		if _end_icon.visible:
			_end_icon.position = Vector2(
				track_rect.end.x - _end_icon.size.x - padding,
				center - _end_icon.size.y / 2
			)

# ============================================
# RANGE INPUT HANDLING
# ============================================

func _on_range_hitbox_input(event: InputEvent):
	if slider_variant != Variant.RANGE:
		return
	
	# Convert event position from hitbox-local to parent-local (M3Slider space)
	var local_pos = event.position + _range_hitbox.position
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var range_handle_pos = _get_handle_position(range_value)
				var hit_w: float
				var hit_h: float
				if _is_vertical():
					hit_w = _get_handle_h() * 2
					hit_h = _get_handle_w() * 4
				else:
					hit_w = _get_handle_w() * 4
					hit_h = _get_handle_h() * 2
				var hit_rect = Rect2(
					Vector2(range_handle_pos.x - hit_w / 2, range_handle_pos.y - hit_h / 2),
					Vector2(hit_w, hit_h)
				)
				if hit_rect.has_point(local_pos):
					_is_dragging_range = true
					accept_event()
			else:
				if _is_dragging_range:
					_is_dragging_range = false
					accept_event()
	
	elif event is InputEventMouseMotion:
		if _is_dragging_range:
			var track = _get_track_rect()
			var ratio: float
			if _is_vertical():
				ratio = clamp((local_pos.y - track.position.y) / track.size.y, 0.0, 1.0)
				# Invert for vertical (top is max)
				ratio = 1.0 - ratio
			else:
				ratio = clamp((local_pos.x - track.position.x) / track.size.x, 0.0, 1.0)
			var new_val = lerpf(min_value, max_value, ratio)
			if step > 0:
				new_val = snappedf(new_val, step)
			# Prevent range handle from crossing above primary handle
			new_val = min(new_val, value)
			range_value = clamp(new_val, min_value, max_value)
			range_value_changed.emit(range_value)
			_update_icon_color(_start_icon, true)
			_update_icon_color(_end_icon, false)
			if _overlay:
				_overlay.queue_redraw()
			accept_event()
