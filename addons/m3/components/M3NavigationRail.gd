@tool
class_name M3NavigationRail
extends M3Navigation

## Material 3 Navigation Rail
## Vertical navigation component with collapsed (icon-only) and expanded (icon+label) modes.

# ============================================
# SIZE SPECS (all values in dp)
# ============================================

const WIDTH_COLLAPSED := 96
const WIDTH_EXPANDED := 360
const ITEM_HEIGHT_COLLAPSED := 80
const ITEM_HEIGHT_EXPANDED := 56

# ============================================
# EXPORTS
# ============================================

@export var expanded: bool = false:
	set(value):
		if value == expanded:
			return
		expanded = value
		_update_dimensions()
		_update_destinations_layout()
		queue_redraw()

@export var header_content: Node = null:
	set(value):
		if value == header_content:
			return
		if header_content and header_content.get_parent():
			header_content.get_parent().remove_child(header_content)
		header_content = value
		if header_content:
			# Add to end of content container
			if _content_container:
				_content_container.add_child(header_content)
		_update_dimensions()

# ============================================
# INTERNAL
# ============================================

var _content_container: VBoxContainer
var _menu_button: M3IconButton
var _top_spacer: Control

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	_create_layout()
	super._ready()

func _create_layout():
	# Single child: VBoxContainer
	_content_container = VBoxContainer.new()
	_content_container.name = "ContentContainer"
	_content_container.add_theme_constant_override("separation", 0)
	add_child(_content_container)
	
	# Top spacer for padding
	_top_spacer = Control.new()
	_top_spacer.name = "TopSpacer"
	_top_spacer.custom_minimum_size = Vector2(0, M3Units.dp(12))
	_content_container.add_child(_top_spacer)
	
	# Menu toggle button
	_menu_button = M3IconButton.new()
	_menu_button.name = "MenuButton"
	_menu_button.icon_name = "menu"
	_menu_button.icon_button_variant = M3IconButton.IconVariant.STANDARD
	_menu_button.icon_button_size = M3IconButton.IconSize.MEDIUM
	_menu_button.pressed.connect(_on_menu_button_pressed)
	_content_container.add_child(_menu_button)
	
	_update_dimensions()

func _update_dimensions():
	if not _content_container:
		return
	
	var width_px = M3Units.dp(WIDTH_EXPANDED) if expanded else M3Units.dp(WIDTH_COLLAPSED)
	custom_minimum_size = Vector2(width_px, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _on_menu_button_pressed():
	expanded = not expanded

# ============================================
# DESTINATION MANAGEMENT (override)
# ============================================

func _rebuild_destinations():
	if not _content_container:
		return
	
	# Clear destination items
	for item in _destination_items:
		if item.get_parent():
			item.get_parent().remove_child(item)
		item.queue_free()
	_destination_items.clear()
	
	# Remove all children except spacer and menu button
	var to_remove = []
	for child in _content_container.get_children():
		if child != _top_spacer and child != _menu_button and child != header_content:
			to_remove.append(child)
	
	for child in to_remove:
		_content_container.remove_child(child)
		child.queue_free()
	
	# Build new items
	for i in range(destinations.size()):
		var data = destinations[i]
		
		# Check if this is a section header
		if data.icon_name.is_empty() and not data.label.is_empty():
			# Add spacing before header
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, M3Units.dp(12))
			_content_container.add_child(spacer)
			
			# Create header label
			var header = Label.new()
			header.text = data.label
			header.add_theme_font_size_override("font_size", M3Units.dp(12))
			header.add_theme_color_override("font_color", M3Theme.get_on_surface_variant())
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if expanded else HORIZONTAL_ALIGNMENT_CENTER
			
			# Padding for header
			var header_container = MarginContainer.new()
			header_container.add_theme_constant_override("margin_left", M3Units.dp(16))
			header_container.add_theme_constant_override("margin_right", M3Units.dp(16))
			header_container.add_theme_constant_override("margin_top", M3Units.dp(12))
			header_container.add_theme_constant_override("margin_bottom", M3Units.dp(8))
			header_container.add_child(header)
			_content_container.add_child(header_container)
			continue
		
		# Create destination item
		var item = M3NavigationDestination.new()
		item.destination_icon = data.icon_name
		item.destination_label = data.label
		item.destination_layout = M3NavigationDestination.LayoutMode.HORIZONTAL if expanded else M3NavigationDestination.LayoutMode.VERTICAL
		item.active = (i == selected_index)
		item.disabled = data.disabled
		item.custom_minimum_size = Vector2(
			M3Units.dp(WIDTH_EXPANDED) if expanded else M3Units.dp(WIDTH_COLLAPSED),
			M3Units.dp(ITEM_HEIGHT_EXPANDED) if expanded else M3Units.dp(ITEM_HEIGHT_COLLAPSED)
		)
		
		# Connect signal
		var idx = i
		item.pressed.connect(func(): _on_destination_pressed(idx))
		
		_destination_items.append(item)
		_content_container.add_child(item)
	
	# Ensure header content is at the end if present
	if header_content and header_content.get_parent() == _content_container:
		_content_container.move_child(header_content, -1)

func _update_destinations_layout():
	for item in _destination_items:
		item.destination_layout = M3NavigationDestination.LayoutMode.HORIZONTAL if expanded else M3NavigationDestination.LayoutMode.VERTICAL
		item.custom_minimum_size = Vector2(
			M3Units.dp(WIDTH_EXPANDED) if expanded else M3Units.dp(WIDTH_COLLAPSED),
			M3Units.dp(ITEM_HEIGHT_EXPANDED) if expanded else M3Units.dp(ITEM_HEIGHT_COLLAPSED)
		)

# ============================================
# THEME
# ============================================

func refresh_theme():
	super.refresh_theme()
	if _menu_button:
		_menu_button.refresh_theme()
	# Update header label colors
	for child in _content_container.get_children():
		if child is MarginContainer:
			for label in child.get_children():
				if label is Label:
					label.add_theme_color_override("font_color", M3Theme.get_on_surface_variant())
