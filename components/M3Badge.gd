class_name M3Badge
extends Control

## M3-style circular badge drawn via _draw() so the glyph is centered from the
## font's actual ascent/descent metrics rather than Label layout behavior.
## The glyph renders slightly larger than the circle; icon-font padding bleeds
## past the edge invisibly (clip_contents is off).

@export var icon_name: String = "":
	set(value):
		if value == icon_name:
			return
		icon_name = value
		visible = not icon_name.is_empty()
		queue_redraw()

@export_enum("MaterialIcons", "Emojis", "ControllerIcons")
var icon_font: String = "MaterialIcons":
	set(value):
		if value == icon_font:
			return
		icon_font = value
		queue_redraw()

## Glyph size relative to the badge diameter. >1.0 crops the icon font's
## built-in padding so the visible artwork fills the circle.
var glyph_fill_ratio := 1.1

## Multi-glyph (pill) mode: icon_name may hold several glyph names joined by
## "+" (e.g. "xbox-left-trigger+xbox-view"), rendered side by side in a pill.
const PILL_PAD_X_RATIO := 0.25
const PILL_SPACING_RATIO := 0.08

func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = not icon_name.is_empty()

func _get_glyph_names() -> PackedStringArray:
	return icon_name.split("+", false)

## Returns the size the badge needs at the given height: a square for a single
## glyph (classic circle), a wider pill for multi-glyph names.
func measure(badge_height: float) -> Vector2:
	var names := _get_glyph_names()
	if names.size() <= 1:
		return Vector2(badge_height, badge_height)
	var font := _get_font()
	if font == null:
		return Vector2(badge_height, badge_height)
	var glyph_size := max(1, int(badge_height * glyph_fill_ratio))
	var width := badge_height * PILL_PAD_X_RATIO * 2.0
	for i in range(names.size()):
		var ch: String = IconsFonts.get_icon_char(icon_font, names[i])
		if ch.is_empty():
			continue
		width += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x
		if i < names.size() - 1:
			width += badge_height * PILL_SPACING_RATIO
	return Vector2(maxf(width, badge_height), badge_height)

func _draw():
	if icon_name.is_empty():
		return
	var names := _get_glyph_names()
	if names.size() > 1:
		_draw_pill(names)
		return

	draw_circle(size / 2.0, size.x / 2.0, M3Theme.get_surface_container())

	var font := _get_font()
	if font == null:
		return
	var ch: String = IconsFonts.get_icon_char(icon_font, icon_name)
	if ch.is_empty():
		return

	var glyph_size := max(1, int(size.x * glyph_fill_ratio))
	var draw_pos := _get_centered_glyph_pos(font, ch, glyph_size)
	font.draw_string(
		get_canvas_item(), draw_pos,
		ch, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size,
		M3Theme.get_on_surface()
	)

func _draw_pill(names: PackedStringArray) -> void:
	var font := _get_font()
	if font == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = M3Theme.get_surface_container()
	var r := int(size.y / 2.0)
	bg.corner_radius_top_left = r
	bg.corner_radius_top_right = r
	bg.corner_radius_bottom_left = r
	bg.corner_radius_bottom_right = r
	draw_style_box(bg, Rect2(Vector2.ZERO, size))

	var glyph_size := max(1, int(size.y * glyph_fill_ratio))
	var x := size.y * PILL_PAD_X_RATIO
	for glyph_name in names:
		var ch: String = IconsFonts.get_icon_char(icon_font, glyph_name)
		if ch.is_empty():
			continue
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x
		var draw_pos := _get_centered_glyph_pos(font, ch, glyph_size, Vector2(w, size.y)) + Vector2(x, 0)
		font.draw_string(
			get_canvas_item(), draw_pos,
			ch, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size,
			M3Theme.get_on_surface()
		)
		x += w + size.y * PILL_SPACING_RATIO

func _get_centered_glyph_pos(font: Font, ch: String, glyph_size: int, area: Vector2 = Vector2(-1, -1)) -> Vector2:
	# Center the glyph's actual ink box via TextServer metrics; PromptFont's
	# line metrics are asymmetric, so ascent/descent centering drifts low.
	if area.x < 0.0:
		area = size
	var rids := font.get_rids()
	if not rids.is_empty():
		var ts := TextServerManager.get_primary_interface()
		var glyph_idx := ts.font_get_glyph_index(rids[0], glyph_size, ch.unicode_at(0), 0)
		if glyph_idx != 0:
			var vec := Vector2i(glyph_size, 0)
			var ink_size: Vector2 = ts.font_get_glyph_size(rids[0], vec, glyph_idx)
			var ink_offset: Vector2 = ts.font_get_glyph_offset(rids[0], vec, glyph_idx)
			return area / 2.0 - ink_size / 2.0 - ink_offset

	# Fallback: center by line metrics
	var text_size := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size)
	var baseline_y := area.y / 2.0 + (font.get_ascent(glyph_size) - font.get_descent(glyph_size)) / 2.0
	return Vector2((area.x - text_size.x) / 2.0, baseline_y)

func refresh() -> void:
	queue_redraw()

func _get_font() -> Font:
	match icon_font:
		"MaterialIcons":
			return load(IconsFonts.material_icons_font)
		"Emojis":
			return load(IconsFonts.emojis_font)
		"ControllerIcons":
			return load(IconsFonts.controller_icons_font)
	return null
