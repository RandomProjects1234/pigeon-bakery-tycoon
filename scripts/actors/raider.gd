class_name Raider
extends Node3D
## A Crow Clan raider. Flies in, lands next to something valuable (a stocked
## shelf, the till's cash pile, a machine tray, or the office safe = your
## wallet), pecks at it for a moment, grabs the loot and flies off with it.
## Hit it (walk into it, guards, slingshots) and it drops everything.

enum S { FLY_IN, STEAL, FLEE, DEAD }

const STEAL_TIME := 1.8

var world: Node = null
var rig: PigeonRig
var pile: ItemPile
var boss := false
var hp := 1
var max_hp := 1
var state := S.FLY_IN
var target: Node = null
var target_kind := ""       # "shelf", "cash", "wallet", "machine"
var loot_money := 0
var loot_from: CashPile = null
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 0.0
var _dur := 2.4
var _steal := 0.0
var _knock := Vector3.ZERO
var _flash := 0.0
var _hp_bar: Sprite3D
var _hp_fill: Sprite3D
var _mark: Label3D


func setup(w: Node, is_boss: bool, tgt: Node, kind: String, spawn_dir: Vector3) -> void:
	world = w
	boss = is_boss
	target = tgt
	target_kind = kind
	max_hp = 5 if boss else 1
	hp = max_hp
	rig = PigeonRig.new("crow_boss" if boss else "crow")
	rig.scale = Vector3.ONE * (1.45 if boss else 1.0)
	add_child(rig)
	pile = ItemPile.new()
	pile.position = Vector3(0, 0.8 * rig.scale.y, 0.14)
	pile.scale = Vector3.ONE * 0.55
	pile.capacity = 20
	add_child(pile)
	_to = _landing_spot() + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
	_from = _to + spawn_dir * randf_range(20.0, 26.0) + Vector3(randf_range(-4, 4), 15, randf_range(-4, 4))
	_dur = randf_range(2.2, 3.0)
	global_position = _from
	if boss:
		_build_hp_bar()
	_mark = Fx.label3d("!", 130 if boss else 105, Color(1, 0.25, 0.2), 22)
	_mark.no_depth_test = true
	_mark.render_priority = 8
	_mark.position = Vector3(0, 2.6 if boss else 1.7, 0)
	add_child(_mark)


func _build_hp_bar() -> void:
	_hp_bar = Sprite3D.new()
	_hp_bar.texture = Items.icon("fx_fill")
	_hp_bar.modulate = Color(0.15, 0.1, 0.15, 0.8)
	_hp_bar.pixel_size = 0.009
	_hp_bar.scale = Vector3(1.2, 0.22, 1)
	_hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.no_depth_test = true
	_hp_bar.render_priority = 5
	_hp_bar.position = Vector3(0, 2.2, 0)
	add_child(_hp_bar)
	_hp_fill = Sprite3D.new()
	_hp_fill.texture = Items.icon("fx_fill")
	_hp_fill.modulate = Color(1.0, 0.3, 0.3)
	_hp_fill.pixel_size = 0.009
	_hp_fill.scale = Vector3(1.1, 0.16, 1)
	_hp_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_fill.no_depth_test = true
	_hp_fill.render_priority = 6
	_hp_fill.position = Vector3(0, 2.2, 0.01)
	add_child(_hp_fill)


func _landing_spot() -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3(randf_range(-10, 10), 0, randf_range(-6, 4))
	match target_kind:
		"shelf":
			return (target as Shelf).global_position + Vector3(randf_range(-1.0, 1.0), 0, -1.2)
		"cash":
			return (target as CashPile).global_position + Vector3(0.9, 0, 0.6)
		"wallet":
			return (target as Office).pad_pos("desk") + Vector3(0, 0, 0.3)
		"machine":
			return (target as Machine).pad_pos("out") + Vector3(0.2, 0, 0.4)
	return (target as Node3D).global_position


## Can be hit right now (on or near the ground).
func hittable() -> bool:
	if state == S.DEAD:
		return false
	return global_position.y < 2.2


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if _knock.length() > 0.01:
		global_position += _knock * delta
		_knock = _knock.move_toward(Vector3.ZERO, delta * 12.0)
	match state:
		S.FLY_IN:
			_t = minf(1.0, _t + delta / _dur)
			var e := 1.0 - pow(1.0 - _t, 2.0)
			var p := _from.lerp(_to, e) + Vector3(0, sin(_t * PI) * 2.5, 0)
			var d := p - global_position
			global_position = p
			if Vector2(d.x, d.z).length() > 0.001:
				rotation.y = atan2(-d.x, -d.z)
			rig.animate(delta, 0.0, "fly")
			if _t >= 1.0:
				state = S.STEAL
				_steal = 0.0
				if randf() < 0.5:
					Sfx.play("caw", -10.0, randf_range(0.9, 1.2), 0.3)
		S.STEAL:
			global_position.y = 0.0
			rig.animate(delta, 0.0, "peck")
			_steal += delta
			if _steal >= STEAL_TIME:
				_grab()
				_flee()
		S.FLEE:
			_t = minf(1.0, _t + delta / _dur)
			global_position = _from.lerp(_to, _t * _t)
			rig.animate(delta, 0.0, "fly")
			if _t >= 1.0:
				_escaped()
		S.DEAD:
			pass
	_mark.visible = state != S.DEAD
	_mark.position.y = (2.6 if boss else 1.7) + sin(Time.get_ticks_msec() / 120.0) * 0.08
	if _hp_fill != null:
		_hp_fill.scale.x = 1.1 * float(hp) / float(max_hp)
		_hp_bar.visible = state != S.DEAD
		_hp_fill.visible = state != S.DEAD
	rig.scale = Vector3.ONE * (1.45 if boss else 1.0) * (1.0 + _flash * 0.6)


func _grab() -> void:
	if target == null or not is_instance_valid(target):
		return
	var take := 6 if boss else 3
	match target_kind:
		"shelf":
			var sh := target as Shelf
			for i in take:
				if sh.stock() <= 0:
					break
				sh.display.give_to(pile, sh.product, 0.3, 0.5)
		"machine":
			var m := target as Machine
			for i in take:
				if m.out_pile.count() <= 0:
					break
				m.out_pile.give_to(pile, m.output, 0.3, 0.5)
		"cash":
			var c := target as CashPile
			var amt := mini(c.value, int(ceil(c.value * (0.6 if boss else 0.35))) + 5)
			if amt > 0:
				c.value -= amt
				loot_money = amt
				loot_from = c
				for i in mini(4, c.visual.count()):
					var bill := c.visual.take()
					if bill != null:
						pile.add_node(bill, "cash", 0.3, 0.5)
		"wallet":
			var cap := (400 if boss else 150) + 60 * int(Game.stats["raids"])
			var amt2 := mini(Game.money, mini(cap, int(Game.money * (0.08 if boss else 0.04)) + 10))
			if amt2 > 0:
				Game.add_money(-amt2)
				loot_money = amt2
				for i in 3:
					pile.add_new("cash", global_position + Vector3(0, 0.6, 0), 0.3, 0.5)
				Fx.float_text(global_position + Vector3(0, 2.0, 0), "-$" + Game.fmt(amt2), Color(1, 0.4, 0.35), 64)
	if pile.count() > 0 or loot_money > 0:
		Sfx.play("caw", -6.0, randf_range(1.0, 1.2), 0.2)


func _flee() -> void:
	state = S.FLEE
	_t = 0.0
	_dur = 2.2
	_from = global_position
	var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_to = global_position + dir * 24.0 + Vector3(0, 16, 0)
	rotation.y = atan2(-dir.x, -dir.z)


## Damage from the player, a guard or a slingshot. Returns true if it died.
func hit(dmg: int, from_pos: Vector3) -> bool:
	if not hittable():
		return false
	hp -= dmg
	_flash = 0.25
	var away := Vector3(global_position.x - from_pos.x, 0, global_position.z - from_pos.z)
	if away.length() < 0.01:
		away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	_knock = away.normalized() * (4.0 if not boss else 2.0)
	Sfx.play("bonk", -3.0, randf_range(0.9, 1.15), 0.04)
	Fx.poof(global_position + Vector3(0, 0.5, 0), Color(0.15, 0.15, 0.2), 6, 0.12)
	if hp > 0:
		return false
	_die()
	return true


func _die() -> void:
	state = S.DEAD
	Game.stats["crows_beaten"] = int(Game.stats["crows_beaten"]) + 1
	var bounty := (60 if boss else 12) + 4 * int(Game.stats["raids"])
	Fx.poof(global_position + Vector3(0, 0.6, 0), Color(0.12, 0.12, 0.16), 18, 0.2)
	Fx.float_text(global_position + Vector3(0, 1.8, 0), "+$%d" % bounty, Color(1, 0.9, 0.3), 60)
	Game.add_money(bounty)
	# drop the loot: money comes back, items go back where they came from
	if loot_money > 0:
		if loot_from != null and is_instance_valid(loot_from):
			loot_from.value += loot_money
		else:
			Game.add_money(loot_money)
		Fx.float_text(global_position + Vector3(0, 2.5, 0), "Recovered $" + Game.fmt(loot_money), Color(0.6, 1.0, 0.5), 50)
		loot_money = 0
	for i in pile.count():
		var n := pile.take()
		if n == null:
			break
		var back: ItemPile = null
		if target_kind == "shelf" and is_instance_valid(target):
			back = (target as Shelf).display
		elif target_kind == "machine" and is_instance_valid(target):
			back = (target as Machine).out_pile
		elif target_kind == "cash" and loot_from != null and is_instance_valid(loot_from):
			back = loot_from.visual
		var t := str(n.name)
		if back != null and not back.is_full():
			back.add_node(n, _type_of(t), 0.35, 0.8)
		else:
			ItemPile.fly_away(n, global_position + Vector3(0, 0.1, 0), 0.3, 0.6)
	if world != null:
		world.call("raider_gone", self, false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.05, 1.3), 0.18)
	tw.tween_callback(queue_free)


func _type_of(node_name: String) -> String:
	for t in Items.DEF:
		if node_name.begins_with(str(t)):
			return str(t)
	return "cash"


func _escaped() -> void:
	Game.stats["stolen"] = int(Game.stats["stolen"]) + loot_money
	Game.stats["stolen_items"] = int(Game.stats.get("stolen_items", 0)) + pile.count()
	if world != null:
		world.call("raider_gone", self, true)
	queue_free()
