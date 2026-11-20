class_name UiKit
extends RefCounted
## The game's look for every screen: an ANCIENT SPELLBOOK.
##   - panels are old parchment pages with burnt edges and gold corner flourishes
##   - titles are written in Rashi script in gold leaf with a dark ink outline
##   - text is brown ink in a classic Hebrew book font (David)
##   - buttons are leather (stitched, gold trim) or paper; the big ones are red wax
## Use these helpers for all UI so everything shares one style.

const FONT_TITLE := preload("res://assets/fonts/NotoRashiHebrew.ttf")
const FONT_BODY := preload("res://assets/fonts/DavidLibre-Medium.ttf")
const FONT_BOLD := preload("res://assets/fonts/DavidLibre-Bold.ttf")
const FONT_UI := FONT_BODY
const TEX_PARCHMENT := preload("res://assets/ui/parchment.png")
const TEX_LEATHER := preload("res://assets/ui/leather.png")
const TEX_PAPER := preload("res://assets/ui/paper_button.png")
const TEX_SEAL := preload("res://assets/ui/wax_seal.png")

const INK := Color(0.23, 0.13, 0.06)            # brown ink
const INK_SOFT := Color(0.42, 0.29, 0.16)
const RED_INK := Color(0.62, 0.10, 0.07)        # illuminated letters, warnings
const GOLD := Color(0.98, 0.80, 0.38)           # gold leaf (always with a dark outline)
const GOLD_DARK := Color(0.62, 0.42, 0.12)
const PARCHMENT := Color(0.93, 0.85, 0.66)
const CREAM := Color(0.99, 0.93, 0.78)          # text on leather
const OUTLINE := Color(0.16, 0.08, 0.03)

## Text on parchment is ink; light text (on the map, on leather) gets an outline.
const TEXT := INK
const TEXT_SOFT := INK_SOFT
const TEXT_LIGHT := CREAM

## Button styles (tints of the leather / paper)
const BUTTON_RED := Color(0.62, 0.10, 0.08)      # red wax-leather: the main action
const BUTTON_BRONZE := Color(0.50, 0.30, 0.13)   # brown leather with gold
const BUTTON_STEEL := Color(1, 1, 1, 0)          # paper button (quiet actions)
const BUTTON_PURPLE := Color(0.36, 0.17, 0.48)   # violet leather: magic
const BUTTON_GREY := Color(0.30, 0.27, 0.24)
const PANEL_BG := PARCHMENT
const PANEL_BORDER := GOLD_DARK

static var _fonts: Dictionary = {}


static func font(weight: int) -> Font:
	return FONT_BOLD if weight >= 600 else FONT_BODY


static func title_font() -> Font:
	return FONT_TITLE


static func body_font() -> Font:
	return FONT_BODY


static func is_light(c: Color) -> bool:
	return c.get_luminance() > 0.55


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT_BODY
	t.default_font_size = 20
	t.set_color("font_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_color("font_outline_color", "Button", OUTLINE)
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_color", "Button", INK)
	# tooltips are little parchment notes
	var tip := StyleBoxTexture.new()
	tip.texture = TEX_PARCHMENT
	tip.set_texture_margin_all(40)
	tip.set_content_margin_all(14)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font("font", "TooltipLabel", FONT_BODY)
	t.set_font_size("font_size", "TooltipLabel", 18)
	# sliders and progress bars in ink and gold
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.25, 0.15, 0.07, 0.35)
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GOLD_DARK
	bar_fill.set_corner_radius_all(4)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_stylebox("slider", "HSlider", bar_bg)
	return t


## A parchment page with burnt edges.
static func panel_style(_bg: Color = PANEL_BG, _border: Color = PANEL_BORDER, _radius: int = 8) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_PARCHMENT
	sb.set_texture_margin_all(58)
	sb.set_content_margin_all(30)
	return sb


## A smaller parchment strip (HUD pieces).
static func strip_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_PARCHMENT
	sb.set_texture_margin_all(40)
	sb.set_content_margin_all(14)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	return sb


## Stitched leather (tinted).
static func leather_style(tint: Color = BUTTON_BRONZE, margin: int = 12) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_LEATHER
	sb.set_texture_margin_all(26)
	sb.set_content_margin_all(margin)
	sb.modulate_color = Color(1, 1, 1).lerp(tint * 2.2, 0.55) if tint.a > 0.0 else Color.WHITE
	return sb


static func panel(accent: Color = GOLD) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	var decor := BookDecor.new()
	decor.accent = accent
	p.add_child(decor)
	return p


static func accent_for(color: Color) -> Color:
	return GOLD


static func label(text: String, size: int = 20, color: Color = TEXT, weight: int = 500) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", FONT_TITLE if weight >= 800 else font(weight))
	if is_light(color):
		l.add_theme_color_override("font_outline_color", OUTLINE)
		l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A title in Rashi script, gold leaf with an ink outline.
static func title(text: String, size: int = 30, color: Color = GOLD) -> Label:
	var l := label(text, size, color, 900)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(6, size / 4))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


## Rich text with an illuminated first letter (big, red) like an old manuscript.
static func illuminated(text: String, size: int = 20, width: float = 400) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(width, 0)
	r.add_theme_font_override("normal_font", FONT_BODY)
	r.add_theme_font_override("bold_font", FONT_BOLD)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", INK)
	if text.length() > 1:
		r.text = "[font=res://assets/fonts/NotoRashiHebrew.ttf][font_size=%d][color=#%s]%s[/color][/font_size][/font]%s" % [
			int(size * 1.7), RED_INK.to_html(false), text.substr(0, 1), text.substr(1)]
	else:
		r.text = text
	return r


## A leather / paper button with gold trim (see BookButton).
static func button(text: String, color: Color = BUTTON_BRONZE, size: int = 22) -> Button:
	var b := BookButton.new(text, color)
	b.add_theme_font_override("font", FONT_BOLD)
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 54)
	var paper := color.a == 0.0
	var c := INK if paper else CREAM
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_hover_color", RED_INK if paper else GOLD)
	b.add_theme_color_override("font_pressed_color", RED_INK if paper else GOLD)
	b.add_theme_color_override("font_focus_color", c)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.42, 0.34))
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_constant_override("outline_size", 0 if paper else 5)
	return b


## The big round red wax seal button (the main action of a screen).
static func seal_button(text: String, diameter: float = 128.0, size: int = 30) -> Button:
	var b := BookButton.new(text, BUTTON_RED)
	b.seal = true
	b.add_theme_font_override("font", FONT_TITLE)
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.6))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.92, 0.6))
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.45, 0.4))
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_constant_override("outline_size", 8)
	return b
