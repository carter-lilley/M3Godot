@tool
class_name M3Dialog
extends PanelContainer

## Material 3 Dialog Component
## Extends PanelContainer for modal overlay rendering within a CanvasLayer.
## Supports BASIC and FULL_SCREEN variants with hero icon, title, body,
## custom content slot, and action buttons.

enum Variant { BASIC, FULL_SCREEN }

# ============================================
# SIZE SPECS (all values in dp)
# ============================================

const BASIC_MAX_WIDTH := 560.0
const BASIC_RADIUS := 28.0
const PADDING := 24.0
const PADDING_TOP_NO_ICON := 16.0
const ICON_SIZE := 24.0
const ICON_TITLE_GAP := 16.0
const ACTIONS_GAP := 8.0
const FULLSCREEN_TOP_BAR_HEIGHT := 64.0
const FULLSCREEN_ACTIONS_HEIGHT := 64.0

# ============================================
# EXPORTS
# ============================================

@export var dialog_variant: Variant = Variant.BASIC:
	set(value):
		if value == dialog_variant:
			return
		dialog_variant = value
		if _ready_called or get_child_count() > 0:
			_rebuild_layout()

@export var title_text: String = "":
	set(value):
		if value == title_text:
			return
		title_text = value
		if _ready_called:
			_update_text()

@export var body_text: String = "":
	set(value):
		if value == body_text:
			return
		body_text = value
		if _ready_called:
			_update_text()

@export var hero_icon_name: String = "":
	set(value):
		if value == hero_icon_name:
			return
		hero_icon_name = value
		if _ready_called:
			_update_hero_icon()

@export var dismissible: bool = true

# ============================================
# SIGNALS
# ============================================

signal dismissed
signal action_pressed(action_label: String)

# ============================================
# INTERNAL
# ============================================

var _vbox: VBoxContainer
var _hero_icon: FontIcon
var _title_label: Label
var _body_label: Label
var _content_slot: VBoxContainer
var _divider: HSeparator
var _actions_container: HBoxContainer

var _fullscreen_root: VBoxContainer
var _top_bar: Panel
var _top_bar_title: Label
var _close_button: M3IconButton
var _scroll: ScrollContainer
var _scroll_content: VBoxContainer
var _bottom_actions: Panel

var _actions: Array[M3Button] = []
var _ready_called: bool = false

# ============================================
# PUBLIC API
# ============================================

## The content slot for adding custom controls (VBoxContainer).
var content_slot: VBoxContainer:
	get:
		return _content_slot

## Add an action button to the dialog.
## Primary actions use the filled variant; secondary use text variant.
func add_action(label: String, callback: Callable = Callable(), primary: bool = false):
	var btn = M3Button.new()
	btn.text = label
	btn.button_size = M3Button.Size.SMALL
	btn.button_variant = M3Button.Variant.FILLED if primary else M3Button.Variant.TEXT
	btn.pressed.connect(_on_action_pressed.bind(label))
	if callback.is_valid():
		btn.pressed.connect(callback)
	_actions.append(btn)
	# Only add to container if layout is ready; otherwise _ready() will add pending actions
	if _actions_container:
		_actions_container.add_child(btn)

## Clear all action buttons.
func clear_actions():
	for btn in _actions:
		btn.queue_free()
	_actions.clear()

## Dismiss the dialog programmatically.
func dismiss():
	dismissed.emit()
	hide()

# ============================================
# LIFECYCLE
# ============================================

func _init():
	# Build layout immediately so content_slot and other nodes are available
	# before the dialog is added to the scene tree
	_build_layout()

func _ready():
	_update_appearance()
	_update_text()
	_update_hero_icon()
	
	# Add any actions that were queued before _ready() (e.g. user called add_action() before adding to tree)
	for btn in _actions:
		if btn.get_parent() == null and _actions_container:
			_actions_container.add_child(btn)
	
	_add_default_action()
	
	_ready_called = true

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") and dismissible:
		accept_event()
		dismiss()

func _build_layout():
	if dialog_variant == Variant.BASIC:
		_build_basic_layout()
	else:
		_build_fullscreen_layout()

func _build_basic_layout():
	# This PanelContainer is the root with M3 styling
	# Vertical layout with explicit spacers for M3 spec spacing
	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_vbox)
	
	_vbox.add_theme_constant_override("separation", 0)
	
	# Hero icon (optional, centered)
	_hero_icon = FontIcon.new()
	_hero_icon.icon_settings = FontIconSettings.new()
	_hero_icon.icon_settings.icon_size = M3Units.dp(ICON_SIZE)
	_hero_icon.icon_settings.icon_font = "MaterialIcons"
	_hero_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_icon.visible = false
	_vbox.add_child(_hero_icon)
	
	# Title (left-aligned per M3 spec)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_title_label)
	
	# Spacer: 16dp between title and body
	var title_body_spacer = Control.new()
	title_body_spacer.custom_minimum_size = Vector2(0, M3Units.dp(16))
	_vbox.add_child(title_body_spacer)
	
	# Body (left-aligned per M3 spec)
	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_body_label)
	
	# Spacer: 24dp between body and content/actions
	var body_content_spacer = Control.new()
	body_content_spacer.custom_minimum_size = Vector2(0, M3Units.dp(24))
	body_content_spacer.name = "BodyContentSpacer"
	_vbox.add_child(body_content_spacer)
	
	# Content slot
	_content_slot = VBoxContainer.new()
	_vbox.add_child(_content_slot)
	
	# Divider
	_divider = HSeparator.new()
	_divider.visible = false
	_vbox.add_child(_divider)
	
	# Spacer before actions: only visible when divider is shown
	var divider_actions_spacer = Control.new()
	divider_actions_spacer.custom_minimum_size = Vector2(0, M3Units.dp(24))
	divider_actions_spacer.visible = false
	divider_actions_spacer.name = "DividerActionsSpacer"
	_vbox.add_child(divider_actions_spacer)
	
	# Actions container
	_actions_container = HBoxContainer.new()
	_actions_container.alignment = BoxContainer.ALIGNMENT_END
	_actions_container.add_theme_constant_override("separation", M3Units.dp(ACTIONS_GAP))
	_vbox.add_child(_actions_container)
	
	# Set size constraints
	var max_width = M3Units.dp(BASIC_MAX_WIDTH)
	custom_minimum_size = Vector2(max_width, 0)

func _build_fullscreen_layout():
	# Full viewport dialog
	# Use a full-size background panel
	var bg_panel = Panel.new()
	bg_panel.name = "FullscreenBackground"
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_panel)
	
	# Main layout container on top
	_fullscreen_root = VBoxContainer.new()
	_fullscreen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fullscreen_root)
	
	# Top bar
	_top_bar = Panel.new()
	_top_bar.custom_minimum_size = Vector2(0, M3Units.dp(FULLSCREEN_TOP_BAR_HEIGHT))
	_fullscreen_root.add_child(_top_bar)
	
	var top_hbox = HBoxContainer.new()
	top_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_bar.add_child(top_hbox)
	
	_close_button = M3IconButton.new()
	_close_button.icon_name = "close"
	_close_button.pressed.connect(dismiss)
	top_hbox.add_child(_close_button)
	
	_top_bar_title = Label.new()
	_top_bar_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_hbox.add_child(_top_bar_title)
	
	# Scrollable content area
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fullscreen_root.add_child(_scroll)
	
	# MarginContainer provides the 24dp padding around content
	var scroll_margin = MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pad = M3Units.dp(PADDING)
	scroll_margin.add_theme_constant_override("margin_left", pad)
	scroll_margin.add_theme_constant_override("margin_right", pad)
	scroll_margin.add_theme_constant_override("margin_top", pad)
	scroll_margin.add_theme_constant_override("margin_bottom", pad)
	_scroll.add_child(scroll_margin)
	
	_scroll_content = VBoxContainer.new()
	_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_content.add_theme_constant_override("separation", M3Units.dp(16))
	scroll_margin.add_child(_scroll_content)
	
	# Hero icon
	_hero_icon = FontIcon.new()
	_hero_icon.icon_settings = FontIconSettings.new()
	_hero_icon.icon_settings.icon_size = M3Units.dp(ICON_SIZE)
	_hero_icon.icon_settings.icon_font = "MaterialIcons"
	_hero_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_icon.visible = false
	_scroll_content.add_child(_hero_icon)
	
	# Title (left-aligned per M3 spec)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scroll_content.add_child(_title_label)
	
	# Body (left-aligned per M3 spec)
	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scroll_content.add_child(_body_label)
	
	# Content slot
	_content_slot = VBoxContainer.new()
	_scroll_content.add_child(_content_slot)
	
	# Bottom actions
	_bottom_actions = Panel.new()
	_bottom_actions.custom_minimum_size = Vector2(0, M3Units.dp(FULLSCREEN_ACTIONS_HEIGHT))
	_fullscreen_root.add_child(_bottom_actions)
	
	_actions_container = HBoxContainer.new()
	_actions_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_actions_container.alignment = BoxContainer.ALIGNMENT_END
	_actions_container.add_theme_constant_override("separation", M3Units.dp(ACTIONS_GAP))
	_bottom_actions.add_child(_actions_container)
	
	# Full viewport size
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _rebuild_layout():
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	_vbox = null
	_fullscreen_root = null
	_top_bar = null
	_scroll = null
	_scroll_content = null
	_bottom_actions = null
	
	_actions.clear()
	
	_build_layout()
	_update_appearance()
	_update_text()
	_update_hero_icon()

func _add_default_action():
	if _actions.is_empty():
		add_action("OK", Callable(), true)

func _on_action_pressed(label: String):
	action_pressed.emit(label)

# ============================================
# APPEARANCE
# ============================================

func _update_appearance():
	var fonts = M3Theme.load_fonts()
	
	if dialog_variant == Variant.BASIC:
		# Panel styling with 24dp content margins (inner padding)
		var bg = M3Theme.get_surface_container()
		var sb = M3Theme.make_shadow(bg, M3Units.dpi(BASIC_RADIUS), 
			M3Theme.ELEVATION_3["size"], M3Theme.ELEVATION_3["offset"], M3Theme.ELEVATION_3["color"])
		var pad = M3Units.dp(PADDING)
		sb.content_margin_left = pad
		sb.content_margin_right = pad
		sb.content_margin_top = pad
		sb.content_margin_bottom = pad
		add_theme_stylebox_override("panel", sb)
		
		# Title styling
		_title_label.add_theme_font_override("font", fonts["regular"])
		_title_label.add_theme_font_size_override("font_size", M3Units.dp(24))
		_title_label.add_theme_color_override("font_color", M3Theme.get_on_surface())
		
		# Body styling
		_body_label.add_theme_font_override("font", fonts["regular"])
		_body_label.add_theme_font_size_override("font_size", M3Units.dp(14))
		_body_label.add_theme_color_override("font_color", M3Theme.get_on_surface_variant())
		
		# Divider
		var div_style = StyleBoxLine.new()
		div_style.color = M3Theme.get_outline()
		div_style.thickness = 1
		_divider.add_theme_stylebox_override("separator", div_style)
		
		# Hero icon color
		if _hero_icon and _hero_icon.visible:
			_hero_icon.icon_settings.icon_color = M3Theme.get_secondary()
		
	else:
		# Full-screen styling
		# Update background panel
		for child in get_children():
			if child.name == "FullscreenBackground":
				child.add_theme_stylebox_override("panel", M3Theme.make_flat(M3Theme.get_surface()))
				break
		
		_top_bar.add_theme_stylebox_override("panel", M3Theme.make_flat(M3Theme.get_surface()))
		_top_bar_title.add_theme_font_override("font", fonts["regular"])
		_top_bar_title.add_theme_font_size_override("font_size", M3Units.dp(22))
		_top_bar_title.add_theme_color_override("font_color", M3Theme.get_on_surface())
		
		_bottom_actions.add_theme_stylebox_override("panel", M3Theme.make_flat(M3Theme.get_surface()))
		
		# Title and body styling (same as basic)
		_title_label.add_theme_font_override("font", fonts["regular"])
		_title_label.add_theme_font_size_override("font_size", M3Units.dp(24))
		_title_label.add_theme_color_override("font_color", M3Theme.get_on_surface())
		
		_body_label.add_theme_font_override("font", fonts["regular"])
		_body_label.add_theme_font_size_override("font_size", M3Units.dp(14))
		_body_label.add_theme_color_override("font_color", M3Theme.get_on_surface_variant())
		
		# Hero icon color
		if _hero_icon and _hero_icon.visible:
			_hero_icon.icon_settings.icon_color = M3Theme.get_secondary()

func _update_text():
	if _title_label:
		_title_label.text = title_text
		_title_label.visible = not title_text.is_empty()
	if _body_label:
		_body_label.text = body_text
		_body_label.visible = not body_text.is_empty()
	if _top_bar_title:
		_top_bar_title.text = title_text

func _update_hero_icon():
	if not _hero_icon:
		return
	
	if hero_icon_name.is_empty():
		_hero_icon.visible = false
	else:
		_hero_icon.icon_settings.icon_name = hero_icon_name
		_hero_icon.visible = true

func refresh_theme():
	_update_appearance()
