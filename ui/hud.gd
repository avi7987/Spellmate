class_name Hud
extends CanvasLayer
## Everything drawn on top of the board: team cards with energy, the selected
## character's card, the main menu, promotion choice and game-over screens.
## The HUD never changes the game - it only emits signals.

signal new_game_requested(vs_ai: bool, powers: bool, level: int)
signal undo_requested
signal power_pressed
signal cancel_pressed
signal promotion_chosen(kind: int)

var _root: Control
var _banner: Label
var _hint: Label
var _team_cards: Dictionary = {}     # color -> { panel, name, energy, pips, captured }
var _card: PanelContainer
var _card_name: Label
var _card_role: Label
var _card_power: Label
var _card_desc: Label
var _card_status: Label
var _power_btn: Button
var _cancel_btn: Button
var _undo_btn: Button
var _menu: Control
var _menu_resume: Button
var _over: Control
var _over_label: Label
var _promo: Control

var _vs_ai := true
var _powers := true
var _level := 1
var _mode_buttons: Array = []
var _level_buttons: Array = []
var _level_row: Control
var _powers_check: CheckButton


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.make_theme()
	add_child(_root)
	_build_banner()
	_build_team_cards()
	_build_character_card()
	_build_buttons()
	_build_menu()
	_build_game_over()
	_build_promotion()


# ------------------------------------------------------------ building

func _build_banner() -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-300, 8)
	box.custom_minimum_size = Vector2(600, 0)
	_root.add_child(box)
	_banner = UiKit.label("", 30, UiKit.TEXT, 800)
	_banner.add_theme_constant_override("outline_size", 10)
	box.add_child(_banner)
	_hint = UiKit.label("", 20, UiKit.TEXT_SOFT)
	box.add_child(_hint)


func _build_team_cards() -> void:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	col.offset_left = -250
	col.offset_right = -14
	col.offset_top = 70
	col.offset_bottom = -14
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_root.add_child(col)
	for color in [Chess.BLACK, Chess.WHITE]:
		var p := UiKit.panel()
		col.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		p.add_child(v)
		var name := UiKit.label(Texts.TEAM[color], 24, Style.team(color)["ui"].lightened(0.3), 800)
		v.add_child(name)
		var energy := UiKit.label("", 18, UiKit.TEXT_SOFT)
		v.add_child(energy)
		var pips := HBoxContainer.new()
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		pips.add_theme_constant_override("separation", 3)
		pips.layout_direction = Control.LAYOUT_DIRECTION_RTL
		v.add_child(pips)
		for i in Balance.energy_max():
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(16, 22)
			pips.add_child(pip)
		var captured := UiKit.label("", 16, UiKit.TEXT_SOFT)
		v.add_child(captured)
		_team_cards[color] = { "panel": p, "energy": energy, "pips": pips, "captured": captured }


func _build_character_card() -> void:
	_card = UiKit.panel()
	_card.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_card.offset_left = 14
	_card.offset_right = 264
	_card.offset_top = 70
	_card.offset_bottom = -100
	_root.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_card.add_child(v)
	_card_name = UiKit.label("", 26, UiKit.PANEL_BORDER, 800)
	v.add_child(_card_name)
	_card_role = UiKit.label("", 18, UiKit.TEXT_SOFT)
	v.add_child(_card_role)
	v.add_child(HSeparator.new())
	_card_power = UiKit.label("", 22, Color(0.85, 0.65, 1.0), 800)
	v.add_child(_card_power)
	_card_desc = UiKit.label("", 17, UiKit.TEXT)
	v.add_child(_card_desc)
	_card_status = UiKit.label("", 17, Color(1, 0.9, 0.5))
	v.add_child(_card_status)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	_power_btn = UiKit.button(Texts.USE_POWER, UiKit.BUTTON_PURPLE)
	_power_btn.pressed.connect(func(): power_pressed.emit())
	v.add_child(_power_btn)
	_cancel_btn = UiKit.button(Texts.CANCEL, UiKit.BUTTON_GREY, 20)
	_cancel_btn.pressed.connect(func(): cancel_pressed.emit())
	v.add_child(_cancel_btn)
	_card.visible = false


func _build_buttons() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	row.offset_left = 14
	row.offset_top = -78
	row.offset_right = 264
	row.offset_bottom = -14
	row.add_theme_constant_override("separation", 10)
	_root.add_child(row)
	_undo_btn = UiKit.button(Texts.UNDO, UiKit.BUTTON_BLUE, 20)
	_undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_btn.pressed.connect(func(): undo_requested.emit())
	row.add_child(_undo_btn)
	var menu_btn := UiKit.button(Texts.MENU, UiKit.BUTTON_GOLD, 20)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.pressed.connect(func(): show_menu(true))
	row.add_child(menu_btn)


func _overlay() -> Control:
	var o := ColorRect.new()
	o.color = Color(0.02, 0.02, 0.08, 0.6)
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
	var v := _center_panel(_menu, 520)
	var title := UiKit.label(Texts.GAME_TITLE, 64, UiKit.PANEL_BORDER, 900)
	title.add_theme_constant_override("outline_size", 14)
	v.add_child(title)
	v.add_child(UiKit.label(Texts.SUBTITLE, 24, UiKit.TEXT_SOFT))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	modes.layout_direction = Control.LAYOUT_DIRECTION_RTL
	v.add_child(modes)
	for vs_ai in [true, false]:
		var b := UiKit.button(Texts.MODE_AI if vs_ai else Texts.MODE_LOCAL, UiKit.BUTTON_BLUE, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.pressed.connect(func(): _vs_ai = vs_ai; _refresh_menu())
		b.set_meta("value", vs_ai)
		modes.add_child(b)
		_mode_buttons.append(b)
	_level_row = VBoxContainer.new()
	v.add_child(_level_row)
	_level_row.add_child(UiKit.label(Texts.LEVEL, 20, UiKit.TEXT_SOFT))
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
	_powers_check.add_theme_font_size_override("font_size", 22)
	_powers_check.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_powers_check.toggled.connect(func(on): _powers = on)
	v.add_child(_powers_check)
	var start := UiKit.button(Texts.START, UiKit.BUTTON_GOLD, 30)
	start.custom_minimum_size = Vector2(0, 68)
	start.pressed.connect(func():
		show_menu(false)
		new_game_requested.emit(_vs_ai, _powers, _level))
	v.add_child(start)
	_menu_resume = UiKit.button("חזרה למשחק", UiKit.BUTTON_GREY, 20)
	_menu_resume.pressed.connect(func(): show_menu(false))
	v.add_child(_menu_resume)
	_refresh_menu()


func _refresh_menu() -> void:
	for b in _mode_buttons:
		var on: bool = b.get_meta("value") == _vs_ai
		b.modulate = Color(1, 1, 1) if on else Color(0.55, 0.55, 0.65)
	for i in _level_buttons.size():
		_level_buttons[i].modulate = Color(1, 1, 1) if i == _level else Color(0.55, 0.55, 0.65)
	_level_row.visible = _vs_ai


func _build_game_over() -> void:
	_over = _overlay()
	var v := _center_panel(_over, 480)
	_over_label = UiKit.label("", 36, UiKit.PANEL_BORDER, 900)
	v.add_child(_over_label)
	var again := UiKit.button(Texts.NEW_GAME, UiKit.BUTTON_GOLD, 28)
	again.pressed.connect(func():
		_over.visible = false
		show_menu(true))
	v.add_child(again)
	var look := UiKit.button("לצפות בלוח", UiKit.BUTTON_GREY, 20)
	look.pressed.connect(func(): _over.visible = false)
	v.add_child(look)
	_over.visible = false


func _build_promotion() -> void:
	_promo = _overlay()
	var v := _center_panel(_promo, 460)
	v.add_child(UiKit.label(Texts.PROMOTE, 28, UiKit.PANEL_BORDER, 800))
	for kind in [Chess.Kind.QUEEN, Chess.Kind.ROOK, Chess.Kind.BISHOP, Chess.Kind.KNIGHT]:
		var b := UiKit.button("%s (%s)" % [Texts.CHARACTER[kind], Texts.CHESS_ROLE[kind]], UiKit.BUTTON_BLUE, 22)
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
	_over_label.text = text
	_over.visible = true


func update_state(state: GameState, controller: GameController) -> void:
	var me := state.side_to_move
	if controller.is_vs_ai() and controller.players[me] == GameController.PlayerType.HUMAN:
		_banner.text = Texts.YOU
	else:
		_banner.text = Texts.TURN_OF % Texts.TEAM[me]
	if Rules.in_check(state, me) and not controller.is_over():
		_banner.text += "  ·  " + Texts.CHECK
	_banner.add_theme_color_override("font_color", Style.team(me)["ui"].lightened(0.35))
	var lost := { Chess.WHITE: 16, Chess.BLACK: 16 }
	for p in state.all_pieces():
		lost[p.color] -= 1
	for color in _team_cards:
		var c: Dictionary = _team_cards[color]
		var active: bool = color == me and not controller.is_over()
		var sb := UiKit.panel_style(UiKit.PANEL_BG, Style.team(color)["ui"] if active else Color(0.3, 0.3, 0.4))
		if active:
			sb.set_border_width_all(6)
		c["panel"].add_theme_stylebox_override("panel", sb)
		var e := int(state.energy[color])
		c["energy"].text = "%s: %d/%d" % [Texts.ENERGY, e, Balance.energy_max()]
		c["energy"].visible = state.abilities_enabled
		c["pips"].visible = state.abilities_enabled
		var pips: Array = c["pips"].get_children()
		for i in pips.size():
			var sbp := StyleBoxFlat.new()
			sbp.set_corner_radius_all(5)
			sbp.bg_color = Color(0.55, 0.85, 1.0) if i < e else Color(0.2, 0.2, 0.3)
			sbp.border_color = Color(0.05, 0.05, 0.1)
			sbp.set_border_width_all(2)
			pips[i].add_theme_stylebox_override("panel", sbp)
		# Pieces this team defeated = pieces the other team lost.
		c["captured"].text = Texts.CAPTURED % lost[Chess.other(color)]
	_undo_btn.disabled = not controller.can_undo()


func set_hint(text: String) -> void:
	_hint.text = text


func set_thinking(on: bool) -> void:
	set_hint(Texts.AI_THINKING if on else "")


## Shows the card of the piece on `s`. targeting = we are choosing a target.
func show_character(state: GameState, s: int, power_targets: int, targeting: bool) -> void:
	var p := state.piece_at(s)
	if p == null:
		hide_character()
		return
	_card.visible = true
	_card_name.text = Texts.CHARACTER[p.kind]
	_card_role.text = "%s · %s" % [Texts.CHESS_ROLE[p.kind], Texts.TEAM[p.color]]
	var ab := AbilityRegistry.for_kind(p.kind)
	var show_power := state.abilities_enabled and ab != null
	_card_power.visible = show_power
	_card_desc.visible = show_power
	_card_status.visible = true
	_power_btn.visible = show_power and p.color == state.side_to_move
	_cancel_btn.visible = targeting
	if not show_power:
		_card_status.text = ""
		return
	_card_power.text = "✦ " + Texts.ABILITY_NAME[ab.id]
	_card_desc.text = Texts.ABILITY_DESC[ab.id]
	var status := [Texts.COST % ab.cost]
	var wait := ab.turns_until_ready(state, s)
	status.append(Texts.COOLDOWN % wait if wait > 0 else Texts.READY)
	if state.is_frozen(p):
		status.append(Texts.FROZEN)
	if state.is_shielded(p):
		status.append(Texts.SHIELDED)
	_card_status.text = "  ·  ".join(status)
	_power_btn.disabled = power_targets == 0 or targeting
	if p.color == state.side_to_move and power_targets == 0 and wait == 0:
		if int(state.energy[p.color]) < ab.cost:
			_power_btn.text = Texts.NOT_ENOUGH
		else:
			_power_btn.text = Texts.NO_TARGETS
	else:
		_power_btn.text = Texts.USE_POWER


func hide_character() -> void:
	_card.visible = false
