class_name Hud
extends CanvasLayer
## Everything drawn on top of the board: the turn banner, team cards with
## energy crystals, the selected character with its power card, the main menu,
## promotion choice and game-over screens. The HUD never changes the game -
## it only emits signals.

signal new_game_requested(vs_ai: bool, powers: bool, level: int)
signal undo_requested
signal power_pressed
signal cancel_pressed
signal promotion_chosen(kind: int)

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.3, 0.15);
void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.25, 1.0);
	float v = smoothstep(0.32, 0.82, length(uv));
	COLOR = vec4(tint.rgb * (1.0 - v), max(v * 0.62, tint.a * (1.0 - v)));
}
"""

var _root: Control
var _vignette: ColorRect
var _banner: PanelContainer
var _banner_label: Label
var _banner_crest: Label
var _hint: Label
var _flash: Label
var _team_cards: Dictionary = {}     # color -> { panel, energy, pips, captured }
var _char_panel: PanelContainer
var _card_name: Label
var _card_role: Label
var _card_status: Label
var _power_card: PowerCard
var _cancel_btn: Button
var _undo_btn: Button
var _menu: Control
var _menu_resume: Button
var _over: Control
var _over_label: Label
var _promo: Control
var _turn_color := -1

var _vs_ai := true
var _powers := true
var _level := 1
var _mode_buttons: Array = []
var _level_buttons: Array = []
var _level_row: Control
var _powers_check: CheckButton


func _ready() -> void:
	layer = 10
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_vignette.material = mat
	var bg := CanvasLayer.new()
	bg.layer = 5
	add_sibling.call_deferred(bg)
	bg.add_child(_vignette)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.make_theme()
	add_child(_root)
	_build_banner()
	_build_team_cards()
	_build_character_panel()
	_build_buttons()
	_build_flash()
	_build_menu()
	_build_game_over()
	_build_promotion()


# ------------------------------------------------------------ building

func _build_banner() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.position = Vector2(-260, 6)
	holder.custom_minimum_size = Vector2(520, 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_child(v)
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.pivot_offset = Vector2(150, 24)
	v.add_child(_banner)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_banner.add_child(row)
	_banner_crest = UiKit.label("", 28, UiKit.GOLD)
	_banner_crest.visible = false
	_banner_label = UiKit.title("", 28)
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_banner_label)
	_hint = UiKit.label("", 18, UiKit.TEXT_SOFT)
	v.add_child(_hint)


func _build_flash() -> void:
	_flash = UiKit.title("", 92, Color(1.0, 0.3, 0.2))
	_flash.add_theme_constant_override("outline_size", 18)
	_flash.set_anchors_preset(Control.PRESET_CENTER)
	_flash.position = Vector2(-300, -80)
	_flash.size = Vector2(600, 160)
	_flash.pivot_offset = Vector2(300, 80)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	_root.add_child(_flash)


func _build_team_cards() -> void:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	col.offset_left = -256
	col.offset_right = -14
	col.offset_top = 80
	col.offset_bottom = -14
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	_root.add_child(col)
	for color in [Chess.BLACK, Chess.WHITE]:
		var p := UiKit.panel()
		p.pivot_offset = Vector2(121, 70)
		col.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		p.add_child(v)
		v.add_child(UiKit.title(Texts.TEAM[color], 26, Style.team(color)["ui"]))
		var energy := UiKit.label("", 16, UiKit.TEXT_SOFT)
		v.add_child(energy)
		var pips := HBoxContainer.new()
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		pips.add_theme_constant_override("separation", 2)
		pips.layout_direction = Control.LAYOUT_DIRECTION_RTL
		v.add_child(pips)
		for i in Balance.energy_max():
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(17, 24)
			pips.add_child(pip)
		var captured := UiKit.label("", 15, UiKit.TEXT_SOFT)
		v.add_child(captured)
		_team_cards[color] = { "panel": p, "energy": energy, "pips": pips, "captured": captured }


func _build_character_panel() -> void:
	_char_panel = UiKit.panel()
	_char_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_char_panel.offset_left = 14
	_char_panel.offset_right = 290
	_char_panel.offset_top = 70
	_char_panel.offset_bottom = -96
	_root.add_child(_char_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_char_panel.add_child(v)
	_card_name = UiKit.title("", 26)
	v.add_child(_card_name)
	_card_role = UiKit.label("", 16, UiKit.TEXT_SOFT)
	v.add_child(_card_role)
	_card_status = UiKit.label("", 15, Color(0.6, 0.85, 1.0))
	v.add_child(_card_status)
	var center := CenterContainer.new()
	v.add_child(center)
	_power_card = PowerCard.new()
	_power_card.activated.connect(func(): power_pressed.emit())
	center.add_child(_power_card)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	_cancel_btn = UiKit.button(Texts.CANCEL, UiKit.BUTTON_STEEL, 20)
	_cancel_btn.pressed.connect(func(): cancel_pressed.emit())
	v.add_child(_cancel_btn)
	_char_panel.visible = false


func _build_buttons() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	row.offset_left = 14
	row.offset_top = -78
	row.offset_right = 290
	row.offset_bottom = -14
	row.add_theme_constant_override("separation", 10)
	_root.add_child(row)
	_undo_btn = UiKit.button(Texts.UNDO, UiKit.BUTTON_STEEL, 19)
	_undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_btn.pressed.connect(func(): undo_requested.emit())
	row.add_child(_undo_btn)
	var menu_btn := UiKit.button(Texts.MENU, UiKit.BUTTON_BRONZE, 19)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.pressed.connect(func(): show_menu(true))
	row.add_child(menu_btn)


func _overlay() -> Control:
	var o := ColorRect.new()
	o.color = Color(0.02, 0.01, 0.02, 0.72)
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(o)
	return o


func _center_panel(parent: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	return v


func _build_menu() -> void:
	_menu = _overlay()
	var v := _center_panel(_menu, 540)
	var t := UiKit.title(Texts.GAME_TITLE, 72)
	t.add_theme_constant_override("outline_size", 14)
	v.add_child(t)
	v.add_child(UiKit.label(Texts.SUBTITLE, 24, UiKit.TEXT_SOFT, 400))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	modes.layout_direction = Control.LAYOUT_DIRECTION_RTL
	v.add_child(modes)
	for vs_ai in [true, false]:
		var b := UiKit.button(Texts.MODE_AI if vs_ai else Texts.MODE_LOCAL, UiKit.BUTTON_STEEL, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _vs_ai = vs_ai; _refresh_menu())
		b.set_meta("value", vs_ai)
		modes.add_child(b)
		_mode_buttons.append(b)
	_level_row = VBoxContainer.new()
	v.add_child(_level_row)
	_level_row.add_child(UiKit.label(Texts.LEVEL, 18, UiKit.TEXT_SOFT))
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 8)
	levels.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_level_row.add_child(levels)
	for i in Texts.LEVELS.size():
		var b := UiKit.button(Texts.LEVELS[i], UiKit.BUTTON_PURPLE, 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _level = i; _refresh_menu())
		levels.add_child(b)
		_level_buttons.append(b)
	_powers_check = CheckButton.new()
	_powers_check.text = Texts.POWERS_ON
	_powers_check.button_pressed = true
	_powers_check.add_theme_font_size_override("font_size", 21)
	_powers_check.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_powers_check.toggled.connect(func(on): _powers = on)
	v.add_child(_powers_check)
	var start := UiKit.button(Texts.START, UiKit.BUTTON_RED, 30)
	start.custom_minimum_size = Vector2(0, 66)
	start.pressed.connect(func():
		show_menu(false)
		new_game_requested.emit(_vs_ai, _powers, _level))
	v.add_child(start)
	_menu_resume = UiKit.button("חזרה למשחק", UiKit.BUTTON_GREY, 19)
	_menu_resume.pressed.connect(func(): show_menu(false))
	v.add_child(_menu_resume)
	_refresh_menu()


func _refresh_menu() -> void:
	for b in _mode_buttons:
		var on: bool = b.get_meta("value") == _vs_ai
		b.modulate = Color(1, 1, 1) if on else Color(0.5, 0.48, 0.45)
	for i in _level_buttons.size():
		_level_buttons[i].modulate = Color(1, 1, 1) if i == _level else Color(0.5, 0.48, 0.45)
	_level_row.visible = _vs_ai


func _build_game_over() -> void:
	_over = _overlay()
	var v := _center_panel(_over, 500)
	_over_label = UiKit.title("", 40)
	v.add_child(_over_label)
	var again := UiKit.button(Texts.NEW_GAME, UiKit.BUTTON_RED, 26)
	again.pressed.connect(func():
		_over.visible = false
		show_menu(true))
	v.add_child(again)
	var look := UiKit.button("לצפות בלוח", UiKit.BUTTON_GREY, 19)
	look.pressed.connect(func(): _over.visible = false)
	v.add_child(look)
	_over.visible = false


func _build_promotion() -> void:
	_promo = _overlay()
	var v := _center_panel(_promo, 460)
	v.add_child(UiKit.title(Texts.PROMOTE, 28))
	for kind in [Chess.Kind.QUEEN, Chess.Kind.ROOK, Chess.Kind.BISHOP, Chess.Kind.KNIGHT]:
		var b := UiKit.button(Texts.CHESS_ROLE[kind], UiKit.BUTTON_STEEL, 22)
		b.pressed.connect(func():
			_promo.visible = false
			promotion_chosen.emit(kind))
		v.add_child(b)
	_promo.visible = false


# ------------------------------------------------------------ updating

func show_menu(visible_now: bool, can_resume: bool = true) -> void:
	_menu.visible = visible_now
	_menu_resume.visible = can_resume


func show_promotion() -> void:
	_promo.visible = true


func show_game_over(result: Dictionary) -> void:
	var reason: String = result["reason"]
	var text: String = Texts.RESULT.get(reason, "")
	if reason == "checkmate":
		var winner := Chess.WHITE if result["result"] == Rules.Result.WHITE_WINS else Chess.BLACK
		text = text % Texts.TEAM[winner]
		_over_label.add_theme_color_override("font_color", Style.team(winner)["ui"])
	_over_label.text = text
	_over.visible = true


## Big animated word in the middle of the screen ("שח!", "מט!").
func flash(text: String, color: Color) -> void:
	_flash.text = text
	_flash.add_theme_color_override("font_color", color)
	_flash.visible = true
	_flash.scale = Vector2.ONE * 2.2
	_flash.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_flash, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_flash, "modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(0.8)
	tw.chain().tween_property(_flash, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func(): _flash.visible = false)


func update_state(state: GameState, controller: GameController) -> void:
	var me := state.side_to_move
	if controller.is_vs_ai() and controller.players[me] == GameController.PlayerType.HUMAN:
		_banner_label.text = Texts.YOU
	else:
		_banner_label.text = Texts.TURN_OF % Texts.TEAM[me]
	if me != _turn_color:
		_turn_color = me
		_set_turn_look(me)
	var lost := { Chess.WHITE: 16, Chess.BLACK: 16 }
	for p in state.all_pieces():
		lost[p.color] -= 1
	for color in _team_cards:
		var c: Dictionary = _team_cards[color]
		var active: bool = color == me and not controller.is_over()
		var team_ui: Color = Style.team(color)["ui"]
		var sb := UiKit.panel_style(UiKit.PANEL_BG, team_ui if active else Color(0.25, 0.22, 0.2))
		if active:
			sb.set_border_width_all(5)
			sb.shadow_color = Color(team_ui.r, team_ui.g, team_ui.b, 0.55)
			sb.shadow_size = 22
			sb.shadow_offset = Vector2.ZERO
		c["panel"].add_theme_stylebox_override("panel", sb)
		c["panel"].modulate = Color.WHITE if active else Color(0.62, 0.6, 0.6)
		var tw: Tween = c["panel"].create_tween()
		tw.tween_property(c["panel"], "scale", Vector2.ONE * (1.05 if active else 0.95), 0.3)
		var e := int(state.energy[color])
		c["energy"].text = "%s: %d/%d" % [Texts.ENERGY, e, Balance.energy_max()]
		c["energy"].visible = state.abilities_enabled
		c["pips"].visible = state.abilities_enabled
		var pips: Array = c["pips"].get_children()
		for i in pips.size():
			var sbp := StyleBoxFlat.new()
			sbp.set_corner_radius_all(3)
			sbp.corner_radius_top_left = 9
			sbp.corner_radius_top_right = 9
			sbp.bg_color = Color(0.35, 0.75, 1.0) if i < e else Color(0.14, 0.13, 0.16)
			sbp.border_color = Color(0.85, 0.95, 1.0, 0.8) if i < e else Color(0.3, 0.27, 0.24)
			sbp.set_border_width_all(1)
			pips[i].add_theme_stylebox_override("panel", sbp)
		c["captured"].text = Texts.CAPTURED % lost[Chess.other(color)]
	_undo_btn.disabled = not controller.can_undo()


## Colours of the banner and the screen tint follow the side to move.
func _set_turn_look(color: int) -> void:
	var mood: Dictionary = Style.MOOD[color]
	var team_ui: Color = Style.team(color)["ui"]
	var sb := UiKit.panel_style(Color(0.07, 0.05, 0.05, 0.92), team_ui, 10)
	sb.set_border_width_all(4)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(team_ui.r, team_ui.g, team_ui.b, 0.5)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2.ZERO
	_banner.add_theme_stylebox_override("panel", sb)
	_banner_label.add_theme_color_override("font_color", team_ui.lightened(0.2))
	_banner.scale = Vector2(0.6, 0.6)
	_banner.create_tween().tween_property(_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var mat := _vignette.material as ShaderMaterial
	var cur = mat.get_shader_parameter("tint")
	var from: Color = cur if cur is Color else Color(mood["tint"], 0.0)
	_vignette.create_tween().tween_method(func(c: Color): mat.set_shader_parameter("tint", c), from, mood["tint"], 0.8)


func set_hint(text: String) -> void:
	_hint.text = text


func set_thinking(on: bool) -> void:
	set_hint(Texts.AI_THINKING if on else "")


## Shows the character on `s` and its power card. targeting = choosing a target now.
func show_character(state: GameState, s: int, power_targets: int, targeting: bool) -> void:
	var p := state.piece_at(s)
	if p == null:
		hide_character()
		return
	_char_panel.visible = true
	_card_name.text = Texts.character(p.kind, p.color)
	_card_name.add_theme_color_override("font_color", Style.team(p.color)["ui"])
	_card_role.text = "%s · %s" % [Texts.CHESS_ROLE[p.kind], Texts.TEAM[p.color]]
	var flags := []
	if state.is_frozen(p):
		flags.append(Texts.FROZEN)
	if state.is_shielded(p):
		flags.append(Texts.SHIELDED)
	_card_status.text = "  ".join(flags)
	_cancel_btn.visible = targeting
	var ab := AbilityRegistry.for_kind(p.kind)
	_power_card.visible = state.abilities_enabled and ab != null
	if not _power_card.visible:
		return
	var mine := p.color == state.side_to_move
	var wait := ab.turns_until_ready(state, s)
	var status := Texts.READY
	if targeting:
		status = Texts.CHOOSE_TARGET
	elif wait > 0:
		status = Texts.COOLDOWN % wait
	elif Rules.in_check(state, p.color) and mine:
		status = Texts.IN_CHECK_NO_POWER
	elif int(state.energy[p.color]) < ab.cost:
		status = Texts.NOT_ENOUGH
	elif power_targets == 0 and mine:
		status = Texts.NO_TARGETS
	elif not mine:
		status = Texts.ENEMY_POWER
	_power_card.setup(ab.id, Texts.ABILITY_NAME[ab.id], Texts.ABILITY_DESC[ab.id], ab.cost, status,
		mine and power_targets > 0 and not targeting, targeting)


func hide_character() -> void:
	_char_panel.visible = false
