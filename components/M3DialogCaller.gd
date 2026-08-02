class_name M3DialogCaller
extends CanvasLayer

## Material 3 Dialog Caller
## Manages dialog presentation with scrim overlay.
## Handles modal blocking, positioning, and cleanup.

const M3Units = preload("res://addons/m3/M3Units.gd")

# ============================================
# STATIC INSTANCE
# ============================================

static var _current_caller: M3DialogCaller = null

## Show a dialog with the given configuration.
static func show_dialog(dialog: M3Dialog):
	# Dismiss any existing dialog
	if _current_caller != null and is_instance_valid(_current_caller):
		_current_caller.dismiss()
	
	var caller = M3DialogCaller.new()
	caller._setup_dialog(dialog)
	
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		tree.root.add_child(caller)
		_current_caller = caller

## Show a confirmation dialog with title, body, and accept/cancel actions.
static func show_confirm(title: String, body: String, on_accept: Callable = Callable(), on_cancel: Callable = Callable()) -> M3Dialog:
	var dialog = M3Dialog.new()
	dialog.title_text = title
	dialog.body_text = body
	dialog.add_action("Cancel", on_cancel, false)
	dialog.add_action("Accept", on_accept, true)
	show_dialog(dialog)
	return dialog

## Show an alert dialog with title, body, and OK action.
static func show_alert(title: String, body: String, on_ok: Callable = Callable()) -> M3Dialog:
	var dialog = M3Dialog.new()
	dialog.title_text = title
	dialog.body_text = body
	dialog.add_action("OK", on_ok, true)
	show_dialog(dialog)
	return dialog

## Dismiss the currently showing dialog.
static func dismiss_current():
	if _current_caller != null and is_instance_valid(_current_caller):
		_current_caller.dismiss()
		_current_caller = null

## Check if a dialog is currently showing.
static func is_showing() -> bool:
	return _current_caller != null and is_instance_valid(_current_caller)

# ============================================
# INTERNAL
# ============================================

var _scrim: ColorRect
var _dialog: M3Dialog

func _setup_dialog(dialog: M3Dialog):
	_dialog = dialog
	layer = 90  # Below snackbar (100), above normal content
	
	# Create scrim overlay
	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(M3Theme.get_on_surface().r, M3Theme.get_on_surface().g, M3Theme.get_on_surface().b, 0.32)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)
	
	# Connect scrim click to dismiss
	_scrim.gui_input.connect(_on_scrim_input)
	
	# Add dialog as child of CanvasLayer
	add_child(dialog)
	
	# Connect dialog close
	dialog.dismissed.connect(_on_dialog_dismissed)
	
	# Position the dialog
	_position_dialog(dialog)
	
	# Show dialog
	dialog.show()

func _position_dialog(dialog: M3Dialog):
	var viewport_size = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1920, 1080)
	
	if dialog.dialog_variant == M3Dialog.Variant.BASIC:
		var max_width = M3Units.dp(M3Dialog.BASIC_MAX_WIDTH)
		var dialog_width = min(max_width, viewport_size.x - M3Units.dp(48))
		var min_height = M3Units.dp(200)
		
		# Use center anchors with negative offsets for true centering
		dialog.anchor_left = 0.5
		dialog.anchor_top = 0.5
		dialog.anchor_right = 0.5
		dialog.anchor_bottom = 0.5
		
		dialog.offset_left = -dialog_width / 2.0
		dialog.offset_top = -min_height / 2.0
		dialog.offset_right = dialog_width / 2.0
		dialog.offset_bottom = min_height / 2.0
		
		dialog.custom_minimum_size = Vector2(dialog_width, min_height)
	else:
		# Full screen - explicit position and size
		dialog.position = Vector2.ZERO
		dialog.size = viewport_size

func _on_scrim_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if _dialog and _dialog.dismissible:
			_dialog.dismiss()

func _on_dialog_dismissed():
	_current_caller = null
	queue_free()

func dismiss():
	if _dialog:
		_dialog.dismiss()
