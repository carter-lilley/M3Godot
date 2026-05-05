@tool
class_name M3NavigationRail
extends M3Navigation

## Material 3 Navigation Rail
## Vertical navigation component with collapsed (icon-only) and expanded (icon+label) modes.

enum MenuGravity { TOP, CENTER, BOTTOM }

# ============================================
# SIZE SPECS (all values in dp)
# ============================================

const WIDTH_COLLAPSED := 96
const WIDTH_EXPANDED := 220
const ITEM_HEIGHT_COLLAPSED := 60
const ITEM_HEIGHT_EXPANDED := 56

# ============================================
# EXPORTS
# ============================================

@export var menu_gravity: MenuGravity = MenuGravity.TOP:
	set(value):
		if value == menu_gravity:
			return
		menu_gravity = value
		_update_menu_gravity()

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
var _items_area: VBoxContainer
var _menu_button: M3IconButton
var _menu_wrapper: MarginContainer
var _top_spacer: Control
var _top_flex_spacer: Control
var _bottom_flex_spacer: Control
var _header_nodes: Array[Node] = []
var _sectioned_items: Array[M3NavigationDestination] = []

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
	
	# Menu toggle button wrapped in MarginContainer for alignment
	_menu_wrapper = MarginContainer.new()
	_menu_wrapper.name = "MenuWrapper"
	_menu_wrapper.add_theme_constant_override("margin_top", 0)
	_menu_wrapper.add_theme_constant_override("margin_bottom", 0)
	_content_container.add_child(_menu_wrapper)
	
	_menu_button = M3IconButton.new()
	_menu_button.name = "MenuButton"
	_menu_button.icon_name = "menu"
	_menu_button.icon_button_variant = M3IconButton.IconVariant.STANDARD
	_menu_button.icon_button_size = M3IconButton.IconSize.MEDIUM
	_menu_button.pressed.connect(_on_menu_button_pressed)
	_menu_wrapper.add_child(_menu_button)
	
	# Items area container (takes all remaining space, holds flex spacers and items)
	_items_area = VBoxContainer.new()
	_items_area.name = "ItemsArea"
	_items_area.add_theme_constant_override("separation", 0)
	_items_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_child(_items_area)
	
	_update_dimensions()

func _update_dimensions():
	if not _content_container or not _menu_wrapper:
		return
	
	var width_px = M3Units.dp(WIDTH_EXPANDED) if expanded else M3Units.dp(WIDTH_COLLAPSED)
	custom_minimum_size = Vector2(width_px, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Position menu button via MarginContainer margins
	var btn_size = M3Units.dp(48)
	if expanded:
		# Left-aligned at 24dp (slightly inset, but not as far as destinations)
		_menu_wrapper.add_theme_constant_override("margin_left", M3Units.dp(24))
		_menu_wrapper.add_theme_constant_override("margin_right", width_px - M3Units.dp(24) - btn_size)
	else:
		# Centered
		var side_margin = (width_px - btn_size) / 2.0
		_menu_wrapper.add_theme_constant_override("margin_left", side_margin)
		_menu_wrapper.add_theme_constant_override("margin_right", side_margin)

func _on_menu_button_pressed():
	expanded = not expanded

func _update_menu_gravity():
	if not _top_flex_spacer or not _bottom_flex_spacer:
		return
	
	# Reset
	_top_flex_spacer.size_flags_vertical = 0
	_top_flex_spacer.custom_minimum_size = Vector2.ZERO
	_bottom_flex_spacer.size_flags_vertical = 0
	_bottom_flex_spacer.custom_minimum_size = Vector2.ZERO
	
	match menu_gravity:
		MenuGravity.TOP:
			_bottom_flex_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		MenuGravity.CENTER:
			var rail_height = size.y
			# Menu area = top spacer (12dp) + menu button height (48dp for MEDIUM)
			var menu_btn_height = _menu_button.custom_minimum_size.y if _menu_button else M3Units.dp(48)
			var menu_area_height = _top_spacer.custom_minimum_size.y + menu_btn_height
			var items_height = _calculate_items_height()
			# Center items within the ENTIRE rail, not just the space below the menu
			# items_center = menu_area + top_padding + items_height/2 = rail_height/2
			# top_padding = (rail_height - items_height)/2 - menu_area_height
			var top_padding = (rail_height - items_height) / 2.0 - menu_area_height
			
			if top_padding > 0:
				_top_flex_spacer.custom_minimum_size = Vector2(0, top_padding)
			_bottom_flex_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		MenuGravity.BOTTOM:
			_top_flex_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _calculate_items_height() -> float:
	var total = 0.0
	for child in _items_area.get_children():
		if child == _top_flex_spacer or child == _bottom_flex_spacer:
			continue
		if child.visible:
			total += child.custom_minimum_size.y if child.custom_minimum_size.y > 0 else child.size.y
	return total

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if menu_gravity == MenuGravity.CENTER:
			_update_menu_gravity()

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
	
	# Clear header nodes
	for node in _header_nodes:
		if node.get_parent():
			node.get_parent().remove_child(node)
		node.queue_free()
	_header_nodes.clear()
	
	# Clear sectioned items list
	_sectioned_items.clear()
	
	# Remove all children from items area
	for child in _items_area.get_children():
		_items_area.remove_child(child)
		child.queue_free()
	
	# Re-add top flex spacer
	_top_flex_spacer = Control.new()
	_top_flex_spacer.name = "TopFlexSpacer"
	_items_area.add_child(_top_flex_spacer)
	
	# Build new items
	var item_idx = 0
	var in_section = false
	for i in range(destinations.size()):
		var data = destinations[i]
		
		# Check if this is a section header
		if data.icon_name.is_empty() and not data.label.is_empty():
			in_section = true
			
			# Add spacing before header
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, M3Units.dp(12))
			spacer.visible = expanded
			_items_area.add_child(spacer)
			_header_nodes.append(spacer)
			
			# Create header label
			var header = Label.new()
			header.text = data.label
			header.add_theme_font_size_override("font_size", M3Units.dp(12))
			header.add_theme_color_override("font_color", M3Theme.get_on_surface_variant())
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			# Padding for header - aligned with icons at 36dp
			var header_container = MarginContainer.new()
			header_container.add_theme_constant_override("margin_left", M3Units.dp(36))
			header_container.add_theme_constant_override("margin_right", M3Units.dp(16))
			header_container.add_theme_constant_override("margin_top", M3Units.dp(12))
			header_container.add_theme_constant_override("margin_bottom", M3Units.dp(8))
			header_container.add_child(header)
			header_container.visible = expanded
			_items_area.add_child(header_container)
			_header_nodes.append(header_container)
			continue
		
		# Create destination item
		var item = M3NavigationDestination.new()
		item.destination_icon = data.icon_name
		item.destination_label = data.label
		item.destination_layout = M3NavigationDestination.LayoutMode.HORIZONTAL if expanded else M3NavigationDestination.LayoutMode.VERTICAL
		item.active = (item_idx == selected_index)
		item.disabled = data.disabled
		item.label_visibility = _get_effective_label_visibility()
		# Size: collapsed fills width, expanded shrinks to content width
		var height_px = M3Units.dp(ITEM_HEIGHT_EXPANDED) if expanded else M3Units.dp(ITEM_HEIGHT_COLLAPSED)
		item.custom_minimum_size.y = height_px
		if expanded:
			item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		else:
			item.custom_minimum_size.x = M3Units.dp(WIDTH_COLLAPSED)
			item.size_flags_horizontal = Control.SIZE_FILL
		
		# If under a section, mark as sectioned and hide in collapsed mode
		if in_section:
			_sectioned_items.append(item)
			item.visible = expanded
		
		# Connect signal - use item_idx which accounts for skipped headers
		var idx = item_idx
		item.pressed.connect(func(): _on_destination_pressed(idx))
		
		_destination_items.append(item)
		_items_area.add_child(item)
		item_idx += 1
	
	# Add bottom flex spacer after all items
	_bottom_flex_spacer = Control.new()
	_bottom_flex_spacer.name = "BottomFlexSpacer"
	_items_area.add_child(_bottom_flex_spacer)
	
	# Ensure header content is at the end of content container if present
	if header_content and header_content.get_parent() == _content_container:
		_content_container.move_child(header_content, -1)
	
	_update_menu_gravity()

func _update_destinations_layout():
	# Toggle header visibility
	for node in _header_nodes:
		node.visible = expanded
	
	# Toggle sectioned item visibility
	for item in _sectioned_items:
		item.visible = expanded
	
	for item in _destination_items:
		item.destination_layout = M3NavigationDestination.LayoutMode.HORIZONTAL if expanded else M3NavigationDestination.LayoutMode.VERTICAL
		item.label_visibility = _get_effective_label_visibility()
		# Size: collapsed fills width, expanded shrinks to content width
		var height_px = M3Units.dp(ITEM_HEIGHT_EXPANDED) if expanded else M3Units.dp(ITEM_HEIGHT_COLLAPSED)
		item.custom_minimum_size.y = height_px
		if expanded:
			item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		else:
			item.custom_minimum_size.x = M3Units.dp(WIDTH_COLLAPSED)
			item.size_flags_horizontal = Control.SIZE_FILL
	
	_update_menu_gravity()

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
