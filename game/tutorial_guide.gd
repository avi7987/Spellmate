class_name TutorialGuide
extends CanvasLayer
## The first battle teaches the game step by step: a note at the top of the
## screen says what to do, and the next step comes when the player did it.
## The computer only defends during the tutorial (BattleAI level 0).

var _steps: Array = []
var _i := 0
var _label: Label
var _count: Label
var _panel: PanelContainer
var _t := 0.0
var _start := {}
var _paused_once := false


func setup(bs: BattleScreen) -> void:
	layer = 5
	_steps = [
		["ברוכים הבאים! זה המלך שלך, בתוך הארמון. אם הוא נופל - מפסידים. אם המלך של האויב נופל - ניצחת!", func(_b): return _t > 6.0],
		["בחר גיבורים: גרור ריבוע סביב הגיבורים שלך מול השער (או לחץ על אחד מהם)", func(b): return not b.selected.is_empty()],
		["מצוין! עכשיו לחצן ימני על הקרקע כדי לשלוח אותם לשם", func(b): return b.selected.any(func(id): return b.battle.unit(id) != null and b.battle.unit(id).order != "")],
		["הכורה הולך לבד למכרה ומביא אנרגיה ◆. כשיש מספיק, לחץ על קלף של גיבור (או מקש 1-8) כדי לזמן אותו בשער", func(b): return _summons(b) > int(_start.get("summons", 0))],
		["קלפי קסם: לחץ על 'פצצת אש' ואז על אויבים במפה כדי להטיל אותה", func(b): return int(b._stats["spells"]) > 0 or _t > 45.0],
		["לחץ על רווח כדי לעצור את הזמן. גם בהפסקה אפשר לבחור ולתת פקודות. לחץ שוב כדי להמשיך", func(b): return _paused_once and not b.paused],
		["כוח מיוחד: בחר את המלכה (עם המטה) ולחץ Q או על כפתור הכוח למטה, ואז על המטרה", func(b): return int(b._stats["powers"]) > 0 or _t > 45.0],
		["עכשיו לשבור את השער או מגדל של האויב - ואז להביס את המלך שלו. בהצלחה!", func(_b): return _t > 12.0],
	]
	_panel = UiKit.panel(UiKit.GOLD)
	_panel.theme = UiKit.make_theme()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(-330, 96)
	_panel.custom_minimum_size = Vector2(660, 0)
	add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	var top := HBoxContainer.new()
	_count = UiKit.label("", 15, UiKit.TEXT_SOFT)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count)
	var skip := UiKit.button("דלג על ההדרכה", UiKit.BUTTON_STEEL, 15)
	skip.custom_minimum_size = Vector2(150, 36)
	skip.pressed.connect(func(): _i = _steps.size(); _panel.visible = false)
	top.add_child(skip)
	v.add_child(top)
	_label = UiKit.label("", 21, UiKit.TEXT, 700)
	_label.custom_minimum_size = Vector2(620, 0)
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
	if b.paused:
		_paused_once = true
	if _i == 3 and not _start.has("summons"):
		_start["summons"] = _summons(b)
	if _steps[_i][1].call(b):
		_i += 1
		_show()
