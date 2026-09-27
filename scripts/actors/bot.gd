class_name PlayerBot
extends RefCounted
## Dev autoplayer (--auto): plays the whole game like a sensible human so the
## economy and every system can be tested headless. Not used in normal play.

var world: World
var task := {}
var _think := 0.0
var _path := PackedVector3Array()
var _pi := 0
var _goal := Vector3.INF
var _hold := 0.0
var _stuck := 0.0
var _last := Vector3.ZERO
var log_tasks := false


func _init(w: World) -> void:
	world = w
	log_tasks = bool(Game.dev["log"])


func steer(delta: float) -> Vector2:
	_think -= delta
	if _think <= 0.0:
		_think = 0.2
		if task.is_empty() or _task_done():
			_decide()
	if task.is_empty():
		return Vector2.ZERO
	var p := world.player.global_position
	var tgt: Vector3 = task["pos"]
	if str(task["kind"]) == "harvest":
		var f := task["st"] as Field
		var r := f.nearest_ripe(p)
		if r != Vector3.INF:
			tgt = r
	var flat := Vector3(tgt.x - p.x, 0, tgt.z - p.z)
	if flat.length() < 0.3:
		_hold += delta
		return Vector2.ZERO
	# follow a nav path, re-planned when the target moves
	if _goal == Vector3.INF or _goal.distance_to(tgt) > 0.5 or _pi >= _path.size():
		_goal = tgt
		_path = world.nav.path(p, tgt)
		_pi = 0
	while _pi < _path.size() - 1 and Vector2(_path[_pi].x - p.x, _path[_pi].z - p.z).length() < 0.45:
		_pi += 1
	var wp := _path[mini(_pi, _path.size() - 1)]
	var d := Vector3(wp.x - p.x, 0, wp.z - p.z)
	# unstick
	if p.distance_to(_last) < 0.02:
		_stuck += delta
		if _stuck > 1.0:
			_stuck = 0.0
			_goal = Vector3.INF
			return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	else:
		_stuck = 0.0
	_last = p
	if d.length() < 0.01:
		return Vector2.ZERO
	var v := Vector2(d.x, d.z).normalized()
	if flat.length() < 0.8:
		v *= 0.6
	return v


func _assign(kind: String, pos: Vector3, st: Node = null, extra := {}) -> void:
	task = {"kind": kind, "pos": pos, "st": st, "t": 0.0}
	for k in extra:
		task[k] = extra[k]
	_hold = 0.0
	_goal = Vector3.INF
	if log_tasks:
		print("[bot] ", kind, " ", st.name if st != null else "", " $", Game.money)


func _task_done() -> bool:
	var kind := str(task["kind"])
	var pl := world.player
	task["t"] = float(task["t"]) + 0.2
	if float(task["t"]) > 25.0:
		return true
	match kind:
		"zone":
			var id := str(task["id"])
			return not world.zones.has(id) or Game.money <= 0
		"cash":
			return world.register.cash.value <= 0
		"serve":
			return world.register.queue.is_empty() or _hold > 6.0
		"crow":
			return world.crows.is_empty()
		"table":
			var tb := task["st"] as CafeTable
			return tb.tips.value <= 0 and tb.dirty_count() == 0
		"deliver":
			var t := str(task["type"])
			if not pl.pile.has_type(t):
				return true
			var st: Node = task["st"]
			if st is Shelf:
				return (st as Shelf).display.is_full()
			if st is Machine:
				return (st as Machine).input_room(t) <= 0
			return false
		"trash":
			return pl.pile.is_empty()
		"pickup":
			var m := task["st"] as Machine
			return pl.pile.is_full() or (m.out_pile.count() == 0 and _hold > 0.4)
		"harvest":
			var f := task["st"] as Field
			return pl.pile.is_full() or f.ripe_count() == 0
		"idle":
			return _hold > 1.0 or float(task["t"]) > 2.0
	return true


func _decide() -> void:
	task = {}
	var pl := world.player
	var reg := world.register
	# 1. crows
	if not world.crows.is_empty():
		var c: Node3D = world.crows[0]
		if is_instance_valid(c):
			_assign("crow", c.global_position)
			return
	# 2. affordable zone (cheapest)
	var best_zone: BuyZone = null
	var best_rem := 1 << 30
	for id in world.zones:
		var z: BuyZone = world.zones[id]
		if z.remaining() < best_rem:
			best_rem = z.remaining()
			best_zone = z
	if best_zone != null and Game.money >= best_rem:
		_assign("zone", best_zone.global_position, best_zone, {"id": best_zone.id})
		return
	# 2b. upgrades (like a player tapping the upgrade button)
	if Game.is_unlocked("office"):
		for k in ["profit", "capacity", "speed", "machine", "staff_speed", "staff_cap"]:
			if Game.upgrade_level(k) >= Game.upgrade_max(k):
				continue
			if k.begins_with("staff") and world.workers.size() < 3:
				continue
			var c := Game.upgrade_cost(k)
			if Game.money >= c and (best_zone == null or c <= best_rem * 0.6):
				Game.buy_upgrade(k)
				Game.log_line("[upgrade] %s -> %d ($%d)" % [k, Game.upgrade_level(k), c])
				break
	# 3. cash
	if reg.cash.value > 0 and (reg.cash.value >= 40 or (best_zone != null and Game.money + reg.cash.value >= best_rem) or pl.pile.is_empty()):
		if reg.cash.value >= 15 or best_zone == null or Game.money + reg.cash.value >= best_rem:
			_assign("cash", reg.cash.global_position)
			return
	# 4. serve if nobody else does
	if not Game.is_unlocked("hire_cashier") and reg.queue.size() > 0:
		var front: Node = reg.queue[0]
		if is_instance_valid(front) and bool(front.call("ready_to_pay")):
			_assign("serve", reg.pad_pos("cashier"))
			return
	# 5. tips
	for t in world.tables():
		var tb := t as CafeTable
		if tb.tips.value >= 20 or (tb.dirty_count() > 0 and not Game.is_unlocked("hire_janitor") and tb.dirty_count() >= 2):
			_assign("table", tb.global_position + Vector3(0, 0, 1.4), tb)
			return
	# 6. deliver what we carry
	if not pl.pile.is_empty():
		for t in _unique(pl.pile.types):
			var dest := _dest_for(t)
			if not dest.is_empty():
				_assign("deliver", dest["pos"], dest["st"], {"type": t})
				return
		var trash: Station = world.stations["trash"]
		_assign("trash", trash.pad_pos("dump"), trash)
		return
	# 7. pick up products / flour
	var best_m: Machine = null
	var best_score := 0.0
	for s in world.station_list:
		var m := s as Machine
		if m == null or m.out_pile.count() == 0:
			continue
		var dest := _dest_for(m.output)
		if dest.is_empty():
			continue
		var score := float(m.out_pile.count())
		var ds: Node = dest["st"]
		if ds is Shelf and (ds as Shelf).stock() < 3:
			score += 6.0
		if score > best_score:
			best_score = score
			best_m = m
	if best_m != null and best_score >= 2.0:
		_assign("pickup", best_m.pad_pos("out"), best_m)
		return
	# 8. harvest for the hungriest machine
	var best_f: Field = null
	var best_need := 0.0
	for s in world.station_list:
		var f := s as Field
		if f == null or f.ripe_count() < 2:
			continue
		for mid in f.def["feeds"]:
			var m2: Machine = world.stations.get(str(mid), null)
			if m2 == null:
				continue
			var need := float(m2.input_room(f.crop)) + (4.0 if m2.out_pile.count() < 2 else 0.0)
			if need > best_need:
				best_need = need
				best_f = f
	if best_f != null and best_need >= 3.0:
		_assign("harvest", best_f.global_position, best_f)
		return
	if best_m != null:
		_assign("pickup", best_m.pad_pos("out"), best_m)
		return
	# 9. idle near the till (collect / serve)
	_assign("idle", reg.pad_pos("cashier"))


func _unique(a: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for i in range(a.size() - 1, -1, -1):
		if not out.has(a[i]):
			out.append(a[i])
	return out


## Where an item of type t should go: {"st":, "pos":} or {}.
func _dest_for(t: String) -> Dictionary:
	if Items.PRODUCTS.has(t):
		for s in world.shelves():
			if s.product == t and not s.display.is_full():
				return {"st": s, "pos": s.pad_pos("stock")}
		return {}
	var best: Machine = null
	var best_room := 0
	for s in world.station_list:
		var m := s as Machine
		if m == null:
			continue
		var room := m.input_room(t)
		if room > best_room:
			best_room = room
			best = m
	if best == null:
		return {}
	return {"st": best, "pos": best.pad_pos("in")}
