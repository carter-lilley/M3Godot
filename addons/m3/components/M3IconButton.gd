@tool
class_name M3IconButton
extends M3Button

## Material 3 Icon Button Component
## Extends M3Button with icon-only layout: fixed square sizes, centered icon,
## circular or rounded-square shapes. Reuses color and toggle logic from M3Button.

# Override parent's enums for icon-button-specific values
enum IconSize { EXTRA_SMALL, SMALL, MEDIUM, LARGE, EXTRA_LARGE }
enum IconShape { CIRCULAR, ROUNDED_SQUARE }
enum IconVariant { STANDARD, FILLED, TONAL, OUTLINED }

# ============================================
# ICON BUTTON SIZE SPECS (all values in dp)
# All sizes are square: width == height
# ============================================

const ICON_SIZE_SPECS = {
	IconSize.EXTRA_SMALL: {
		"size": 32,
		"icon_size": 18,
		"radius": 8,
	},
	IconSize.SMALL: {
		"size": 40,
		"icon_size": 20,
		"radius": 10,
	},
	IconSize.MEDIUM: {
		"size": 48,
		"icon_size": 24,
		"radius": 12,
	},
	IconSize.LARGE: {
		"size": 56,
		"icon_size": 28,
		"radius": 14,
	},
	IconSize.EXTRA_LARGE: {
		"size": 64,
		"icon_size": 32,
		"radius": 16,
	},
}

# ============================================
# EXPORTS
# ============================================

@export var icon_button_size: IconSize = IconSize.MEDIUM:
	set(value):
		if value == icon_button_size:
			return
		icon_button_size = value
		_update_size()
		_update_theme()
		queue_redraw()

@export var icon_button_shape: IconShape = IconShape.CIRCULAR:
	set(value):
		if value == icon_button_shape:
			return
		icon_button_shape = value
		_update_theme()
		queue_redraw()

@export var icon_button_variant: IconVariant = IconVariant.STANDARD:
	set(value):
		if value == icon_button_variant:
			return
		icon_button_variant = value
		_update_theme()
		queue_redraw()

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	super._ready()
	# Hide text, this is icon-only
	text = ""
	# Fixed size, don't expand in containers
	size_flags_horizontal = 0
	size_flags_vertical = 0

# ============================================
# OVERRIDE GEOMETRY METHODS
# ============================================

func _update_size():
	if not _cached_style_normal:
		return
	var spec = ICON_SIZE_SPECS[icon_button_size]
	var size_px = M3Units.dp(spec["size"])
	var icon_size_px = M3Units.dp(spec["icon_size"])
	
	# Force square dimensions
	custom_minimum_size = Vector2(size_px, size_px)
	
	if _icon_node:
		_icon_node.icon_settings.icon_size = icon_size_px
		_icon_node.custom_minimum_size = Vector2(icon_size_px, icon_size_px)
		_icon_node.size = Vector2(icon_size_px, icon_size_px)

func _update_icon():
	if not _icon_node:
		return
	
	var spec = ICON_SIZE_SPECS[icon_button_size]
	var was_visible = _icon_node.visible
	if icon_name:
		_icon_node.visible = true
		_icon_node.icon_settings.icon_name = icon_name
		_icon_node.icon_settings.icon_size = M3Units.dp(spec["icon_size"])
	else:
		_icon_node.visible = false
	
	if was_visible != _icon_node.visible:
		_update_theme()

func _update_icon_position():
	if not _icon_node or not _icon_node.visible:
		return
	
	var spec = ICON_SIZE_SPECS[icon_button_size]
	var icon_size_px = M3Units.dp(spec["icon_size"])
	
	# Center icon both horizontally and vertically
	_icon_node.position = Vector2(
		size.x / 2.0 - icon_size_px / 2.0,
		size.y / 2.0 - icon_size_px / 2.0
	)

func _configure_stylebox(style: StyleBoxFlat, bg: Color, radius: int, pad_h: int, border_w: int = 0, border_c: Color = Color.TRANSPARENT, shadow_size: int = 0, shadow_off: Vector2 = Vector2.ZERO, shadow_col: Color = Color.TRANSPARENT):
	if not style:
		return
	
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(pad_h)
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_off
	style.shadow_color = shadow_col
	
	if border_w > 0:
		style.border_color = border_c
		style.set_border_width_all(border_w)
	else:
		style.set_border_width_all(0)

func _get_radius() -> int:
	var spec = ICON_SIZE_SPECS[icon_button_size]
	if icon_button_shape == IconShape.CIRCULAR:
		return int(M3Units.dp(spec["size"]) / 2.0)
	return M3Units.dp(spec["radius"])

# ============================================
# OVERRIDE THEME METHOD
# ============================================

func _update_theme():
	if not _cached_style_normal:
		return
	
	var spec = ICON_SIZE_SPECS[icon_button_size]
	var radius = _get_radius()
	var pad_h := 0  # No extra padding for icon buttons
	
	# Color logic:
	# - Toggle: unselected=false, selected=true (always distinct)
	# - Non-toggle: most variants use selected=true colors as default,
	#   except STANDARD which is always icon-only
	var colors: Dictionary
	var selected_colors: Dictionary
	
	if button_type == Type.TOGGLE:
		colors = _get_icon_variant_colors(false)
		selected_colors = _get_icon_variant_colors(true)
	else:
		# Non-toggle: default state matches the "selected" colors for
		# FILLED/Tonal (showing their container), and "unselected" for
		# STANDARD/Outlined (no container or outline)
		match icon_button_variant:
			IconVariant.FILLED, IconVariant.TONAL:
				colors = _get_icon_variant_colors(true)
			_:
				colors = _get_icon_variant_colors(false)
		selected_colors = colors
	
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
	
	# Normal state
	_configure_stylebox(_cached_style_normal, bg, radius, pad_h, border_w, border_c)
	add_theme_stylebox_override("normal", _cached_style_normal)
	
	# Hover state
	_configure_stylebox(_cached_style_hover, hover_bg, radius, pad_h, border_w, border_c)
	add_theme_stylebox_override("hover", _cached_style_hover)
	
	# Pressed state
	_configure_stylebox(_cached_style_pressed, pressed_bg, radius, pad_h, border_w, border_c)
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
		_configure_stylebox(_cached_style_hover_pressed, sel_hover_bg, radius, pad_h, sel_border_w, sel_border_c)
		add_theme_stylebox_override("hover_pressed", _cached_style_hover_pressed)
		_configure_stylebox(_cached_style_pressed, sel_bg, radius, pad_h, sel_border_w, sel_border_c)
		add_theme_stylebox_override("pressed", _cached_style_pressed)
		
		add_theme_stylebox_override("normal_mirrored", _cached_style_normal)
		add_theme_stylebox_override("hover_mirrored", _cached_style_hover)
		add_theme_stylebox_override("pressed_mirrored", _cached_style_pressed)
		add_theme_stylebox_override("hover_pressed_mirrored", _cached_style_hover_pressed)
	
	# Text colors (for icon color sync)
	var current_text: Color
	if disabled:
		current_text = disabled_text
	elif button_type == Type.TOGGLE:
		var target_selected: bool = button_pressed != _is_pressing
		current_text = sel_text if target_selected else text
	else:
		current_text = text
	
	add_theme_color_override("font_color", current_text)
	add_theme_color_override("font_hover_color", current_text)
	add_theme_color_override("font_pressed_color", current_text)
	add_theme_color_override("font_hover_pressed_color", current_text)
	add_theme_color_override("font_focus_color", current_text)
	add_theme_color_override("font_disabled_color", disabled_text)
	
	# Hide text, center alignment
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Sync icon color (pass cached colors to avoid recomputation)
	_update_icon_color(colors, selected_colors)

# ============================================
# ICON VARIANT COLORS
# ============================================

func _get_icon_variant_colors(selected: bool) -> Dictionary:
	var result = {}
	
	match icon_button_variant:
		IconVariant.STANDARD:
			# Standard: always no container; only icon color changes
			if selected:
				result.bg = Color.TRANSPARENT
				result.text = M3Theme.get_primary()
				result.hover_bg = Color(M3Theme.get_primary().r, M3Theme.get_primary().g, M3Theme.get_primary().b, M3Theme.OPACITY_HOVER)
				result.pressed_bg = Color(M3Theme.get_primary().r, M3Theme.get_primary().g, M3Theme.get_primary().b, M3Theme.OPACITY_PRESSED)
			else:
				result.bg = Color.TRANSPARENT
				result.text = M3Theme.get_on_surface_variant()
				result.hover_bg = Color(M3Theme.get_on_surface_variant().r, M3Theme.get_on_surface_variant().g, M3Theme.get_on_surface_variant().b, M3Theme.OPACITY_HOVER)
				result.pressed_bg = Color(M3Theme.get_on_surface_variant().r, M3Theme.get_on_surface_variant().g, M3Theme.get_on_surface_variant().b, M3Theme.OPACITY_PRESSED)
			result.disabled_bg = Color.TRANSPARENT
			result.disabled_text = M3Theme.disabled_color(M3Theme.get_on_surface())
			result.focus_border = result.text
			result.border_c = Color.TRANSPARENT
			result.border_w = 0
		IconVariant.FILLED:
			# Filled: unselected = surface container, selected = primary
			if selected:
				result.bg = M3Theme.get_primary()
				result.text = M3Theme.get_on_primary()
			else:
				result.bg = M3Theme.get_surface_container()
				result.text = M3Theme.get_on_surface_variant()
			result.hover_bg = M3Theme.state_overlay(result.bg, result.text, M3Theme.OPACITY_HOVER)
			result.pressed_bg = M3Theme.state_overlay(result.bg, result.text, M3Theme.OPACITY_PRESSED)
			result.disabled_bg = M3Theme.disabled_color(M3Theme.get_on_surface_variant())
			result.disabled_text = M3Theme.disabled_color(M3Theme.get_on_surface())
			result.focus_border = result.text
			result.border_c = Color.TRANSPARENT
			result.border_w = 0
		IconVariant.TONAL:
			# Tonal: unselected = secondary container, selected = secondary
			if selected:
				result.bg = M3Theme.get_secondary()
				result.text = M3Theme.get_on_secondary()
			else:
				result.bg = M3Theme.get_secondary_container()
				result.text = M3Theme.get_on_secondary_container()
			result.hover_bg = M3Theme.state_overlay(result.bg, result.text, M3Theme.OPACITY_HOVER)
			result.pressed_bg = M3Theme.state_overlay(result.bg, result.text, M3Theme.OPACITY_PRESSED)
			result.disabled_bg = M3Theme.disabled_color(M3Theme.get_on_surface_variant())
			result.disabled_text = M3Theme.disabled_color(M3Theme.get_on_surface())
			result.focus_border = result.text
			result.border_c = Color.TRANSPARENT
			result.border_w = 0
		IconVariant.OUTLINED:
			if selected:
				result.bg = M3Theme.get_inverse_surface()
				result.text = M3Theme.get_inverse_on_surface()
				result.border_c = Color.TRANSPARENT
				result.hover_bg = M3Theme.state_overlay(M3Theme.get_inverse_surface(), result.text, M3Theme.OPACITY_HOVER)
				result.pressed_bg = M3Theme.state_overlay(M3Theme.get_inverse_surface(), result.text, M3Theme.OPACITY_PRESSED)
			else:
				result.bg = Color.TRANSPARENT
				result.text = M3Theme.get_on_surface_variant()
				result.border_c = M3Theme.get_outline_variant()
				result.hover_bg = M3Theme.state_overlay(M3Theme.get_surface(), result.text, M3Theme.OPACITY_HOVER)
				result.pressed_bg = M3Theme.state_overlay(M3Theme.get_surface(), result.text, M3Theme.OPACITY_PRESSED)
			result.disabled_bg = Color.TRANSPARENT
			result.disabled_text = M3Theme.disabled_color(M3Theme.get_on_surface())
			result.focus_border = result.text
			result.border_w = 1
	
	return result

# ============================================
# OVERRIDE ICON COLOR (uses icon variant colors)
# ============================================

func _update_icon_color(colors: Dictionary = {}, selected_colors: Dictionary = {}):
	if not _icon_node or not _icon_node.visible:
		return
	
	# Use cached colors if provided (avoids redundant _get_icon_variant_colors calls)
	if colors.is_empty():
		colors = _get_icon_variant_colors(false)
	if selected_colors.is_empty():
		selected_colors = _get_icon_variant_colors(true)
	
	var current_text: Color
	if disabled:
		current_text = colors.disabled_text
	elif button_type == Type.TOGGLE:
		var target_selected: bool = button_pressed != _is_pressing
		current_text = selected_colors.text if target_selected else colors.text
	else:
		current_text = colors.text
	
	if _icon_node.icon_settings.icon_color != current_text:
		_icon_node.icon_settings.icon_color = current_text
		# FontIcon auto-updates via signal from settings resource
