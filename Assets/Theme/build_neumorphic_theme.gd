@tool
extends SceneTree

func _init():
	print("Building Neumorphic Theme...")
	
	var theme = Theme.new()
	
	# -- Colors --
	var c_bg = Color("1e1e24")
	var c_surface = Color("2c2c35")
	var c_highlight = Color("3a3a44") # Hover
	var c_pressed = Color("22232a")
	var c_accent = Color("4fffa3")
	var c_shadow = Color(0, 0, 0, 0.5)
	var c_text = Color("a0a0ab")
	
	# -- Font Defaults --
	theme.set_color("font_color", "Button", c_text)
	theme.set_color("font_color", "Label", c_text)
	
	# -- PanelContainer --
	var sb_panel = StyleBoxFlat.new()
	sb_panel.bg_color = c_bg
	sb_panel.corner_radius_top_left = 20
	sb_panel.corner_radius_top_right = 20
	sb_panel.corner_radius_bottom_right = 20
	sb_panel.corner_radius_bottom_left = 20
	sb_panel.shadow_color = c_shadow
	sb_panel.shadow_size = 10
	sb_panel.content_margin_left = 20
	sb_panel.content_margin_right = 20
	sb_panel.content_margin_top = 20
	sb_panel.content_margin_bottom = 20
	theme.set_stylebox("panel", "PanelContainer", sb_panel)
	
	# -- Button (Standard) --
	var sb_btn_normal = StyleBoxFlat.new()
	sb_btn_normal.bg_color = c_surface
	sb_btn_normal.corner_radius_top_left = 12
	sb_btn_normal.corner_radius_top_right = 12
	sb_btn_normal.corner_radius_bottom_right = 12
	sb_btn_normal.corner_radius_bottom_left = 12
	sb_btn_normal.border_width_bottom = 2
	sb_btn_normal.border_color = c_bg
	sb_btn_normal.shadow_color = c_shadow
	sb_btn_normal.shadow_size = 4
	sb_btn_normal.shadow_offset = Vector2(0, 2)
	sb_btn_normal.content_margin_left = 6
	sb_btn_normal.content_margin_right = 6
	sb_btn_normal.content_margin_top = 4
	sb_btn_normal.content_margin_bottom = 4
	
	var sb_btn_hover = sb_btn_normal.duplicate()
	sb_btn_hover.bg_color = c_highlight
	
	var sb_btn_pressed = sb_btn_normal.duplicate()
	sb_btn_pressed.bg_color = c_pressed
	sb_btn_pressed.shadow_size = 0
	sb_btn_pressed.border_width_bottom = 0
	sb_btn_pressed.border_width_top = 2 # Simulate inset
	sb_btn_pressed.border_color = Color(0, 0, 0, 0.2)
	
	theme.set_stylebox("normal", "Button", sb_btn_normal)
	theme.set_stylebox("hover", "Button", sb_btn_hover)
	theme.set_stylebox("pressed", "Button", sb_btn_pressed)
	
	# -- ProgressBar --
	var sb_prog_bg = StyleBoxFlat.new()
	sb_prog_bg.bg_color = c_pressed # Dark trough
	sb_prog_bg.corner_radius_top_left = 8
	sb_prog_bg.corner_radius_top_right = 8
	sb_prog_bg.corner_radius_bottom_right = 8
	sb_prog_bg.corner_radius_bottom_left = 8
	sb_prog_bg.shadow_color = Color(0, 0, 0, 0.5)
	sb_prog_bg.shadow_size = 2
	sb_prog_bg.shadow_offset = Vector2(0, 1) # Inner shadow? StyleBoxFlat can't do true inner shadow easily, focusing on trough color.
	
	var sb_prog_fill = StyleBoxFlat.new()
	sb_prog_fill.bg_color = c_accent
	sb_prog_fill.corner_radius_top_left = 8
	sb_prog_fill.corner_radius_top_right = 8
	sb_prog_fill.corner_radius_bottom_right = 8
	sb_prog_fill.corner_radius_bottom_left = 8
	
	theme.set_stylebox("background", "ProgressBar", sb_prog_bg)
	theme.set_stylebox("fill", "ProgressBar", sb_prog_fill)
	
	# Save
	var err = ResourceSaver.save(theme, "res://Assets/Theme/neumorphic_theme.tres")
	if err == OK:
		print("Theme saved successfully to res://Assets/Theme/neumorphic_theme.tres")
	else:
		print("Error saving theme: ", err)
	
	quit()
