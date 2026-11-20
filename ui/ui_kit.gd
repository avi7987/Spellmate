class_name UiKit
extends RefCounted
## The game's look for every screen: a bright MOBILE-GAME style (owner's choice).
##   - one font everywhere: Fredoka (round and bold), always white or gold with a
##     thick dark outline and a soft shadow, so it reads on any background
##   - panels: rounded deep-blue boards with a dark rim and a glossy top
##   - buttons: chunky coloured "3D" buttons that press down
##   - all text is right-to-left (Hebrew): labels, buttons and drawn text
## Use these helpers for all UI so everything shares one style.

const FONT_FILE := preload("res://assets/fonts/Fredoka.ttf")
const FONT_SYMBOLS := preload("res://assets/fonts/NotoSansSymbols2-Regular.ttf")
const FONT_EMOJI := preload("res://assets/fonts/NotoEmoji.ttf")

const TEXT := Color(1.0, 1.0, 1.0)
const TEXT_SOFT := Color(0.80, 0.86, 0.98)
const GOLD := Color(1.0, 0.84, 0.30)
const GOLD_DARK := Color(0.85, 0.55, 0.10)
const ACCENT := Color(1.0, 0.50, 0.38)          # warnings, highlights
const GOOD := Color(0.55, 1.0, 0.45)
const OUTLINE := Color(0.05, 0.04, 0.10)
const PANEL_BG := Color(0.14, 0.19, 0.38)
const PANEL_DARK := Color(0.09, 0.12, 0.26)
const PANEL_EDGE := Color(0.03, 0.04, 0.10)

## Button colours
const BUTTON_RED := Color(0.92, 0.30, 0.20)      # the main action
const BUTTON_BRONZE := Color(0.98, 0.62, 0.15)   # orange: normal actions
const BUTTON_STEEL := Color(0.30, 0.52, 0.92)    # blue: quiet actions
const BUTTON_PURPLE := Color(0.62, 0.34, 0.92)   # magic
const BUTTON_GREEN := Color(0.30, 0.78, 0.30)
const BUTTON_GREY := Color(0.45, 0.47, 0.55)

static var _fonts: Dictionary = {}
static var _fallbacks_done := false


## Symbols and emoji (◆ ⚔ 🪙 🏆...) are not in Fredoka, and the browser version
## cannot borrow them from the computer, so the font falls back to two symbol
## fonts that ship with the game.
static func setup_fonts() -> void:
	if _fallbacks_done:
		return
	_fallbacks_done = true
	var f: FontFile = FONT_FILE
	f.fallbacks = [FONT_SYMBOLS, FONT_EMOJI]


static func font(weight: int = 600) -> Font:
	setup_fonts()
	var w := clampi(weight, 400, 700)
	if not _fonts.has(w):
		var f := FontVariation.new()
		f.base_font = FONT_FILE
		f.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): w }
		_fonts[w] = f
	return _fonts[w]


static func title_font() -> Font:
	return font(700)


static func body_font() -> Font:
	return font(500)


static func make_theme() -> Theme:
	setup_fonts()
	var t := Theme.new()
	t.default_font = font(600)
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_color("font_outline_color", "Button", OUTLINE)
	var tip := panel_style(PANEL_DARK, 3, 12)
	tip.set_content_margin_all(12)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font("font", "TooltipLabel", font(500))
	t.set_font_size("font_size", "TooltipLabel", 18)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.45)
	bar_bg.set_corner_radius_all(6)
	bar_bg.border_color = PANEL_EDGE
	bar_bg.set_border_width_all(2)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GOLD
	bar_fill.set_corner_radius_all(6)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_stylebox("slider", "HSlider", bar_bg)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(1, 1, 1, 0.25)
	sc.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", sc)
	return t


## A rounded board with a dark rim and a soft shadow.
static func panel_style(bg: Color = PANEL_BG, border: int = 4, radius: int = 20) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = PANEL_EDGE
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(22)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 5)
	return sb


## A smaller board (HUD pieces).
static func strip_style(bg: Color = PANEL_DARK) -> StyleBoxFlat:
	var sb := panel_style(Color(bg.r, bg.g, bg.b, 0.92), 3, 14)
	sb.set_content_margin_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb


## A frame for drawn things (cards, world tiles).
static func frame_style(edge: Color = PANEL_EDGE, width: int = 3, bg: Color = PANEL_BG) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(14)
	return sb


## Kept for older callers: a coloured board.
static func leather_style(tint: Color = BUTTON_BRONZE, margin: int = 12) -> StyleBoxFlat:
	var sb := panel_style(PANEL_DARK, 3, 16)
	sb.set_content_margin_all(margin)
	return sb


static func panel(accent: Color = GOLD) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	p.layout_direction = Control.LAYOUT_DIRECTION_RTL
	var decor := PanelDecor.new()
	decor.accent = accent
	p.add_child(decor)
	return p


static func label(text: String, size: int = 20, color: Color = TEXT, weight: int = 600) -> Label:
	var l := Label.new()
	l.text = text
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font(weight))
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", clampi(size / 4, 4, 12))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 12))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# short labels never wrap (in a row they would be squeezed into a column);
	# long text wraps - give it a width with custom_minimum_size or a container
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if text.length() > 34 else TextServer.AUTOWRAP_OFF
	return l


## A big title: gold, very thick outline and shadow.
static func title(text: String, size: int = 30, color: Color = GOLD) -> Label:
	var l := label(text, size, color, 700)
	l.add_theme_constant_override("outline_size", clampi(size / 3, 8, 20))
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 9))
	return l


## Kept for older callers: a paragraph (wraps to `width`).
static func illuminated(text: String, size: int = 20, width: float = 400) -> Label:
	var l := label(text, size, TEXT, 500)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## A chunky coloured button (see GameButton).
static func button(text: String, color: Color = BUTTON_BRONZE, size: int = 22) -> Button:
	var b := GameButton.new(text, color)
	b.text_direction = Control.TEXT_DIRECTION_RTL
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 54)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, TEXT)
	b.add_theme_color_override("font_disabled_color", Color(0.75, 0.75, 0.8))
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_constant_override("outline_size", clampi(size / 3, 5, 10))
	return b


## The big round main-action button ("בצע!", "לקרב!").
static func seal_button(text: String, diameter: float = 128.0, size: int = 30) -> Button:
	var b := button(text, BUTTON_RED, size)
	b.seal = true
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7))
	b.add_theme_constant_override("outline_size", 10)
	return b


## Draws outlined right-to-left text on any CanvasItem (cards, tiles...).
static func draw_text_outlined(ci: CanvasItem, pos: Vector2, text: String, width: float, size: int, color: Color,
		outline: int = 6, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, weight: int = 700) -> void:
	var f := font(weight)
	ci.draw_string_outline(f, pos + Vector2(0, 2), text, align, width, size, outline + 2, Color(0, 0, 0, 0.35), 3, TextServer.DIRECTION_RTL)
	ci.draw_string_outline(f, pos, text, align, width, size, outline, OUTLINE, 3, TextServer.DIRECTION_RTL)
	ci.draw_string(f, pos, text, align, width, size, color, 3, TextServer.DIRECTION_RTL)
