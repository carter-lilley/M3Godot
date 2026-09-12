@tool
class_name M3Dialog
extends M3Overlay

## Material 3 Dialog Component
## Extends M3Overlay for modal overlay rendering.
## Supports BASIC and FULL_SCREEN variants with hero icon, title, body,
## custom content slot, and action buttons.

enum Variant { BASIC, FULL_SCREEN }

# ============================================
# SIZE SPECS (all values in dp)
# ============================================

const BASIC_MAX_WIDTH := 720.0
const BASIC_MAX_HEIGHT := 760.0
const BASIC_MIN_HEIGHT := 200.0
const BASIC_RADIUS := 28.0
const PADDING := 24.0
const PADDING_TOP_NO_ICON := 16.0
const ICON_SIZE := 24.0
const ICON_TITLE_GAP := 16.0
const ACTIONS_GAP := 8.0
const BASIC_ACTIONS_HEIGHT := 48.0
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
@export var fill_viewport_height: bool = false
@export var disable_default_action: bool = false
@export var dialog_max_width: float = BASIC_MAX_WIDTH
## Sizing contract. Stamped mode (fixed_size or fill_viewport_height): the
## dialog's size is a pure function of the viewport, re-applied per stamp, and
## content must scroll inside it — content never resizes the dialog.
## Content-sized mode (default): content height is measured analytically once
## at show time (pure function of stamped width, dp scale, and text), then
## only re-clamped against new viewport sizes.
## Both modes: the chrome firewall (_ensure_chrome_firewall) severs min-size
## propagation so the engine's set_size clamp (control.cpp:1529) can never
## grow the dialog past the stamp; _report_content_budget tripwires stamped
## mode if page content still exceeds it.
@export var fixed_size: bool = false

# ============================================
# SIGNALS
# ============================================

signal action_pressed(action_label: String)

# ============================================
# INTERNAL
# ============================================

var _scrim: ColorRect
var _dialog_wrapper: Control
var _dialog_container: PanelContainer

var _vbox: VBoxContainer
var _hero_icon: FontIcon
var _title_label: Label
var _body_label: Label
var _title_body_spacer: Control
var _body_content_spacer: Control
## The content slot for adding custom controls (VBoxContainer).
var content_slot: VBoxContainer
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
var _cached_fonts: Dictionary = {}
var _font_icon_template: FontIconSettings = null
var _cached_divider_sb: StyleBoxLine = null

var _anim_tween: Tween = null
var _dismissing: bool = false
var _scrim_alpha: float = 0.32

# Last stamped BASIC dialog size. Stamped mode derives it from the viewport;
# content-sized mode derives it from _content_height_px (measured once).
var _fixed_size_px: Vector2 = Vector2.ZERO
# Measured content height, content-sized mode only. Set once; 0 = unmeasured.
var _content_height_px: float = 0.0
# Min-size firewall wrapping all chrome (see _ensure_chrome_firewall).
var _chrome_firewall: Control = null
# Viewport whose size_changed drives re-stamps; tracked across DS reparents.
var _size_viewport: Viewport = null
var _cached_bg_sb: StyleBoxFlat = null
var _cached_top_bar_sb: StyleBoxFlat = null
var _cached_bottom_actions_sb: StyleBoxFlat = null

# ============================================
# PUBLIC API
# ============================================

## Add an action button to the dialog.
func add_action(label: String, callback: Callable = Callable(), primary: bool = false):
	var btn = M3Button.new()
	btn.text = label
	btn.button_size = M3Button.Size.SMALL
	btn.button_variant = M3Button.Variant.FILLED if primary else M3Button.Variant.TEXT
	btn.pressed.connect(_on_action_pressed.bind(label))
	if callback.is_valid():
		btn.pressed.connect(callback)
	_actions.append(btn)
	if _actions_container:
		_actions_container.add_child(btn)

## Clear all action buttons.
func clear_actions():
	for btn in _actions:
		btn.queue_free()
	_actions.clear()

## Show the dialog overlay.
func show_overlay():
	var parent = M3Overlay.get_overlay_parent()
	if parent and get_parent() == null:
		parent.add_child(self)
	_position_dialog()
	_dismissing = false
	super.show_overlay()
	_focus_first_action()
	_animate_in()

func _animate_in() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	var scrim_target_a: float = _scrim_alpha
	_scrim.color.a = 0.0
	_dialog_container.modulate.a = 0.0
	var animate_scale: bool = dialog_variant == Variant.BASIC
	if animate_scale:
		_dialog_container.pivot_offset = _dialog_container.size / 2.0
		_dialog_container.scale = Vector2.ONE * 0.8
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.set_trans(M3Motion.EASE_ENTER_TRANS)
	_anim_tween.set_ease(M3Motion.EASE_ENTER)
	_anim_tween.tween_property(_dialog_container, "modulate:a", 1.0, M3Motion.OVERLAY)
	_anim_tween.tween_property(_scrim, "color:a", scrim_target_a, M3Motion.OVERLAY)
	if animate_scale:
		_anim_tween.tween_property(_dialog_container, "scale", Vector2.ONE, M3Motion.OVERLAY)

func dismiss():
	if _dismissing:
		return
	if Engine.is_editor_hint() or not is_inside_tree():
		super.dismiss()
		return
	_dismissing = true
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.set_trans(M3Motion.EASE_EXIT_TRANS)
	_anim_tween.set_ease(M3Motion.EASE_EXIT)
	_anim_tween.tween_property(_dialog_container, "modulate:a", 0.0, M3Motion.OVERLAY)
	_anim_tween.tween_property(_scrim, "color:a", 0.0, M3Motion.OVERLAY)
	if dialog_variant == Variant.BASIC:
		_anim_tween.tween_property(_dialog_container, "scale", Vector2.ONE * 0.9, M3Motion.OVERLAY)
	_anim_tween.set_parallel(false)
	_anim_tween.tween_callback(_finish_dismiss)

func _finish_dismiss() -> void:
	if not _dismissing:
		return
	super.dismiss()

# ============================================
# LIFECYCLE
# ============================================

func _init():
	super._init()
	overlay_type = "dialog"
	overlay_layer = 90
	_restore_focus_on_dismiss = true
	_build_layout()

func _ready():
	super._ready()
	_cached_fonts = M3Theme.load_fonts()
	_update_appearance()
	_update_text()
	_update_hero_icon()
	_apply_chrome_scale()

	for btn in _actions:
		if btn.get_parent() == null and _actions_container:
			_actions_container.add_child(btn)

	if not disable_default_action:
		_add_default_action()
	_ready_called = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_track_size_viewport()

## Keep the size_changed connection on the dialog's CURRENT viewport; DS-mode
## reparenting moves dialogs between the root window and the MainViewport
## SubViewport, and the old connection would die with the old viewport.
func _track_size_viewport() -> void:
	var viewport := get_viewport()
	if viewport == _size_viewport:
		return
	if _size_viewport and is_instance_valid(_size_viewport):
		if _size_viewport.size_changed.is_connected(_on_host_viewport_size_changed):
			_size_viewport.size_changed.disconnect(_on_host_viewport_size_changed)
	_size_viewport = viewport
	if viewport and not viewport.size_changed.is_connected(_on_host_viewport_size_changed):
		viewport.size_changed.connect(_on_host_viewport_size_changed)

func _on_host_viewport_size_changed() -> void:
	_apply_chrome_scale()
	# Re-stamp against the new viewport. Never re-measures content.
	if visible and dialog_variant == Variant.BASIC and _fixed_size_px != Vector2.ZERO:
		_position_dialog()

func _focus_first() -> void:
	_focus_first_action()

func _build_layout():
	# Scrim
	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(M3Theme.get_on_surface().r, M3Theme.get_on_surface().g, M3Theme.get_on_surface().b, 0.32)
	_scrim_alpha = _scrim.color.a
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)
	
	# Wrapper enforces the dialog's fixed size and position. Content clipping is
	# handled by the dialog container's clip_children, so the wrapper does not
	# clip the rounded panel corners or its shadow.
	_dialog_wrapper = Control.new()
	add_child(_dialog_wrapper)
	
	# Dialog container (PanelContainer)
	_dialog_container = PanelContainer.new()
	_dialog_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_dialog_container.size_flags_horizontal = Control.SIZE_FILL
	_dialog_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_dialog_wrapper.add_child(_dialog_container)

	_ensure_chrome_firewall()

	if dialog_variant == Variant.BASIC:
		_build_basic_layout()
	else:
		_build_fullscreen_layout()

## Min-size firewall: a plain (non-Container) Control with a (0,0) minimum
## between the PanelContainer and all dialog chrome. Non-Container Controls do
## not propagate their children's combined minimum size, so no content — e.g.
## an autowrap label whose min height is garbage until layout assigns it a
## width — can ever inflate the dialog's minimum past the stamp (the set_size
## clamp, control.cpp:1529). The stamp is the only source of dialog size.
func _ensure_chrome_firewall() -> void:
	if is_instance_valid(_chrome_firewall):
		return
	_chrome_firewall = Control.new()
	_chrome_firewall.name = "ChromeFirewall"
	_chrome_firewall.custom_minimum_size = Vector2(0, 0)
	_chrome_firewall.clip_contents = true
	_dialog_container.add_child(_chrome_firewall)

func _build_basic_layout():
	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chrome_firewall.add_child(_vbox)
	
	_vbox.add_theme_constant_override("separation", 0)
	
	# Top bar with title and close button for basic variant.
	var top_bar_hbox = HBoxContainer.new()
	top_bar_hbox.name = "TopBar"
	top_bar_hbox.custom_minimum_size = Vector2(0, M3Units.dp(FULLSCREEN_TOP_BAR_HEIGHT))
	top_bar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_child(top_bar_hbox)
	
	_top_bar_title = Label.new()
	_top_bar_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_top_bar_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_bar_hbox.add_child(_top_bar_title)
	
	_close_button = M3IconButton.new()
	_close_button.icon_name = "close"
	_close_button.pressed.connect(_on_close_button_pressed)
	_close_button.visible = dismissible
	top_bar_hbox.add_child(_close_button)
	
	_hero_icon = FontIcon.new()
	_hero_icon.icon_settings = _get_font_icon_settings()
	_hero_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_icon.visible = false
	_vbox.add_child(_hero_icon)
	
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.visible = false
	_vbox.add_child(_title_label)
	
	_title_body_spacer = Control.new()
	_title_body_spacer.custom_minimum_size = Vector2(0, M3Units.dp(16))
	_vbox.add_child(_title_body_spacer)
	
	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_body_label)
	
	_body_content_spacer = Control.new()
	_body_content_spacer.custom_minimum_size = Vector2(0, M3Units.dp(24))
	_body_content_spacer.name = "BodyContentSpacer"
	_vbox.add_child(_body_content_spacer)
	
	content_slot = VBoxContainer.new()
	content_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content_slot.clip_contents = true
	_vbox.add_child(content_slot)
	
	_divider = HSeparator.new()
	_divider.visible = false
	_vbox.add_child(_divider)
	
	_actions_container = HBoxContainer.new()
	_actions_container.alignment = BoxContainer.ALIGNMENT_END
	_actions_container.custom_minimum_size = Vector2(0, M3Units.dp(BASIC_ACTIONS_HEIGHT))
	_actions_container.add_theme_constant_override("separation", M3Units.dp(ACTIONS_GAP))
	_vbox.add_child(_actions_container)

func _build_fullscreen_layout():
	var bg_panel = Panel.new()
	bg_panel.name = "FullscreenBackground"
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_container.add_child(bg_panel)
	# The firewall is created before this runs, so the background would land on
	# top of it — hiding plain Labels and eating every click. Keep it beneath.
	_dialog_container.move_child(bg_panel, 0)

	_fullscreen_root = VBoxContainer.new()
	_fullscreen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chrome_firewall.add_child(_fullscreen_root)
	
	_top_bar = Panel.new()
	_top_bar.custom_minimum_size = Vector2(0, M3Units.dp(FULLSCREEN_TOP_BAR_HEIGHT))
	_fullscreen_root.add_child(_top_bar)
	
	var top_hbox = HBoxContainer.new()
	top_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_bar.add_child(top_hbox)
	
	_close_button = M3IconButton.new()
	_close_button.icon_name = "close"
	_close_button.pressed.connect(_on_close_button_pressed)
	_close_button.visible = dismissible
	
	_top_bar_title = Label.new()
	_top_bar_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_hbox.add_child(_top_bar_title)
	
	top_hbox.add_child(_close_button)
	
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fullscreen_root.add_child(_scroll)
	
	var scroll_margin = MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_margin = scroll_margin
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
	
	_hero_icon = FontIcon.new()
	_hero_icon.icon_settings = _get_font_icon_settings()
	_hero_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_icon.visible = false
	_scroll_content.add_child(_hero_icon)
	
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scroll_content.add_child(_title_label)
	
	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scroll_content.add_child(_body_label)
	
	content_slot = VBoxContainer.new()
	_scroll_content.add_child(content_slot)
	
	_bottom_actions = Panel.new()
	_bottom_actions.custom_minimum_size = Vector2(0, M3Units.dp(FULLSCREEN_ACTIONS_HEIGHT))
	_fullscreen_root.add_child(_bottom_actions)
	
	_actions_container = HBoxContainer.new()
	_actions_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_actions_container.alignment = BoxContainer.ALIGNMENT_END
	_actions_container.add_theme_constant_override("separation", M3Units.dp(ACTIONS_GAP))
	_bottom_actions.add_child(_actions_container)
	
	_dialog_container.set_anchors_preset(Control.PRESET_FULL_RECT)

func _rebuild_layout():
	# Disconnect and remove action buttons before clearing references
	for btn in _actions:
		for c in btn.pressed.get_connections():
			btn.pressed.disconnect(c.callable)
		if btn.get_parent():
			btn.get_parent().remove_child(btn)
	_actions.clear()
	
	for child in _dialog_container.get_children():
		child.queue_free()
	
	_vbox = null
	_fullscreen_root = null
	_top_bar = null
	_scroll = null
	_scroll_content = null
	_bottom_actions = null
	_title_body_spacer = null
	_body_content_spacer = null
	_chrome_firewall = null
	_ensure_chrome_firewall()
	
	if dialog_variant == Variant.BASIC:
		_build_basic_layout()
	else:
		_build_fullscreen_layout()
	_update_appearance()
	_update_text()
	_update_hero_icon()

func _add_default_action():
	if _actions.is_empty():
		add_action("OK", Callable(), true)

func _on_action_pressed(label: String):
	action_pressed.emit(label)

func _on_scrim_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		if dismissible:
			dismiss()

func _on_close_button_pressed() -> void:
	"""Default close-button behavior; subclasses can override to customize."""
	dismiss()

var _scroll_margin: MarginContainer = null

## Compact fullscreen chrome for small screens (viewport < 600dp wide or
## < 700dp tall, per _is_small_screen): tighter padding and shorter bars.
const COMPACT_PADDING := 12.0
const COMPACT_BAR_HEIGHT := 48.0

func _apply_chrome_scale() -> void:
	if dialog_variant != Variant.FULL_SCREEN or not is_inside_tree():
		return
	var small := _is_small_screen()
	if is_instance_valid(_scroll_margin):
		var pad := M3Units.dp(COMPACT_PADDING if small else PADDING)
		_scroll_margin.add_theme_constant_override("margin_left", pad)
		_scroll_margin.add_theme_constant_override("margin_right", pad)
		_scroll_margin.add_theme_constant_override("margin_top", pad)
		_scroll_margin.add_theme_constant_override("margin_bottom", pad)
	if is_instance_valid(_top_bar):
		_top_bar.custom_minimum_size = Vector2(0, M3Units.dp(COMPACT_BAR_HEIGHT if small else FULLSCREEN_TOP_BAR_HEIGHT))
	if is_instance_valid(_bottom_actions):
		_bottom_actions.custom_minimum_size = Vector2(0, M3Units.dp(COMPACT_BAR_HEIGHT if small else FULLSCREEN_ACTIONS_HEIGHT))

func _is_small_screen() -> bool:
	var viewport := M3Overlay.get_sizing_viewport(get_viewport())
	if not viewport:
		return false
	var viewport_size = viewport.get_visible_rect().size
	return viewport_size.x < M3Units.dp(600) or viewport_size.y < M3Units.dp(700)

func _focus_first_action() -> void:
	for btn in _actions:
		if btn is Control and btn.focus_mode != Control.FOCUS_NONE:
			if UIManager and UIManager.has_method("suppress_next_focus_sound"):
				UIManager.suppress_next_focus_sound()
			btn.grab_focus()
			return

func _get_usable_rect() -> Rect2:
	var viewport = M3Overlay.get_sizing_viewport(get_viewport())
	if not viewport:
		return Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var viewport_rect = viewport.get_visible_rect()
	
	# For SubViewports (dual-screen mode), the viewport rect is the authoritative
	# usable area; the screen safe-area is in root-window coordinates and may not
	# match the SubViewport coordinate space.
	if viewport is SubViewport:
		return viewport_rect
	
	# For the root window, intersect the viewport with the display safe area so
	# we don't position dialogs under system cutouts/taskbars. On desktop the safe
	# area can be the entire monitor while the window is smaller, so this falls
	# back to the viewport rect when it is smaller than the safe area.
	var safe_area = DisplayServer.get_display_safe_area()
	if safe_area.has_area():
		var window_pos = DisplayServer.window_get_position()
		var local_safe = Rect2(safe_area.position - window_pos, safe_area.size)
		var intersection = viewport_rect.intersection(local_safe)
		if intersection.has_area():
			return intersection
	return viewport_rect

func _is_content_sized() -> bool:
	return dialog_variant == Variant.BASIC and not fixed_size and not fill_viewport_height

func _position_dialog():
	var usable_rect = _get_usable_rect()
	var viewport_pos = usable_rect.position
	var viewport_size = usable_rect.size

	if dialog_variant == Variant.BASIC:
		var margin_per_side = M3Units.dp(24)
		var max_w = M3Units.dp(dialog_max_width)
		var max_h = M3Units.dp(BASIC_MAX_HEIGHT)
		var min_h = M3Units.dp(BASIC_MIN_HEIGHT)
		var dialog_width = min(max_w, viewport_size.x - margin_per_side * 2)
		var max_available_height := (viewport_size.y - margin_per_side * 2) as float

		var dialog_height: float
		if _is_content_sized():
			# Content-sized mode: analytic one-shot measure (pure function of
			# stamped width, dp scale, and text — no frames, no layout state),
			# then only re-clamp the stored height against new viewport sizes.
			if _content_height_px <= 0.0:
				_content_height_px = _measure_content_height(dialog_width)
			dialog_height = clamp(_content_height_px, min_h, max_h)
			dialog_height = min(dialog_height, max_available_height)
		else:
			# Stamped mode: height is a pure function of the viewport. Content
			# scrolls inside; it never resizes the dialog.
			dialog_height = clamp(max_available_height, min_h, max_h)

		_stamp_dialog(Vector2(dialog_width, dialog_height), viewport_pos, viewport_size)
	else:
		# Fullscreen: wrapper fills the full viewport (including any cutout areas).
		var sizing := M3Overlay.get_sizing_viewport(get_viewport())
		var full_viewport_size = sizing.get_visible_rect().size if sizing else Vector2(1920, 1080)
		_dialog_wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dialog_wrapper.position = Vector2.ZERO
		_dialog_wrapper.size = full_viewport_size

## Pin the container to the stamped size and center it in the wrapper. The
## wrapper is left un-clipped so the rounded panel corners and shadow are not
## cut off; the stylebox's content margin keeps children inside the shape.
func _stamp_dialog(size_px: Vector2, viewport_pos: Vector2, viewport_size: Vector2) -> void:
	_dialog_container.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_dialog_container.position = Vector2.ZERO
	_dialog_container.custom_minimum_size = size_px
	_dialog_container.size = size_px
	_dialog_wrapper.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	_dialog_wrapper.size = size_px
	_dialog_wrapper.position = viewport_pos + (viewport_size - size_px) / 2.0
	_fixed_size_px = size_px
	_report_content_budget("stamp")

# ============================================
# CONTENT MEASUREMENT (content-sized mode)
# ============================================

## One-shot analytic measure: every height contributor is a pure function of
## known inputs (stamped width, dp scale, text). Chrome rows are constants,
## wrapped text is shaped synchronously by TextServer (the same engine Label
## renders with), and fixed-spec controls report layout-independent minimums.
## No frames, no tree layout state — same inputs always give the same height.
func _measure_content_height(dialog_width: float) -> float:
	var sb := _dialog_container.get_theme_stylebox("panel")
	var ml: float = sb.get_margin(SIDE_LEFT) if sb else 0.0
	var mt: float = sb.get_margin(SIDE_TOP) if sb else 0.0
	var mr: float = sb.get_margin(SIDE_RIGHT) if sb else 0.0
	var mb: float = sb.get_margin(SIDE_BOTTOM) if sb else 0.0
	return _measure_min_height(_vbox, dialog_width - ml - mr) + mt + mb

func _measure_min_height(node: Control, width: float) -> float:
	if not node.visible:
		return 0.0
	var h := 0.0
	if node is Label:
		var label := node as Label
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF or width <= 0.0:
			h = label.get_combined_minimum_size().y
		else:
			h = _measure_wrapped_label(label, width)
	elif node is VBoxContainer:
		var sep := float(node.get_theme_constant("separation"))
		var count := 0
		for child in node.get_children():
			if child is Control and child.visible:
				h += _measure_min_height(child, width)
				count += 1
		if count > 1:
			h += sep * (count - 1)
	elif node is HBoxContainer:
		# Slot HBoxes hold fixed-spec rows; a wrapped label here would need its
		# share of the width, which only layout knows — the tripwire will flag it.
		for child in node.get_children():
			if child is Control and child.visible:
				h = maxf(h, _measure_min_height(child, width))
	elif node is MarginContainer:
		var l := float(node.get_theme_constant("margin_left"))
		var t := float(node.get_theme_constant("margin_top"))
		var r := float(node.get_theme_constant("margin_right"))
		var b := float(node.get_theme_constant("margin_bottom"))
		for child in node.get_children():
			if child is Control and child.visible:
				h = maxf(h, _measure_min_height(child, width - l - r) + t + b)
	elif node is PanelContainer:
		var sb := node.get_theme_stylebox("panel")
		var ml: float = sb.get_margin(SIDE_LEFT) if sb else 0.0
		var mt: float = sb.get_margin(SIDE_TOP) if sb else 0.0
		var mr: float = sb.get_margin(SIDE_RIGHT) if sb else 0.0
		var mb: float = sb.get_margin(SIDE_BOTTOM) if sb else 0.0
		for child in node.get_children():
			if child is Control and child.visible:
				h = maxf(h, _measure_min_height(child, width - ml - mr) + mt + mb)
	else:
		# Fixed-spec controls (buttons, spacers, sliders, icons, option
		# buttons): combined minimum is a layout-independent constant.
		h = node.get_combined_minimum_size().y
	return maxf(h, node.custom_minimum_size.y)

## Wrapped-label height at a known width, shaped by TextServer directly —
## identical input to what the Label renders, computed without the scene tree.
func _measure_wrapped_label(label: Label, width: float) -> float:
	if label.text.is_empty():
		return 0.0
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var p := TextParagraph.new()
	# Same autowrap-mode -> break-flags mapping Label applies (label.cpp).
	match label.autowrap_mode:
		TextServer.AUTOWRAP_WORD_SMART:
			p.break_flags = TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		TextServer.AUTOWRAP_WORD:
			p.break_flags = TextServer.BREAK_WORD_BOUND
		TextServer.AUTOWRAP_ARBITRARY:
			p.break_flags = TextServer.BREAK_GRAPHEME_BOUND
		_:
			p.break_flags = TextServer.BREAK_NONE
	p.line_spacing = float(label.get_theme_constant("line_spacing"))
	p.width = width
	p.add_string(label.text, font, font_size)
	return p.get_size().y

## Debug assertion (stamped mode only): page content's combined minimum must
## fit the stamped content area — content taller than the stamp is clipped by
## the firewall instead of scrolling. Fires => fix the page content (give it a
## ScrollContainer or hygienic fixed rows), do not re-add measurement here.
## Content-sized mode is exempt: its labels report garbage minimums until the
## first layout pass, and growth past the stamp is structurally impossible.
func _report_content_budget(tag: String) -> void:
	if _is_content_sized():
		return
	if not is_instance_valid(_vbox) or _fixed_size_px == Vector2.ZERO:
		return
	var sb := _dialog_container.get_theme_stylebox("panel")
	var margin_w: float = (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)) if sb else 0.0
	var margin_h: float = (sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM)) if sb else 0.0
	var budget := _fixed_size_px - Vector2(margin_w, margin_h)
	var min_size := _vbox.get_combined_minimum_size()
	if min_size.x > budget.x + 1.0 or min_size.y > budget.y + 1.0:
		M3Debug.geom("dialog", "CONTENT OVER BUDGET[%s]: content_min=%s content_area=%s" % [tag, min_size, budget])

## Settled-geometry hook (broadcast by the app's overlay manager to persistent
## overlays on debounced resizes and DS swaps): re-stamp from the new viewport.
## Never re-measures content.
func on_viewport_settled() -> void:
	if visible and is_inside_tree():
		_position_dialog()


# ============================================
# APPEARANCE
# ============================================

func _get_font_icon_settings() -> FontIconSettings:
	if _font_icon_template == null:
		_font_icon_template = FontIconSettings.new()
		_font_icon_template.icon_size = M3Units.dp(ICON_SIZE)
		_font_icon_template.icon_font = "MaterialIcons"
	return _font_icon_template.duplicate()

func _update_appearance():
	if _cached_fonts.is_empty():
		_cached_fonts = M3Theme.load_fonts()
	var fonts = _cached_fonts
	
	if dialog_variant == Variant.BASIC:
		var bg = M3Theme.get_surface_container()
		var sb = M3Theme.make_shadow(bg, M3Units.dpi(BASIC_RADIUS),
			M3Theme.ELEVATION_3["size"], M3Theme.ELEVATION_3["offset"], M3Theme.ELEVATION_3["color"])
		var pad = M3Units.dp(PADDING)
		if _is_small_screen():
			pad = M3Units.dp(16)
		sb.content_margin_left = pad
		sb.content_margin_right = pad
		sb.content_margin_top = pad
		sb.content_margin_bottom = pad
		_dialog_container.add_theme_stylebox_override("panel", sb)
		# Don't use clip_children here. The BASIC stylebox already insets content by
		# the full padding (24 dp, 16 dp on very small screens), which keeps the
		# content rectangle well inside the 28 dp rounded panel shape. Using
		# clip_children would nest with M3Card's own clip_children and cause
		# M3Card children to render behind the card background.
		
		_style_label(_top_bar_title, fonts["regular"], M3Units.dp(22), M3Theme.get_on_surface())
		_style_label(_title_label, fonts["regular"], M3Units.dp(24), M3Theme.get_on_surface())
		_style_label(_body_label, fonts["regular"], M3Units.dp(14), M3Theme.get_on_surface_variant())
		
		if _cached_divider_sb == null:
			_cached_divider_sb = StyleBoxLine.new()
		_cached_divider_sb.color = M3Theme.get_outline()
		_cached_divider_sb.thickness = 1
		_divider.add_theme_stylebox_override("separator", _cached_divider_sb)
		
		if _hero_icon and _hero_icon.visible:
			_hero_icon.icon_settings.icon_color = M3Theme.get_secondary()
		
	else:
		if _cached_bg_sb == null:
			_cached_bg_sb = StyleBoxFlat.new()
		_cached_bg_sb.bg_color = M3Theme.get_surface()
		for child in _dialog_container.get_children():
			if child.name == "FullscreenBackground":
				child.add_theme_stylebox_override("panel", _cached_bg_sb)
				break
		
		if _cached_top_bar_sb == null:
			_cached_top_bar_sb = StyleBoxFlat.new()
		_cached_top_bar_sb.bg_color = M3Theme.get_surface()
		_top_bar.add_theme_stylebox_override("panel", _cached_top_bar_sb)
		_style_label(_top_bar_title, fonts["regular"], M3Units.dp(22), M3Theme.get_on_surface())
		
		if _cached_bottom_actions_sb == null:
			_cached_bottom_actions_sb = StyleBoxFlat.new()
		_cached_bottom_actions_sb.bg_color = M3Theme.get_surface()
		_bottom_actions.add_theme_stylebox_override("panel", _cached_bottom_actions_sb)
		
		_style_label(_title_label, fonts["regular"], M3Units.dp(24), M3Theme.get_on_surface())
		_style_label(_body_label, fonts["regular"], M3Units.dp(14), M3Theme.get_on_surface_variant())
		
		if _hero_icon and _hero_icon.visible:
			_hero_icon.icon_settings.icon_color = M3Theme.get_secondary()

func _style_label(label: Label, font: Font, font_size: int, color: Color):
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

func _update_text():
	if _title_label:
		_title_label.text = title_text
		if dialog_variant == Variant.BASIC:
			_title_label.visible = false
		else:
			_title_label.visible = not title_text.is_empty()
	if _body_label:
		_body_label.text = body_text
		_body_label.visible = not body_text.is_empty()
	if _body_content_spacer:
		_body_content_spacer.visible = _body_label.visible
	if _top_bar_title:
		_top_bar_title.text = title_text
		_top_bar_title.visible = not title_text.is_empty()

func _update_hero_icon():
	if not _hero_icon:
		return
	
	if hero_icon_name.is_empty():
		_hero_icon.visible = false
	else:
		_hero_icon.icon_settings.icon_name = hero_icon_name
		_hero_icon.visible = true

func refresh_theme():
	if not _ready_called:
		return
	_update_appearance()

func _update_sizes():
	if dialog_variant == Variant.BASIC:
		if _vbox:
			var top_bar_hbox = _vbox.get_node_or_null("TopBar")
			if top_bar_hbox:
				top_bar_hbox.custom_minimum_size = Vector2(0, M3Units.dp(FULLSCREEN_TOP_BAR_HEIGHT))
		if _title_body_spacer:
			_title_body_spacer.custom_minimum_size = Vector2(0, M3Units.dp(16))
		if _body_content_spacer:
			_body_content_spacer.custom_minimum_size = Vector2(0, M3Units.dp(24))
		if _actions_container:
			_actions_container.custom_minimum_size = Vector2(0, M3Units.dp(BASIC_ACTIONS_HEIGHT))
	else:
		if _top_bar:
			_top_bar.custom_minimum_size = Vector2(0, M3Units.dp(FULLSCREEN_TOP_BAR_HEIGHT))
		if _scroll and _scroll.get_child_count() > 0:
			var scroll_margin = _scroll.get_child(0)
			if scroll_margin is MarginContainer:
				var pad = M3Units.dp(PADDING)
				scroll_margin.add_theme_constant_override("margin_left", pad)
				scroll_margin.add_theme_constant_override("margin_right", pad)
				scroll_margin.add_theme_constant_override("margin_top", pad)
				scroll_margin.add_theme_constant_override("margin_bottom", pad)
		if _scroll_content:
			_scroll_content.add_theme_constant_override("separation", M3Units.dp(16))
		if _bottom_actions:
			_bottom_actions.custom_minimum_size = Vector2(0, M3Units.dp(FULLSCREEN_ACTIONS_HEIGHT))
	if _actions_container:
		_actions_container.add_theme_constant_override("separation", M3Units.dp(ACTIONS_GAP))
	if _font_icon_template:
		_font_icon_template.icon_size = M3Units.dp(ICON_SIZE)
	if _hero_icon and _hero_icon.icon_settings:
		_hero_icon.icon_settings.icon_size = M3Units.dp(ICON_SIZE)

func refresh_scale() -> void:
	if not _ready_called:
		return
	_update_sizes()
	refresh_theme()
	if visible and is_inside_tree() and not Engine.is_editor_hint():
		_position_dialog()

# ============================================
# STATIC FACTORIES
# ============================================

static func show_dialog(dialog: M3Dialog):
	var parent = M3Overlay.get_overlay_parent()
	if parent:
		parent.add_child(dialog)
		dialog.show_overlay()

static func show_confirm(title: String, body: String, on_accept: Callable = Callable(), on_cancel: Callable = Callable()) -> M3Dialog:
	var dialog = M3Dialog.new()
	dialog.title_text = title
	dialog.body_text = body
	dialog.add_action("Cancel", on_cancel, false)
	dialog.add_action("Accept", on_accept, true)
	show_dialog(dialog)
	return dialog

static func show_alert(title: String, body: String, on_ok: Callable = Callable()) -> M3Dialog:
	var dialog = M3Dialog.new()
	dialog.title_text = title
	dialog.body_text = body
	dialog.add_action("OK", on_ok, true)
	show_dialog(dialog)
	return dialog

static func dismiss_current():
	M3Overlay.dismiss_type("dialog")
