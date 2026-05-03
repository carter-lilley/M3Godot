@tool
class_name M3Button
extends Button

const M3Units = preload("res://addons/m3/M3Units.gd")

## Material 3 Button Component
## Extends native Button with M3 sizing, shapes, and variants

enum Size { EXTRA_SMALL, SMALL, MEDIUM, LARGE, EXTRA_LARGE }
enum Shape { ROUNDED, PILL }
enum Type { NORMAL, TOGGLE }
enum Variant { ELEVATED, FILLED, TONAL, OUTLINED, TEXT }

# ============================================
# SIZE SPECS (all values in dp)
# ============================================

const SIZE_SPECS = {
	Size.EXTRA_SMALL: {
		"height": 32,
		"padding_h": 12,
		"icon_size": 20,
		"icon_gap": 4,
		"radius": 8,
		"font_size": 11,
	},
	Size.SMALL: {
		"height": 40,
		"padding_h": 16,
		"icon_size": 20,
		"icon_gap": 8,
		"radius": 8,
		"font_size": 12,
	},
	Size.MEDIUM: {
		"height": 56,
		"padding_h": 24,
		"icon_size": 24,
		"icon_gap": 8,
		"radius": 12,
		"font_size": 14,
	},
	Size.LARGE: {
		"height": 96,
		"padding_h": 48,
		"icon_size": 32,
		"icon_gap": 12,
		"radius": 16,
		"font_size": 16,
	},
	Size.EXTRA_LARGE: {
		"height": 136,
		"padding_h": 64,
		"icon_size": 40,
		"icon_gap": 16,
		"radius": 16,
		"font_size": 22,
	},
}

# ============================================
# EXPORTS
# ============================================

@export var button_variant: Variant = Variant.FILLED:
	set(value):
		button_variant = value
		_update_theme()
		queue_redraw()

@export var button_size: Size = Size.MEDIUM:
	set(value):
		button_size = value
		_update_size()
		_update_theme()
		queue_redraw()

@export var button_shape: Shape = Shape.ROUNDED:
	set(value):
		button_shape = value
		_update_theme()
		queue_redraw()

@export var button_type: Type = Type.NORMAL:
	set(value):
		button_type = value
		toggle_mode = (button_type == Type.TOGGLE)
		_update_theme()
		queue_redraw()

@export var icon_name: String = "":
	set(value):
		icon_name = value
		_update_icon()
		_update_theme()
		queue_redraw()

# ============================================
# INTERNAL
# ============================================

var _icon_node: FontIcon
var _last_icon_width: float = 0.0

# Cached StyleBoxFlat instances (allocated once, mutated per state)
var _cached_style_normal: StyleBoxFlat
var _cached_style_hover: StyleBoxFlat
var _cached_style_pressed: StyleBoxFlat
var _cached_style_disabled: StyleBoxFlat
var _cached_style_focus: StyleBoxFlat
var _cached_style_hover_pressed: StyleBoxFlat

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	_initialize_caches()
	_create_icon()
	_update_icon()  # Set icon visibility first
	_update_size()
	_update_theme()  # Then configure styleboxes with correct visibility
	# Trigger icon position calculation so we get actual icon width for margins
	call_deferred("_update_icon_position")
	# Connect toggle signal to update colors when toggle state changes
	toggled.connect(_on_toggled)

func _initialize_caches():
	_cached_style_normal = StyleBoxFlat.new()
	_cached_style_hover = StyleBoxFlat.new()
	_cached_style_pressed = StyleBoxFlat.new()
	_cached_style_disabled = StyleBoxFlat.new()
	_cached_style_focus = StyleBoxFlat.new()
	_cached_style_hover_pressed = StyleBoxFlat.new()

func _create_icon():
	_icon_node = FontIcon.new()
	_icon_node.visible = false
	_icon_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_node.icon_settings = FontIconSettings.new()
	_icon_node.icon_settings.outline_color = Color.TRANSPARENT
	_icon_node.icon_settings.shadow_color = Color.TRANSPARENT
	add_child(_icon_node)

func _update_size():
	if not _cached_style_normal:
		return
	var spec = SIZE_SPECS[button_size]
	var height_px = M3Units.dp(spec["height"])
	var icon_size_px = M3Units.dp(spec["icon_size"])
	custom_minimum_size = Vector2(custom_minimum_size.x, height_px)
	size.y = height_px
	size_flags_vertical = 0  # Don't expand vertically in containers
	if _icon_node:
		_icon_node.icon_settings.icon_size = icon_size_px
		# Force icon node to exact icon_size so glyph is centered within fixed bounds
		_icon_node.custom_minimum_size = Vector2(icon_size_px, icon_size_px)
		_icon_node.size = Vector2(icon_size_px, icon_size_px)

func _update_icon():
	if not _icon_node:
		return
	
	var spec = SIZE_SPECS[button_size]
	var was_visible = _icon_node.visible
	if icon_name:
		_icon_node.visible = true
		_icon_node.icon_settings.icon_name = icon_name
		_icon_node.icon_settings.icon_size = M3Units.dp(spec["icon_size"])
	else:
		_icon_node.visible = false
	
	# Trigger theme update when icon visibility changes (affects content margins)
	if was_visible != _icon_node.visible:
		_update_theme()

func _on_toggled(_pressed: bool):
	_update_theme()
	if _icon_node and _icon_node.visible:
		_update_icon_color()
	queue_redraw()

func _get_variant_colors(selected: bool) -> Dictionary:
	"""Get colors for a variant in either selected (on) or unselected (off) toggle state."""
	var result = {}
	
	match button_variant:
		Variant.ELEVATED:
			if selected:
				result.bg = M3Theme.get_primary()
				result.text = M3Theme.get_on_primary()
			else:
				result.bg = M3Theme.get_surface_container_low()
				result.text = M3Theme.get_primary()
			result.hover_bg = M3Theme.state_overlay(result.bg, result.text, M3Theme.OPACITY_HOVER)
			result.pressed_bg = M3Theme.state_overlay(result.bg, result.text, M3Theme.OPACITY_PRESSED)
			result.disabled_bg = Color(M3Theme.get_surface().r, M3Theme.get_surface().g, M3Theme.get_surface().b, M3Theme.OPACITY_DISABLED)
			result.disabled_text = Color(M3Theme.get_on_surface().r, M3Theme.get_on_surface().g, M3Theme.get_on_surface().b, M3Theme.OPACITY_DISABLED)
			result.focus_border = result.text
			result.border_c = Color.TRANSPARENT
			result.border_w = 0
		Variant.FILLED:
			if selected:
				result.bg = M3Theme.get_primary()
				result.text = M3Theme.get_on_primary()
			else:
				result.bg = M3Theme.get_primary_container()
				result.text = M3Theme.get_on_primary_container()
			result.hover_bg = M3Theme.state_overlay(result.bg, result.text, M3Theme.OPACITY_HOVER)
			result.pressed_bg = M3Theme.state_overlay(result.bg, result.text, M3Theme.OPACITY_PRESSED)
			result.disabled_bg = Color(M3Theme.get_on_surface_variant().r, M3Theme.get_on_surface_variant().g, M3Theme.get_on_surface_variant().b, M3Theme.OPACITY_DISABLED)
			result.disabled_text = Color(M3Theme.get_on_surface().r, M3Theme.get_on_surface().g, M3Theme.get_on_surface().b, M3Theme.OPACITY_DISABLED)
			result.focus_border = result.text
			result.border_c = Color.TRANSPARENT
			result.border_w = 0
		Variant.TONAL:
			if selected:
				result.bg = M3Theme.get_secondary()
				result.text = M3Theme.get_on_secondary()
			else:
				result.bg = M3Theme.get_secondary_container()
				result.text = M3Theme.get_on_secondary_container()
			result.hover_bg = M3Theme.state_overlay(result.bg, result.text, M3Theme.OPACITY_HOVER)
			result.pressed_bg = M3Theme.state_overlay(result.bg, result.text, M3Theme.OPACITY_PRESSED)
			result.disabled_bg = Color(M3Theme.get_on_surface_variant().r, M3Theme.get_on_surface_variant().g, M3Theme.get_on_surface_variant().b, M3Theme.OPACITY_DISABLED)
			result.disabled_text = Color(M3Theme.get_on_surface().r, M3Theme.get_on_surface().g, M3Theme.get_on_surface().b, M3Theme.OPACITY_DISABLED)
			result.focus_border = result.text
			result.border_c = Color.TRANSPARENT
			result.border_w = 0
		Variant.OUTLINED:
			if selected:
				result.bg = M3Theme.get_inverse_surface()
				result.text = M3Theme.get_inverse_on_surface()
				result.border_c = Color.TRANSPARENT
			else:
				result.bg = Color.TRANSPARENT
				result.text = M3Theme.get_on_surface_variant()
				result.border_c = M3Theme.get_outline_variant()
			result.hover_bg = M3Theme.state_overlay(M3Theme.get_surface(), result.text, M3Theme.OPACITY_HOVER)
			result.pressed_bg = M3Theme.state_overlay(M3Theme.get_surface(), result.text, M3Theme.OPACITY_PRESSED)
			result.disabled_bg = Color.TRANSPARENT
			result.disabled_text = Color(M3Theme.get_on_surface().r, M3Theme.get_on_surface().g, M3Theme.get_on_surface().b, M3Theme.OPACITY_DISABLED)
			result.focus_border = result.text
			result.border_w = 1
		Variant.TEXT:
			if selected:
				result.bg = M3Theme.get_primary_container()
				result.text = M3Theme.get_on_primary_container()
			else:
				result.bg = Color.TRANSPARENT
				result.text = M3Theme.get_on_surface_variant()
			result.hover_bg = M3Theme.state_overlay(M3Theme.get_surface(), result.text, M3Theme.OPACITY_HOVER)
			result.pressed_bg = M3Theme.state_overlay(M3Theme.get_surface(), result.text, M3Theme.OPACITY_PRESSED)
			result.disabled_bg = Color.TRANSPARENT
			result.disabled_text = Color(M3Theme.get_on_surface().r, M3Theme.get_on_surface().g, M3Theme.get_on_surface().b, M3Theme.OPACITY_DISABLED)
			result.focus_border = result.text
			result.border_c = Color.TRANSPARENT
			result.border_w = 0
	
	return result

func _update_theme():
	if not _cached_style_normal:
		return
	var spec = SIZE_SPECS[button_size]
	var radius = _get_radius()
	var pad_h = M3Units.dp(spec["padding_h"])
	var font_size = M3Units.dp(spec["font_size"])
	
	# Determine colors based on variant and toggle state
	var colors: Dictionary
	var selected_colors: Dictionary
	
	if button_type == Type.TOGGLE:
		colors = _get_variant_colors(false)  # Unselected (normal) colors
		selected_colors = _get_variant_colors(true)  # Selected (pressed) colors
	else:
		colors = _get_variant_colors(false)
		selected_colors = colors  # Same for normal buttons
	
	var bg: Color = colors.bg
	var text: Color = colors.text
	var hover_bg: Color = colors.hover_bg
	var pressed_bg: Color = colors.pressed_bg
	var disabled_bg: Color = colors.disabled_bg
	var disabled_text: Color = colors.disabled_text
	var focus_border: Color = colors.focus_border
	var border_c: Color = colors.border_c
	var border_w: int = colors.border_w
	
	var sel_bg: Color = selected_colors.bg
	var sel_text: Color = selected_colors.text
	var sel_hover_bg: Color = selected_colors.hover_bg
	var sel_pressed_bg: Color = selected_colors.pressed_bg
	
	# Shadow for elevated variant
	var shadow_size: int = 0
	var shadow_off: Vector2 = Vector2.ZERO
	var shadow_col: Color = Color.TRANSPARENT
	if button_variant == Variant.ELEVATED:
		shadow_size = M3Theme.ELEVATION_1["size"]
		shadow_off = M3Theme.ELEVATION_1["offset"]
		shadow_col = M3Theme.ELEVATION_1["color"]
	
	# Normal state
	_configure_stylebox(_cached_style_normal, bg, radius, pad_h, border_w, border_c, shadow_size, shadow_off, shadow_col)
	add_theme_stylebox_override("normal", _cached_style_normal)
	
	# Hover state
	_configure_stylebox(_cached_style_hover, hover_bg, radius, pad_h, border_w, border_c, shadow_size, shadow_off, shadow_col)
	add_theme_stylebox_override("hover", _cached_style_hover)
	
	# Pressed state (elevated drops shadow on press)
	var pressed_shadow_size: int = 0 if button_variant == Variant.ELEVATED else shadow_size
	_configure_stylebox(_cached_style_pressed, pressed_bg, radius, pad_h, border_w, border_c, pressed_shadow_size, shadow_off, shadow_col)
	add_theme_stylebox_override("pressed", _cached_style_pressed)
	
	# Disabled state
	_configure_stylebox(_cached_style_disabled, disabled_bg, radius, pad_h, border_w, border_c)
	add_theme_stylebox_override("disabled", _cached_style_disabled)
	
	# Focus state
	_configure_stylebox(_cached_style_focus, bg, radius, pad_h, 3, focus_border)
	add_theme_stylebox_override("focus", _cached_style_focus)
	
	# Hover pressed state (checked hover for toggles)
	if button_type == Type.TOGGLE:
		var sel_border_w = selected_colors.border_w
		var sel_border_c = selected_colors.border_c
		_configure_stylebox(_cached_style_hover_pressed, sel_hover_bg, radius, pad_h, sel_border_w, sel_border_c, shadow_size, shadow_off, shadow_col)
		add_theme_stylebox_override("hover_pressed", _cached_style_hover_pressed)
		# Override pressed with selected colors for toggle mode
		_configure_stylebox(_cached_style_pressed, sel_bg, radius, pad_h, sel_border_w, sel_border_c, pressed_shadow_size, shadow_off, shadow_col)
		add_theme_stylebox_override("pressed", _cached_style_pressed)
		
		# Toggle selected stylebox overrides (for RTL/mirrored layouts)
		add_theme_stylebox_override("normal_mirrored", _cached_style_normal)
		add_theme_stylebox_override("hover_mirrored", _cached_style_hover)
		add_theme_stylebox_override("pressed_mirrored", _cached_style_pressed)
		add_theme_stylebox_override("hover_pressed_mirrored", _cached_style_hover_pressed)
	
	# Text colors
	if button_type == Type.TOGGLE:
		# Toggle buttons need different colors for normal vs pressed (checked)
		add_theme_color_override("font_color", text)
		add_theme_color_override("font_hover_color", text)
		add_theme_color_override("font_pressed_color", sel_text)
		add_theme_color_override("font_hover_pressed_color", sel_text)
		add_theme_color_override("font_focus_color", text)
		add_theme_color_override("font_disabled_color", disabled_text)
	else:
		add_theme_color_override("font_color", text)
		add_theme_color_override("font_hover_color", text)
		add_theme_color_override("font_pressed_color", text)
		add_theme_color_override("font_focus_color", text)
		add_theme_color_override("font_disabled_color", disabled_text)
	
	# Font size
	add_theme_font_size_override("font_size", font_size)
	
	# Text alignment
	if _icon_node and _icon_node.visible:
		alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		alignment = HORIZONTAL_ALIGNMENT_CENTER

func _configure_stylebox(style: StyleBoxFlat, bg: Color, radius: int, pad_h: int, border_w: int = 0, border_c: Color = Color.TRANSPARENT, shadow_size: int = 0, shadow_off: Vector2 = Vector2.ZERO, shadow_col: Color = Color.TRANSPARENT):
	if not style:
		return
	var spec = SIZE_SPECS[button_size]
	var icon_gap = M3Units.dp(spec["icon_gap"])
	var has_icon = _icon_node and _icon_node.visible
	
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_off
	style.shadow_color = shadow_col
	
	if has_icon:
		# Icon area is exactly icon_size wide, glyph centered within
		var icon_size_px = M3Units.dp(spec["icon_size"])
		style.content_margin_left = pad_h + icon_size_px + icon_gap
		style.content_margin_right = pad_h
	else:
		style.content_margin_left = pad_h
		style.content_margin_right = pad_h
	
	if border_w > 0:
		style.border_color = border_c
		style.border_width_left = border_w
		style.border_width_top = border_w
		style.border_width_right = border_w
		style.border_width_bottom = border_w
	else:
		style.border_width_left = 0
		style.border_width_top = 0
		style.border_width_right = 0
		style.border_width_bottom = 0

func _get_radius() -> int:
	var spec = SIZE_SPECS[button_size]
	if button_shape == Shape.PILL:
		return int(M3Units.dp(spec["height"]) / 2.0)
	return M3Units.dp(spec["radius"])

func refresh_theme():
	"""Refresh theme when dark mode changes. Called by parent."""
	_update_theme()
	if _icon_node and _icon_node.visible:
		_update_icon_color()

func _update_icon_color():
	if not _icon_node or not _icon_node.visible:
		return
	
	var is_selected = button_type == Type.TOGGLE and button_pressed
	var color: Color
	
	match button_variant:
		Variant.ELEVATED:
			color = M3Theme.get_on_primary() if is_selected else M3Theme.get_primary()
		Variant.FILLED:
			color = M3Theme.get_on_primary() if is_selected else M3Theme.get_on_primary_container()
		Variant.TONAL:
			color = M3Theme.get_on_secondary() if is_selected else M3Theme.get_on_secondary_container()
		Variant.OUTLINED:
			color = M3Theme.get_inverse_on_surface() if is_selected else M3Theme.get_on_surface_variant()
		Variant.TEXT:
			color = M3Theme.get_on_primary_container() if is_selected else M3Theme.get_on_surface_variant()
	
	if _icon_node.icon_settings.icon_color != color:
		_icon_node.icon_settings.icon_color = color
		_icon_node._on_icon_settings_changed()

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		_update_icon_position()

func _update_icon_position():
	if not _icon_node or not _icon_node.visible:
		return
	
	var spec = SIZE_SPECS[button_size]
	var pad_h = M3Units.dp(spec["padding_h"])
	var icon_size_px = M3Units.dp(spec["icon_size"])
	
	# Position icon area at left padding, vertically centered
	_icon_node.position = Vector2(
		pad_h,
		size.y / 2.0 - icon_size_px / 2.0
	)
	
	# Re-apply theme with spec icon size for correct text positioning
	_update_theme()
