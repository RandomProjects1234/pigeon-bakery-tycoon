class_name Security
extends RefCounted
## Crow Clan raids. After General Coo's warning, a raid is announced with a
## siren every few minutes; a flock (plus a Crow Boss every third raid) comes
## in from one side and goes for your stock, your till and your wallet.

const WARN_TIME := 8.0

var world: Node
var raiders: Array[Node] = []
var raid_active := false
var warn_t := -1.0
var next_raid := 75.0
var _raid_stolen := 0
var _raid_beaten := 0
var _stolen_at_start := 0
var _items_at_start := 0


func _init(w: Node) -> void:
	world = w
	if float(Game.dev["raid_in"]) >= 0.0:
		next_raid = float(Game.dev["raid_in"])


func enabled() -> bool:
	return Game.has_flag("general_met") and Game.playing


func tick(delta: float) -> void:
	if not enabled():
		return
	if raid_active:
		if raiders.is_empty():
			_end_raid()
		return
	if warn_t > 0.0:
		warn_t -= delta
		if warn_t <= 0.0:
			_start_raid()
		return
	next_raid -= delta
	if next_raid <= 0.0:
		warn_t = WARN_TIME
		Sfx.play("siren", -3.0)
		if Game.hud != null:
			Game.hud.call("toast", "CROW CLAN RAID INCOMING!", "ui_close")


func raid_number() -> int:
	return int(Game.stats["raids"]) + 1


func _start_raid() -> void:
	raid_active = true
	var n := raid_number()
	var count := mini(4 + n, 14)
	var boss := n % 3 == 0
	_raid_beaten = 0
	_stolen_at_start = int(Game.stats["stolen"])
	_items_at_start = int(Game.stats.get("stolen_items", 0))
	Game.log_line("[raid] #%d start: %d crows%s" % [n, count, " + BOSS" if boss else ""])
	var side := [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)].pick_random() as Vector3
	Sfx.play("caw", 0.0, 0.85)
	for i in count:
		var t := world.get_tree().create_timer(0.25 * i, false)
		var is_boss := boss and i == 0
		t.timeout.connect(func() -> void: _spawn(is_boss, side))


func _spawn(is_boss: bool, side: Vector3) -> void:
	var pick := _pick_target()
	if pick.is_empty():
		pick = {"node": world.get("register"), "kind": "cash"}
		pick["node"] = (world.get("register") as Register).cash
	var r := Raider.new()
	world.add_child(r)
	r.setup(world, is_boss, pick["node"], str(pick["kind"]), side)
	raiders.append(r)


## Weighted random pick of something worth stealing.
func _pick_target() -> Dictionary:
	var opts: Array[Dictionary] = []
	var weights: Array[float] = []
	var reg: Register = world.get("register")
	if reg.cash.value > 0:
		opts.append({"node": reg.cash, "kind": "cash"})
		weights.append(3.0)
	var st: Dictionary = world.get("stations")
	if st.has("office") and Game.money > 100:
		opts.append({"node": st["office"], "kind": "wallet"})
		weights.append(2.5)
	if st.has("military_depot"):
		var dep: Node = st["military_depot"]
		var dc: CashPile = dep.get("cash")
		if dc != null and dc.value > 0:
			opts.append({"node": dc, "kind": "cash"})
			weights.append(2.0)
	for s in world.call("shelves"):
		var sh := s as Shelf
		if sh.stock() > 0:
			opts.append({"node": sh, "kind": "shelf"})
			weights.append(2.0)
	for s in world.get("station_list"):
		var m := s as Machine
		if m != null and m.out_pile.count() >= 2:
			opts.append({"node": m, "kind": "machine"})
			weights.append(0.8)
	if opts.is_empty():
		return {}
	var total := 0.0
	for w in weights:
		total += w
	var r := randf() * total
	for i in opts.size():
		r -= weights[i]
		if r <= 0.0:
			return opts[i]
	return opts[opts.size() - 1]


func raider_gone(r: Node, escaped: bool) -> void:
	raiders.erase(r)
	if not escaped:
		_raid_beaten += 1


func _end_raid() -> void:
	raid_active = false
	Game.stats["raids"] = int(Game.stats["raids"]) + 1
	next_raid = randf_range(150.0, 230.0)
	var lost := int(Game.stats["stolen"]) - _stolen_at_start
	var items := int(Game.stats.get("stolen_items", 0)) - _items_at_start
	Game.log_line("[raid] over: beaten=%d stolen=$%d items=%d money=%d" % [_raid_beaten, lost, items, Game.money])
	var msg := "Raid over! %d crows beaten" % _raid_beaten
	if lost > 0 or items > 0:
		var parts: Array[String] = []
		if lost > 0:
			parts.append("$" + Game.fmt(lost))
		if items > 0:
			parts.append("%d items" % items)
		msg += ", they stole " + " and ".join(parts)
	else:
		msg += ", nothing stolen!"
	if Game.hud != null:
		Game.hud.call("toast", msg, "security")
	Sfx.play("fanfare" if lost == 0 and items == 0 else "unlock", -6.0)


## Hits the closest hittable raider within `radius` of `pos`. Returns it or null.
func hit_near(pos: Vector3, radius: float, dmg: int) -> Node:
	var best: Raider = null
	var best_d := radius * radius
	for r in raiders:
		var rd := r as Raider
		if rd == null or not is_instance_valid(rd) or not rd.hittable():
			continue
		var d := Vector2(rd.global_position.x - pos.x, rd.global_position.z - pos.z).length_squared()
		if d < best_d:
			best_d = d
			best = rd
	if best != null:
		best.hit(dmg, pos)
	return best


func nearest(pos: Vector3, max_d := 999.0) -> Raider:
	var best: Raider = null
	var best_d := max_d * max_d
	for r in raiders:
		var rd := r as Raider
		if rd == null or not is_instance_valid(rd) or not rd.hittable():
			continue
		var d := rd.global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = rd
	return best


func alive_count() -> int:
	return raiders.size()
