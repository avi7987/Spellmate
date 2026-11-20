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
		["ברוכים הבאים! המלך שלכם יושב בארמון למטה. אם הוא נופל, מפסידים. אם המלך של האויב נופל, מנצחים!", func(_b): return _t > 6.0],
		["המשחק מתנהל בתורות, ועכשיו זה שלב התכנון: הזמן עוצר. בחרו גיבורים: גררו ריבוע סביבם או לחצו על אחד מהם.", func(b): return not b.selected.is_empty()],
		["מצוין! עכשיו לחצו לחצן ימני על הקרקע כדי לשלוח אותם לשם. לחיצה על אויב שולחת אותם לתקוף.", func(b): return b.selected.any(func(id): return b.battle.unit(id) != null and b.battle.unit(id).order != "")],
		["לחצו על הכפתור העגול 'בצע!' (או רווח). שני הצדדים יפעלו יחד חמש שניות, ואז שוב תורכם.", func(b): return b._turns_done >= 1],
		["הכורה הולך לבד למכרה ומביא אנרגיה. בשלב התכנון לחצו על קלף של גיבור (או מקש 1 עד 8), והוא יופיע ליד השער כשתלחצו 'בצע!'.", func(b): return _summons(b) > int(_start.get("summons", 0))],
		["עכשיו קסם: לחצו על 'פצצת אש', כוונו אותה על אויבים במפה, ואז לחצו 'בצע!'.", func(b): return int(b._stats["spells"]) > 0 or _t > 60.0],
		["כוח מיוחד: בחרו את המלכה (זו עם המטה), לחצו Q או על כפתור הכוח למטה, כוונו ולחצו 'בצע!'.", func(b): return int(b._stats["powers"]) > 0 or _t > 60.0],
		["רוצים לדעת מה גיבור עושה? לחצו עליו, ויופיע עליו דף מידע. הכפתור '?' למעלה מסביר את כל המשחק.", func(_b): return _t > 9.0],
		["ועכשיו לעבודה: שברו את השער או מגדל של האויב, ואז הביסו את המלך שלו. בהצלחה!", func(_b): return _t > 10.0],
	]
	var holder := HBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 112
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.theme = UiKit.make_theme()
	add_child(holder)
	_panel = UiKit.panel()
	_panel.custom_minimum_size = Vector2(700, 0)
	holder.add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	var top := HBoxContainer.new()
	_count = UiKit.label("", 16, UiKit.TEXT_SOFT, 700)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count)
	var skip := UiKit.button("לדלג על ההדרכה", UiKit.BUTTON_STEEL, 15)
	skip.custom_minimum_size = Vector2(150, 36)
	skip.pressed.connect(func(): _i = _steps.size(); _panel.visible = false)
	top.add_child(skip)
	v.add_child(top)
	_label = UiKit.label("", 22, UiKit.TEXT, 700)
	_label.custom_minimum_size = Vector2(640, 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_label)
	_show()


func _summons(b: BattleScreen) -> int:
	return b.battle.summons[0]


func _show() -> void:
	if _i >= _steps.size():
		_panel.visible = false
		return
	_label.text = _steps[_i][0]
	_count.text = "הדרכה · שלב %d מתוך %d" % [_i + 1, _steps.size()]
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
