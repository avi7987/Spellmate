class_name BattleHealthBar
extends Control
## A health bar that floats above a fighter in the battle arena.
## Shows the character's name, its strength (win chance) and its health.

const W := 230.0
const H := 62.0

var target: Node3D
var cam: Camera3D
var _name := ""
var _power := 50
var _color := Color.WHITE
var _hp := 100.0
var _shown_hp := 100.0


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_name: String, power: int, color: Color) -> void:
	_name = p_name
	_power = power
	_color = color
	_hp = 100.0
	_shown_hp = 100.0
	queue_redraw()


func damage(amount: int) -> void:
	_hp = maxf(0.0, _hp - amount)


func set_hp(value: float) -> void:
	_hp = value
	_shown_hp = value


func _process(delta: float) -> void:
	if target != null and cam != null and is_instance_valid(target):
		var head := target.global_position + Vector3(0, 3.0, 0)
		position = cam.unproject_position(head) - Vector2(W / 2.0, H)
	_shown_hp = move_toward(_shown_hp, _hp, delta * 120.0)
	queue_redraw()


func _draw() -> void:
	var font := UiKit.title_font()
	draw_string(font, Vector2(0, 18), _name, HORIZONTAL_ALIGNMENT_CENTER, W, 20, Color(1, 0.95, 0.85))
	draw_string(UiKit.body_font(), Vector2(0, 34), "%s %d" % [Texts.ATK, _power], HORIZONTAL_ALIGNMENT_CENTER, W, 15, _color.lightened(0.3))
	var bar := Rect2(10, 40, W - 20, 16)
	draw_rect(bar.grow(3), Color(0.05, 0.04, 0.04, 0.9))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _shown_hp / 100.0, bar.size.y)), Color(0.85, 0.2, 0.15))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _hp / 100.0, bar.size.y)), _color)
	draw_rect(bar.grow(3), UiKit.PANEL_BORDER, false, 2.0)
