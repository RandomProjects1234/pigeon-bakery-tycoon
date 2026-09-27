class_name Worker
extends Carrier
## Hired staff. Farmers harvest one field and feed its machine(s); bakers
## carry one machine's output to its shelf (or next machine); the cashier
## mans the till; the janitor wipes the cafe tables.

enum J { GO_PICK, PICK, GO_DROP, DROP, POST }

var station_id := ""
var home: Node = null
var job := J.GO_PICK
var drop_target: Station = null
var drop_pad := ""
var carry_type := ""
var _path := PackedVector3Array()
var _pi := 0
var _goal := Vector3.INF
var _arrived := false
var _wait := 0.0
var _speed_now := 0.0
var _think := 0.0
var _clean_table: CafeTable = null


func setup(w: Node, r: String, st_id: String, spawn_at: Vector3) -> void:
	world = w
	role = r
	station_id = st_id
	rig = HumanRig.new(role)
	add_child(rig)
	setup_pile(Vector3(0, 0.98, -0.5))
	collision_layer = 0
	collision_mask = 0
	global_position = spawn_at
	home = (world.get("stations") as Dictionary).get(station_id, null)
	if role == "cashier":
		home = world.get("register")
	job = J.GO_PICK if role in ["farmer", "baker"] else J.POST


func capacity() -> int:
	return Game.staff_capacity()


func interval() -> float:
	return 0.15


func wants_pick(st: Node, _pad: String, _t: String) -> bool:
	return st == home and job == J.PICK and pile.room() > 0


func wants_drop(st: Node, _pad: String, _t: String) -> bool:
	return job == J.DROP and st == drop_target


func is_cashier() -> bool:
	return role == "cashier"


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
		_speed_now = 0.0
		return true
	var target := _path[_pi]
	var to := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var d := to.length()
	var spd := Game.staff_speed()
	var step := spd * delta
	_speed_now = spd
	if d <= step:
		global_position = Vector3(target.x, 0, target.z)
		_pi += 1
		if _pi >= _path.size():
			_arrived = true
			_speed_now = 0.0
			return true
		return false
	var dir := to / d
	global_position += dir * step
	velocity = dir * spd
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 12.0, 0.0, 1.0))
	return false


func _face_dir(dir: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 8.0, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	velocity = Vector3.ZERO
	if home == null or not is_instance_valid(home):
		home = (world.get("stations") as Dictionary).get(station_id, null)
		if role == "cashier":
			home = world.get("register")
	match role:
		"farmer":
			_farmer(delta)
		"baker":
			_baker(delta)
		"cashier":
			_cashier(delta)
		"janitor":
			_janitor(delta)
	pile.capacity = capacity()
	rig.carrying = pile.count() > 0
	rig.animate(delta, _speed_now)
	update_sway(delta, velocity)


# ------------------------------------------------------------- farmer ----
func _farmer(delta: float) -> void:
	var field := home as Field
	if field == null:
		return
	match job:
		J.GO_PICK:
			_go(field.global_position + Vector3(0, 0, -1.9))
			_walk(delta)
			if _arrived or field.in_field(global_position):
				job = J.PICK
				_wait = 0.0
		J.PICK:
			if pile.room() <= 0:
				_choose_drop_farmer(field)
				return
			var target := field.nearest_ripe(global_position)
			if target == Vector3.INF:
				_speed_now = 0.0
				_wait += delta
				if pile.count() > 0 and _wait > 1.5:
					_choose_drop_farmer(field)
				return
			_wait = 0.0
			var to := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
			var d := to.length()
			if d > 0.45:
				var spd := Game.staff_speed() * 0.8
				var dir := to / d
				global_position += dir * minf(spd * delta, d)
				velocity = dir * spd
				_speed_now = spd
				rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 12.0, 0.0, 1.0))
			else:
				_speed_now = 0.0
		J.GO_DROP:
			if drop_target == null or not is_instance_valid(drop_target):
				job = J.GO_PICK
				return
			_go(drop_target.pad_pos(drop_pad))
			if _walk(delta):
				job = J.DROP
				_wait = 0.0
		J.DROP:
			_face_dir(Vector3(0, 0, -1), delta)
			if pile.count_of(carry_type) == 0:
				job = J.GO_PICK
				_goal = Vector3.INF
				return
			var m := drop_target as Machine
			if m != null and m.input_room(carry_type) <= 0:
				_wait += delta
				if _wait > 4.0:
					_choose_drop_farmer(field)


func _choose_drop_farmer(field: Field) -> void:
	carry_type = field.crop
	var best: Machine = null
	var best_room := -1
	for id in field.def["feeds"]:
		var st: Node = (world.get("stations") as Dictionary).get(str(id), null)
		var m := st as Machine
		if m == null:
			continue
		var room := m.input_room(carry_type)
		if room > best_room:
			best_room = room
			best = m
	if best == null:
		job = J.PICK
		return
	drop_target = best
	drop_pad = "in"
	job = J.GO_DROP
	_goal = Vector3.INF
	_wait = 0.0


# -------------------------------------------------------------- baker ----
func _baker(delta: float) -> void:
	var m := home as Machine
	if m == null:
		return
	match job:
		J.GO_PICK:
			_go(m.pad_pos("out"))
			if _walk(delta):
				job = J.PICK
				_wait = 0.0
		J.PICK:
			_face_dir(Vector3(0, 0, -1), delta)
			if pile.room() <= 0:
				_choose_drop_baker(m)
				return
			if m.out_pile.count() == 0:
				_wait += delta
				if pile.count() > 0 and _wait > 1.2:
					_choose_drop_baker(m)
			else:
				_wait = 0.0
		J.GO_DROP:
			if drop_target == null or not is_instance_valid(drop_target):
				job = J.GO_PICK
				return
			_go(drop_target.pad_pos(drop_pad))
			if _walk(delta):
				job = J.DROP
				_wait = 0.0
		J.DROP:
			if pile.count_of(carry_type) == 0:
				job = J.GO_PICK
				_goal = Vector3.INF
				return
			var full := false
			if drop_target is Shelf:
				_face_dir(Vector3(0, 0, -1), delta)
				full = (drop_target as Shelf).display.is_full()
			elif drop_target is Machine:
				_face_dir(Vector3(0, 0, -1), delta)
				full = (drop_target as Machine).input_room(carry_type) <= 0
			if full:
				_wait += delta
				if _wait > 4.0:
					_choose_drop_baker(m)


func _choose_drop_baker(m: Machine) -> void:
	carry_type = m.output
	var best: Station = null
	var best_ratio := 2.0
	for id in m.def["to"]:
		var st: Node = (world.get("stations") as Dictionary).get(str(id), null)
		if st is Shelf:
			var r := (st as Shelf).fill_ratio()
			if r < best_ratio:
				best_ratio = r
				best = st
		elif st is Machine:
			var r2 := (st as Machine).fill_ratio(carry_type)
			if r2 < best_ratio:
				best_ratio = r2
				best = st
	if best == null:
		job = J.PICK
		return
	drop_target = best
	drop_pad = "stock" if best is Shelf else "in"
	job = J.GO_DROP
	_goal = Vector3.INF
	_wait = 0.0


# ------------------------------------------------------ cashier/janitor --
func _cashier(delta: float) -> void:
	var r := home as Register
	if r == null:
		return
	_go(r.pad_pos("cashier"))
	if _walk(delta):
		_face_dir(Vector3(0, 0, -1), delta)


func _janitor(delta: float) -> void:
	_think -= delta
	if _clean_table == null or _clean_table.dirty_count() == 0:
		if _think > 0.0 and _clean_table == null:
			_idle_spot(delta)
			return
		_think = 1.0
		_clean_table = null
		var best_d := INF
		for t in world.call("tables"):
			var tb := t as CafeTable
			if tb != null and tb.dirty_count() > 0:
				var d := tb.global_position.distance_squared_to(global_position)
				if d < best_d:
					best_d = d
					_clean_table = tb
		if _clean_table == null:
			_idle_spot(delta)
			return
	_go(_clean_table.global_position + Vector3(0, 0, 1.3))
	if _walk(delta):
		_face_dir(Vector3(0, 0, -1), delta)


func _idle_spot(delta: float) -> void:
	_go(Vector3(-22.3, 0, -8.6))
	_walk(delta)
