class_name UiKit
extends RefCounted
## Builds the medieval-style UI pieces (panels, buttons, labels) and the theme,
## so every screen looks the same: dark leather/iron panels with bronze trim.

const FONT_UI := preload("res://assets/fonts/Rubik.ttf")
const FONT_TITLE := preload("res://assets/fonts/SuezOne.ttf")
const FONT_BODY := preload("res://assets/fonts/FrankRuhlLibre.ttf")

const PANEL_BG := Color(0.075, 0.075, 0.09, 0.94)   # dark forged iron
const PANEL_BORDER := Color(0.62, 0.46, 0.22)        # bronze rim
const GOLD := Color(0.98, 0.80, 0.42)
const BUTTON_RED := Color(0.48, 0.12, 0.09)
const BUTTON_BRONZE := Color(0.55, 0.38, 0.15)
const BUTTON_STEEL := Color(0.24, 0.25, 0.29)
const BUTTON_PURPLE := Color(0.33, 0.16, 0.45)
const BUTTON_GREY := Color(0.24, 0.23, 0.24)
const TEXT := Color(0.97, 0.93, 0.85)
const TEXT_SOFT := Color(0.80, 0.74, 0.64)

# Old names kept so other screens keep working.
const BUTTON_BLUE := BUTTON_STEEL
const BUTTON_GOLD := BUTTON_BRONZE

static var _fonts: Dictionary = {}


static func font(weight: int) -> FontVariation:
	var key := "ui%d" % weight
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = FONT_UI
		f.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): weight }
		_fonts[key] = f
	return _fonts[key]


static func title_font() -> Font:
	return FONT_TITLE


static func body_font() -> Font:
	if not _fonts.has("body"):
		var f := FontVariation.new()
		f.base_font = FONT_BODY
		f.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 600 }
		_fonts["body"] = f
	return _fonts["body"]


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(500)
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.02, 0.01, 0.0))
	t.set_constant("outline_size", "Label", 5)
	t.set_color("font_outline_color", "Button", Color(0.02, 0.01, 0.0))
	t.set_constant("outline_size", "Button", 5)
	t.set_color("font_color", "CheckButton", TEXT)
	return t


static func panel_style(bg: Color = PANEL_BG, border: Color = PANEL_BORDER, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func panel(accent: Color = Color(0.45, 0.8, 1.0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	var decor := MetalDecor.new()
	decor.accent = accent
	p.add_child(decor)
	return p


## The rune colour that goes with a button colour.
static func accent_for(color: Color) -> Color:
	if color == BUTTON_RED:
		return Color(1.0, 0.5, 0.2)
	if color == BUTTON_BRONZE:
		return Color(1.0, 0.8, 0.35)
	if color == BUTTON_PURPLE:
		return Color(0.8, 0.5, 1.0)
	return Color(0.45, 0.8, 1.0)


static func label(text: String, size: int = 20, color: Color = TEXT, weight: int = 500) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if weight >= 800:
		l.add_theme_font_override("font", FONT_TITLE)
	elif weight != 500:
		l.add_theme_font_override("font", font(weight))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func title(text: String, size: int = 30, color: Color = GOLD) -> Label:
	var l := label(text, size, color, 900)
	l.add_theme_constant_override("outline_size", 8)
	return l


## A forged-iron button with glowing runes (see RuneButton).
static func button(text: String, color: Color = BUTTON_STEEL, size: int = 22) -> Button:
	var b := RuneButton.new(text, accent_for(color))
	b.add_theme_font_override("font", FONT_TITLE)
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", accent_for(color).lightened(0.4))
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_focus_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.43, 0.4))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	b.add_theme_constant_override("outline_size", 6)
	return b
