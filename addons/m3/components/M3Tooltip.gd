@tool
class_name M3Tooltip
extends Control

const M3Units = preload("res://addons/m3/M3Units.gd")

## Material 3 Tooltip Component
## Renders as a top_level overlay positioned relative to its anchor node.
## Supports plain (compact, dark) and rich (spacious, light) variants.

enum Variant { PLAIN, RICH }

# ============================================
# EXPORTS
# ============================================

@export var m3_tooltip_text: String = "":
	set(value):
		if value == m3_tooltip_text:
			return
		m3_tooltip_text = value
		if _ready_called:
			_update_content()

@export var m3_tooltip_variant: Variant = Variant.PLAIN:
	set(value):
		if value == m3_tooltip_variant:
			return
		m3_tooltip_variant = value
		if _ready_called:
			_update_appearance()
			_update_content()

@export var show_delay_ms: int = 500

# ============================================
# CONSTANTS
# ============================================

const PLAIN_PADDING_H := 8.0
const PLAIN_PADDING_V := 4.0
const PLAIN_RADIUS := 4.0
const PLAIN_MAX_WIDTH := 120.0

const RICH_PADDING := 16.0
const RICH_RADIUS := 12.0
const RICH_MAX_WIDTH := 280.0

const VIEWPORT_MARGIN := 8.0
const OFFSET_WITH_BOUNDARY := 4.0
const OFFSET_WITHOUT_BOUNDARY := 8.0

# ============================================
# INTERNAL
# ============================================

var _label: Label
var _rich_label: RichTextLabel
var _bg_panel: Panel
var _ready_called: bool = false
var _show_timer: Timer
var _anchor_node: Control = null

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	top_level = true
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	
	_create_visuals()
	_create_timer()
	_update_appearance()
	_update_content()
	
	_ready_called = true

func _create_visuals():
	# Background panel
	_bg_panel = Panel.new()
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_panel)
	
	# Plain label
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	
	# Rich label
	_rich_label = RichTextLabel.new()
	_rich_label.bbcode_enabled = true
	_rich_label.fit_content = true
	_rich_label.scroll_active = false
	_rich_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rich_label)

func _create_timer():
	_show_timer = Timer.new()
	_show_timer.one_shot = true
	_show_timer.wait_time = show_delay_ms / 1000.0
	_show_timer.timeout.connect(_on_timer_timeout)
	add_child(_show_timer)

# ============================================
# PUBLIC API
# ============================================

## Show tooltip anchored to the given Control node.
func show_for(anchor: Control):
	if not anchor:
		return
	_anchor_node = anchor
	
	# Cancel any pending show
	_show_timer.stop()
	hide()
	
	# Start delay timer
	_show_timer.start()

## Hide tooltip immediately.
func hide_tooltip():
	_show_timer.stop()
	hide()

# ============================================
# PRIVATE
# ============================================

func _on_timer_timeout():
	if not _anchor_node:
		return
	
	_update_appearance()
	_update_content()
	_position_tooltip()
	visible = true
	queue_redraw()

func _position_tooltip():
	if not _anchor_node:
		return
	
	var anchor_rect = _anchor_node.get_global_rect()
	var tooltip_size = _get_tooltip_size()
	var viewport_size = get_viewport_rect().size
	var margin = M3Units.dp(VIEWPORT_MARGIN)
	
	var pos: Vector2
	
	if m3_tooltip_variant == Variant.PLAIN:
		pos = _position_plain(anchor_rect, tooltip_size, viewport_size, margin)
	else:
		pos = _position_rich(anchor_rect, tooltip_size, viewport_size, margin)
	
	# Snap to 8dp grid
	var grid = M3Units.dp(8)
	pos = Vector2(
		floor(pos.x / grid) * grid,
		floor(pos.y / grid) * grid
	)
	
	global_position = pos
	size = tooltip_size
	
	# Update panel size
	_bg_panel.position = Vector2.ZERO
	_bg_panel.size = tooltip_size
	
	# Update label position
	if m3_tooltip_variant == Variant.PLAIN:
		var pad_h = M3Units.dp(PLAIN_PADDING_H)
		_label.position = Vector2(pad_h, 0)
		_label.size = Vector2(tooltip_size.x - pad_h * 2, tooltip_size.y)
	else:
		var pad = M3Units.dp(RICH_PADDING)
		_rich_label.position = Vector2(pad, pad)
		_rich_label.size = Vector2(tooltip_size.x - pad * 2, tooltip_size.y - pad * 2)

func _position_plain(anchor_rect: Rect2, tooltip_size: Vector2, viewport_size: Vector2, margin: float) -> Vector2:
	var offset = M3Units.dp(_get_offset_for_anchor())
	var placement = _get_placement_for_anchor()
	
	# Horizontal: centered on anchor
	var pos = anchor_rect.position + Vector2(
		(anchor_rect.size.x - tooltip_size.x) / 2.0,
		0
	)
	
	# Vertical: above or below based on placement
	if placement == "below":
		pos.y = anchor_rect.position.y + anchor_rect.size.y + offset
	else:
		pos.y = anchor_rect.position.y - tooltip_size.y - offset
	
	# Clamp to viewport bounds
	pos.x = clamp(pos.x, margin, viewport_size.x - tooltip_size.x - margin)
	pos.y = clamp(pos.y, margin, viewport_size.y - tooltip_size.y - margin)
	
	# If preferred placement doesn't fit, flip
	if placement == "below" and pos.y + tooltip_size.y > viewport_size.y - margin:
		pos.y = anchor_rect.position.y - tooltip_size.y - offset
		pos.y = max(pos.y, margin)
	elif placement == "above" and pos.y < margin:
		pos.y = anchor_rect.position.y + anchor_rect.size.y + offset
		pos.y = min(pos.y, viewport_size.y - tooltip_size.y - margin)
	
	return pos

func _position_rich(anchor_rect: Rect2, tooltip_size: Vector2, viewport_size: Vector2, margin: float) -> Vector2:
	var gap = M3Units.dp(8)
	
	# Try positions: bottom-right, bottom-left, top-right, top-left
	var positions = [
		Vector2(anchor_rect.position.x + anchor_rect.size.x + gap, anchor_rect.position.y + anchor_rect.size.y + gap),  # bottom-right
		Vector2(anchor_rect.position.x - tooltip_size.x - gap, anchor_rect.position.y + anchor_rect.size.y + gap),      # bottom-left
		Vector2(anchor_rect.position.x + anchor_rect.size.x + gap, anchor_rect.position.y - tooltip_size.y - gap),      # top-right
		Vector2(anchor_rect.position.x - tooltip_size.x - gap, anchor_rect.position.y - tooltip_size.y - gap),          # top-left
	]
	
	for pos in positions:
		# Check if this position keeps the tooltip on screen and doesn't overlap anchor
		var fits_x = pos.x >= margin and pos.x + tooltip_size.x <= viewport_size.x - margin
		var fits_y = pos.y >= margin and pos.y + tooltip_size.y <= viewport_size.y - margin
		var overlaps_anchor = Rect2(pos, tooltip_size).intersects(anchor_rect)
		
		if fits_x and fits_y and not overlaps_anchor:
			return pos
	
	# Fallback: clamp the first position (bottom-right) to viewport, even if it overlaps
	var pos = positions[0]
	pos.x = clamp(pos.x, margin, viewport_size.x - tooltip_size.x - margin)
	pos.y = clamp(pos.y, margin, viewport_size.y - tooltip_size.y - margin)
	return pos

func _get_offset_for_anchor() -> float:
	if _has_visual_boundary(_anchor_node):
		return OFFSET_WITH_BOUNDARY
	return OFFSET_WITHOUT_BOUNDARY

func _get_placement_for_anchor() -> String:
	if _is_in_app_bar(_anchor_node):
		return "below"
	return "above"

func _has_visual_boundary(node: Control) -> bool:
	if not node:
		return false
	# M3 components with clear visual boundaries
	if node is M3Button or node is M3IconButton or node is M3Switch or node is M3Slider or node is M3NavigationDestination or node is M3TextField:
		return true
	# Native Godot controls that typically have boundaries
	if node is Button or node is LineEdit or node is TextEdit or node is CheckBox or node is CheckButton or node is OptionButton:
		return true
	return false

func _is_in_app_bar(node: Control) -> bool:
	if not node:
		return false
	var parent = node.get_parent()
	while parent:
		if parent is M3NavigationBar or parent is M3NavigationRail:
			return true
		parent = parent.get_parent()
	return false

func _get_tooltip_size() -> Vector2:
	if m3_tooltip_variant == Variant.PLAIN:
		var pad_h = M3Units.dp(PLAIN_PADDING_H)
		var pad_v = M3Units.dp(PLAIN_PADDING_V)
		var max_w = M3Units.dp(PLAIN_MAX_WIDTH)
		
		var old_size = _label.size
		var old_autowrap = _label.autowrap_mode
		
		# Measure unwrapped width for sizing
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var unwrapped_size = _label.get_minimum_size()
		
		# Measure wrapped height at max width
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.size.x = max_w - pad_h * 2
		var wrapped_size = _label.get_minimum_size()
		
		_label.size = old_size
		_label.autowrap_mode = old_autowrap
		
		var width = min(unwrapped_size.x + pad_h * 2, max_w)
		var height = max(wrapped_size.y + pad_v * 2, M3Units.dp(24))
		
		return Vector2(width, height)
	else:
		var pad = M3Units.dp(RICH_PADDING)
		var max_w = M3Units.dp(RICH_MAX_WIDTH)
		
		_rich_label.size = Vector2(max_w - pad * 2, 0)
		var text_size = _rich_label.get_content_height()
		var width = max_w
		var height = text_size + pad * 2
		
		return Vector2(width, height)

func _update_appearance():
	var fonts = M3Theme.load_fonts()
	
	if m3_tooltip_variant == Variant.PLAIN:
		_label.visible = true
		_rich_label.visible = false
		
		# Plain: inverse_surface bg, inverse_on_surface text
		var bg = M3Theme.get_inverse_surface()
		var text_color = M3Theme.get_inverse_on_surface()
		
		_label.add_theme_color_override("font_color", text_color)
		_label.add_theme_font_override("font", fonts["medium"])
		_label.add_theme_font_size_override("font_size", M3Units.dp(12))
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(M3Units.dpi(PLAIN_RADIUS))
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 1.0
		_bg_panel.add_theme_stylebox_override("panel", sb)
		
	else:
		_label.visible = false
		_rich_label.visible = true
		
		# Rich: surface_container bg, on_surface text
		var bg = M3Theme.get_surface_container()
		var text_color = M3Theme.get_on_surface()
		
		_rich_label.add_theme_color_override("default_color", text_color)
		_rich_label.add_theme_font_override("normal_font", fonts["regular"])
		_rich_label.add_theme_font_override("bold_font", fonts["bold"])
		_rich_label.add_theme_font_size_override("normal_font_size", M3Units.dp(14))
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(M3Units.dpi(RICH_RADIUS))
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 1.0
		_bg_panel.add_theme_stylebox_override("panel", sb)

func _update_content():
	if m3_tooltip_variant == Variant.PLAIN:
		_label.text = m3_tooltip_text
	else:
		_rich_label.text = m3_tooltip_text

func refresh_theme():
	_update_appearance()
	if visible:
		_position_tooltip()
		queue_redraw()
