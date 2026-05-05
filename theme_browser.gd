extends Control

@export var dark_mode: bool = false:
	set(value):
		dark_mode = value
		M3Theme.is_dark_mode = dark_mode
		apply_theme()

func _ready():
	M3Theme.is_dark_mode = dark_mode
	apply_theme()
	
	# Connect dark mode toggle
	var dark_mode_toggle = $MarginContainer/ScrollContainer/VBoxContainer/RowHeader/DarkModeToggle
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
	
	# Add content to inner ScrollContainer
	var scroll_vbox = $MarginContainer/ScrollContainer/VBoxContainer/ScrollContainer/VBoxContainer
	for i in range(20):
		var label = Label.new()
		label.text = "Scroll item %d" % (i + 1)
		scroll_vbox.add_child(label)
	
	# Add toggle button test row
	_add_toggle_button_row()
	
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

func _on_dark_mode_toggled(pressed: bool):
	dark_mode = pressed

func _create_nav_dest(icon: String, label: String) -> M3NavigationDestinationData:
	var data = M3NavigationDestinationData.new()
	data.icon_name = icon
	data.label = label
	return data

func _add_toggle_button_row():
	var vbox = $MarginContainer/ScrollContainer/VBoxContainer
	
	# Label
	var label = Label.new()
	label.text = "M3 Toggle Buttons"
	vbox.add_child(label)
	
	# Row for toggle buttons
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)
	
	# Create toggle buttons for each variant
	var variants = [
		{"name": "Elevated", "variant": M3Button.Variant.ELEVATED},
		{"name": "Filled", "variant": M3Button.Variant.FILLED},
		{"name": "Tonal", "variant": M3Button.Variant.TONAL},
		{"name": "Outlined", "variant": M3Button.Variant.OUTLINED},
		{"name": "Text", "variant": M3Button.Variant.TEXT},
	]
	
	for v in variants:
		var btn = M3Button.new()
		btn.text = v.name
		btn.button_variant = v.variant
		btn.button_type = M3Button.Type.TOGGLE
		btn.button_pressed = true  # Start in selected state to show toggle colors
		btn.icon_name = "check"  # Test icon colors too
		row.add_child(btn)
	
	# Row for unselected toggle buttons
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 16)
	vbox.add_child(row2)
	
	for v in variants:
		var btn = M3Button.new()
		btn.text = v.name
		btn.button_variant = v.variant
		btn.button_type = M3Button.Type.TOGGLE
		btn.button_pressed = false  # Unselected state
		btn.icon_name = "check"
		row2.add_child(btn)

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
		if child is M3Slider or child is M3Button or child is M3IconButton or child is M3Navigation:
			child.refresh_theme()
		if child.get_child_count() > 0:
			_update_m3_components(child)
