class_name UiKit
extends RefCounted
## Builds the cartoon-style UI pieces (panels, buttons, labels) and the theme,
## so every screen looks the same.

const FONT := preload("res://assets/fonts/Rubik.ttf")

const PANEL_BG := Color(0.11, 0.10, 0.24, 0.92)
const PANEL_BORDER := Color(0.98, 0.76, 0.27)
const BUTTON_BLUE := Color(0.20, 0.45, 0.95)
const BUTTON_GOLD := Color(0.98, 0.70, 0.15)
const BUTTON_PURPLE := Color(0.55, 0.28, 0.85)
const BUTTON_GREY := Color(0.42, 0.42, 0.50)
const TEXT := Color(1, 1, 1)
const TEXT_SOFT := Color(0.85, 0.85, 0.95)
const TEXT_DARK := Color(0.15, 0.10, 0.05)


static func font(weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = FONT
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	f.variation_opentype = { tag: weight }
	return f


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(600)
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.05, 0.03, 0.10))
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_outline_color", "Button", Color(0.05, 0.03, 0.10))
	t.set_constant("outline_size", "Button", 6)
	t.set_color("font_color", "CheckButton", TEXT)
	return t


static func panel_style(bg: Color = PANEL_BG, border: Color = PANEL_BORDER, radius: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	return p


static func label(text: String, size: int = 22, color: Color = TEXT, weight: int = 600) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if weight != 600:
		l.add_theme_font_override("font", font(weight))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, color: Color = BUTTON_BLUE, size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font(800))
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 54)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		var c := color
		match state_name:
			"hover": c = color.lightened(0.15)
			"pressed": c = color.darkened(0.15)
			"disabled": c = BUTTON_GREY.darkened(0.2)
		sb.bg_color = c
		sb.border_color = c.darkened(0.45)
		sb.set_border_width_all(3)
		sb.border_width_bottom = 7 if state_name != "pressed" else 3
		sb.set_corner_radius_all(14)
		sb.set_content_margin_all(10)
		if state_name == "focus":
			sb.draw_center = false
			sb.border_color = Color(1, 1, 1, 0.6)
		b.add_theme_stylebox_override(state_name, sb)
	b.add_theme_color_override("font_disabled_color", Color(0.75, 0.75, 0.8))
	return b
