@tool
class_name M3NavigationBar
extends M3Navigation

## Material 3 Bottom Navigation Bar
## Horizontal navigation component for top-level destinations.

# ============================================
# SIZE SPECS (all values in dp)
# ============================================

const HEIGHT := 80
const ITEM_PADDING := 12

# ============================================
# INTERNAL
# ============================================

var _content_container: HBoxContainer

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	_create_layout()
	super._ready()

func _create_layout():
	# Set fixed height
	custom_minimum_size = Vector2(0, M3Units.dp(HEIGHT))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_END
	
	# Create horizontal content container
	_content_container = HBoxContainer.new()
	_content_container.name = "ContentContainer"
	_content_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_container.add_theme_constant_override("separation", 0)
	add_child(_content_container)

# ============================================
# DESTINATION MANAGEMENT (override)
# ============================================

func _rebuild_destinations():
	# Guard: container not initialized yet
	if not _content_container:
		return
	
	# Clear existing items
	for item in _destination_items:
		if item.get_parent():
			item.get_parent().remove_child(item)
		item.queue_free()
	_destination_items.clear()
	
	# Clear content container
	for child in _content_container.get_children():
		_content_container.remove_child(child)
		child.queue_free()
	
	# Build new items - each item expands to fill space
	for i in range(destinations.size()):
		var data = destinations[i]
		
		# Create destination item
		var item = M3NavigationDestination.new()
		item.destination_icon = data.icon_name
		item.destination_label = data.label
		item.destination_layout = M3NavigationDestination.LayoutMode.VERTICAL
		item.active = (i == selected_index)
		item.disabled = data.disabled
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Connect signal
		var idx = i
		item.pressed.connect(func(): _on_destination_pressed(idx))
		
		_destination_items.append(item)
		_content_container.add_child(item)

func _update_destinations_layout():
	for item in _destination_items:
		item.destination_layout = M3NavigationDestination.LayoutMode.VERTICAL

# ============================================
# THEME
# ============================================

func refresh_theme():
	super.refresh_theme()
