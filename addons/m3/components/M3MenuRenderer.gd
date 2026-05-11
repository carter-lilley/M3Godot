class_name M3MenuRenderer
extends Control

const M3MenuItem = preload("res://addons/m3/components/M3MenuItem.gd")

## Material 3 Menu Renderer
## Visual popup layer for M3Menu. Lazy-loaded when popup() is called.
## Handles rendering, input, keyboard navigation, and dismissal.

const M3Units = preload("res://addons/m3/M3Units.gd")

# ============================================
# SIZE SPECS (all values in dp)
# ============================================

const CONTAINER_RADIUS := 16.0
const CONTAINER_PADDING_V := 8.0
const CONTAINER_PADDING_H := 0.0
const ITEM_HEIGHT := 48.0
const ITEM_HEIGHT_TWO_LINE := 56.0
const ITEM_PADDING_H := 12.0
const ICON_SIZE := 24.0
const ICON_TEXT_GAP := 12.0
const SECTION_LABEL_PADDING_TOP := 16.0
const SECTION_LABEL_PADDING_BOTTOM := 8.0
const SEPARATOR_PADDING_H := 16.0
const SEPARATOR_HEIGHT := 1.0
const MIN_WIDTH := 112.0
const MAX_WIDTH := 280.0

# ============================================
# ENUMS
# ============================================

enum ColorVariant { STANDARD, VIBRANT }

# ============================================
# SIGNALS
# ============================================

signal item_pressed(index: int)
signal dismissed

# ============================================
# INTERNAL
# ============================================

var _bg_panel: Panel
var _vbox: VBoxContainer
var _item_nodes: Array[Control] = []
var _menu_items: Array[M3MenuItem] = []
var _color_variant: ColorVariant = ColorVariant.STANDARD
var _anchor_control: Control = null

# ============================================
# LIFECYCLE
# ============================================

func _init():
	top_level = true
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func _ready():
	_create_visuals()
	_update_appearance()

func _ensure_visuals():
	if _vbox == null:
		_create_visuals()

func _create_visuals():
	if _bg_panel != null:
		return
	
	# Background panel with M3 shadow
	_bg_panel = Panel.new()
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_panel)
	
	# Vertical container for items
	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_vbox.add_theme_constant_override("separation", 0)
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_vbox)

func _update_appearance():
	if not _bg_panel:
		return
	
	var bg: Color
	var shadow_color: Color
	
	match _color_variant:
		ColorVariant.VIBRANT:
			bg = M3Theme.get_tertiary_container()
			shadow_color = Color(0, 0, 0, 0.15)
		_:
			bg = M3Theme.get_surface_container_low()
			shadow_color = Color(0, 0, 0, 0.18)
	
	var sb = M3Theme.make_shadow(bg, M3Units.dpi(CONTAINER_RADIUS), 
		M3Theme.ELEVATION_2["size"], M3Theme.ELEVATION_2["offset"], shadow_color)
	_bg_panel.add_theme_stylebox_override("panel", sb)

# ============================================
# PUBLIC API
# ============================================

func popup(items: Array[M3MenuItem], anchor: Control, variant: ColorVariant = ColorVariant.STANDARD):
	_ensure_visuals()
	
	_menu_items = items.duplicate()
	_color_variant = variant
	_anchor_control = anchor
	
	_clear_items()
	_build_items()
	_update_appearance()
	_calculate_size_and_position()
	
	visible = true
	
	# Focus the first Button
	for node in _item_nodes:
		if node is Button:
			node.grab_focus()
			break
	_update_item_visuals()
	
	# Connect input events
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

func dismiss():
	visible = false
	dismissed.emit()

func is_open() -> bool:
	return visible

# ============================================
# ITEM BUILDING
# ============================================

func _clear_items():
	for node in _item_nodes:
		node.queue_free()
	_item_nodes.clear()
	if _vbox == null:
		return
	for child in _vbox.get_children():
		child.queue_free()

func _build_items():
	var fonts = M3Theme.load_fonts()
	
	for i in range(_menu_items.size()):
		var item = _menu_items[i]
		var node = _create_item_node(item, i, fonts)
		_vbox.add_child(node)
		_item_nodes.append(node)

func _create_item_node(item: M3MenuItem, index: int, fonts: Dictionary) -> Control:
	match item.item_type:
		M3MenuItem.Type.SEPARATOR:
			return _create_separator_node()
		M3MenuItem.Type.SECTION_LABEL:
			return _create_section_label_node(item, fonts)
		M3MenuItem.Type.TWO_LINE:
			return _create_two_line_node(item, index, fonts)
		_:
			return _create_normal_node(item, index, fonts)

func _create_separator_node() -> Control:
	var container = Control.new()
	var sep_height = M3Units.dp(SEPARATOR_HEIGHT)
	var pad_v = M3Units.dp(CONTAINER_PADDING_V)
	container.custom_minimum_size = Vector2(0, sep_height + pad_v * 2)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var line = ColorRect.new()
	line.color = M3Theme.get_outline_variant()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(line)
	
	# Position line with horizontal padding, centered vertically
	var pad_h = M3Units.dp(SEPARATOR_PADDING_H)
	line.position = Vector2(pad_h, pad_v)
	line.size = Vector2(100, sep_height)  # Temporary width, updated on resize
	
	# Use resized signal to update line width
	container.resized.connect(func():
		line.size = Vector2(container.size.x - pad_h * 2, sep_height)
	)
	
	return container

func _create_section_label_node(item: M3MenuItem, fonts: Dictionary) -> Control:
	var container = Control.new()
	var top_pad = M3Units.dp(SECTION_LABEL_PADDING_TOP)
	var bottom_pad = M3Units.dp(SECTION_LABEL_PADDING_BOTTOM)
	container.custom_minimum_size = Vector2(0, M3Units.dp(16) + top_pad + bottom_pad)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var label = Label.new()
	label.text = item.text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", fonts["medium"])
	label.add_theme_font_size_override("font_size", M3Units.dp(12))
	label.add_theme_color_override("font_color", _get_secondary_text_color())
	label.position = Vector2(M3Units.dp(ITEM_PADDING_H), top_pad)
	container.add_child(label)
	
	container.resized.connect(func():
		label.size = Vector2(container.size.x - M3Units.dp(ITEM_PADDING_H) * 2, M3Units.dp(16))
	)
	
	return container

func _create_normal_node(item: M3MenuItem, index: int, fonts: Dictionary) -> Control:
	var height = M3Units.dp(ITEM_HEIGHT)
	var node = _create_interactable_node(item, index, height)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.position = Vector2(M3Units.dp(ITEM_PADDING_H), 0)
	hbox.size = Vector2(node.size.x - M3Units.dp(ITEM_PADDING_H) * 2, height)
	node.add_child(hbox)
	
	# Icon or checkmark (always reserve space for alignment)
	var icon_node = FontIcon.new()
	icon_node.icon_settings = FontIconSettings.new()
	icon_node.icon_settings.icon_size = M3Units.dp(ICON_SIZE)
	icon_node.icon_settings.icon_font = "MaterialIcons"
	icon_node.custom_minimum_size = Vector2(M3Units.dp(ICON_SIZE), M3Units.dp(ICON_SIZE))
	icon_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if item.checkable and item.checked:
		icon_node.icon_settings.icon_name = "check"
		icon_node.icon_settings.icon_color = _get_primary_text_color()
	elif item.checkable and not item.checked:
		icon_node.icon_settings.icon_color = Color.TRANSPARENT
	elif not item.icon.is_empty():
		icon_node.icon_settings.icon_name = item.icon
		icon_node.icon_settings.icon_color = _get_icon_color()
	else:
		icon_node.icon_settings.icon_color = Color.TRANSPARENT
	
	hbox.add_child(icon_node)
	
	# Gap between icon and text (always present for alignment)
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(M3Units.dp(ICON_TEXT_GAP), 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(gap)
	
	# Text label
	if not item.text.is_empty():
		var label = Label.new()
		label.text = item.text
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_override("font", fonts["regular"])
		label.add_theme_font_size_override("font_size", M3Units.dp(14))
		label.add_theme_color_override("font_color", _get_primary_text_color() if not item.disabled else _get_disabled_text_color())
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(label)
	
	# Shortcut text
	if not item.shortcut_text.is_empty():
		var shortcut = Label.new()
		shortcut.text = item.shortcut_text
		shortcut.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		shortcut.add_theme_font_override("font", fonts["regular"])
		shortcut.add_theme_font_size_override("font_size", M3Units.dp(14))
		shortcut.add_theme_color_override("font_color", _get_secondary_text_color())
		shortcut.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(shortcut)
	
	# Trailing icon (right side)
	if not item.trailing_icon.is_empty():
		var trailing_icon_node = FontIcon.new()
		trailing_icon_node.icon_settings = FontIconSettings.new()
		trailing_icon_node.icon_settings.icon_size = M3Units.dp(ICON_SIZE)
		trailing_icon_node.icon_settings.icon_font = "MaterialIcons"
		trailing_icon_node.icon_settings.icon_name = item.trailing_icon
		trailing_icon_node.icon_settings.icon_color = _get_secondary_text_color()
		trailing_icon_node.custom_minimum_size = Vector2(M3Units.dp(ICON_SIZE), M3Units.dp(ICON_SIZE))
		trailing_icon_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		trailing_icon_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trailing_icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(trailing_icon_node)
	
	node.resized.connect(func():
		hbox.size = Vector2(node.size.x - M3Units.dp(ITEM_PADDING_H) * 2, height)
	)
	
	return node

func _create_two_line_node(item: M3MenuItem, index: int, fonts: Dictionary) -> Control:
	var height = M3Units.dp(ITEM_HEIGHT_TWO_LINE)
	var node = _create_interactable_node(item, index, height)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.position = Vector2(M3Units.dp(ITEM_PADDING_H), 0)
	hbox.size = Vector2(node.size.x - M3Units.dp(ITEM_PADDING_H) * 2, height)
	node.add_child(hbox)
	
	# Icon (always reserve space for alignment)
	var icon_node = FontIcon.new()
	icon_node.icon_settings = FontIconSettings.new()
	icon_node.icon_settings.icon_size = M3Units.dp(ICON_SIZE)
	icon_node.icon_settings.icon_font = "MaterialIcons"
	if not item.icon.is_empty():
		icon_node.icon_settings.icon_name = item.icon
		icon_node.icon_settings.icon_color = _get_icon_color()
	else:
		icon_node.icon_settings.icon_color = Color.TRANSPARENT
	icon_node.custom_minimum_size = Vector2(M3Units.dp(ICON_SIZE), M3Units.dp(ICON_SIZE))
	icon_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_node)
	
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(M3Units.dp(ICON_TEXT_GAP), 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(gap)
	
	# Text column
	var text_vbox = VBoxContainer.new()
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)
	
	var primary = Label.new()
	primary.text = item.text
	primary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	primary.add_theme_font_override("font", fonts["regular"])
	primary.add_theme_font_size_override("font_size", M3Units.dp(14))
	primary.add_theme_color_override("font_color", _get_primary_text_color() if not item.disabled else _get_disabled_text_color())
	primary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(primary)
	
	var secondary = Label.new()
	secondary.text = item.secondary_text
	secondary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	secondary.add_theme_font_override("font", fonts["regular"])
	secondary.add_theme_font_size_override("font_size", M3Units.dp(12))
	secondary.add_theme_color_override("font_color", _get_secondary_text_color())
	secondary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(secondary)
	
	# Shortcut
	if not item.shortcut_text.is_empty():
		var shortcut = Label.new()
		shortcut.text = item.shortcut_text
		shortcut.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		shortcut.add_theme_font_override("font", fonts["regular"])
		shortcut.add_theme_font_size_override("font_size", M3Units.dp(14))
		shortcut.add_theme_color_override("font_color", _get_secondary_text_color())
		shortcut.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(shortcut)
	
	# Trailing icon (right side)
	if not item.trailing_icon.is_empty():
		var trailing_icon_node = FontIcon.new()
		trailing_icon_node.icon_settings = FontIconSettings.new()
		trailing_icon_node.icon_settings.icon_size = M3Units.dp(ICON_SIZE)
		trailing_icon_node.icon_settings.icon_font = "MaterialIcons"
		trailing_icon_node.icon_settings.icon_name = item.trailing_icon
		trailing_icon_node.icon_settings.icon_color = _get_secondary_text_color()
		trailing_icon_node.custom_minimum_size = Vector2(M3Units.dp(ICON_SIZE), M3Units.dp(ICON_SIZE))
		trailing_icon_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		trailing_icon_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trailing_icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(trailing_icon_node)
	
	node.resized.connect(func():
		hbox.size = Vector2(node.size.x - M3Units.dp(ITEM_PADDING_H) * 2, height)
	)
	
	return node

func _create_interactable_node(item: M3MenuItem, index: int, height: float) -> Button:
	var node = Button.new()
	node.custom_minimum_size = Vector2(0, height)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_PASS if not item.disabled else Control.MOUSE_FILTER_IGNORE
	node.set_meta("item_index", index)
	node.set_meta("disabled", item.disabled)
	
	# Suppress native Button visuals; we draw our own overlay
	node.flat = true
	var empty = StyleBoxEmpty.new()
	node.add_theme_stylebox_override("normal", empty)
	node.add_theme_stylebox_override("pressed", empty)
	node.add_theme_stylebox_override("hover", empty)
	node.add_theme_stylebox_override("disabled", empty)
	node.add_theme_stylebox_override("focus", empty)
	
	# Hover/selected overlay - Panel with rounded StyleBoxFlat, inset 4dp from edges
	var overlay = Panel.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = M3Units.dp(4)
	overlay.offset_top = M3Units.dp(4)
	overlay.offset_right = -M3Units.dp(4)
	overlay.offset_bottom = -M3Units.dp(4)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	overlay.set_meta("m3_menu_overlay", true)
	
	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(M3Units.dpi(12))
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.0
	sb.set_border_width_all(0)
	overlay.add_theme_stylebox_override("panel", sb)
	# Store reference to stylebox for color updates
	overlay.set_meta("m3_menu_overlay_sb", sb)
	
	node.add_child(overlay)
	
	# Store the menu item index so we can map back to _menu_items
	node.set_meta("menu_item_index", index)
	
	# Connect Button signals
	if not item.disabled:
		node.pressed.connect(_activate_item.bind(index))
		node.focus_entered.connect(_on_item_focus_entered.bind(index))
		node.mouse_entered.connect(_on_item_mouse_entered.bind(index))
	
	return node

# ============================================
# COLORS
# ============================================

func _get_primary_text_color() -> Color:
	match _color_variant:
		ColorVariant.VIBRANT:
			return M3Theme.get_on_tertiary_container()
		_:
			return M3Theme.get_on_surface()

func _get_secondary_text_color() -> Color:
	match _color_variant:
		ColorVariant.VIBRANT:
			return M3Theme.get_on_tertiary_container()
		_:
			return M3Theme.get_on_surface_variant()

func _get_icon_color() -> Color:
	match _color_variant:
		ColorVariant.VIBRANT:
			return M3Theme.get_on_tertiary_container()
		_:
			return M3Theme.get_on_surface_variant()

func _get_disabled_text_color() -> Color:
	return M3Theme.disabled_color(_get_primary_text_color())

func _get_selected_bg_color() -> Color:
	match _color_variant:
		ColorVariant.VIBRANT:
			return M3Theme.get_tertiary()
		_:
			return M3Theme.get_secondary_container()

func _get_hover_bg_color() -> Color:
	match _color_variant:
		ColorVariant.VIBRANT:
			return M3Theme.state_overlay(M3Theme.get_tertiary_container(), M3Theme.get_on_tertiary_container(), M3Theme.OPACITY_HOVER)
		_:
			return M3Theme.state_overlay(M3Theme.get_surface_container_low(), M3Theme.get_on_surface(), M3Theme.OPACITY_HOVER)

# ============================================
# SIZING & POSITIONING
# ============================================

func _calculate_size_and_position():
	var pad_h = M3Units.dp(CONTAINER_PADDING_H)
	var pad_v = M3Units.dp(CONTAINER_PADDING_V)
	
	# Calculate required width
	var max_content_width = 0.0
	var fonts = M3Theme.load_fonts()
	
	for item in _menu_items:
		var item_width = M3Units.dp(ITEM_PADDING_H) * 2
		
		if item.item_type == M3MenuItem.Type.SEPARATOR:
			continue
		elif item.item_type == M3MenuItem.Type.SECTION_LABEL:
			item_width += _measure_text(item.text, fonts["medium"], M3Units.dp(12))
		else:
			# Icon/checkmark width (always reserved for alignment)
			item_width += M3Units.dp(ICON_SIZE) + M3Units.dp(ICON_TEXT_GAP)
			
			# Text width
			if not item.text.is_empty():
				item_width += _measure_text(item.text, fonts["regular"], M3Units.dp(14))
			
			# Shortcut width
			if not item.shortcut_text.is_empty():
				item_width += M3Units.dp(16) + _measure_text(item.shortcut_text, fonts["regular"], M3Units.dp(14))
			
			# Trailing icon width
			if not item.trailing_icon.is_empty():
				item_width += M3Units.dp(ICON_SIZE) + M3Units.dp(12)
		
		max_content_width = max(max_content_width, item_width)
	
	# Right margin equals half the width of the longest item
	var width = clamp(max_content_width * 1.5, M3Units.dp(MIN_WIDTH), M3Units.dp(MAX_WIDTH))
	
	# Calculate height
	var height = pad_v * 2
	for item in _menu_items:
		match item.item_type:
			M3MenuItem.Type.SEPARATOR:
				height += M3Units.dp(SEPARATOR_HEIGHT) + pad_v * 2
			M3MenuItem.Type.SECTION_LABEL:
				height += M3Units.dp(16) + M3Units.dp(SECTION_LABEL_PADDING_TOP) + M3Units.dp(SECTION_LABEL_PADDING_BOTTOM)
			M3MenuItem.Type.TWO_LINE:
				height += M3Units.dp(ITEM_HEIGHT_TWO_LINE)
			_:
				height += M3Units.dp(ITEM_HEIGHT)
	
	# Position relative to anchor
	var viewport = get_viewport()
	var viewport_size = Vector2(1920, 1080)
	if viewport:
		viewport_size = viewport.get_visible_rect().size
	var anchor_rect = _anchor_control.get_global_rect() if _anchor_control else Rect2(Vector2.ZERO, Vector2.ZERO)
	
	var pos = Vector2(
		anchor_rect.position.x,
		anchor_rect.position.y + anchor_rect.size.y + M3Units.dp(4)
	)
	
	# Clamp to viewport
	pos.x = clamp(pos.x, M3Units.dp(8), viewport_size.x - width - M3Units.dp(8))
	pos.y = clamp(pos.y, M3Units.dp(8), viewport_size.y - height - M3Units.dp(8))
	
	# If below doesn't fit, try above
	if pos.y + height > viewport_size.y - M3Units.dp(8):
		pos.y = anchor_rect.position.y - height - M3Units.dp(4)
		pos.y = max(pos.y, M3Units.dp(8))
	
	global_position = pos
	size = Vector2(width, height)
	
	# Update background panel
	_bg_panel.position = Vector2.ZERO
	_bg_panel.size = size
	
	# Update vbox
	_vbox.position = Vector2(pad_h, pad_v)
	_vbox.size = Vector2(width - pad_h * 2, height - pad_v * 2)

func _measure_text(text: String, font: Font, font_size: int) -> float:
	if text.is_empty():
		return 0.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

# ============================================
# INPUT
# ============================================

func _on_gui_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				accept_event()
				_activate_focused()

func _input(event: InputEvent):
	if not visible:
		return
	
	# ui_cancel (Escape / controller B / back button) closes the menu
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		dismiss()
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not get_global_rect().has_point(event.global_position):
			dismiss()

func _on_item_mouse_entered(index: int):
	# Mouse hover grabs focus so there's only ever one focused item
	if index >= 0 and index < _item_nodes.size():
		var node = _item_nodes[index]
		if not node.has_focus():
			node.grab_focus()

func _on_item_focus_entered(index: int):
	_update_item_visuals()

func _activate_focused():
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null:
		return
	for i in range(_item_nodes.size()):
		if _item_nodes[i] == focused:
			_activate_item(i)
			return

func _activate_item(index: int):
	if index < 0 or index >= _menu_items.size():
		return
	
	var item = _menu_items[index]
	if item.disabled:
		return
	
	# Toggle checkable items
	if item.checkable:
		item.checked = not item.checked
		_update_item_checkmark(index)
	
	if item.callback.is_valid():
		item.callback.call()
	
	item_pressed.emit(index)
	dismiss()

# ============================================
# VISUAL UPDATES
# ============================================

func _update_item_visuals():
	for i in range(_item_nodes.size()):
		var node = _item_nodes[i]
		var is_focused = node.has_focus()
		
		# Find overlay child (Panel with meta)
		for child in node.get_children():
			if child is Panel and child.has_meta("m3_menu_overlay"):
				var sb = child.get_meta("m3_menu_overlay_sb") as StyleBoxFlat
				if is_focused:
					if sb:
						sb.bg_color = _get_selected_bg_color()
					child.visible = true
				else:
					child.visible = false
				break

func _update_item_checkmark(index: int):
	if index < 0 or index >= _item_nodes.size():
		return
	
	var node = _item_nodes[index]
	var item = _menu_items[index]
	
	# Find FontIcon in hbox
	for child in node.get_children():
		if child is HBoxContainer:
			for hbox_child in child.get_children():
				if hbox_child is FontIcon and hbox_child.icon_settings:
					if item.checkable:
						if item.checked:
							hbox_child.icon_settings.icon_name = "check"
							hbox_child.icon_settings.icon_color = _get_primary_text_color()
						else:
							hbox_child.icon_settings.icon_name = ""
							hbox_child.icon_settings.icon_color = Color.TRANSPARENT
					break

func _notification(what: int):
	if what == NOTIFICATION_FOCUS_EXIT:
		# Dismiss when focus is lost (unless clicking inside)
		call_deferred("_check_focus_loss")

func _check_focus_loss():
	if visible and not has_focus():
		# Check if any child has focus
		var focused = get_viewport().gui_get_focus_owner()
		if focused and not focused.is_ancestor_of(self):
			dismiss()
