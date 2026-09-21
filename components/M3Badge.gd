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

func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = not icon_name.is_empty()

func _draw():
	if icon_name.is_empty():
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
