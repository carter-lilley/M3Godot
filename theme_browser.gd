extends Control

const CONTENT_PADDING := 20.0

const M3Menu = preload("res://addons/m3/components/M3Menu.gd")
const M3MenuRenderer = preload("res://addons/m3/components/M3MenuRenderer.gd")

var _menu_test_buttons: Array[Button] = []
var _checkable_menu: M3Menu = null
var _multi_select_menu: M3Menu = null
var _submenu_menu: M3Menu = null

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
	if has_node("MarginContainer/ScrollContainer/VBoxContainer/RowBasicControls/MenuButton"):
		var menu_btn = $MarginContainer/ScrollContainer/VBoxContainer/RowBasicControls/MenuButton
		var menu = menu_btn.get_popup()
		menu.add_item("Item 1")
		menu.add_item("Item 2")
		menu.add_item("Item 3")
	
	# Populate OptionButton
	if has_node("MarginContainer/ScrollContainer/VBoxContainer/RowBasicControls/OptionButton"):
		var option = $MarginContainer/ScrollContainer/VBoxContainer/RowBasicControls/OptionButton
		option.add_item("Option 1")
		option.add_item("Option 2")
		option.add_item("Option 3")
		option.select(0)
	
	# Create M3OptionButton test section
	var option_section = VBoxContainer.new()
	option_section.name = "M3OptionButtonTests"
	
	var option_label = Label.new()
	option_label.text = "M3 Option Button"
	option_section.add_child(option_label)
	
	var option_row = HBoxContainer.new()
	option_row.add_theme_constant_override("separation", 16)
	
	var m3_option = M3OptionButton.new()
	m3_option.name = "M3OptionButton"
	m3_option.field_variant = M3TextField.Variant.FILLED
	m3_option.label_text = "Select an option"
	m3_option.supporting_text = "Tap to open dropdown"
	m3_option.add_item("Apple", 0)
	m3_option.add_item("Banana", 1)
	m3_option.add_item("Cherry", 2)
	m3_option.add_item("Date", 3)
	m3_option.add_item("Elderberry", 4)
	m3_option.selected = 0
	m3_option.item_selected.connect(func(idx): print("Selected item: %d" % idx))
	option_row.add_child(m3_option)
	
	var m3_option_outlined = M3OptionButton.new()
	m3_option_outlined.name = "M3OptionButtonOutlined"
	m3_option_outlined.field_variant = M3TextField.Variant.OUTLINED
	m3_option_outlined.label_text = "Outlined variant"
	m3_option_outlined.add_item("Small", 0)
	m3_option_outlined.add_item("Medium", 1)
	m3_option_outlined.add_item("Large", 2)
	m3_option_outlined.add_item("Extra Large", 3)
	m3_option_outlined.selected = 1
	option_row.add_child(m3_option_outlined)
	
	var m3_option_multi = M3OptionButton.new()
	m3_option_multi.name = "M3OptionButtonMulti"
	m3_option_multi.field_variant = M3TextField.Variant.FILLED
	m3_option_multi.label_text = "Dietary preferences"
	m3_option_multi.supporting_text = "Select all that apply"
	m3_option_multi.multi_select = true
	m3_option_multi.add_item("Vegetarian", 0)
	m3_option_multi.add_item("Vegan", 1)
	m3_option_multi.add_item("Gluten-free", 2)
	m3_option_multi.add_item("Nut-free", 3)
	m3_option_multi.add_item("Dairy-free", 4)
	m3_option_multi.set_selected_indices([0, 2])
	m3_option_multi.item_selected.connect(func(idx): print("Toggled dietary: %d" % idx))
	option_row.add_child(m3_option_multi)
	
	option_section.add_child(option_row)
	
	# Add after M3TextFields
	var text_fields = $MarginContainer/ScrollContainer/VBoxContainer/M3TextFields
	var text_fields_idx = text_fields.get_index()
	$MarginContainer/ScrollContainer/VBoxContainer.add_child(option_section)
	$MarginContainer/ScrollContainer/VBoxContainer.move_child(option_section, text_fields_idx + 1)
	
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
	
	var standard_menu_btn = _create_test_button("Standard", _on_standard_menu_test_pressed, M3Button.Variant.FILLED)
	var vibrant_menu_btn = _create_test_button("Vibrant", _on_vibrant_menu_test_pressed, M3Button.Variant.ELEVATED)
	var checkable_menu_btn = _create_test_button("Checkable", _on_checkable_menu_test_pressed, M3Button.Variant.TONAL)
	var twoline_menu_btn = _create_test_button("Two-Line", _on_twoline_menu_test_pressed, M3Button.Variant.OUTLINED)
	var icon_menu_btn = _create_test_icon_button("more_vert", _on_icon_menu_test_pressed)
	var multi_select_menu_btn = _create_test_button("Multi-Select", _on_multi_select_menu_test_pressed, M3Button.Variant.ELEVATED)
	var submenu_menu_btn = _create_test_button("Submenu", _on_submenu_menu_test_pressed, M3Button.Variant.TONAL)
	
	menu_btn_row.add_child(standard_menu_btn)
	menu_btn_row.add_child(vibrant_menu_btn)
	menu_btn_row.add_child(checkable_menu_btn)
	menu_btn_row.add_child(twoline_menu_btn)
	menu_btn_row.add_child(icon_menu_btn)
	menu_btn_row.add_child(multi_select_menu_btn)
	menu_btn_row.add_child(submenu_menu_btn)
	
	_menu_test_buttons = [standard_menu_btn, vibrant_menu_btn, checkable_menu_btn, twoline_menu_btn, icon_menu_btn, multi_select_menu_btn, submenu_menu_btn]
	
	menu_section.add_child(menu_btn_row)
	
	# Add after dialog section
	var dialog_idx = dialog_section.get_index()
	$MarginContainer/ScrollContainer/VBoxContainer.add_child(menu_section)
	$MarginContainer/ScrollContainer/VBoxContainer.move_child(menu_section, dialog_idx + 1)
	
	# Build persistent checkable menus so checked states survive across openings
	_checkable_menu = M3Menu.new()
	_checkable_menu.add_check_item("Show bounding box", false, func(): print("Toggle bounding box"))
	_checkable_menu.add_check_item("Show grid", true, func(): print("Toggle grid"))
	_checkable_menu.add_separator()
	_checkable_menu.add_section_label("View options")
	_checkable_menu.add_check_item("Night mode", false, func(): print("Toggle night mode"))
	
	_multi_select_menu = M3Menu.new()
	_multi_select_menu.multi_select = true
	_multi_select_menu.add_check_item("Wi-Fi", true, func(): print("Toggle Wi-Fi"))
	_multi_select_menu.add_check_item("Bluetooth", false, func(): print("Toggle Bluetooth"))
	_multi_select_menu.add_check_item("Airplane mode", false, func(): print("Toggle Airplane mode"))
	_multi_select_menu.add_separator()
	_multi_select_menu.add_check_item("Dark theme", false, func(): print("Toggle Dark theme"))
	_multi_select_menu.add_check_item("High contrast", false, func(): print("Toggle High contrast"))
	
	# Build submenu test
	var sub = M3Menu.new()
	sub.add_item("Sub-item 1", func(): print("Sub-item 1"))
	sub.add_item("Sub-item 2", func(): print("Sub-item 2"))
	sub.add_separator()
	sub.add_item("Sub-item 3", func(): print("Sub-item 3"))
	
	_submenu_menu = M3Menu.new()
	_submenu_menu.add_item("Regular item", func(): print("Regular item"))
	_submenu_menu.add_submenu_item("More options", sub, "expand_more")
	_submenu_menu.add_item("Another item", func(): print("Another item"))
	
	# Create chip test section
	var chip_section = VBoxContainer.new()
	chip_section.name = "ChipTests"
	
	var chip_label = Label.new()
	chip_label.text = "M3 Chips"
	chip_section.add_child(chip_label)
	
	var chip_row = HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 8)
	
	var assist_chip = M3Chip.new()
	assist_chip.text = "Assist"
	assist_chip.chip_variant = M3Chip.ChipVariant.ASSIST
	assist_chip.leading_icon = "event"
	assist_chip.pressed.connect(func(): print("Assist chip pressed"))
	chip_row.add_child(assist_chip)
	
	var filter_chip = M3Chip.new()
	filter_chip.text = "Filter"
	filter_chip.chip_variant = M3Chip.ChipVariant.FILTER
	filter_chip.checked = true
	filter_chip.checked_changed.connect(func(c): print("Filter chip: %s" % c))
	chip_row.add_child(filter_chip)
	
	var filter_dropdown_chip = M3Chip.new()
	filter_dropdown_chip.text = "Sort"
	filter_dropdown_chip.chip_variant = M3Chip.ChipVariant.FILTER
	filter_dropdown_chip.trailing_icon = "triangle-small-down"
	filter_dropdown_chip.menu_requested.connect(func():
		var menu = M3Menu.new()
		menu.add_item("Name", func():
			print("Sort by name")
			filter_dropdown_chip.checked = true
		)
		menu.add_item("Date", func():
			print("Sort by date")
			filter_dropdown_chip.checked = true
		)
		menu.add_item("Rating", func():
			print("Sort by rating")
			filter_dropdown_chip.checked = true
		)
		menu.popup(filter_dropdown_chip)
	)
	chip_row.add_child(filter_dropdown_chip)
	
	var input_chip = M3Chip.new()
	input_chip.text = "Input"
	input_chip.chip_variant = M3Chip.ChipVariant.INPUT
	input_chip.close_requested.connect(func(): print("Input chip close"))
	chip_row.add_child(input_chip)
	
	var suggestion_chip = M3Chip.new()
	suggestion_chip.text = "Suggestion"
	suggestion_chip.chip_variant = M3Chip.ChipVariant.SUGGESTION
	suggestion_chip.pressed.connect(func(): print("Suggestion chip pressed"))
	chip_row.add_child(suggestion_chip)
	
	var elevated_chip = M3Chip.new()
	elevated_chip.text = "Elevated"
	elevated_chip.chip_variant = M3Chip.ChipVariant.SUGGESTION
	elevated_chip.elevated = true
	elevated_chip.pressed.connect(func(): print("Elevated chip pressed"))
	chip_row.add_child(elevated_chip)
	
	chip_section.add_child(chip_row)
	
	# Add after menu section
	var menu_tests = $MarginContainer/ScrollContainer/VBoxContainer/MenuTests
	var menu_idx = menu_tests.get_index()
	$MarginContainer/ScrollContainer/VBoxContainer.add_child(chip_section)
	$MarginContainer/ScrollContainer/VBoxContainer.move_child(chip_section, menu_idx + 1)
	
	# Create progress test section
	var progress_section = VBoxContainer.new()
	progress_section.name = "ProgressTests"
	
	var progress_label = Label.new()
	progress_label.text = "M3 Progress"
	progress_section.add_child(progress_label)
	
	# Linear progress row
	var linear_row = VBoxContainer.new()
	linear_row.add_theme_constant_override("separation", 16)
	
	var linear_small = M3Progress.new()
	linear_small.mode = M3Progress.Mode.LINEAR
	linear_small.progress_size = M3Progress.Size.SMALL
	linear_small.indeterminate = true
	linear_small.custom_minimum_size = Vector2(300, 0)
	linear_row.add_child(linear_small)
	
	var linear_large = M3Progress.new()
	linear_large.mode = M3Progress.Mode.LINEAR
	linear_large.progress_size = M3Progress.Size.LARGE
	linear_large.indeterminate = true
	linear_large.custom_minimum_size = Vector2(300, 0)
	linear_row.add_child(linear_large)
	
	progress_section.add_child(linear_row)
	
	# Circular progress row
	var circular_row = HBoxContainer.new()
	circular_row.add_theme_constant_override("separation", 24)
	
	var circular_small = M3Progress.new()
	circular_small.mode = M3Progress.Mode.CIRCULAR
	circular_small.progress_size = M3Progress.Size.SMALL
	circular_small.indeterminate = true
	circular_row.add_child(circular_small)
	
	var circular_large = M3Progress.new()
	circular_large.mode = M3Progress.Mode.CIRCULAR
	circular_large.progress_size = M3Progress.Size.LARGE
	circular_large.indeterminate = true
	circular_row.add_child(circular_large)
	
	progress_section.add_child(circular_row)
	
	# Add after chip section
	var chip_idx = chip_section.get_index()
	$MarginContainer/ScrollContainer/VBoxContainer.add_child(progress_section)
	$MarginContainer/ScrollContainer/VBoxContainer.move_child(progress_section, chip_idx + 1)
	
	# Create split button test section
	var split_section = VBoxContainer.new()
	split_section.name = "SplitButtonTests"
	
	var split_label = Label.new()
	split_label.text = "M3 Split Buttons"
	split_section.add_child(split_label)
	
	# Row 1: Icon + Label variants
	var split_row1 = HBoxContainer.new()
	split_row1.add_theme_constant_override("separation", 12)
	
	var split_filled = M3SplitButton.new()
	split_filled.button_size = M3Button.Size.MEDIUM
	split_filled.button_variant = M3Button.Variant.FILLED
	split_filled.icon_name = "edit"
	split_filled.text = "Edit"
	split_filled.pressed.connect(func(): print("Split button main action: Edit"))
	var edit_menu = M3Menu.new()
	edit_menu.add_item("Cut", func(): print("Cut"))
	edit_menu.add_item("Copy", func(): print("Copy"))
	edit_menu.add_item("Paste", func(): print("Paste"))
	split_filled.menu = edit_menu
	split_row1.add_child(split_filled)
	
	var split_tonal = M3SplitButton.new()
	split_tonal.button_size = M3Button.Size.MEDIUM
	split_tonal.button_variant = M3Button.Variant.TONAL
	split_tonal.icon_name = "download"
	split_tonal.text = "Download"
	var download_menu = M3Menu.new()
	download_menu.add_item("PDF", func(): print("Download PDF"))
	download_menu.add_item("PNG", func(): print("Download PNG"))
	download_menu.add_item("SVG", func(): print("Download SVG"))
	split_tonal.menu = download_menu
	split_row1.add_child(split_tonal)
	
	var split_outlined = M3SplitButton.new()
	split_outlined.button_size = M3Button.Size.MEDIUM
	split_outlined.button_variant = M3Button.Variant.OUTLINED
	split_outlined.icon_name = "share"
	split_outlined.text = "Share"
	var share_menu = M3Menu.new()
	share_menu.add_item("Email", func(): print("Share via Email"))
	share_menu.add_item("Message", func(): print("Share via Message"))
	share_menu.add_item("Copy link", func(): print("Copy link"))
	split_outlined.menu = share_menu
	split_row1.add_child(split_outlined)
	
	split_section.add_child(split_row1)
	
	# Row 2: Label-only and Icon-only, different sizes
	var split_row2 = HBoxContainer.new()
	split_row2.add_theme_constant_override("separation", 12)
	
	var split_small = M3SplitButton.new()
	split_small.button_size = M3Button.Size.SMALL
	split_small.button_variant = M3Button.Variant.FILLED
	split_small.text = "Small"
	var small_menu = M3Menu.new()
	small_menu.add_item("Option A", func(): print("Small A"))
	small_menu.add_item("Option B", func(): print("Small B"))
	split_small.menu = small_menu
	split_row2.add_child(split_small)
	
	var split_large = M3SplitButton.new()
	split_large.button_size = M3Button.Size.LARGE
	split_large.button_variant = M3Button.Variant.FILLED
	split_large.icon_name = "star"
	var large_menu = M3Menu.new()
	large_menu.add_item("Favorite", func(): print("Favorite"))
	large_menu.add_item("Bookmark", func(): print("Bookmark"))
	split_large.menu = large_menu
	split_row2.add_child(split_large)
	
	var split_xl = M3SplitButton.new()
	split_xl.button_size = M3Button.Size.EXTRA_LARGE
	split_xl.button_variant = M3Button.Variant.ELEVATED
	split_xl.icon_name = "settings"
	split_xl.text = "Settings"
	var xl_menu = M3Menu.new()
	xl_menu.add_item("General", func(): print("General settings"))
	xl_menu.add_item("Display", func(): print("Display settings"))
	xl_menu.add_item("Network", func(): print("Network settings"))
	split_xl.menu = xl_menu
	split_row2.add_child(split_xl)
	
	split_section.add_child(split_row2)
	
	# Row 3: Text variant and disabled
	var split_row3 = HBoxContainer.new()
	split_row3.add_theme_constant_override("separation", 12)
	
	var split_text = M3SplitButton.new()
	split_text.button_size = M3Button.Size.MEDIUM
	split_text.button_variant = M3Button.Variant.TEXT
	split_text.icon_name = "filter_list"
	split_text.text = "Filter"
	var filter_menu = M3Menu.new()
	filter_menu.add_check_item("Active", true, func(): print("Toggle active"))
	filter_menu.add_check_item("Archived", false, func(): print("Toggle archived"))
	split_text.menu = filter_menu
	split_row3.add_child(split_text)
	
	var split_disabled = M3SplitButton.new()
	split_disabled.button_size = M3Button.Size.MEDIUM
	split_disabled.button_variant = M3Button.Variant.FILLED
	split_disabled.icon_name = "cloud_upload"
	split_disabled.text = "Upload"
	split_disabled.disabled = true
	split_row3.add_child(split_disabled)
	
	split_section.add_child(split_row3)
	
	# Add after progress section
	var progress_idx = progress_section.get_index()
	$MarginContainer/ScrollContainer/VBoxContainer.add_child(split_section)
	$MarginContainer/ScrollContainer/VBoxContainer.move_child(split_section, progress_idx + 1)

func _create_test_button(text: String, callback: Callable, variant: int = M3Button.Variant.FILLED) -> M3Button:
	var btn = M3Button.new()
	btn.text = text
	btn.button_variant = variant
	btn.pressed.connect(callback)
	return btn

func _create_test_icon_button(icon_name: String, callback: Callable) -> M3IconButton:
	var btn = M3IconButton.new()
	btn.icon_name = icon_name
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
	_checkable_menu.popup(_menu_test_buttons[2])

func _on_twoline_menu_test_pressed():
	var menu = M3Menu.new()
	menu.add_two_line_item("Headline", "Supporting text", func(): print("Headline"), "article")
	menu.add_two_line_item("List item", "Secondary text", func(): print("List item"), "list")
	menu.add_separator()
	menu.add_item("Simple item", func(): print("Simple"))
	menu.popup(_menu_test_buttons[3])

func _on_icon_menu_test_pressed():
	var menu = M3Menu.new()
	menu.add_item("Settings", func(): print("Settings"), "settings")
	menu.add_item("Profile", func(): print("Profile"), "person")
	menu.add_separator()
	menu.add_item("Help", func(): print("Help"), "help")
	menu.add_item("Logout", func(): print("Logout"), "logout")
	menu.popup(_menu_test_buttons[4])

func _on_multi_select_menu_test_pressed():
	_multi_select_menu.popup(_menu_test_buttons[5])

func _on_submenu_menu_test_pressed():
	_submenu_menu.popup(_menu_test_buttons[6])

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
	if has_node("MarginContainer/ScrollContainer/VBoxContainer/RowToggles/ColorRect"):
		var color_rect = $MarginContainer/ScrollContainer/VBoxContainer/RowToggles/ColorRect
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
		if child is M3Slider or child is M3Button or child is M3IconButton or child is M3Navigation or child is M3Switch or child is M3TextField or child is M3Checkbox or child is M3Tooltip or child is M3Dialog or child is M3Snackbar or child is M3Menu or child is M3OptionButton or child is M3Chip or child is M3Progress or child is M3SplitButton:
			child.refresh_theme()
		if child.get_child_count() > 0:
			_update_m3_components(child)
