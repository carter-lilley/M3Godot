class_name M3Shimmer
extends RefCounted

## Attaches an animated skeleton-shimmer loading state to any existing Control
## (Panel, TextureRect, etc.) without adding nodes to the tree. Colors follow
## the active M3 theme and refresh automatically on theme changes.

const ShimmerShader := preload("res://shaders/skeleton_shimmer.gdshader")

const META_MATERIAL := &"m3_shimmer_material"
const META_RESIZED_CB := &"m3_shimmer_resized_cb"
const META_THEME_CB := &"m3_shimmer_theme_cb"
const META_BLANK_TEX := &"m3_shimmer_blank_tex"

static var _blank_texture: Texture2D = null

## 2x2 white texture so texture-less controls (e.g. TextureRect with a null
## texture) still rasterize pixels for the shimmer shader to color.
static func get_blank_texture() -> Texture2D:
	if _blank_texture == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_blank_texture = ImageTexture.create_from_image(img)
	return _blank_texture

## corner_radius is relative to half the control's shortest side (0.0-0.5),
## matching M3Card's card_rounding_ratio convention.
static func attach(control: Control, corner_radius: float = 0.12, speed: float = 2.2, angle_degrees: float = 25.0) -> void:
	if control == null or control.has_meta(META_MATERIAL):
		return
	var mat := ShaderMaterial.new()
	mat.shader = ShimmerShader
	mat.set_shader_parameter("corner_radius", corner_radius)
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("angle_degrees", angle_degrees)
	_apply_theme_colors(mat)
	_apply_aspect(mat, control)
	control.material = mat
	control.set_meta(META_MATERIAL, mat)

	# TextureRect draws nothing while its texture is null; give it a blank so
	# the shimmer shader has pixels to shade.
	if control is TextureRect and control.texture == null:
		control.texture = get_blank_texture()
		control.set_meta(META_BLANK_TEX, true)

	var resized_cb := func(): _apply_aspect(mat, control)
	control.resized.connect(resized_cb)
	control.set_meta(META_RESIZED_CB, resized_cb)

	var theme_cb := func(): _apply_theme_colors(mat)
	control.theme_changed.connect(theme_cb)
	control.set_meta(META_THEME_CB, theme_cb)

static func detach(control: Control) -> void:
	if control == null or not control.has_meta(META_MATERIAL):
		return
	var resized_cb: Variant = control.get_meta(META_RESIZED_CB, null)
	if resized_cb is Callable and control.resized.is_connected(resized_cb):
		control.resized.disconnect(resized_cb)
	var theme_cb: Variant = control.get_meta(META_THEME_CB, null)
	if theme_cb is Callable and control.theme_changed.is_connected(theme_cb):
		control.theme_changed.disconnect(theme_cb)
	control.material = null
	if control.has_meta(META_BLANK_TEX):
		if control is TextureRect and control.texture == get_blank_texture():
			control.texture = null
		control.remove_meta(META_BLANK_TEX)
	control.remove_meta(META_MATERIAL)
	control.remove_meta(META_RESIZED_CB)
	control.remove_meta(META_THEME_CB)

static func is_attached(control: Control) -> bool:
	return control != null and control.has_meta(META_MATERIAL)

static func _apply_theme_colors(mat: ShaderMaterial) -> void:
	var base := M3Theme.get_elevation_surface(5)
	# The glint is always a brighter sweep of the base surface, dark or light.
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("shimmer_color", base.lightened(0.18))

static func _apply_aspect(mat: ShaderMaterial, control: Control) -> void:
	var w := maxf(control.size.x, 1.0)
	var h := maxf(control.size.y, 1.0)
	mat.set_shader_parameter("aspect_ratio", w / h)
