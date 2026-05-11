class_name M3Menu
extends M3Overlay

const M3MenuItem = preload("res://addons/m3/components/M3MenuItem.gd")
const M3MenuRenderer = preload("res://addons/m3/components/M3MenuRenderer.gd")

## Material 3 Menu Component
## Extends M3Overlay for consistent overlay behavior.
## Builds and shows M3-styled popup menus.

const M3Units = preload("res://addons/m3/M3Units.gd")

# ============================================
# EXPORTS
# ============================================

@export var menu_variant: M3MenuRenderer.ColorVariant = M3MenuRenderer.ColorVariant.STANDARD:
	set(value):
		if value == menu_variant:
			return
		menu_variant = value

# ============================================
# INTERNAL
# ============================================

var _items: Array[M3MenuItem] = []
var _renderer: M3MenuRenderer = null

# ============================================
# LIFECYCLE
# ============================================

func _init():
	super._init()
	overlay_type = "menu"
	overlay_layer = 95

# ============================================
# BUILDER API
# ============================================

## Add a normal menu item.
func add_item(text: String, callback: Callable = Callable(), icon: String = "", trailing_icon: String = ""):
	_items.append(M3MenuItem.make_normal(text, icon, callback, trailing_icon))

## Add a checkable menu item.
func add_check_item(text: String, checked: bool = false, callback: Callable = Callable(), icon: String = "", trailing_icon: String = ""):
	_items.append(M3MenuItem.make_checkable(text, checked, icon, callback, trailing_icon))

## Add a two-line menu item.
func add_two_line_item(primary: String, secondary: String, callback: Callable = Callable(), icon: String = "", trailing_icon: String = ""):
	_items.append(M3MenuItem.make_two_line(primary, secondary, icon, callback, trailing_icon))

## Add a section label (non-interactive heading).
func add_section_label(text: String):
	_items.append(M3MenuItem.make_section_label(text))

## Add a separator line.
func add_separator():
	_items.append(M3MenuItem.make_separator())

## Remove all items.
func clear():
	_items.clear()
	if _renderer and _renderer.is_open():
		_renderer.dismiss()

## Get the number of items.
func get_item_count() -> int:
	return _items.size()

## Get an item by index.
func get_item(index: int) -> M3MenuItem:
	if index >= 0 and index < _items.size():
		return _items[index]
	return null

# ============================================
# POPUP API
# ============================================

## Show the menu popup anchored to the given Control.
func popup(anchor: Control):
	if _items.is_empty():
		return
	
	show_overlay()
	
	_ensure_renderer()
	_renderer.popup(_items, anchor, menu_variant)
	_renderer.item_pressed.connect(_on_item_pressed, CONNECT_ONE_SHOT)
	_renderer.dismissed.connect(_on_renderer_dismissed, CONNECT_ONE_SHOT)

## Check if the menu is currently open.
func is_open() -> bool:
	return _renderer != null and _renderer.is_open()

# ============================================
# OVERRIDES
# ============================================

func show_overlay():
	var tree = Engine.get_main_loop()
	if tree and tree.root and get_parent() == null:
		tree.root.add_child(self)
	super.show_overlay()

# ============================================
# PRIVATE
# ============================================

func _ensure_renderer():
	if _renderer == null or not is_instance_valid(_renderer):
		_renderer = M3MenuRenderer.new()
		_renderer.name = "M3MenuRenderer"
		add_child(_renderer)

func _on_item_pressed(index: int):
	pass

func _on_renderer_dismissed():
	# Renderer dismissed itself (outside click or item selection)
	# Use M3Overlay dismiss to clean up singleton registry
	super.dismiss()
