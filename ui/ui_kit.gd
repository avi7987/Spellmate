class_name UiKit
extends RefCounted
## The game's look for every screen: ROYAL GOLD (owner's choice, concept 1 of 10):
## deep-red velvet boards with a gold rim and a little crown, titles in gold
## leaf (a gold gradient with a shine) with a dark-brown outline, gold buttons.
##   - titles and buttons: Noto Serif Hebrew Black (a strong modern serif, like an
##     epic movie title); text: Secular One (clean, bold). Always white or gold
##     with a thick dark outline and a soft shadow, so it reads on any background
##   - panels: rounded red-velvet boards with a gold rim, a gold inner line and a crown
##   - buttons: chunky coloured "3D" buttons that press down
##   - all text is right-to-left (Hebrew): labels, buttons and drawn text
## Use these helpers for all UI so everything shares one style.

const FONT_FILE := preload("res://assets/fonts/SecularOne-Regular.ttf")     ## text: clean and bold
const FONT_TITLE_FILE := preload("res://assets/fonts/NotoSerifHebrew.ttf")  ## titles and buttons: knightly serif
const FONT_SYMBOLS := preload("res://assets/fonts/NotoSansSymbols2-Regular.ttf")
const FONT_EMOJI := preload("res://assets/fonts/NotoEmoji.ttf")

const TEXT := Color(1.0, 1.0, 1.0)
const TEXT_SOFT := Color(1.0, 0.90, 0.76)
const GOLD := Color(1.0, 0.84, 0.30)
const GOLD_DARK := Color(0.85, 0.55, 0.10)
const ACCENT := Color(1.0, 0.50, 0.38)          # warnings, highlights
const GOOD := Color(0.55, 1.0, 0.45)
const OUTLINE := Color(0.18, 0.05, 0.02)
const PANEL_BG := Color(0.40, 0.05, 0.08)       # red velvet
const PANEL_DARK := Color(0.24, 0.03, 0.05)
const PANEL_EDGE := Color(0.12, 0.02, 0.02)
const GOLD_RIM := Color(0.93, 0.73, 0.27)        # the gold frame of every board

## Button colours
const BUTTON_RED := Color(0.80, 0.14, 0.15)      # crimson: the main action
const BUTTON_BRONZE := Color(0.90, 0.66, 0.16)   # gold: normal actions
const BUTTON_STEEL := Color(0.22, 0.34, 0.66)    # royal blue: quiet actions
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
	for font_file in [FONT_FILE, FONT_TITLE_FILE]:
		var f: FontFile = font_file
		f.fallbacks = [FONT_SYMBOLS, FONT_EMOJI]


## weight >= 700 = the knightly title font, below = the text font.
static func font(weight: int = 600) -> Font:
	setup_fonts()
	if weight < 700:
		return FONT_FILE
	if not _fonts.has("title"):
		var f := FontVariation.new()
		f.base_font = FONT_TITLE_FILE
		f.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 900 }
		_fonts["title"] = f
	return _fonts["title"]


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
	sb.border_color = GOLD_RIM
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


## A big title: GOLD LEAF (a gold gradient with a shine), very thick outline and shadow.
static func title(text: String, size: int = 30, color: Color = GOLD) -> Label:
	var l := label(text, size, color, 700)
	l.add_theme_constant_override("outline_size", clampi(size / 3, 8, 20))
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 9))
	if color == GOLD:
		gild(l, size)
	return l


const _GOLD_SHADER := """
shader_type canvas_item;
uniform vec4 c_top : source_color = vec4(1.0, 0.97, 0.75, 1.0);
uniform vec4 c_mid : source_color = vec4(1.0, 0.78, 0.2, 1.0);
uniform vec4 c_bot : source_color = vec4(0.62, 0.36, 0.05, 1.0);
uniform float y0 = 0.0;
uniform float y1 = 40.0;
varying vec2 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec4 c = COLOR;
	// only the letters themselves (pure white), not the outline or the shadow
	if (c.r > 0.96 && c.g > 0.96 && c.b > 0.96) {
		float t = clamp((lp.y - y0) / (y1 - y0), 0.0, 1.0);
		vec3 g = t < 0.5 ? mix(c_top.rgb, c_mid.rgb, t * 2.0) : mix(c_mid.rgb, c_bot.rgb, t * 2.0 - 1.0);
		g += vec3(smoothstep(0.07, 0.0, abs(t - 0.42)) * 0.25);
		COLOR = vec4(g, c.a);
	}
}
"""
static var _gold_shader: Shader


## Turns a label's letters into gold leaf. Its font colour becomes white (the
## shader paints the gold); the label should be about one line high.
static func gild(l: Label, size: int) -> void:
	if _gold_shader == null:
		_gold_shader = Shader.new()
		_gold_shader.code = _GOLD_SHADER
	var m := ShaderMaterial.new()
	m.shader = _gold_shader
	m.set_shader_parameter("y0", size * 0.3)
	m.set_shader_parameter("y1", size * 1.25)
	l.material = m
	l.add_theme_color_override("font_color", Color.WHITE)


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
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_constant_override("outline_size", 10)
	# gold-leaf letters (see gild)
	if _gold_shader == null:
		_gold_shader = Shader.new()
		_gold_shader.code = _GOLD_SHADER
	var m := ShaderMaterial.new()
	m.shader = _gold_shader
	var mid := (diameter - GameButton.DEPTH) / 2.0
	m.set_shader_parameter("y0", mid - size * 0.55)
	m.set_shader_parameter("y1", mid + size * 0.5)
	b.material = m
	return b


## Draws outlined right-to-left text on any CanvasItem (cards, tiles...).
static func draw_text_outlined(ci: CanvasItem, pos: Vector2, text: String, width: float, size: int, color: Color,
		outline: int = 6, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, weight: int = 700) -> void:
	var f := font(weight)
	ci.draw_string_outline(f, pos + Vector2(0, 2), text, align, width, size, outline + 2, Color(0, 0, 0, 0.35), 3, TextServer.DIRECTION_RTL)
	ci.draw_string_outline(f, pos, text, align, width, size, outline, OUTLINE, 3, TextServer.DIRECTION_RTL)
	ci.draw_string(f, pos, text, align, width, size, color, 3, TextServer.DIRECTION_RTL)
