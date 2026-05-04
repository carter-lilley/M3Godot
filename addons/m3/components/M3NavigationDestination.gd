@tool
class_name M3NavigationDestination
extends Button

## Material 3 Navigation Destination
## Individual item used in NavigationBar and NavigationRail.
## Supports VERTICAL (icon above label) and HORIZONTAL (icon beside label) layouts.

enum LayoutMode { VERTICAL, HORIZONTAL }

# ============================================
# EXPORTS
# ============================================

@export var destination_icon: String = "":
	set(value):
		if value == destination_icon:
			return
		destination_icon = value
		_update_icon()

@export var destination_label: String = "":
	set(value):
		if value == destination_label:
			return
		destination_label = value
		_update_label()

@export var destination_layout: LayoutMode = LayoutMode.VERTICAL:
	set(value):
		if value == destination_layout:
			return
		destination_layout = value
		_update_layout()

@export var active: bool = false:
	set(value):
		if value == active:
			return
		active = value
		_update_theme()
		queue_redraw()

# ============================================
# INTERNAL
# ============================================

var _icon_node: FontIcon
var _label_node: Label

var _cached_style_normal: StyleBoxFlat
var _cached_style_pressed: StyleBoxFlat
var _cached_style_hover: StyleBoxFlat
var _cached_style_disabled: StyleBoxFlat
var _cached_style_focus: StyleBoxFlat

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	_initialize_caches()
	_create_children()
	flat = true  # Use custom styling, not Button's default
	_update_layout()
	_update_theme()

func _initialize_caches():
	_cached_style_normal = StyleBoxFlat.new()
	_cached_style_pressed = StyleBoxFlat.new()
	_cached_style_hover = StyleBoxFlat.new()
	_cached_style_disabled = StyleBoxFlat.new()
	_cached_style_focus = StyleBoxFlat.new()

func _create_children():
	# Create icon
	_icon_node = FontIcon.new()
	_icon_node.visible = false
	_icon_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_node.icon_settings = FontIconSettings.new()
	_icon_node.icon_settings.outline_color = Color.TRANSPARENT
	_icon_node.icon_settings.shadow_color = Color.TRANSPARENT
	add_child(_icon_node)
	
	# Create label
	_label_node = Label.new()
	_label_node.visible = false
	_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label_node)
	
	_update_icon()
	_update_label()

func _update_icon():
	if not _icon_node:
		return
	if destination_icon:
		_icon_node.visible = true
		_icon_node.icon_settings.icon_name = destination_icon
		_icon_node.icon_settings.icon_size = M3Units.dp(24)
	else:
		_icon_node.visible = false

func _update_label():
	if not _label_node:
		return
	if destination_label:
		_label_node.visible = true
		_label_node.text = destination_label
		_label_node.add_theme_font_size_override("font_size", M3Units.dp(12))
	else:
		_label_node.visible = false

func _update_layout():
	if not _icon_node or not _label_node:
		return
	
	var icon_size_px = M3Units.dp(24)
	
	match destination_layout:
		LayoutMode.VERTICAL:
			# Icon above label, both centered
			_icon_node.position = Vector2(
				size.x / 2.0 - icon_size_px / 2.0,
				M3Units.dp(12)
			)
			_label_node.position = Vector2(
				0,
				_icon_node.position.y + icon_size_px + M3Units.dp(4)
			)
			_label_node.size = Vector2(size.x, M3Units.dp(16))
			_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
		LayoutMode.HORIZONTAL:
			# Icon left, label right
			var left_pad = M3Units.dp(16) if active else M3Units.dp(24)
			_icon_node.position = Vector2(left_pad, size.y / 2.0 - icon_size_px / 2.0)
			_label_node.position = Vector2(
				_icon_node.position.x + icon_size_px + M3Units.dp(12),
				0
			)
			_label_node.size = Vector2(size.x - _label_node.position.x - M3Units.dp(16), size.y)
			_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
	_update_theme()

# ============================================
# THEME
# ============================================

func _update_theme():
	if not _cached_style_normal:
		return
	
	var radius = M3Units.dp(16)
	
	# Active colors: secondary container + on_secondary_container
	# Inactive colors: transparent + on_surface_variant
	var bg: Color
	var text: Color
	var hover_bg: Color
	var pressed_bg: Color
	var disabled_bg: Color
	var disabled_text: Color
	var focus_border: Color
	
	if active:
		bg = M3Theme.get_secondary_container()
		text = M3Theme.get_on_secondary_container()
		hover_bg = M3Theme.state_overlay(bg, text, M3Theme.OPACITY_HOVER)
		pressed_bg = M3Theme.state_overlay(bg, text, M3Theme.OPACITY_PRESSED)
		disabled_bg = M3Theme.disabled_color(bg)
		disabled_text = M3Theme.disabled_color(text)
		focus_border = text
	else:
		bg = Color.TRANSPARENT
		text = M3Theme.get_on_surface_variant()
		hover_bg = M3Theme.state_overlay(M3Theme.get_surface(), text, M3Theme.OPACITY_HOVER)
		pressed_bg = M3Theme.state_overlay(M3Theme.get_surface(), text, M3Theme.OPACITY_PRESSED)
		disabled_bg = Color.TRANSPARENT
		disabled_text = M3Theme.disabled_color(text)
		focus_border = text
	
	# Configure styleboxes
	_configure_stylebox(_cached_style_normal, bg, radius)
	_configure_stylebox(_cached_style_hover, hover_bg, radius)
	_configure_stylebox(_cached_style_pressed, pressed_bg, radius)
	_configure_stylebox(_cached_style_disabled, disabled_bg, radius)
	_configure_stylebox(_cached_style_focus, bg, radius, 3, focus_border)
	
	add_theme_stylebox_override("normal", _cached_style_normal)
	add_theme_stylebox_override("hover", _cached_style_hover)
	add_theme_stylebox_override("pressed", _cached_style_pressed)
	add_theme_stylebox_override("disabled", _cached_style_disabled)
	add_theme_stylebox_override("focus", _cached_style_focus)
	
	# Text/icon colors
	add_theme_color_override("font_color", text)
	add_theme_color_override("font_hover_color", text)
	add_theme_color_override("font_pressed_color", text)
	add_theme_color_override("font_focus_color", text)
	add_theme_color_override("font_disabled_color", disabled_text)
	
	# Update icon color
	if _icon_node and _icon_node.visible:
		_icon_node.icon_settings.icon_color = text if not disabled else disabled_text

func _configure_stylebox(style: StyleBoxFlat, bg: Color, radius: int, border_w: int = 0, border_c: Color = Color.TRANSPARENT):
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(M3Units.dp(4))
	if border_w > 0:
		style.border_color = border_c
		style.set_border_width_all(border_w)
	else:
		style.set_border_width_all(0)

func refresh_theme():
	_update_theme()

# ============================================
# INPUT
# ============================================

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		_update_layout()
