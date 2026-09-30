class_name WarCrow
extends Node3D
## Crow Clan soldier in the Crow War at the HQ tower.
##   bomber   - flies over the tower in passes, dropping poop bombs
##   commando - lands and pecks at the tower
##   heavy    - armoured commando, lots of health, pecks hard
##   warlord  - boss: circles above the tower dropping mega poop
##   king     - the Crow King, final boss: mega poop + calls in reinforcements

var war: Node = null
var hq_center := Vector3.ZERO
var kind := "commando"
var rig: PigeonRig
var hp := 3.0
var max_hp := 3.0
var dead := false
var speed := 2.5
var _state := "fly_in"
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 0.0
var _dur := 2.5
var _passes := 0
var _bomb_t := 0.0
var _peck_t := 0.0
var _orbit := 0.0
var _slow := 0.0
var _flash := 0.0
var _summon_t := 6.0
var _bar: Sprite3D
var _mark: Label3D
var wave := 1


func setup(w: Node, center: Vector3, k: String, n: int) -> void:
	war = w
	hq_center = center
	kind = k
	wave = n
	var variant := "crow"
	var sc := 1.0
	match kind:
		"bomber":
			variant = "crow_bomber"
			max_hp = 3.0 + 0.8 * n
			speed = 5.0
		"commando":
			max_hp = 4.0 + 1.2 * n
			speed = 2.6
		"heavy":
			variant = "crow_heavy"
			max_hp = 25.0 + 4.0 * n
			speed = 1.7
			sc = 1.5
		"warlord":
			variant = "crow_boss"
			max_hp = 200.0 + 40.0 * n
			speed = 3.0
			sc = 2.4
		"king":
			variant = "crow_king"
			max_hp = 3000.0
			speed = 2.5
			sc = 4.0
	hp = max_hp
	rig = PigeonRig.new(variant)
	rig.scale = Vector3.ONE * sc
	add_child(rig)
	_orbit = randf() * TAU
	var ang := randf() * TAU
	var dir := Vector3(cos(ang), 0, sin(ang))
	match kind:
		"bomber":
			_start_pass(dir)
		"warlord", "king":
			_from = center + dir * 45.0 + Vector3(0, 16, 0)
			_to = center + Vector3(cos(_orbit), 0, sin(_orbit)) * 6.0 + Vector3(0, 9.0 if kind == "warlord" else 11.0, 0)
			_dur = 4.0
			global_position = _from
		_:
			_from = center + dir * 42.0 + Vector3(0, 14, 0)
			_to = center + dir * randf_range(20.0, 25.0)
			_dur = randf_range(2.5, 3.5)
			global_position = _from
	if kind in ["heavy", "warlord", "king"]:
		_bar = Sprite3D.new()
		_bar.texture = Items.icon("fx_fill")
		_bar.modulate = Color(1, 0.3, 0.3)
		_bar.pixel_size = 0.009
		_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bar.no_depth_test = true
		_bar.render_priority = 6
		_bar.position = Vector3(0, 1.3 * sc + 0.4, 0)
		add_child(_bar)
	if kind != "bomber":
		_mark = Fx.label3d("!", 110, Color(1, 0.25, 0.2), 22)
		_mark.no_depth_test = true
		_mark.render_priority = 8
		_mark.position = Vector3(0, 1.2 * sc + 0.9, 0)
		add_child(_mark)


func _start_pass(dir: Vector3) -> void:
	var side := Vector3(-dir.z, 0, dir.x) * randf_range(-5.0, 5.0)
	_from = hq_center + dir * 40.0 + side + Vector3(0, 8, 0)
	_to = hq_center - dir * 40.0 + side + Vector3(0, 8, 0)
	_dur = _from.distance_to(_to) / speed
	_t = 0.0
	global_position = _from
	_state = "pass"


func is_air() -> bool:
	return global_position.y > 2.5


func hittable() -> bool:
	return not dead


func _process(delta: float) -> void:
	if dead:
		return
	_flash = maxf(0.0, _flash - delta)
	_slow = maxf(0.0, _slow - delta)
	var spd_k := 0.5 if _slow > 0.0 else 1.0
	match _state:
		"fly_in":
			_t = minf(1.0, _t + delta * spd_k / _dur)
			var e := 1.0 - pow(1.0 - _t, 2.0)
			var p := _from.lerp(_to, e)
			_face(p - global_position, delta)
			global_position = p
			rig.animate(delta, 0.0, "fly")
			if _t >= 1.0:
				_state = "hover" if kind in ["warlord", "king"] else "walk"
		"pass":
			_t = minf(1.0, _t + delta * spd_k / _dur)
			var p2 := _from.lerp(_to, _t)
			_face(p2 - global_position, delta)
			global_position = p2
			rig.animate(delta, 0.0, "fly")
			_bomb_t -= delta
			var flat := Vector2(global_position.x - hq_center.x, global_position.z - hq_center.z).length()
			if _bomb_t <= 0.0 and flat < 13.0:
				_bomb_t = 1.1
				war.call("drop_bomb", global_position, false)
			if _t >= 1.0:
				_passes += 1
				if _passes >= 2:
					war.call("enemy_gone", self, true)
					queue_free()
					return
				# turn around and make another pass the other way
				var fwd := _to - _from
				fwd.y = 0
				_start_pass(fwd.normalized())
		"walk":
			var to := Vector3(hq_center.x - global_position.x, 0, hq_center.z - global_position.z)
			var d := to.length()
			if d > 4.8:
				var dir := to / d
				global_position += dir * speed * spd_k * delta
				global_position.y = 0.0
				_face(dir, delta)
				rig.animate(delta, speed, "walk")
			else:
				rig.animate(delta, 0.0, "peck")
				_peck_t -= delta
				if _peck_t <= 0.0:
					_peck_t = 0.5
					var dps := (14.0 + wave) if kind == "heavy" else (5.0 + wave * 0.5)
					war.call("damage_hq", dps * 0.5, global_position)
		"hover":
			_orbit += delta * 0.35 * spd_k
			var r := 6.0 if kind == "warlord" else 8.0
			var target := hq_center + Vector3(cos(_orbit) * r, 9.0 if kind == "warlord" else 11.0, sin(_orbit) * r)
			var mv := target - global_position
			global_position += mv * minf(1.0, delta * 2.0)
			_face(Vector3(-sin(_orbit), 0, cos(_orbit)), delta)
			rig.animate(delta, 0.0, "fly")
			_bomb_t -= delta
			if _bomb_t <= 0.0:
				_bomb_t = 2.0 if kind == "warlord" else 1.4
				war.call("drop_bomb", global_position, true)
			if kind == "king":
				_summon_t -= delta
				if _summon_t <= 0.0:
					_summon_t = 9.0
					war.call("summon", 3)
	if _bar != null:
		_bar.scale = Vector3(1.6 * hp / max_hp, 0.18, 1)
	if _mark != null:
		_mark.position.y = 1.2 * rig.scale.y + 0.9 + sin(Time.get_ticks_msec() / 120.0) * 0.08


func _face(dir: Vector3, delta: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 8.0, 0.0, 1.0))


func slow(secs: float) -> void:
	_slow = maxf(_slow, secs)


## Returns true when this hit killed it.
func hit(dmg: float, from_pos: Vector3) -> bool:
	if dead:
		return false
	hp -= dmg
	_flash = 0.2
	if not is_air() and kind != "heavy":
		var away := Vector3(global_position.x - from_pos.x, 0, global_position.z - from_pos.z)
		if away.length() > 0.01:
			global_position += away.normalized() * 0.35
	Fx.poof(global_position + Vector3(0, 0.5 * rig.scale.y, 0), Color(0.15, 0.15, 0.2), 4, 0.1 * rig.scale.y)
	if hp > 0.0:
		return false
	dead = true
	var bounty := int(max_hp * 220.0)
	Game.add_money(bounty)
	Fx.float_text(global_position + Vector3(0, 1.5 * rig.scale.y, 0), "+$" + Game.fmt(bounty), Color(1, 0.9, 0.3), 60)
	Fx.poof(global_position + Vector3(0, 0.6 * rig.scale.y, 0), Color(0.1, 0.1, 0.14), 16, 0.2 * rig.scale.y)
	Sfx.play("caw", -6.0, randf_range(1.1, 1.4), 0.05)
	war.call("enemy_gone", self, false)
	var tw := create_tween()
	if is_air():
		tw.tween_property(self, "global_position", Vector3(global_position.x, 0.1, global_position.z), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector3(1.3, 0.05, 1.3), 0.2)
	tw.tween_callback(queue_free)
	return true
