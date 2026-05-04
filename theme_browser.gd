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
	# Add icon button test rows
	_add_icon_button_rows()

func _on_dark_mode_toggled(pressed: bool):
	dark_mode = pressed

func _add_icon_button_rows():
	var vbox = $MarginContainer/ScrollContainer/VBoxContainer
	
	# Label
	var label = Label.new()
	label.text = "M3 Icon Buttons"
	vbox.add_child(label)
	
	# Row 1: Sizes (Standard variant, circular)
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 16)
	vbox.add_child(row1)
	
	var sizes = [
		{"name": "XS", "size": M3IconButton.IconSize.EXTRA_SMALL},
		{"name": "S", "size": M3IconButton.IconSize.SMALL},
		{"name": "M", "size": M3IconButton.IconSize.MEDIUM},
		{"name": "L", "size": M3IconButton.IconSize.LARGE},
		{"name": "XL", "size": M3IconButton.IconSize.EXTRA_LARGE},
	]
	
	for s in sizes:
		var btn = M3IconButton.new()
		btn.icon_name = "play"
		btn.icon_button_size = s.size
		btn.icon_button_variant = M3IconButton.IconVariant.FILLED
		row1.add_child(btn)
	
	# Row 2: Variants (Medium size, circular)
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 16)
	vbox.add_child(row2)
	
	var icon_variants = [
		{"name": "Std", "variant": M3IconButton.IconVariant.STANDARD},
		{"name": "Fld", "variant": M3IconButton.IconVariant.FILLED},
		{"name": "Tnl", "variant": M3IconButton.IconVariant.TONAL},
		{"name": "Out", "variant": M3IconButton.IconVariant.OUTLINED},
	]
	
	for v in icon_variants:
		var btn = M3IconButton.new()
		btn.icon_name = "share"
		btn.icon_button_variant = v.variant
		row2.add_child(btn)
	
	# Row 3: Toggle icon buttons (selected)
	var row3 = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 16)
	vbox.add_child(row3)
	
	for v in icon_variants:
		var btn = M3IconButton.new()
		btn.icon_name = "check"
		btn.icon_button_variant = v.variant
		btn.button_type = M3Button.Type.TOGGLE
		btn.button_pressed = true
		row3.add_child(btn)
	
	# Row 4: Shapes (Medium, Filled)
	var row4 = HBoxContainer.new()
	row4.add_theme_constant_override("separation", 16)
	vbox.add_child(row4)
	
	var btn_circ = M3IconButton.new()
	btn_circ.icon_name = "menu"
	btn_circ.icon_button_variant = M3IconButton.IconVariant.FILLED
	btn_circ.icon_button_shape = M3IconButton.IconShape.CIRCULAR
	row4.add_child(btn_circ)
	
	var btn_sq = M3IconButton.new()
	btn_sq.icon_name = "menu"
	btn_sq.icon_button_variant = M3IconButton.IconVariant.FILLED
	btn_sq.icon_button_shape = M3IconButton.IconShape.ROUNDED_SQUARE
	row4.add_child(btn_sq)

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
		if child is M3Slider or child is M3Button or child is M3IconButton:
			child.refresh_theme()
		if child.get_child_count() > 0:
			_update_m3_components(child)
