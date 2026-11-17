class_name DarkFantasyTheme
extends RefCounted


static func build() -> Theme:
	var t := Theme.new()

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.06, 0.08, 0.94)
	panel.border_color = Color(0.56, 0.42, 0.22)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(6)
	t.set_stylebox("panel", "PanelContainer", panel)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.14, 0.12, 0.16)
	btn_normal.border_color = Color(0.42, 0.32, 0.18)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(4)
	btn_normal.set_content_margin_all(6)
	t.set_stylebox("normal", "Button", btn_normal)

	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.25, 0.15, 0.17)
	btn_hover.border_color = Color(0.82, 0.63, 0.30)
	t.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.09, 0.07, 0.10)
	btn_pressed.border_color = Color(0.95, 0.75, 0.35)
	t.set_stylebox("pressed", "Button", btn_pressed)

	var btn_disabled := btn_normal.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(0.09, 0.08, 0.10, 0.65)
	btn_disabled.border_color = Color(0.25, 0.20, 0.15, 0.5)
	t.set_stylebox("disabled", "Button", btn_disabled)

	t.set_color("font_color", "Label", Color(0.92, 0.88, 0.80))
	t.set_color("font_color", "Button", Color(0.93, 0.88, 0.78))
	t.set_color("font_hover_color", "Button", Color(1.0, 0.90, 0.55))
	t.set_color("font_disabled_color", "Button", Color(0.50, 0.46, 0.42))
	return t
