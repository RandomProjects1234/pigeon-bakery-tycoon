class_name Crow
extends Node3D
## A thief. Lands on a stocked shelf and starts pinching items. Walk up to it
## to scare it off: it drops everything it stole back on the shelf.

enum S { FLY_IN, STEAL, FLEE }

const SCARE_R := 2.8

var world: Node = null
var rig: PigeonRig
var pile: ItemPile
var shelf: Shelf
var state := S.FLY_IN
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 0.0
var _dur := 2.2
var _steal := 0.0
var stolen := 0
var scared := false
var _caw_t := 0.0


func setup(w: Node, s: Shelf) -> void:
	world = w
	shelf = s
	rig = PigeonRig.new("crow")
	rig.scale = Vector3.ONE * 1.05
	add_child(rig)
	pile = ItemPile.new()
	pile.position = Vector3(0, 0.82, 0.14)
	pile.scale = Vector3.ONE * 0.55
	pile.capacity = 10
	add_child(pile)
	_to = s.global_position + Vector3(randf_range(-0.8, 0.8), 0.9, 0.05)
	_from = _to + Vector3(randf_range(-12, 12), 16, -20)
	global_position = _from
	Sfx.play("caw", -6.0, randf_range(0.9, 1.05))


func _process(delta: float) -> void:
	match state:
		S.FLY_IN:
			_t = minf(1.0, _t + delta / _dur)
			var e := 1.0 - pow(1.0 - _t, 2.0)
			var p := _from.lerp(_to, e) + Vector3(0, sin(_t * PI) * 2.0, 0)
			var d := p - global_position
			global_position = p
			if Vector2(d.x, d.z).length() > 0.001:
				rotation.y = atan2(-d.x, -d.z)
			rig.animate(delta, 0.0, "fly")
			if _t >= 1.0:
				state = S.STEAL
				rotation.y = PI
		S.STEAL:
			rig.animate(delta, 0.0, "peck")
			_steal += delta
			_caw_t -= delta
			if _caw_t <= 0.0:
				_caw_t = randf_range(2.5, 4.0)
				Sfx.play("caw", -12.0, randf_range(0.95, 1.1), 0.5)
			if _steal >= 1.8:
				_steal = 0.0
				if shelf.stock() > 0 and stolen < 4:
					shelf.display.give_to(pile, shelf.product, 0.3, 0.5)
					stolen += 1
				else:
					_flee(false)
		S.FLEE:
			_t = minf(1.0, _t + delta / _dur)
			global_position = _from.lerp(_to, _t * _t)
			rig.animate(delta, 0.0, "fly")
			if _t >= 1.0:
				if world != null:
					world.call("crow_gone", self)
				queue_free()


## True when the player is close enough to scare it (called by the world).
func try_scare(player_pos: Vector3) -> bool:
	if state == S.FLEE:
		return false
	if state == S.FLY_IN and _t < 0.6:
		return false
	var d := Vector2(player_pos.x - global_position.x, player_pos.z - global_position.z)
	if d.length() > SCARE_R:
		return false
	_flee(true)
	return true


func _flee(by_player: bool) -> void:
	if state == S.FLEE:
		return
	scared = by_player
	if by_player:
		Sfx.play("caw", -3.0, 1.2)
		Sfx.play("flap", -6.0)
		Fx.float_text(global_position + Vector3(0, 1.6, 0), "CAW!", Color(1, 1, 1), 70)
		Fx.poof(global_position + Vector3(0, 0.5, 0), Color(0.2, 0.2, 0.25), 10, 0.18)
		# drop the loot back on the shelf
		while pile.count() > 0 and not shelf.display.is_full():
			pile.give_to(shelf.display, shelf.product, 0.35, 0.6)
	state = S.FLEE
	_t = 0.0
	_dur = 2.0
	_from = global_position
	_to = global_position + Vector3(randf_range(-10, 10), 16, -22)
	rotation.y = atan2(-(_to.x - _from.x), -(_to.z - _from.z))
