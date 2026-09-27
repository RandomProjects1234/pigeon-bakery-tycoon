class_name Carrier
extends CharacterBody3D
## Anything that walks around carrying a stack: the player and the staff.
## Stations call wants_pick / wants_drop so staff only touch their own job.

var pile: ItemPile
var rig: HumanRig
var is_player := false
var role := "owner"
var world: Node = null
var _sway := Vector2.ZERO
var _sway_v := Vector2.ZERO
var _last_vel := Vector3.ZERO


func setup_pile(local_pos: Vector3) -> void:
	pile = ItemPile.new()
	pile.name = "Stack"
	pile.jitter = 0.12
	pile.capacity = capacity()
	pile.position = local_pos
	add_child(pile)


func capacity() -> int:
	return 6


func interval() -> float:
	return 0.09


func wants_pick(_st: Node, _pad: String, _t: String) -> bool:
	return pile.room() > 0


func wants_drop(_st: Node, _pad: String, _t: String) -> bool:
	return true


func is_cashier() -> bool:
	return is_player


func planar() -> Vector3:
	return Vector3(global_position.x, 0, global_position.z)


## Leans the carried stack against the direction of acceleration, springy.
func update_sway(delta: float, vel: Vector3) -> void:
	var local_v := global_transform.basis.inverse() * vel
	var acc := (local_v - _last_vel) / maxf(delta, 0.001)
	_last_vel = local_v
	var target := Vector2(clampf(acc.z * 0.012, -0.3, 0.3), clampf(-acc.x * 0.012, -0.3, 0.3))
	# spring toward target
	var k := 120.0
	var damp := 12.0
	_sway_v += (target - _sway) * k * delta - _sway_v * damp * delta
	_sway += _sway_v * delta
	var h := clampf(pile.count() / 12.0, 0.2, 1.0)
	pile.rotation.x = _sway.x * h
	pile.rotation.z = _sway.y * h
