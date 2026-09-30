class_name CrowWar
extends Node3D
## The Crow War: the post-ending campaign at your corporate HQ tower.
## Crow Clan waves (bombers, commandos, heavies, warlords, the Crow King) try
## to poop your tower into the ground. Build pigeon weapons on the 12 pads,
## upgrade the tower at the Command Center, bonk crows yourself. Every wave
## you win weakens the Clan; at 20% the Crow King comes for the final battle.
## Meanwhile Clan bombers hit your restaurants around the world.

const ORIGIN := Vector3(-230, 0, -10)
const BOUND_R := 27.0
const SHIELD_R := 11.5
const CMD_PAD := Vector3(0, 0, 5.8)
const LIMO_PAD := Vector3(0, 0, 23.5)
const SPAWN := Vector3(0, 0, 21.0)

var world: Node
var root: Node3D
var center := ORIGIN
var enemies: Array[Node] = []
var weapons := {}            # slot -> HQWeapon
var pads: Array[Vector3] = []
var phase := "calm"          # calm | warn | wave
var next_wave := 45.0
var warn_t := 0.0
var final_wave := false
var hq_hp := 1500.0
var shield_hp := 0.0
var city_t := 120.0
var _to_spawn: Array[String] = []
var _spawn_t := 0.0
var _was_on := {}
var _hp_fill: Sprite3D
var _dome: MeshInstance3D
var _dome_mat: StandardMaterial3D
var _splats: Array = []
var _regen_t := 0.0
var _shield_t := 0.0
var _company: Label3D


func _init(w: Node) -> void:
	world = w


func _ready() -> void:
	root = self
	position = ORIGIN
	center = ORIGIN
	_build()
	for k in Game.war["weapons"]:
		var d: Dictionary = Game.war["weapons"][k]
		_place_weapon(int(k), str(d["type"]), int(d["level"]), false)
	hq_hp = float(Game.war["hq_hp"])
	if hq_hp < 0.0:
		hq_hp = max_hp()
	shield_hp = shield_max()
	if float(Game.dev["wave_in"]) >= 0.0:
		next_wave = float(Game.dev["wave_in"])


func active() -> bool:
	return Game.has_flag("war_started") and not bool(Game.war["won"])


func player_here() -> bool:
	return str(world.get("location")) == "hq"


func upg(k: String) -> int:
	return int((Game.war["upg"] as Dictionary).get(k, 0))


func max_hp() -> float:
	return 1500.0 + 600.0 * upg("armor")


func shield_max() -> float:
	var n := 0
	for s in weapons:
		var w: HQWeapon = weapons[s]
		if w.type == "shield":
			n += 10 + 6 * w.level
	return float(n)


func wave_number() -> int:
	return int(Game.war["wave"]) + 1


# ---------------------------------------------------------------- build --
func _build() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(170, 170)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Models.C_GRASS_DARK
	g.material_override = gm
	g.position.y = -0.01
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	var plaza := MeshBuilder.node(Models.cached("hq_plaza", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.cyl(28.0, 28.0, 0.04, Vector3(0, 0.02, 0), Color(0.6, 0.61, 0.66), Vector3.ZERO, 40)
		for r in [8.0, 15.0, 22.0]:
			b.torus(r, 0.12, Vector3(0, 0.045, 0), Color(0.5, 0.5, 0.56), Vector3.ZERO, Vector3(1, 0.05, 1))
		for k in 4:
			var a := k * PI * 0.5
			b.box(Vector3(6, 0.03, 60), Vector3(cos(a) * 55.0, 0.015, sin(a) * 55.0), Color(0.42, 0.44, 0.5), Vector3(0, rad_to_deg(a) + 90.0, 0))
		return b.build()), self)
	plaza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the tower
	MeshBuilder.node(Models.cached("hq_tower", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var glass := Color(0.45, 0.62, 0.88)
		b.box(Vector3(8.4, 0.6, 8.4), Vector3(0, 0.3, 0), Color(0.75, 0.75, 0.8))
		b.box(Vector3(6.4, 7.0, 6.4), Vector3(0, 4.1, 0), glass)
		for f in 5:
			b.box(Vector3(6.5, 0.12, 6.5), Vector3(0, 1.4 + f * 1.4, 0), Color(0.9, 0.92, 0.96))
		for side in 4:
			for c in 4:
				var off := -2.4 + c * 1.6
				var pos := Vector3(off, 4.1, 3.21) if side == 0 else (Vector3(off, 4.1, -3.21) if side == 1 else (Vector3(3.21, 4.1, off) if side == 2 else Vector3(-3.21, 4.1, off)))
				var sz := Vector3(0.1, 7.0, 0.05) if side < 2 else Vector3(0.05, 7.0, 0.1)
				b.box(sz, pos, Color(0.85, 0.88, 0.95))
		b.box(Vector3(6.8, 0.5, 6.8), Vector3(0, 7.85, 0), Models.C_GOLD)
		b.cyl(2.0, 2.0, 0.08, Vector3(0, 8.14, 0), Color(0.25, 0.25, 0.3), Vector3.ZERO, 20)
		b.box(Vector3(0.3, 0.02, 1.6), Vector3(-0.5, 8.19, 0), Color(1, 1, 1))
		b.box(Vector3(0.3, 0.02, 1.6), Vector3(0.5, 8.19, 0), Color(1, 1, 1))
		b.box(Vector3(1.0, 0.02, 0.3), Vector3(0, 8.19, 0), Color(1, 1, 1))
		b.cyl(0.06, 0.08, 2.5, Vector3(2.6, 9.3, -2.6), Color(0.8, 0.8, 0.85), Vector3.ZERO, 6)
		b.sphere(0.15, Vector3(2.6, 10.6, -2.6), Color(1, 0.2, 0.2))
		b.box(Vector3(2.2, 2.4, 0.1), Vector3(0, 1.2, 3.25), Color(0.3, 0.4, 0.6))
		return b.build()), self)
	var badge := Sprite3D.new()
	badge.texture = load("res://assets/logo/logo_badge.png")
	badge.pixel_size = 2.4 / 512.0
	badge.position = Vector3(-1.6, 6.0, 3.3)
	add_child(badge)
	_company = Fx.label3d(Game.company, 80, Color(1, 0.85, 0.3), 16)
	_company.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_company.position = Vector3(1.2, 6.0, 3.3)
	add_child(_company)
	var hq_label := Fx.label3d("GLOBAL HQ", 60, Color(1, 1, 1), 14)
	hq_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	hq_label.position = Vector3(0, 3.3, 3.3)
	add_child(hq_label)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(7.2, 8.0, 7.2)
	cs.shape = bs
	cs.position.y = 4.0
	body.add_child(cs)
	add_child(body)
	# tower health bar
	var bg := Sprite3D.new()
	bg.texture = Items.icon("fx_fill")
	bg.modulate = Color(0.1, 0.08, 0.12, 0.85)
	bg.pixel_size = 0.03
	bg.scale = Vector3(1.0, 0.16, 1)
	bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bg.no_depth_test = true
	bg.render_priority = 5
	bg.position = Vector3(0, 11.5, 0)
	add_child(bg)
	_hp_fill = Sprite3D.new()
	_hp_fill.texture = Items.icon("fx_fill")
	_hp_fill.modulate = Color(0.35, 0.9, 0.35)
	_hp_fill.pixel_size = 0.03
	_hp_fill.scale = Vector3(0.94, 0.11, 1)
	_hp_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_fill.no_depth_test = true
	_hp_fill.render_priority = 6
	_hp_fill.position = Vector3(0, 11.5, 0.05)
	add_child(_hp_fill)
	# umbrella shield dome
	_dome = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = SHIELD_R
	sm.height = SHIELD_R
	sm.is_hemisphere = true
	sm.radial_segments = 32
	sm.rings = 12
	_dome.mesh = sm
	_dome_mat = StandardMaterial3D.new()
	_dome_mat.albedo_color = Color(0.4, 0.7, 1.0, 0.1)
	_dome_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dome_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dome_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dome.material_override = _dome_mat
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dome.visible = false
	add_child(_dome)
	# weapon pads: inner and outer ring
	for k in 6:
		var a := deg_to_rad(30.0 + k * 60.0)
		pads.append(Vector3(cos(a) * 11.0, 0, sin(a) * 11.0))
	for k in 6:
		var a2 := deg_to_rad(k * 60.0)
		pads.append(Vector3(cos(a2) * 18.5, 0, sin(a2) * 18.5))
	for i in pads.size():
		_pad_marker(pads[i], 2.0, "turret", Color(1, 1, 1, 0.9))
	_pad_marker(CMD_PAD, 1.1, "w_armor", Color(0.7, 0.85, 1.0, 0.95))
	var cl := Fx.label3d("COMMAND CENTER", 34, Color(0.8, 0.9, 1.0), 10)
	cl.position = CMD_PAD + Vector3(0, 1.3, 0)
	add_child(cl)
	# limo home
	MeshBuilder.node(Models.cached("limo", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var black := Color(0.08, 0.08, 0.1)
		b.box(Vector3(1.8, 0.7, 5.2), Vector3(3.2, 0.6, 23.5), black)
		b.box(Vector3(1.6, 0.55, 3.2), Vector3(3.2, 1.2, 23.7), Color(0.12, 0.12, 0.15))
		b.box(Vector3(1.62, 0.35, 3.0), Vector3(3.2, 1.25, 23.7), Color(0.4, 0.5, 0.65))
		for z in [21.6, 25.4]:
			for x in [2.3, 4.1]:
				b.cyl(0.35, 0.35, 0.22, Vector3(x, 0.35, z), Color(0.2, 0.2, 0.22), Vector3(0, 0, 90), 12)
		b.box(Vector3(0.2, 0.1, 0.05), Vector3(3.2, 0.9, 20.88), Models.C_GOLD)
		return b.build()), self)
	_pad_marker(LIMO_PAD, 1.0, "ui_up", Color(1.0, 0.9, 0.6, 0.95))
	var ll := Fx.label3d("Limo to the bakery", 32, Color(1, 1, 1), 10)
	ll.position = LIMO_PAD + Vector3(0, 1.4, 0)
	add_child(ll)
	# city skyline + bushes around the plaza
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var cols := [Color(0.72, 0.8, 0.95), Color(0.95, 0.8, 0.7), Color(0.85, 0.85, 0.9), Color(0.8, 0.92, 0.8)]
	for k in 26:
		var a3 := k * TAU / 26.0 + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(38.0, 52.0)
		var w := snappedf(rng.randf_range(6, 10), 0.5)
		var h := snappedf(rng.randf_range(8, 24), 0.5)
		var bm := MeshBuilder.node(Models.building_mesh(w, w, h, cols[k % cols.size()], k % 5), self)
		bm.position = Vector3(cos(a3) * r, 0, sin(a3) * r)
		bm.rotation.y = -a3 - PI * 0.5
	for k in 40:
		var a4 := k * TAU / 40.0
		var bu := MeshBuilder.node(Models.bush_mesh(), self)
		bu.position = Vector3(cos(a4) * (BOUND_R + 0.6), 0, sin(a4) * (BOUND_R + 0.6))
	for k in 36:
		var a5 := k * TAU / 36.0
		var wall := StaticBody3D.new()
		var wcs := CollisionShape3D.new()
		var wbs := BoxShape3D.new()
		wbs.size = Vector3(5.0, 2.0, 0.5)
		wcs.shape = wbs
		wall.add_child(wcs)
		wall.position = Vector3(cos(a5) * BOUND_R, 1.0, sin(a5) * BOUND_R)
		wall.rotation.y = -a5 + PI * 0.5
		add_child(wall)
	Game.company_changed.connect(func(n: String) -> void: _company.text = n)


func _pad_marker(p: Vector3, r: float, icon: String, color: Color) -> void:
	var m := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(r * 2.0, r * 2.0)
	m.mesh = q
	m.material_override = Station.pad_material(color)
	m.position = p + Vector3(0, 0.05, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var s := Sprite3D.new()
	s.texture = Items.icon(icon)
	s.axis = Vector3.AXIS_Y
	s.pixel_size = r * 0.7 / 128.0
	s.position = p + Vector3(0, 0.06, r * 0.55)
	s.shaded = false
	add_child(s)


# -------------------------------------------------------------- weapons --
func build_weapon(slot: int, type: String) -> bool:
	if weapons.has(slot):
		return false
	var cost := int(WarData.WEAPONS[type]["cost"])
	if not Game.spend(cost):
		return false
	_place_weapon(slot, type, 1, true)
	_save_weapons()
	return true


func upgrade_weapon(slot: int) -> bool:
	if not weapons.has(slot):
		return false
	var w: HQWeapon = weapons[slot]
	if w.level >= WarData.MAX_LEVEL:
		return false
	if not Game.spend(WarData.upgrade_cost(w.type, w.level)):
		return false
	w.set_level(w.level + 1)
	Sfx.play("unlock", -4.0, 1.2)
	_save_weapons()
	return true


func _place_weapon(slot: int, type: String, level: int, animate: bool) -> void:
	var w := HQWeapon.new()
	add_child(w)
	w.position = pads[slot]
	w.rotation.y = atan2(pads[slot].x, pads[slot].z)
	w.setup(self, type, level, slot)
	weapons[slot] = w
	if animate:
		Fx.pop_in(w, 0.5)
		Fx.confetti(w.global_position + Vector3(0, 1, 0), 40)
		Sfx.play("thud", -4.0)
		Sfx.play("unlock", -4.0)
	if type == "shield":
		shield_hp = shield_max()


func _save_weapons() -> void:
	var d := {}
	for s in weapons:
		var w: HQWeapon = weapons[s]
		d[str(s)] = {"type": w.type, "level": w.level}
	Game.war["weapons"] = d
	Game.save_game()


func buy_hq_upgrade(k: String) -> bool:
	var lvl := upg(k)
	var d: Dictionary = WarData.HQ_UPGRADES[k]
	if lvl >= int(d["max"]):
		return false
	if not Game.spend(WarData.hq_upgrade_cost(k, lvl)):
		return false
	(Game.war["upg"] as Dictionary)[k] = lvl + 1
	if k == "armor":
		hq_hp += 600.0
	Sfx.play("unlock", -4.0, 1.2)
	Game.save_game()
	return true


# ----------------------------------------------------------------- tick --
func tick(delta: float) -> void:
	if not active():
		return
	# repairs + shield
	_regen_t += delta
	if _regen_t >= 1.0:
		_regen_t -= 1.0
		hq_hp = minf(max_hp(), hq_hp + 2.0 + 6.0 * upg("repair"))
	var smax := shield_max()
	if smax > 0.0:
		_shield_t += delta
		if _shield_t >= 2.5:
			_shield_t = 0.0
			shield_hp = minf(smax, shield_hp + 1.0)
	_dome.visible = smax > 0.0 and shield_hp > 0.0
	_hp_fill.scale.x = 0.94 * clampf(hq_hp / max_hp(), 0.0, 1.0)
	_hp_fill.modulate = Color(0.35, 0.9, 0.35) if hq_hp > max_hp() * 0.35 else Color(1, 0.35, 0.3)
	Game.war["hq_hp"] = hq_hp
	# the Clan bombs your restaurants worldwide every few minutes
	city_t -= delta
	if city_t <= 0.0:
		city_t = randf_range(140.0, 200.0)
		bomb_cities(1 + wave_number() / 4)
	_purge()
	if not player_here():
		return
	# spawning
	if not _to_spawn.is_empty():
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = 0.35
			_spawn(_to_spawn.pop_front())
	match phase:
		"calm":
			next_wave -= delta
			if next_wave <= 0.0:
				phase = "warn"
				warn_t = 8.0 + 4.0 * upg("radar")
				Sfx.play("siren", -2.0)
		"warn":
			warn_t -= delta
			if warn_t <= 0.0:
				_start_wave()
		"wave":
			if enemies.is_empty() and _to_spawn.is_empty():
				_end_wave()


func _physics_process(_delta: float) -> void:
	if not active() or not player_here():
		_was_on.clear()
		return
	var p: Vector3 = (world.get("player") as Node3D).global_position - ORIGIN
	var flat := Vector2(p.x, p.z)
	for i in pads.size():
		var on := flat.distance_to(Vector2(pads[i].x, pads[i].z)) < 2.0
		if on and not bool(_was_on.get(i, false)) and Game.hud != null and not bool(Game.hud.call("is_busy")):
			Game.hud.call("war_pad_menu", self, i)
		_was_on[i] = on
	var on_cmd := flat.distance_to(Vector2(CMD_PAD.x, CMD_PAD.z)) < 1.1
	if on_cmd and not bool(_was_on.get("cmd", false)) and Game.hud != null:
		Game.hud.call("war_command_menu", self)
	_was_on["cmd"] = on_cmd
	var on_limo := flat.distance_to(Vector2(LIMO_PAD.x, LIMO_PAD.z)) < 1.0
	if on_limo and not bool(_was_on.get("limo", false)):
		world.call("travel", "bakery")
	_was_on["limo"] = on_limo


func _start_wave() -> void:
	phase = "wave"
	var n := wave_number()
	final_wave = float(Game.war["strength"]) <= 20.0
	_to_spawn.clear()
	if final_wave:
		_to_spawn.append("king")
		for i in 6:
			_to_spawn.append("bomber")
			_to_spawn.append("commando")
		_to_spawn.append("heavy")
		_to_spawn.append("heavy")
		Sfx.play("caw", 0.0, 0.6)
		if Game.hud != null:
			Game.hud.call("big_card", "FINAL BATTLE!", "The Crow King attacks!", "Defeat him to destroy the Crow Clan forever.", "portrait_crow")
	else:
		for i in 2 + n:
			_to_spawn.append("bomber")
		for i in 2 + n:
			_to_spawn.append("commando")
		for i in maxi(0, n - 2):
			_to_spawn.append("heavy")
		if n % 5 == 0:
			_to_spawn.insert(0, "warlord")
		_to_spawn.shuffle()
		Sfx.play("caw", -2.0, 0.85)
	Game.log_line("[war] wave %d start (%d crows)%s" % [n, _to_spawn.size(), " FINAL" if final_wave else ""])


func _spawn(kind: String) -> void:
	var c := WarCrow.new()
	add_child(c)
	c.setup(self, ORIGIN, kind, wave_number())
	enemies.append(c)


func summon(count: int) -> void:
	for i in count:
		_spawn("commando")


func enemy_gone(e: Node, _escaped: bool) -> void:
	enemies.erase(e)


func _end_wave() -> void:
	var n := wave_number()
	phase = "calm"
	next_wave = randf_range(50.0, 70.0)
	Game.war["wave"] = n
	if final_wave:
		_victory()
		return
	var hit := 12.0 if n % 5 == 0 else 7.0
	Game.war["strength"] = maxf(5.0, float(Game.war["strength"]) - hit)
	var reward := 40000 * n
	Game.add_money(reward)
	var cleaned := 0
	for city in (Game.war["bombed"] as Dictionary).keys():
		if cleaned >= 2:
			break
		(Game.war["bombed"] as Dictionary).erase(city)
		cleaned += 1
	Game.log_line("[war] wave %d won: clan %.0f%%, hq %.0f/%.0f, money %d" % [n, float(Game.war["strength"]), hq_hp, max_hp(), Game.money])
	if Game.hud != null:
		var extra := " %d cities cleaned." % cleaned if cleaned > 0 else ""
		Game.hud.call("toast", "Wave %d defeated! +$%s. Crow Clan down to %d%%.%s" % [n, Game.fmt(reward), int(float(Game.war["strength"])), extra], "security")
	Sfx.play("fanfare", -4.0)
	Game.save_game()


func _victory() -> void:
	Game.war["won"] = true
	Game.war["strength"] = 0.0
	Game.war["bombed"] = {}
	Game.set_flag("war_won")
	Game.log_line("[war] VICTORY: the Crow Clan is destroyed")
	for k in 8:
		Fx.confetti(ORIGIN + Vector3(randf_range(-10, 10), 4, randf_range(-10, 10)), 70, 70.0)
	Sfx.play("fanfare", 0.0)
	Game.save_game()
	world.call("war_victory")


func _overrun() -> void:
	var lost := int(Game.money * 0.10)
	Game.add_money(-lost)
	Game.war["strength"] = minf(100.0, float(Game.war["strength"]) + 5.0)
	for e in enemies.duplicate():
		if is_instance_valid(e):
			(e as Node).queue_free()
	enemies.clear()
	_to_spawn.clear()
	phase = "calm"
	next_wave = 60.0
	hq_hp = max_hp() * 0.6
	final_wave = false
	Sfx.play("nope", 0.0)
	Game.log_line("[war] HQ OVERRUN: lost $%d, clan back to %.0f%%" % [lost, float(Game.war["strength"])])
	if Game.hud != null:
		Game.hud.call("big_card", "HQ OVERRUN!", "-$" + Game.fmt(lost), "The crows looted your tower. Build more defences!", "portrait_crow")


# ---------------------------------------------------------------- combat --
func damage_hq(n: float, _from: Vector3) -> void:
	if not active():
		return
	hq_hp -= n
	if hq_hp <= 0.0:
		_overrun()


func drop_bomb(from: Vector3, mega: bool) -> void:
	var b := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5 if mega else 0.25
	sm.height = sm.radius * 2.2
	b.mesh = sm
	b.material_override = HQWeapon.ammo_material(Color(0.95, 0.94, 0.86))
	add_child(b)
	b.global_position = from
	var land := Vector3(from.x + randf_range(-1.0, 1.0), 0.0, from.z + randf_range(-1.0, 1.0))
	var fall := func(t: float) -> void:
		b.global_position = from.lerp(land, t * t)
	var hit := func() -> void:
		_bomb_hits(land, mega)
		b.queue_free()
	var tw := b.create_tween()
	tw.tween_method(fall, 0.0, 1.0, 0.75)
	tw.tween_callback(hit)


func _bomb_hits(at: Vector3, mega: bool) -> void:
	var rel := at - ORIGIN
	var dist := Vector2(rel.x, rel.z).length()
	Sfx.play("splat", -4.0 if mega else -8.0, randf_range(0.8, 1.1), 0.05)
	if dist <= SHIELD_R and shield_hp > 0.0 and shield_max() > 0.0:
		shield_hp = maxf(0.0, shield_hp - (3.0 if mega else 1.0))
		_dome_mat.albedo_color = Color(0.6, 0.85, 1.0, 0.45)
		var tw := create_tween()
		tw.tween_property(_dome_mat, "albedo_color", Color(0.4, 0.7, 1.0, 0.16), 0.4)
		Fx.poof(at + Vector3(0, SHIELD_R * 0.6, 0), Color(0.6, 0.85, 1.0), 6, 0.3)
		return
	_splat_decal(at, mega)
	if dist <= 4.6:
		damage_hq((45.0 if mega else 12.0 + wave_number()), at)
	for s in weapons:
		var w: HQWeapon = weapons[s]
		if w.global_position.distance_to(at) < (3.0 if mega else 2.0):
			w.splat(10.0 if mega else 6.0)
	var pl: Node3D = world.get("player")
	if pl.global_position.distance_to(at) < (2.5 if mega else 1.5):
		pl.set("slow_t", 3.0)
		Fx.float_text(pl.global_position + Vector3(0, 2.4, 0), "EWW!", Color(0.95, 0.95, 0.85), 60)


func _splat_decal(at: Vector3, mega: bool) -> void:
	var d := MeshBuilder.node(HQWeapon.splat_mesh(), self)
	var rel := at - ORIGIN
	if Vector2(rel.x, rel.z).length() < 3.6:
		# landed on the tower roof
		d.global_position = Vector3(at.x, 8.2, at.z)
	else:
		d.global_position = Vector3(at.x, 0.06, at.z)
	d.scale = Vector3.ONE * (2.2 if mega else 1.1) * Vector3(1, 0.4, 1)
	d.rotation.y = randf() * TAU
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(_splats.size() - 1, -1, -1):
		if not is_instance_valid(_splats[i]):
			_splats.remove_at(i)
	_splats.append(d)
	if _splats.size() > 50:
		var old: Variant = _splats.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()
	var tw := d.create_tween()
	tw.tween_interval(18.0)
	tw.tween_property(d, "scale", Vector3.ZERO, 1.0)
	tw.tween_callback(d.queue_free)


func nearest_enemy(pos: Vector3, max_d: float, tgt: String) -> WarCrow:
	var best: WarCrow = null
	var best_d := max_d * max_d
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var c := e as WarCrow
		if c == null or c.dead:
			continue
		if tgt == "air" and not c.is_air():
			continue
		if tgt == "ground" and c.is_air():
			continue
		var d := c.global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = c
	return best


func enemies_near(pos: Vector3, r: float, tgt: String) -> Array:
	var out: Array = []
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var c := e as WarCrow
		if c == null or c.dead:
			continue
		if tgt == "air" and not c.is_air():
			continue
		if tgt == "ground" and c.is_air():
			continue
		if c.global_position.distance_to(pos) <= r:
			out.append(c)
	return out


func alive() -> int:
	return enemies.size() + _to_spawn.size()


func _purge() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[i]):
			enemies.remove_at(i)


# ---------------------------------------------------------------- cities --
func bomb_cities(count: int) -> void:
	if not bool(Game.ceo["deal"]):
		return
	var bombed: Dictionary = Game.war["bombed"]
	var free: Array[String] = []
	for c in Investors.CITIES:
		if not bombed.has(str(c[0])):
			free.append(str(c[0]))
	free.shuffle()
	var hit: Array[String] = []
	for i in mini(count, free.size()):
		bombed[free[i]] = true
		hit.append(free[i])
	if hit.is_empty():
		return
	Game.log_line("[war] cities bombed: %s" % str(hit))
	if Game.hud != null:
		Game.hud.call("toast", "Crow bombers pooped on %s! Income down there." % ", ".join(hit), "portrait_crow")


static func clean_cost(i: int) -> int:
	var lvl := int((Game.ceo["cities"] as Dictionary).get(str(Investors.CITIES[i][0]), 1))
	return Game.nice_number(Investors.upgrade_cost(i, lvl) * 0.35)
