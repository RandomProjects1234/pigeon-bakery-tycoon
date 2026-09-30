class_name World
extends Node3D
## Runs the bakery: builds everything, spawns stations as zones are bought,
## spawns pigeons / crows / staff, drives the camera and the objective arrow.

const CAM_OFFSET := Vector3(0, 15.5, 11.2)
const CAM_FOV := 42.0

var nav := NavGrid.new()
var player: Player
var cam: Camera3D
var cam_yaw := 0.0
var cam_target := Vector3.ZERO
var stations := {}          # id -> Station (includes "register" and "trash")
var station_list: Array[Station] = []
var zones := {}             # id -> BuyZone
var workers: Array[Worker] = []
var pigeons: Array[Node] = []
var crows: Array[Node] = []
var carriers: Array[Carrier] = []
var register: Register
var objectives: Objectives
var company_label: Label3D
var menu_mode := true
var military: Military
var security: Security
var nest: CrowsNest
var _van: TvVan = null
var _invite_t := 0.0
var _inviting := false
var _global_t := 0.0

var _gates := {}
var _arrow: MeshInstance3D
var _ground_arrow: MeshInstance3D
var _spawn_t := 1.0
var _rush_t := 160.0
var _crow_t := 80.0
var _obj_t := 0.0
var _pan_target := Vector3.INF
var _pan_time := 0.0
var _orbit_t := 0.0
var _shake := 0.0
var _t := 0.0
var _intro_t := 0.0
var _intro_running := false
var _attack_cd := 0.0


func _ready() -> void:
	Game.world = self
	ItemPile.fx_root = self
	Fx.root = self
	military = Military.new(self)
	security = Security.new(self)
	nest = CrowsNest.new(self)
	add_child(nest)
	# saves that finished the game before the military update still get General Coo
	if Game.is_unlocked("statue"):
		Game.flags["won"] = true
	var built := WorldBuilder.build(self, nav)
	_gates = built.get("gates", {})
	# pre-built: register + trash
	register = Register.new()
	add_child(register)
	register.setup(self, {"id": "register", "pos": Layout.REGISTER_POS})
	_register_station(register)
	var trash := TrashBin.new()
	add_child(trash)
	trash.setup(self, {"id": "trash", "pos": Layout.TRASH_POS})
	_register_station(trash)
	for z in Layout.ZONES:
		if Game.is_unlocked(str(z["id"])):
			_spawn_station(z, false)
	for id in Game.station_state:
		if stations.has(id):
			(stations[id] as Station).load_state(Game.station_state[id])
	_refresh_zones(false)
	# player
	player = Player.new()
	player.name = "Player"
	player.world = self
	add_child(player)
	var sp := Game.player_pos if Game.player_pos != Vector2.INF else Layout.PLAYER_SPAWN
	player.global_position = Vector3(sp.x, 0, sp.y)
	carriers.append(player)
	for z in Layout.ZONES:
		if str(z["kind"]) == "hire" and Game.is_unlocked(str(z["id"])):
			_spawn_worker(z, false)
	# camera
	cam = Camera3D.new()
	cam.fov = CAM_FOV
	cam.near = 0.3
	cam.far = 250.0
	add_child(cam)
	cam.current = true
	cam_target = player.global_position
	_place_camera(1.0)
	# guidance arrows
	_arrow = MeshBuilder.node(Models.arrow_mesh(), self)
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.visible = false
	_ground_arrow = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.9, 0.9)
	_ground_arrow.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = Items.icon("fx_ground_arrow")
	m.albedo_color = Color(1.0, 0.9, 0.2, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ground_arrow.material_override = m
	_ground_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_arrow.visible = false
	add_child(_ground_arrow)
	objectives = Objectives.new(self)
	if Game.has_flag("nest_invite") and not bool(Game.ceo["deal"]):
		_spawn_van(false)
	if bool(Game.ceo["deal"]):
		_init_cities()
	if bool(Game.dev["nest_now"]):
		Game.flags["nest_invite"] = true
		_spawn_van(false)
		get_tree().create_timer(2.0, false).timeout.connect(start_nest)
	Game.zone_unlocked.connect(_on_unlocked)
	Game.flag_set.connect(func(_f: String) -> void: _refresh_zones(true))
	Game.company_changed.connect(_on_company_changed)
	_apply_dev_camera()


func _register_station(s: Station) -> void:
	stations[s.id] = s
	station_list.append(s)


func _spawn_station(z: Dictionary, animate: bool) -> Station:
	var kind := str(z["kind"])
	var s: Station = null
	match kind:
		"field":
			s = Field.new()
		"machine":
			s = Machine.new()
		"shelf":
			s = Shelf.new()
		"table":
			s = CafeTable.new()
		"office":
			s = Office.new()
		"decor", "statue":
			s = Decor.new()
		"depot":
			s = Depot.new()
		"security":
			s = SecurityHQ.new()
		"turret":
			s = Turret.new()
		"land":
			_open_gate(str(z["id"]), animate)
			return null
		_:
			return null
	add_child(s)
	s.setup(self, z)
	_register_station(s)
	if animate:
		Fx.pop_in(s, 0.5)
		_push_player_out.call_deferred()
	return s


## A station that pops up under the player shoves them to the nearest free spot.
func _push_player_out() -> void:
	if player == null:
		return
	var c := nav.cell(player.global_position)
	if nav.is_free(c):
		return
	var p := nav.to_world(nav.nearest_free(c))
	var tw := create_tween()
	tw.tween_property(player, "global_position", p, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _spawn_worker(z: Dictionary, animate: bool) -> Worker:
	var wk := Worker.new()
	wk.name = "Worker_" + str(z["id"])
	add_child(wk)
	var role := str(z["role"])
	var at := Vector3.ZERO
	if role == "guard" and stations.has("security_hq") and animate:
		at = (stations["security_hq"] as SecurityHQ).door_pos()
	elif role == "runner" and stations.has("military_depot") and animate:
		at = (stations["military_depot"] as Node3D).global_position + Vector3(0, 0, 3.2)
	elif stations.has("office") and animate:
		at = (stations["office"] as Office).door_pos()
	else:
		var p: Vector2 = z["pos"]
		at = Vector3(p.x, 0, p.y)
	wk.setup(self, role, str(z["station"]), at)
	workers.append(wk)
	carriers.append(wk)
	if animate:
		Fx.poof(at + Vector3(0, 0.6, 0), Color(1, 1, 1), 16, 0.3)
		Fx.pop_in(wk, 0.4)
	return wk


func _open_gate(id: String, animate: bool) -> void:
	var gate: Node3D = _gates.get(id, null)
	if gate != null and is_instance_valid(gate):
		if animate:
			Fx.poof(gate.global_position + Vector3(0, 0.6, 0), Color(0.9, 0.7, 0.5), 20, 0.35)
		gate.queue_free()
	_gates.erase(id)
	var g: Array = Layout.GATES.get(id, [])
	if g.size() == 2:
		# free only the middle of the gap so paths don't clip the fence posts
		var a: Vector2 = g[0]
		var b: Vector2 = g[1]
		var d := (b - a).normalized() * 0.45
		nav.set_line(a + d, b - d, false, 0.35)


## Creates buy zones that just became visible. Returns the new ones.
func _refresh_zones(animate: bool) -> Array[BuyZone]:
	var fresh: Array[BuyZone] = []
	for z in Layout.ZONES:
		var id := str(z["id"])
		if zones.has(id) or not Game.zone_visible(z):
			continue
		var bz := BuyZone.new()
		add_child(bz)
		bz.setup(self, z)
		zones[id] = bz
		fresh.append(bz)
		if animate:
			Fx.pop_in(bz, 0.45, 0.35 + fresh.size() * 0.12)
	return fresh


func _on_unlocked(id: String) -> void:
	var z := Layout.zone(id)
	if z.is_empty():
		return
	var pos := Layout.v3(z["pos"])
	if zones.has(id):
		(zones[id] as Node).queue_free()
		zones.erase(id)
	var kind := str(z["kind"])
	Game.log_line("[unlock] t=%4.0fs %-18s money=%d served=%d pigeons=%d" % [_t, id, Game.money, int(Game.stats["served"]), pigeons.size()])
	if kind == "hire":
		_spawn_worker(z, true)
	else:
		_spawn_station(z, true)
	Sfx.play("unlock", -3.0)
	Sfx.play("thud", -6.0)
	Fx.confetti(pos + Vector3(0, 0.5, 0), 50)
	Fx.float_text(pos + Vector3(0, 2.8, 0), "UNLOCKED!", Color(1, 0.9, 0.3), 80)
	_shake = 0.25
	if kind == "shelf" and Game.hud != null:
		var product := str(z["product"])
		Game.hud.call("big_card", "New product!", "%s  $%d" % [Items.title(product), Items.price(product)],
			"Pigeons will now come for %s." % Items.title(product).to_lower(), product)
		Sfx.play("fanfare", -4.0)
	elif kind == "hire" and Game.hud != null:
		Game.hud.call("toast", "%s hired!" % str(z["name"]).replace("Hire ", ""), Layout.zone_icon(z))
	elif kind == "land" and Game.hud != null:
		var blurb := "Room for more fields and landmarks." if id == "backlot" else "Build the Supply Depot for General Coo."
		Game.hud.call("big_card", "More land!", str(z["name"]), blurb, "land")
		Sfx.play("fanfare", -4.0)
	elif kind == "statue":
		_win()
	var fresh := _refresh_zones(true)
	if not fresh.is_empty() and Game.playing:
		var tgt := fresh[0].global_position
		if tgt.distance_to(player.global_position) > 8.0:
			pan_to(tgt, 1.6)


# ------------------------------------------------ General Coo arrives --
func _update_intro(delta: float) -> void:
	if _intro_running or not Game.playing or not Game.has_flag("won") or Game.has_flag("general_met"):
		return
	if Game.hud == null or bool(Game.hud.call("is_busy")):
		return
	_intro_t += delta
	if _intro_t < 5.0:
		return
	_intro_running = true
	var gen := PigeonRig.new("general")
	gen.scale = Vector3.ONE * 1.4
	add_child(gen)
	var land := player.global_position + Vector3(1.6, 0, 1.2)
	var from := land + Vector3(14, 12, -10)
	gen.global_position = from
	Sfx.play("bugle", -2.0)
	Sfx.play("flap", -6.0)
	var fly := func(t: float) -> void:
		var e := 1.0 - pow(1.0 - t, 2.0)
		gen.global_position = from.lerp(land, e) + Vector3(0, sin(t * PI) * 2.0, 0)
		gen.animate(0.016, 0.0, "fly" if t < 0.98 else "idle")
	var tw := create_tween()
	tw.tween_method(fly, 0.0, 1.0, 2.4)
	tw.tween_callback(func() -> void:
		gen.look_at(Vector3(player.global_position.x, 0, player.global_position.z), Vector3.UP)
		for i in 12:
			gen.animate(0.1, 0.0, "idle")   # settle out of the flying pose
		_general_speech(gen))


func _general_speech(gen: PigeonRig) -> void:
	var lines: Array[String] = [
		"ATTENTION, BAKER! I am General Coo of the Pigeon Army.",
		"The Crow Clans have declared war on every pigeon in this city.",
		"My soldiers are brave... but brave birds get HUNGRY. And your bread is the finest in the land.",
		"Build a Supply Depot at my outpost, east of your yard. I will send you orders. BIG orders. With deadlines.",
		"You may haggle, of course. But don't push your luck with me, baker.",
		"And watch your back. The crows know who feeds my army. They will raid your shop, and your wallet!",
		"Get yourself some security. Dismissed!",
	]
	Game.hud.call("dialog", lines, "General Coo", "portrait_general", func() -> void:
		Game.set_flag("general_met")
		Sfx.play("fanfare", -3.0)
		Game.hud.call("big_card", "Military Update!", "War against the crows", "Build the Military Outpost and a Security Booth.", "military")
		var from := gen.global_position
		var to := from + Vector3(18, 14, -6)
		var away := func(t: float) -> void:
			gen.global_position = from.lerp(to, t * t)
			gen.animate(0.016, 0.0, "fly")
		var tw := create_tween()
		tw.tween_method(away, 0.0, 1.0, 2.0)
		tw.tween_callback(gen.queue_free)
		_intro_running = false)


# ------------------------------------------------------- Crow's Nest --
## "Basically finished": every zone bought and a few army orders delivered.
func game_finished() -> bool:
	if bool(Game.dev["nest"]):
		return true
	for z in Layout.ZONES:
		if not Game.is_unlocked(str(z["id"])):
			return false
	return int(Game.military["done"]) >= 3


func _update_nest_invite(delta: float) -> void:
	if _inviting or not Game.playing or Game.has_flag("nest_invite") or bool(Game.ceo["deal"]):
		return
	if not game_finished() or Game.hud == null or bool(Game.hud.call("is_busy")):
		return
	if security.raid_active or security.warn_t > 0.0 or military.state == "offer":
		return
	_invite_t += delta
	if _invite_t < 6.0:
		return
	_inviting = true
	Game.log_line("[nest] Producer Pip invites you")
	var lines: Array[String] = [
		"Hi hi hi! Producer Pip, from the hit TV show CROW'S NEST!",
		"Everyone's talking about %s. You fed the whole army AND beat the Crow Clans!" % Game.company,
		"On Crow's Nest you pitch your business to the richest pigeons in the world. If they invest, you go GLOBAL!",
		"Our TV van is parked at your military outpost. Walk up the red carpet when you're ready. You're on in five!",
	]
	Sfx.play("bugle", -4.0)
	Game.hud.call("dialog", lines, "Producer Pip", "portrait_producer", func() -> void:
		Game.set_flag("nest_invite")
		_spawn_van(true)
		_inviting = false
		Game.hud.call("big_card", "Final Update!", "Crow's Nest", "Pitch to rich pigeon investors and take your bakery global.", "nest")
		Sfx.play("fanfare", -3.0)
		if _van != null:
			pan_to(_van.global_position, 1.8))


func _spawn_van(animate: bool) -> void:
	if _van != null:
		return
	_van = TvVan.new()
	add_child(_van)
	_van.setup(self, {"id": "tv_van", "pos": Vector2(26.8, 3.4)})
	_register_station(_van)
	if animate:
		Fx.pop_in(_van, 0.5)
		Fx.confetti(_van.global_position + Vector3(0, 1, 0), 60)


func start_nest() -> void:
	if bool(Game.ceo["deal"]) or nest.running:
		return
	if nest.cooldown > 0.0:
		Fx.float_text(player.global_position + Vector3(0, 2.6, 0), "Next season in %ds" % int(nest.cooldown), Color(1, 1, 1), 50)
		return
	nest.start()


func start_ending() -> void:
	_init_cities()
	if _van != null:
		station_list.erase(_van)
		stations.erase("tv_van")
		Fx.poof(_van.global_position + Vector3(0, 1, 0), Color(1, 1, 1), 20, 0.4)
		_van.queue_free()
		_van = null
	var e := Ending.new()
	get_parent().add_child(e)


func _init_cities() -> void:
	var cities: Dictionary = Game.ceo["cities"]
	for c in Investors.CITIES:
		var n := str(c[0])
		if not cities.has(n):
			cities[n] = 1


## Your share of every restaurant's income worldwide, paid once a second.
func global_income() -> float:
	if not bool(Game.ceo["deal"]):
		return 0.0
	var total := 0.0
	var cities: Dictionary = Game.ceo["cities"]
	for i in Investors.CITIES.size():
		var lvl := int(cities.get(str(Investors.CITIES[i][0]), 0))
		total += Investors.city_income(i, lvl)
	return total * (1.0 - float(Game.ceo["equity"]) / 100.0)


func _update_global_income(delta: float) -> void:
	if not bool(Game.ceo["deal"]) or not bool(Game.ceo["seen_end"]) or not Game.playing:
		return
	_global_t += delta
	if _global_t >= 1.0:
		_global_t -= 1.0
		Game.add_money(int(global_income()))


func pan_to(p: Vector3, secs: float) -> void:
	_pan_target = p
	_pan_time = secs
	player.locked = true
	Sfx.play("whoosh", -8.0)


func _win() -> void:
	Game.set_flag("won")
	for i in 6:
		var t := get_tree().create_timer(0.3 * i, false)
		var p := Layout.v3(Layout.zone("statue")["pos"]) + Vector3(randf_range(-4, 4), 1.0, randf_range(-3, 3))
		t.timeout.connect(func() -> void: Fx.confetti(p, 70, 60.0))
	Sfx.play("fanfare", 0.0)
	if Game.hud != null:
		var t2 := get_tree().create_timer(2.5, false)
		t2.timeout.connect(func() -> void: Game.hud.call("show_win"))


func _on_company_changed(n: String) -> void:
	if company_label != null:
		WorldBuilder.fit_sign(company_label, n)


# ------------------------------------------------------------ queries ----
func shelves() -> Array[Shelf]:
	var out: Array[Shelf] = []
	for s in station_list:
		if s is Shelf:
			out.append(s)
	return out


func tables() -> Array:
	var out: Array = []
	for s in station_list:
		if s is CafeTable:
			out.append(s)
	return out


func find_seat() -> Array:
	var ts := tables()
	ts.shuffle()
	for t in ts:
		var i := (t as CafeTable).free_seat()
		if i >= 0:
			return [t, i]
	return []


func popularity() -> float:
	var p := 1.0 + 0.08 * tables().size()
	for z in Layout.ZONES:
		if z.has("popularity") and Game.is_unlocked(str(z["id"])):
			p += float(z["popularity"])
	return p


func notify(ev: String, _st: Node) -> void:
	if ev == "collected":
		Game.set_flag("first_cash")


func raider_gone(r: Node, escaped: bool) -> void:
	security.raider_gone(r, escaped)


func pigeon_gone(p: Node) -> void:
	pigeons.erase(p)


func crow_gone(c: Node) -> void:
	crows.erase(c)


func hired_count() -> int:
	return workers.size()


# --------------------------------------------------------------- loop ----
func _physics_process(delta: float) -> void:
	for a in carriers:
		for s in station_list:
			s.service(a, delta)
	_attack_cd -= delta
	if Game.playing and not security.raiders.is_empty() and _attack_cd <= 0.0:
		if security.hit_near(player.global_position, 1.5, 1) != null:
			_attack_cd = 0.35
			player.rig.swing()
	if Game.playing and not player.locked:
		for id in zones:
			(zones[id] as BuyZone).service(player, delta)
		for c in crows:
			if is_instance_valid(c) and bool(c.call("try_scare", player.global_position)):
				Game.stats["shooed"] = int(Game.stats["shooed"]) + 1
				var bonus := 5 * shelves().size()
				Game.add_money(bonus)
				Fx.float_text(player.global_position + Vector3(0, 2.6, 0), "+$%d" % bonus, Color(1, 0.9, 0.3), 60)


func _process(delta: float) -> void:
	_t += delta
	_update_spawning(delta)
	military.tick(delta)
	security.tick(delta)
	_update_intro(delta)
	_update_nest_invite(delta)
	_update_global_income(delta)
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.15
		objectives.update()
		if Game.hud != null:
			Game.hud.call("set_objective", objectives.text, objectives.icon, objectives.step_label)
	_update_arrows(delta)
	_update_camera(delta)
	if Game.playing:
		Game.player_pos = Vector2(player.global_position.x, player.global_position.z)


func _update_spawning(delta: float) -> void:
	var sh := shelves()
	if sh.is_empty():
		return
	var cap := 3 + sh.size() * 4 + tables().size()
	# rush hour
	_rush_t -= delta
	if _rush_t <= 0.0:
		_rush_t = randf_range(150.0, 240.0)
		if sh.size() >= 2 and Game.tut >= 9 and Game.playing:
			if Game.hud != null:
				Game.hud.call("toast", "PIGEON RUSH!", "ui_star")
			Sfx.coo(-2.0)
			for i in 6:
				var t := get_tree().create_timer(0.35 * i, false)
				t.timeout.connect(func() -> void: _spawn_pigeon(sh.pick_random() as Shelf))
	# crows
	_crow_t -= delta
	if _crow_t <= 0.0:
		_crow_t = randf_range(70.0, 110.0)
		if Game.is_unlocked("hire_cashier") and crows.is_empty() and Game.playing:
			var candidates: Array[Shelf] = []
			for s in sh:
				if s.stock() >= 3:
					candidates.append(s)
			if not candidates.is_empty():
				var crow := Crow.new()
				add_child(crow)
				crow.setup(self, candidates.pick_random() as Shelf)
				crows.append(crow)
				if Game.hud != null:
					Game.hud.call("toast", "A crow is stealing from your shelf!", "ui_close")
	if pigeons.size() >= cap:
		return
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	# tutorial: one customer at a time until the first sale
	if Game.tut < 8 and pigeons.size() >= 1:
		_spawn_t = 1.0
		return
	_spawn_t = randf_range(4.0, 6.5) / (popularity() * (1.0 + 0.45 * (sh.size() - 1)))
	var options: Array[Shelf] = []
	var weights: Array[float] = []
	for s in sh:
		if s.has_room_in_queue():
			options.append(s)
			# the $500 pie is a luxury: only the odd rich pigeon wants one
			weights.append(0.1 if s.product == "pie" else 1.0)
	if options.is_empty():
		return
	var total := 0.0
	for w in weights:
		total += w
	var r := randf() * total
	for i in options.size():
		r -= weights[i]
		if r <= 0.0:
			_spawn_pigeon(options[i])
			return
	_spawn_pigeon(options[options.size() - 1])


func _spawn_pigeon(s: Shelf) -> void:
	if s == null or not s.has_room_in_queue():
		return
	var n_products := shelves().size()
	var qty := randi_range(1 if n_products < 4 else 2, clampi(1 + n_products, 2, 6))
	if Game.tut < 8:
		qty = 2
	var vip := Game.is_unlocked("golden_perch") and randf() < 0.12
	if vip:
		qty += 1
	if s.product == "pie":
		qty = 1
	var p := Pigeon.new()
	add_child(p)
	p.setup(self, s, register, qty, vip)
	pigeons.append(p)


func _update_arrows(_delta: float) -> void:
	var tgt := objectives.target
	var show := tgt != Vector3.INF and Game.playing
	_arrow.visible = show
	if not show:
		_ground_arrow.visible = false
		return
	_arrow.global_position = tgt + Vector3(0, 3.1 + absf(sin(_t * 4.0)) * 0.45, 0)
	_arrow.rotation.y = cam_yaw
	var to := Vector3(tgt.x - player.global_position.x, 0, tgt.z - player.global_position.z)
	var d := to.length()
	_ground_arrow.visible = d > 3.2
	if _ground_arrow.visible:
		var dir := to / d
		_ground_arrow.global_position = player.global_position + dir * 1.35 + Vector3(0, 0.06, 0)
		_ground_arrow.rotation.y = atan2(-dir.x, -dir.z)


func _view_scale() -> float:
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(vs.y, 1.0)
	if aspect >= 1.3:
		return 1.0
	return clampf(1.0 + (1.3 - aspect) * 0.9, 1.0, 1.9)


func _place_camera(k: float) -> void:
	var off := CAM_OFFSET.rotated(Vector3.UP, cam_yaw) * _view_scale()
	var shake := Vector3.ZERO
	if _shake > 0.0:
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
	var desired := cam_target + off
	cam.global_position = cam.global_position.lerp(desired, k) + shake
	cam.look_at(cam.global_position - off, Vector3.UP)


func _update_camera(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta)
	if menu_mode:
		_orbit_t += delta
		var center := Vector3(-3.0, 0, -8.0)
		var a := _orbit_t * 0.08
		var off := Vector3(sin(a) * 26.0, 19.0, cos(a) * 26.0)
		cam.global_position = center + off
		cam.look_at(center, Vector3.UP)
		return
	if _pan_time > 0.0:
		_pan_time -= delta
		cam_target = cam_target.lerp(_pan_target, clampf(delta * 4.0, 0.0, 1.0))
		if _pan_time <= 0.0:
			_pan_target = Vector3.INF
			player.locked = false
	else:
		cam_target = cam_target.lerp(player.global_position, clampf(delta * 6.0, 0.0, 1.0))
	_place_camera(clampf(delta * 10.0, 0.0, 1.0))


func start_play() -> void:
	menu_mode = false
	Game.playing = true
	cam_target = player.global_position
	_place_camera(1.0)


func _apply_dev_camera() -> void:
	var c := str(Game.dev["cam"])
	if c.is_empty():
		return
	# --cam x,z  : park the follow camera over a point (for screenshots)
	var parts := c.split(",")
	if parts.size() >= 2:
		player.global_position = Vector3(float(parts[0]), 0, float(parts[1]))


## Snapshot of every station's contents for the save file.
func collect_state() -> void:
	var d := {}
	for s in station_list:
		var st := s.save_state()
		if not st.is_empty():
			d[s.id] = st
	Game.station_state = d
