@tool
class_name M3Navigation
extends PanelContainer

## Abstract base class for Material 3 Navigation components.
## Subclasses: M3NavigationRail, M3NavigationBar

signal destination_selected(index: int, reselected: bool)

# ============================================
# EXPORTS
# ============================================

@export var destinations: Array = []:
	set(value):
		destinations = value
		_rebuild_destinations()

@export var selected_index: int = -1:
	set(value):
		if value == selected_index:
			return
		var old_index = selected_index
		selected_index = value
		_update_selection(old_index)

# ============================================
# INTERNAL
# ============================================

var _destination_items: Array[M3NavigationDestination] = []
var _cached_background: StyleBoxFlat

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	_initialize_background()
	_rebuild_destinations()

func _initialize_background():
	_cached_background = StyleBoxFlat.new()
	_cached_background.bg_color = M3Theme.get_surface_container()
	add_theme_stylebox_override("panel", _cached_background)

# ============================================
# DESTINATION MANAGEMENT
# ============================================

func _rebuild_destinations():
	# Override in subclasses
	pass

func _update_selection(old_index: int):
	# Update visual state of items
	for i in range(_destination_items.size()):
		var item = _destination_items[i]
		item.active = (i == selected_index)
	
	# Emit signal
	if selected_index >= 0 and selected_index < destinations.size():
		var reselected = (old_index == selected_index)
		destination_selected.emit(selected_index, reselected)

func _on_destination_pressed(index: int):
	if index < 0 or index >= destinations.size():
		return
	if destinations[index].disabled:
		return
	selected_index = index

# ============================================
# THEME
# ============================================

func refresh_theme():
	if _cached_background:
		_cached_background.bg_color = M3Theme.get_surface_container()
	for item in _destination_items:
		item.refresh_theme()

# ============================================
# PUBLIC API
# ============================================

func get_destination_count() -> int:
	return destinations.size()

func set_destination_enabled(index: int, enabled: bool):
	if index >= 0 and index < destinations.size():
		destinations[index].disabled = not enabled
		if index < _destination_items.size():
			_destination_items[index].disabled = not enabled
