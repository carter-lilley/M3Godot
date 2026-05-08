extends Control

const CONTENT_PADDING := 20.0

@export var dark_mode: bool = false:
	set(value):
		dark_mode = value
		M3Theme.is_dark_mode = dark_mode
		apply_theme()

func _ready():
	M3Theme.is_dark_mode = dark_mode
	apply_theme()
	
	# Connect dark mode toggle
	var dark_mode_toggle = $MarginContainer/ScrollContainer/VBoxContainer/DarkmodeToggle
	dark_mode_toggle.button_pressed = dark_mode
	dark_mode_toggle.toggled.connect(_on_dark_mode_toggled)
	
	# Populate MenuButton
	var menu = $MarginContainer/ScrollContainer/VBoxContainer/RowBasicControls/MenuButton.get_popup()
	menu.add_item("Item 1")
	menu.add_item("Item 2")
	menu.add_item("Item 3")
	
	# Populate OptionButton
	var option = $MarginContainer/ScrollContainer/VBoxContainer/RowBasicControls/OptionButton
	option.add_item("Option 1")
	option.add_item("Option 2")
	option.add_item("Option 3")
	option.select(0)
	
	# Set RichTextLabel content
	$MarginContainer/ScrollContainer/VBoxContainer/RowTextAreas/RichTextLabel.text = "[b]Bold[/b] and [i]italic[/i] text\n[color=red]Colored text[/color]\n[code]Code snippet[/code]"
	
	# Configure NavigationRail
	var nav_rail = $NavigationRail
	var nav_destinations = [
		_create_nav_dest("home", "Home"),
		_create_nav_dest("star", "Favorites"),
		_create_nav_dest("search", "Search"),
		_create_nav_dest("", "Section A"),
		_create_nav_dest("settings", "Settings"),
		_create_nav_dest("info", "About"),
	]
	nav_rail.destinations = nav_destinations
	
	# Configure NavigationBar
	var nav_bar = $NavigationBar
	var bar_destinations = [
		_create_nav_dest("home", "Home"),
		_create_nav_dest("star", "Favorites"),
		_create_nav_dest("search", "Search"),
		_create_nav_dest("settings", "Settings"),
	]
	nav_bar.destinations = bar_destinations
	
	# Set up content slot for integrated mode
	var margin_container = $MarginContainer
	nav_rail.content_node = margin_container
	nav_bar.content_node = margin_container
	# For testing: use INTEGRATED mode (nav pushes content)
	# Change to OVERLAY if you want nav to float over content
	# nav_rail.placement_mode = M3Navigation.PlacementMode.INTEGRATED
	# nav_bar.placement_mode = M3Navigation.PlacementMode.INTEGRATED
	
	# Connect snackbar test button
	var snackbar_btn = $MarginContainer/ScrollContainer/VBoxContainer/SnackbarTestButton
	if snackbar_btn:
		snackbar_btn.pressed.connect(_on_snackbar_test_pressed)

func _on_snackbar_test_pressed():
	M3Snackbar.show_message(
		"Item deleted",
		"Undo",
		func(): print("Undo clicked!"),
		true
	)

func _on_dark_mode_toggled(pressed: bool):
	dark_mode = pressed

func _create_nav_dest(icon: String, label: String) -> M3NavigationDestinationData:
	var data = M3NavigationDestinationData.new()
	data.icon_name = icon
	data.label = label
	return data

func apply_theme():
	var theme = M3Theme.generate_theme()
	self.theme = theme
	
	# Background is now a Panel, uses theme's Panel stylebox automatically
	# But we need to make sure it picks up the theme
	$Background.queue_redraw()
	
	# Update the ColorRect to show surface variant color
	var color_rect = $MarginContainer/ScrollContainer/VBoxContainer/RowToggles/ColorRect
	if color_rect:
		color_rect.color = M3Theme.get_surface_variant()
	
	# Update elevation preview panels
	var elevation_row = $MarginContainer/ScrollContainer/VBoxContainer/RowElevation
	for i in range(6):
		var panel = elevation_row.get_node("Elevation%d" % i)
		if panel:
			var shadow_size = int(M3Theme.ELEVATION_1["size"] * i / 2.0)
			var shadow_offset = M3Theme.ELEVATION_1["offset"] * (i / 2.0)
			var style = M3Theme.make_shadow(
				M3Theme.get_elevation_surface(i),
				M3Theme.RADIUS_MEDIUM,
				shadow_size,
				shadow_offset,
				M3Theme.ELEVATION_1["color"]
			)
			panel.add_theme_stylebox_override("panel", style)
			
	# Force redraw of all controls
	queue_redraw()
	
	# Update all M3 component instances
	_update_m3_components(self)

func _update_m3_components(node: Node):
	for child in node.get_children():
		if child is M3Slider or child is M3Button or child is M3IconButton or child is M3Navigation or child is M3Switch or child is M3TextField or child is M3Checkbox or child is M3Tooltip:
			child.refresh_theme()
		if child.get_child_count() > 0:
			_update_m3_components(child)
