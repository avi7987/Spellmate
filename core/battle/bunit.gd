class_name BUnit
extends RefCounted
## Anything that fights in a real-time battle: a hero, the king, a gate, a tower
## or a magic wall. Positions are in squares (x, y), y = 0 at the Sun's edge.

var id: int = 0
var kind: String = ""        ## hero id ("soldier", "dragon"...) or "gate" / "tower" / "wall"
var team: int = 0
var pos := Vector2.ZERO
var hp: float = 100.0
var max_hp: float = 100.0
var dmg: float = 10.0
var rate: float = 1.0
var range_: float = 1.2
var speed: float = 1.5
var level: int = 1
var structure := false
var flying := false
var data: Dictionary = {}

## Orders: "" (idle), "move" (walk to order_pos, fighting on the way) or "attack" (a target).
var order := ""
var order_pos := Vector2.ZERO
var target_id := -1
var path: Array = []           ## remaining squares to walk (Vector2)
var repath_at := 0.0
var attack_ready_at := 0.0
var ability_ready_at := 0.0
var expires_at := -1.0         ## magic walls disappear
## Effects: name -> time it ends (freeze, slow, stun, shield, rage, burn)
var effects: Dictionary = {}
var mine_cell := Vector2i(-1, -1)
var mine_timer := 0.0
var facing := Vector2(0, 1)


func has_effect(name: String, now: float) -> bool:
	return effects.has(name) and float(effects[name]) > now


func can_act(now: float) -> bool:
	return not has_effect("freeze", now) and not has_effect("stun", now)


func role() -> String:
	return data.get("role", "")


func cell() -> Vector2i:
	return Vector2i(roundi(pos.x), roundi(pos.y))
