class_name BattleBar
extends Control
## The win-chance bar of a battle. The green part (from the left) is the
## attacker's chance to win; a needle "rolls the dice" and stops on the result:
## inside the green part = the attacker wins.

var chance := 60
var needle := 0.0   ## 0..100
var _spinning := false


func setup(p_chance: int) -> void:
	chance = p_chance
	needle = 0.0
	queue_redraw()


## Sweeps the needle back and forth a few times and stops on `roll`.
func spin_to(roll: int, duration: float) -> void:
	_spinning = true
	var tw := create_tween()
	tw.tween_method(func(t: float):
		# Two fast sweeps, then ease into the result.
		var sweep := absf(sin(t * PI * 2.5)) * 100.0
		needle = lerpf(sweep, roll + 0.5, smoothstep(0.55, 1.0, t))
		queue_redraw(), 0.0, 1.0, duration)
	await tw.finished
	_spinning = false
	needle = roll + 0.5
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(0, 8), Vector2(size.x, size.y - 16))
	var split := r.size.x * chance / 100.0
	draw_rect(Rect2(r.position, Vector2(split, r.size.y)), Color(0.20, 0.55, 0.22))
	draw_rect(Rect2(r.position + Vector2(split, 0), Vector2(r.size.x - split, r.size.y)), Color(0.55, 0.16, 0.12))
	draw_rect(r, UiKit.PANEL_BORDER, false, 2.0)
	var font := UiKit.title_font()
	draw_string(font, r.position + Vector2(8, r.size.y * 0.5 + 8), "%d%%" % chance, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_string(font, r.position + Vector2(r.size.x - 60, r.size.y * 0.5 + 8), "%d%%" % (100 - chance), HORIZONTAL_ALIGNMENT_RIGHT, 52, 20, Color.WHITE)
	var x := r.position.x + r.size.x * needle / 100.0
	draw_colored_polygon(PackedVector2Array([Vector2(x - 9, 0), Vector2(x + 9, 0), Vector2(x, 12)]), UiKit.GOLD)
	draw_line(Vector2(x, 6), Vector2(x, size.y - 4), UiKit.GOLD, 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 9, size.y), Vector2(x + 9, size.y), Vector2(x, size.y - 12)]), UiKit.GOLD)
