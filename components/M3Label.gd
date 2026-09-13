class_name M3Label
extends Label

## Material 3 Label Component
## Drop-in Label replacement that auto-applies M3 typography and colors.

enum Style {
	DISPLAY_LARGE,
	DISPLAY_MEDIUM,
	DISPLAY_SMALL,
	HEADLINE_LARGE,
	HEADLINE_MEDIUM,
	HEADLINE_SMALL,
	TITLE_LARGE,
	TITLE_MEDIUM,
	TITLE_SMALL,
	BODY_LARGE,
	BODY_MEDIUM,
	BODY_SMALL,
	LABEL_LARGE,
	LABEL_MEDIUM,
	LABEL_SMALL,
}

@export var label_style: Style = Style.BODY_MEDIUM:
	set(value):
		if value == label_style:
			return
		label_style = value
		if is_node_ready():
			_apply_style()

@export var use_on_surface_variant: bool = false:
	set(value):
		if value == use_on_surface_variant:
			return
		use_on_surface_variant = value
		if is_node_ready():
			_apply_style()

## Extra leading between lines in pixels; 0 uses the font's default spacing.
@export var line_spacing: float = 0.0:
	set(value):
		if value == line_spacing:
			return
		line_spacing = value
		if is_node_ready():
			_apply_style()

# ============================================
# STYLE SPEC (M3 Type Scale)
# ============================================

const _STYLE_SPECS: Dictionary = {
	Style.DISPLAY_LARGE:   {"weight": "bold", "size": 57},
	Style.DISPLAY_MEDIUM:  {"weight": "bold", "size": 45},
	Style.DISPLAY_SMALL:   {"weight": "bold", "size": 36},
	Style.HEADLINE_LARGE:  {"weight": "bold", "size": 32},
	Style.HEADLINE_MEDIUM: {"weight": "bold", "size": 28},
	Style.HEADLINE_SMALL:  {"weight": "bold", "size": 24},
	Style.TITLE_LARGE:     {"weight": "medium",  "size": 22},
	Style.TITLE_MEDIUM:    {"weight": "medium",  "size": 16},
	Style.TITLE_SMALL:     {"weight": "medium",  "size": 14},
	Style.BODY_LARGE:      {"weight": "regular", "size": 16},
	Style.BODY_MEDIUM:     {"weight": "regular", "size": 14},
	Style.BODY_SMALL:      {"weight": "regular", "size": 12},
	Style.LABEL_LARGE:     {"weight": "medium",  "size": 14},
	Style.LABEL_MEDIUM:    {"weight": "medium",  "size": 12},
	Style.LABEL_SMALL:     {"weight": "medium",  "size": 11},
}

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	_apply_style()

# ============================================
# STYLE APPLICATION
# ============================================

func _apply_style():
	var spec = _STYLE_SPECS.get(label_style, {"weight": "regular", "size": 14})
	var fonts = M3Theme.load_fonts()
	var font = fonts.get(spec.weight, fonts.get("regular", null))
	var font_size = M3Units.dp(spec.size)
	var color = M3Theme.get_on_surface_variant() if use_on_surface_variant else M3Theme.get_on_surface()
	
	if font:
		add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", color)
	if line_spacing != 0.0:
		add_theme_constant_override("line_spacing", int(line_spacing))
	else:
		remove_theme_constant_override("line_spacing")

func refresh_theme():
	_apply_style()
