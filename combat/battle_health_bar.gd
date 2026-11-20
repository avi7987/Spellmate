class_name BattleHealthBar
extends Control
## A health bar that floats above a fighter in the battle arena: the
## character's name, its damage, and its health.

const W := 240.0
const H := 66.0

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


func damage(amount: float) -> void:
	_hp = maxf(0.0, _hp - amount)


func set_hp(value: float) -> void:
	_hp = value
	_shown_hp = value


func _process(delta: float) -> void:
	if target != null and cam != null and is_instance_valid(target):
		var head := target.global_position + Vector3(0, 3.4, 0)
		position = cam.unproject_position(head) - Vector2(W / 2.0, H)
	_shown_hp = move_toward(_shown_hp, _hp, delta * 120.0)
	queue_redraw()


func _draw() -> void:
	UiKit.draw_text_outlined(self, Vector2(0, 22), _name, W, 24, Color.WHITE, 6)
	UiKit.draw_text_outlined(self, Vector2(0, 40), "נזק %d" % _power, W, 15, _color.lightened(0.3), 4, HORIZONTAL_ALIGNMENT_CENTER, 600)
	var bar := Rect2(12, 46, W - 24, 16)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.08, 0.9)
	bg.border_color = UiKit.PANEL_EDGE
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(8)
	draw_style_box(bg, bar.grow(3))
	var loss := StyleBoxFlat.new()
	loss.bg_color = Color(0.95, 0.25, 0.2)
	loss.set_corner_radius_all(6)
	draw_style_box(loss, Rect2(bar.position, Vector2(maxf(1.0, bar.size.x * _shown_hp / 100.0), bar.size.y)))
	var fill := StyleBoxFlat.new()
	fill.bg_color = _color
	fill.set_corner_radius_all(6)
	if _hp > 0.5:
		draw_style_box(fill, Rect2(bar.position, Vector2(bar.size.x * _hp / 100.0, bar.size.y)))
