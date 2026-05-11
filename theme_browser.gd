extends Control

const CONTENT_PADDING := 20.0

const M3Menu = preload("res://addons/m3/components/M3Menu.gd")
const M3MenuRenderer = preload("res://addons/m3/components/M3MenuRenderer.gd")

var _menu_test_buttons: Array[Button] = []

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
	
	# Create dialog test buttons
	var dialog_section = VBoxContainer.new()
	dialog_section.name = "DialogTests"
	
	var dialog_label = Label.new()
	dialog_label.text = "M3 Dialogs"
	dialog_section.add_child(dialog_label)
	
	var dialog_btn_row = HBoxContainer.new()
	dialog_btn_row.add_theme_constant_override("separation", 8)
	
	var basic_btn = _create_test_button("Show Basic Dialog", _on_dialog_basic_test_pressed)
	var confirm_btn = _create_test_button("Show Confirm", _on_dialog_confirm_test_pressed)
	var alert_btn = _create_test_button("Show Alert", _on_dialog_alert_test_pressed)
	var fullscreen_btn = _create_test_button("Show Fullscreen", _on_dialog_fullscreen_test_pressed)
	
	dialog_btn_row.add_child(basic_btn)
	dialog_btn_row.add_child(confirm_btn)
	dialog_btn_row.add_child(alert_btn)
	dialog_btn_row.add_child(fullscreen_btn)
	
	dialog_section.add_child(dialog_btn_row)
	
	# Add to container after snackbar button
	if snackbar_btn:
		var idx = snackbar_btn.get_index() + 1
		$MarginContainer/ScrollContainer/VBoxContainer.add_child(dialog_section)
		$MarginContainer/ScrollContainer/VBoxContainer.move_child(dialog_section, idx)
	else:
		$MarginContainer/ScrollContainer/VBoxContainer.add_child(dialog_section)
	
	# Create menu test section
	var menu_section = VBoxContainer.new()
	menu_section.name = "MenuTests"
	
	var menu_label = Label.new()
	menu_label.text = "M3 Menus"
	menu_section.add_child(menu_label)
	
	var menu_btn_row = HBoxContainer.new()
	menu_btn_row.add_theme_constant_override("separation", 8)
	
	var standard_menu_btn = _create_test_button("Show Standard Menu", _on_standard_menu_test_pressed)
	var vibrant_menu_btn = _create_test_button("Show Vibrant Menu", _on_vibrant_menu_test_pressed)
	var checkable_menu_btn = _create_test_button("Show Checkable Menu", _on_checkable_menu_test_pressed)
	var twoline_menu_btn = _create_test_button("Show Two-Line Menu", _on_twoline_menu_test_pressed)
	
	menu_btn_row.add_child(standard_menu_btn)
	menu_btn_row.add_child(vibrant_menu_btn)
	menu_btn_row.add_child(checkable_menu_btn)
	menu_btn_row.add_child(twoline_menu_btn)
	
	_menu_test_buttons = [standard_menu_btn, vibrant_menu_btn, checkable_menu_btn, twoline_menu_btn]
	
	menu_section.add_child(menu_btn_row)
	
	# Add after dialog section
	var dialog_idx = dialog_section.get_index()
	$MarginContainer/ScrollContainer/VBoxContainer.add_child(menu_section)
	$MarginContainer/ScrollContainer/VBoxContainer.move_child(menu_section, dialog_idx + 1)

func _create_test_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	return btn

func _on_snackbar_test_pressed():
	M3Snackbar.show_message(
		"Item deleted",
		"Undo",
		func(): print("Undo clicked!"),
		true
	)

func _on_dialog_basic_test_pressed():
	var dialog = M3Dialog.new()
	dialog.title_text = "Reset settings?"
	dialog.body_text = "This will reset your app preferences back to their default settings."
	dialog.hero_icon_name = "settings_backup_restore"
	dialog.add_action("Cancel", Callable(), false)
	dialog.add_action("Accept", func(): print("Accept clicked!"), true)
	M3Dialog.show_dialog(dialog)

func _on_dialog_confirm_test_pressed():
	M3Dialog.show_confirm(
		"Delete account?",
		"This action cannot be undone. All your data will be permanently removed.",
		func(): print("Account deleted!"),
		func(): print("Cancelled")
	)

func _on_dialog_alert_test_pressed():
	M3Dialog.show_alert(
		"Update complete",
		"Your app has been updated to the latest version.",
		func(): print("OK clicked")
	)

func _on_standard_menu_test_pressed():
	var menu = M3Menu.new()
	menu.add_item("Preview", func(): print("Preview"), "visibility")
	menu.add_item("Share", func(): print("Share"), "share")
	menu.add_separator()
	menu.add_item("Get link", func(): print("Get link"), "link")
	menu.add_item("Remove", func(): print("Remove"), "delete", "chevron-right")
	menu.popup(_menu_test_buttons[0])

func _on_vibrant_menu_test_pressed():
	var menu = M3Menu.new()
	menu.menu_variant = M3MenuRenderer.ColorVariant.VIBRANT
	menu.add_item("Preview", func(): print("Preview"), "visibility")
	menu.add_item("Share", func(): print("Share"), "share")
	menu.add_separator()
	menu.add_item("Get link", func(): print("Get link"), "link")
	menu.add_item("Remove", func(): print("Remove"), "delete")
	menu.popup(_menu_test_buttons[1])

func _on_checkable_menu_test_pressed():
	var menu = M3Menu.new()
	menu.add_check_item("Show bounding box", false, func(): print("Toggle bounding box"))
	menu.add_check_item("Show grid", true, func(): print("Toggle grid"))
	menu.add_separator()
	menu.add_section_label("View options")
	menu.add_check_item("Night mode", false, func(): print("Toggle night mode"))
	menu.popup(_menu_test_buttons[2])

func _on_twoline_menu_test_pressed():
	var menu = M3Menu.new()
	menu.add_two_line_item("Headline", "Supporting text", func(): print("Headline"), "article")
	menu.add_two_line_item("List item", "Secondary text", func(): print("List item"), "list")
	menu.add_separator()
	menu.add_item("Simple item", func(): print("Simple"))
	menu.popup(_menu_test_buttons[3])

func _on_dialog_fullscreen_test_pressed():
	var dialog = M3Dialog.new()
	dialog.dialog_variant = M3Dialog.Variant.FULL_SCREEN
	dialog.title_text = "Settings"
	dialog.body_text = "Configure your app preferences below."
	dialog.hero_icon_name = "settings"
	
	# Add some sample content
	var checkbox = M3Checkbox.new()
	checkbox.text = "Enable notifications"
	dialog.content_slot.add_child(checkbox)
	
	var checkbox2 = M3Checkbox.new()
	checkbox2.text = "Dark mode"
	dialog.content_slot.add_child(checkbox2)
	
	dialog.add_action("Cancel", Callable(), false)
	dialog.add_action("Save", func(): print("Saved!"), true)
	M3Dialog.show_dialog(dialog)

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
