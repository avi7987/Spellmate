class_name TutorialGuide
extends CanvasLayer
## The first battle teaches the game step by step: a parchment note at the
## top says what to do, and the next step comes when the player did it.
## The computer only defends during the tutorial (BattleAI level 0).

var _steps: Array = []
var _i := 0
var _label: Label
var _count: Label
var _panel: PanelContainer
var _t := 0.0
var _start := {}


func setup(_bs: BattleScreen) -> void:
	layer = 5
	_steps = [
		["ברוכים הבאים! למטה בארמון יושב המלך שלכם. אם הוא נופל - מפסידים. אם המלך של האויב נופל - ניצחתם!", func(_b): return _t > 6.0],
		["זה משחק תורות: עכשיו שלב התכנון והזמן עומד. בחרו גיבורים: גררו ריבוע סביב הגיבורים שלכם (או לחצו על אחד)", func(b): return not b.selected.is_empty()],
		["מצוין! עכשיו לחצן ימני על הקרקע כדי לשלוח אותם לשם (או על אויב כדי לתקוף)", func(b): return b.selected.any(func(id): return b.battle.unit(id) != null and b.battle.unit(id).order != "")],
		["לחצו על החותם האדום 'בצע!' (או רווח). שני הצדדים יפעלו יחד 5 שניות - ואז תורכם שוב", func(b): return b._turns_done >= 1],
		["הכורה הולך לבד למכרה ומביא אנרגיה ◆. בשלב התכנון לחצו על קלף של גיבור (או מקש 1-8) - הוא יופיע בשער כשתלחצו 'בצע!'", func(b): return _summons(b) > int(_start.get("summons", 0))],
		["קלפי קסם: לחצו על 'פצצת אש', כוונו על אויבים במפה, ואז 'בצע!'", func(b): return int(b._stats["spells"]) > 0 or _t > 60.0],
		["כוח מיוחד: בחרו את המלכה (עם המטה), לחצו Q או על כפתור הכוח למטה, כוונו - ו'בצע!'", func(b): return int(b._stats["powers"]) > 0 or _t > 60.0],
		["רוצים לדעת מה כל גיבור עושה? לחצו עליו ותופיע עליו דף מידע משמאל. הכפתור '?' למעלה מסביר הכול", func(_b): return _t > 9.0],
		["עכשיו - שברו את השער או מגדל של האויב, ואז הביסו את המלך שלו. בהצלחה!", func(_b): return _t > 10.0],
	]
	_panel = UiKit.panel()
	_panel.theme = UiKit.make_theme()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(-350, 100)
	_panel.custom_minimum_size = Vector2(700, 0)
	add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	var top := HBoxContainer.new()
	_count = UiKit.label("", 16, UiKit.INK_SOFT, 700)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count)
	var skip := UiKit.button("דלג על ההדרכה", UiKit.BUTTON_STEEL, 15)
	skip.custom_minimum_size = Vector2(150, 36)
	skip.pressed.connect(func(): _i = _steps.size(); _panel.visible = false)
	top.add_child(skip)
	v.add_child(top)
	_label = UiKit.label("", 22, UiKit.INK, 700)
	_label.custom_minimum_size = Vector2(640, 0)
	v.add_child(_label)
	_show()


func _summons(b: BattleScreen) -> int:
	var n := 0
	for c in b.battle.cards[0]:
		if c["unit"] >= 0:
			n += 1
	return n


func _show() -> void:
	if _i >= _steps.size():
		_panel.visible = false
		return
	_label.text = _steps[_i][0]
	_count.text = "הדרכה %d/%d" % [_i + 1, _steps.size()]
	_t = 0.0
	_panel.pivot_offset = _panel.size / 2
	_panel.scale = Vector2(0.9, 0.9)
	_panel.create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("reward", 0.6)


func update(b: BattleScreen) -> void:
	if _i >= _steps.size():
		return
	_t += get_process_delta_time()
	if _i == 4 and not _start.has("summons"):
		_start["summons"] = _summons(b)
	if _steps[_i][1].call(b):
		_i += 1
		_show()
