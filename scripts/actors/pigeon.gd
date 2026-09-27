class_name Pigeon
extends Node3D
## A customer. Flies in, queues behind a shelf until it has its order, queues
## at the till to pay, maybe sits at a cafe table to eat (leaving a tip and
## crumbs), then flies off. Carries its shopping stacked on its back.

enum S { FLY_IN, TO_SHELF, TO_REG, TO_SEAT, EAT, LEAVE }

const WALK_SPEED := 2.3
const GIVE_UP := 70.0

var world: Node = null
var rig: PigeonRig
var pile: ItemPile
var want := "bread"
var qty := 1
var got := 0
var vip := false
var paid := 0
var state := S.FLY_IN
var shelf: Shelf
var reg: Register
var table: CafeTable
var seat := -1

var _path := PackedVector3Array()
var _pi := 0
var _goal := Vector3.INF
var _arrived := false
var _t := 0.0
var _wait := 0.0
var _take := 0.0
var _eat := 0.0
var _fly_from := Vector3.ZERO
var _fly_mid := Vector3.ZERO
var _fly_to := Vector3.ZERO
var _fly_dur := 2.0
var _fly_t := 0.0
var _moving := false
var _face_yaw := 0.0

var _bubble: Node3D
var _bubble_bg: Sprite3D
var _bubble_icon: Sprite3D
var _bubble_count: Label3D


func setup(w: Node, s: Shelf, r: Register, amount: int, is_vip: bool) -> void:
	world = w
	shelf = s
	reg = r
	want = s.product
	qty = amount
	vip = is_vip
	var variant := "std"
	var roll := randf()
	if vip:
		variant = "vip"
	elif roll < 0.2:
		variant = "dark"
	elif roll < 0.38:
		variant = "light"
	rig = PigeonRig.new(variant)
	add_child(rig)
	var sc := randf_range(0.92, 1.08) * (1.12 if vip else 1.0)
	rig.scale = Vector3.ONE * sc
	pile = ItemPile.new()
	pile.position = Vector3(0, 0.78 * sc, 0.12)
	pile.scale = Vector3.ONE * 0.6
	pile.capacity = 99
	pile.jitter = 0.2
	add_child(pile)
	_build_bubble()
	shelf.join(self)
	var land := shelf.queue_slot(shelf.index_of(self)) + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-0.6, 0.6))
	var dir := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, -0.3)).normalized()
	_start_flight(land + dir * 22.0 + Vector3(0, 14, 0), land, 2.4)
	state = S.FLY_IN
	_update_bubble()


func _build_bubble() -> void:
	_bubble = Node3D.new()
	_bubble.position = Vector3(0, 1.7, 0)
	add_child(_bubble)
	_bubble_bg = Sprite3D.new()
	_bubble_bg.texture = Items.icon("fx_bubble")
	_bubble_bg.pixel_size = 0.0068
	_bubble_bg.shaded = false
	_bubble_bg.render_priority = 4
	_bubble_bg.no_depth_test = true
	_bubble.add_child(_bubble_bg)
	_bubble_icon = Sprite3D.new()
	_bubble_icon.pixel_size = 0.0042
	_bubble_icon.position = Vector3(-0.08, 0.07, 0.01)
	_bubble_icon.shaded = false
	_bubble_icon.render_priority = 5
	_bubble_icon.no_depth_test = true
	_bubble.add_child(_bubble_icon)
	_bubble_count = Fx.label3d("", 40, Color(0.2, 0.18, 0.25), 0)
	_bubble_count.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_bubble_count.position = Vector3(0.24, 0.05, 0.02)
	_bubble_count.render_priority = 6
	_bubble_count.no_depth_test = true
	_bubble.add_child(_bubble_count)


func _update_bubble() -> void:
	match state:
		S.FLY_IN, S.TO_SHELF:
			_bubble.visible = true
			_bubble_icon.texture = Items.icon(want)
			_bubble_icon.position.x = -0.08
			_bubble_count.text = str(qty - got)
		S.TO_REG:
			_bubble.visible = true
			_bubble_icon.texture = Items.icon("ui_coin")
			_bubble_icon.position.x = 0.0
			_bubble_count.text = ""
		_:
			_bubble.visible = false


func _start_flight(from: Vector3, to: Vector3, dur: float) -> void:
	_fly_from = from
	_fly_to = to
	_fly_mid = (from + to) * 0.5 + Vector3(0, 2.5, 0)
	_fly_dur = dur
	_fly_t = 0.0
	global_position = from


func _fly(delta: float) -> bool:
	_fly_t = minf(1.0, _fly_t + delta / _fly_dur)
	var t := _fly_t
	if state == S.FLY_IN:
		t = 1.0 - pow(1.0 - t, 2.0)   # ease out: slow down to land
	else:
		t = t * t
	var a := _fly_from.lerp(_fly_mid, t)
	var b := _fly_mid.lerp(_fly_to, t)
	var p := a.lerp(b, t)
	var d := p - global_position
	global_position = p
	if Vector2(d.x, d.z).length() > 0.001:
		_face(Vector3(d.x, 0, d.z).normalized(), delta, 12.0)
	rig.animate(delta, 0.0, "fly")
	return _fly_t >= 1.0


func _face(dir: Vector3, delta: float, rate := 10.0) -> void:
	_face_yaw = atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, _face_yaw, clampf(delta * rate, 0.0, 1.0))


func _go(p: Vector3) -> void:
	if _goal != Vector3.INF and _goal.distance_squared_to(p) < 0.04:
		return
	_goal = p
	_path = (world.get("nav") as NavGrid).path(global_position, p)
	_pi = 0
	_arrived = false


func _walk(delta: float) -> bool:
	if _pi >= _path.size():
		_arrived = true
		_moving = false
		return true
	var target := _path[_pi]
	var to := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var d := to.length()
	var step := WALK_SPEED * delta
	_moving = true
	if d <= step:
		global_position = Vector3(target.x, 0, target.z)
		_pi += 1
		if _pi >= _path.size():
			_arrived = true
			_moving = false
			return true
		return false
	var dir := to / d
	global_position += dir * step
	_face(dir, delta)
	return false


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam != null and _bubble.visible:
		_bubble.global_basis = cam.global_basis
		_bubble.position.y = 1.7 + sin(_t * 3.0 + float(get_instance_id() % 7)) * 0.04
	match state:
		S.FLY_IN:
			if _fly(delta):
				state = S.TO_SHELF
				_goal = Vector3.INF
				if randf() < 0.35:
					Sfx.coo(-10.0)
		S.TO_SHELF:
			_state_shelf(delta)
		S.TO_REG:
			_state_reg(delta)
		S.TO_SEAT:
			_go(table.seat_pos(seat))
			if _walk(delta):
				_face((table.global_position - global_position).normalized(), delta)
				state = S.EAT
				_eat = randf_range(4.0, 6.0)
			rig.animate(delta, WALK_SPEED if _moving else 0.0, "walk" if _moving else "idle")
		S.EAT:
			_state_eat(delta)
		S.LEAVE:
			if _fly(delta):
				_despawn()


func _state_shelf(delta: float) -> void:
	var idx := shelf.index_of(self)
	if idx < 0:
		_leave_now()
		return
	_go(shelf.queue_slot(idx))
	_walk(delta)
	_bubble.visible = idx < 3
	if _arrived:
		_face(Vector3(0, 0, 1), delta, 6.0)
		if idx == 0:
			_take += delta
			if _take >= 0.28 and shelf.stock() > 0:
				_take = 0.0
				shelf.display.give_to(pile, want, 0.3, 0.6)
				got += 1
				_wait = maxf(0.0, _wait - 4.0)
				Sfx.play("pop", -12.0, 1.3, 0.05)
				_update_bubble()
				if got >= qty:
					shelf.leave(self)
					reg.join(self)
					state = S.TO_REG
					_goal = Vector3.INF
					_update_bubble()
					return
		_wait += delta
		_update_patience()
		if _wait > GIVE_UP and Game.tut >= 9:
			shelf.leave(self)
			Fx.float_text(global_position + Vector3(0, 2.0, 0), "too slow!", Color(1, 0.55, 0.5), 48)
			_leave_now()
			return
	rig.animate(delta, WALK_SPEED if _moving else 0.0, "walk" if _moving else "idle")


func _update_patience() -> void:
	var k := clampf((_wait - 25.0) / 40.0, 0.0, 1.0)
	_bubble_bg.modulate = Color(1, 1, 1).lerp(Color(1, 0.55, 0.5), k)


func _state_reg(delta: float) -> void:
	var idx := reg.index_of(self)
	if idx < 0:
		_leave_now()
		return
	_go(reg.queue_slot(idx))
	_walk(delta)
	_bubble.visible = idx < 2
	if _arrived:
		_face(Vector3(0, 0, 1), delta, 6.0)
	rig.animate(delta, WALK_SPEED if _moving else 0.0, "walk" if _moving else "idle")


func ready_to_pay() -> bool:
	return state == S.TO_REG and _arrived and reg.index_of(self) == 0


## Called by the register. Returns the money handed over.
func pay() -> int:
	var price := Items.price(want) * qty
	var amount := int(round(price * Game.profit_mult() * (3.0 if vip else 1.0)))
	if _wait < 20.0:
		amount += int(round(price * 0.1))   # quick service tip
	paid = amount
	reg.leave(self)
	_bubble_bg.modulate = Color(1, 1, 1)
	if randf() < 0.5:
		Sfx.coo(-9.0)
	Fx.float_text(global_position + Vector3(0, 2.1, 0), "+$" + Game.fmt(amount), Color(0.6, 1.0, 0.5), 56, 1.0, 0.9)
	# find a seat?
	var spot: Array = world.call("find_seat")
	if spot.size() == 2 and randf() < 0.8:
		table = spot[0]
		seat = int(spot[1])
		table.reserve(seat, self)
		state = S.TO_SEAT
		_goal = Vector3.INF
	else:
		_leave_now()
	_update_bubble()
	return amount


func _state_eat(delta: float) -> void:
	_eat -= delta
	rig.animate(delta, 0.0, "peck")
	var eaten_frac := 1.0 - clampf(_eat / 5.0, 0.0, 1.0)
	var should_have_left := int(ceil(float(qty) * (1.0 - eaten_frac)))
	while pile.count() > should_have_left and pile.count() > 0:
		var n := pile.take()
		if n != null:
			ItemPile.fly_away(n, table.global_position + Vector3(0, 0.85, 0), 0.3, 0.3)
			Sfx.play("nom", -14.0, randf_range(0.9, 1.2), 0.2)
	if _eat <= 0.0:
		var tip := int(round(paid * randf_range(0.15, 0.3)))
		table.release(seat, tip, global_position + Vector3(0, 1.0, 0))
		table = null
		Fx.float_text(global_position + Vector3(0, 1.9, 0), "yum!", Color(1, 0.8, 0.9), 44, 0.8, 0.8)
		_leave_now()


func _leave_now() -> void:
	if shelf != null:
		shelf.leave(self)
	if reg != null:
		reg.leave(self)
	if table != null and seat >= 0:
		table.seats[seat]["occ"] = null
		table = null
	state = S.LEAVE
	_update_bubble()
	var dir := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 0.2)).normalized()
	_start_flight(global_position, global_position + dir * 24.0 + Vector3(0, 15, 0), 2.6)
	if randf() < 0.3:
		Sfx.play("flap", -14.0, randf_range(0.9, 1.1), 0.2)


func _despawn() -> void:
	if world != null:
		world.call("pigeon_gone", self)
	queue_free()
