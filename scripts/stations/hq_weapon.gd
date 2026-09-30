class_name HQWeapon
extends Node3D
## A pigeon weapon on one of the HQ tower's defence pads. Targets crows of
## the right kind (ground / air) in range and fires cartoon ammo at them:
## seeds, baguettes, feathers, coo shockwaves, birdseed missiles. The hangar
## and tank depot instead deploy units (WarUnit). Poop hits disable it for a bit.

var war: Node = null
var type := "slingshot"
var level := 1
var slot := 0
var disabled_t := 0.0
var _fire_t := 0.0
var _head: Node3D
var _splat: Node3D
var _units: Array[Node] = []
var _lvl_label: Label3D

static var _ammo_mat := {}


func setup(w: Node, t: String, lvl: int, s: int) -> void:
	war = w
	type = t
	level = lvl
	slot = s
	_build()


func def() -> Dictionary:
	return WarData.WEAPONS[type]


func _build() -> void:
	_head = Node3D.new()
	add_child(_head)
	match type:
		"slingshot":
			var base := MeshBuilder.node(Turret.base_mesh(), self)
			base.scale = Vector3.ONE * 1.3
			_head.position = Vector3(0, 2.2, 0)
			var h := MeshBuilder.node(Turret.head_mesh(), _head)
			h.scale = Vector3.ONE * 1.3
		"baguette":
			MeshBuilder.node(Models.cached("w_baguette_base", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.box(Vector3(1.4, 0.5, 1.6), Vector3(0, 0.45, 0), Color(0.45, 0.35, 0.25))
				for x in [-0.8, 0.8]:
					b.cyl(0.45, 0.45, 0.18, Vector3(x, 0.45, 0.2), Color(0.3, 0.22, 0.15), Vector3(0, 0, 90), 12)
				return b.build()), self)
			_head.position = Vector3(0, 0.9, 0)
			MeshBuilder.node(Models.cached("w_baguette_barrel", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.capsule(0.26, 2.2, Vector3(0, 0.35, -0.6), Color(0.88, 0.58, 0.26), Vector3(-65, 0, 0))
				for k in 4:
					b.box(Vector3(0.3, 0.04, 0.06), Vector3(0, 0.55 + k * 0.28, -0.45 - k * 0.14), Color(0.99, 0.84, 0.58), Vector3(-65, 0, 25))
				return b.build()), _head)
		"flak":
			MeshBuilder.node(Models.cached("w_flak_base", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.cyl(0.8, 1.0, 0.7, Vector3(0, 0.35, 0), Models.C_METAL_DARK, Vector3.ZERO, 12)
				return b.build()), self)
			_head.position = Vector3(0, 0.9, 0)
			MeshBuilder.node(Models.cached("w_flak_head", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.box(Vector3(1.0, 0.6, 0.8), Vector3(0, 0.3, 0), Color(0.5, 0.55, 0.62))
				for x in [-0.3, -0.1, 0.1, 0.3]:
					b.cyl(0.05, 0.05, 1.3, Vector3(x, 0.75, -0.55), Color(0.2, 0.2, 0.24), Vector3(-55, 0, 0), 6)
				for x in [-0.55, 0.55]:
					b.sphere(0.5, Vector3(x, 0.55, 0.3), Color(0.95, 0.95, 1.0), Vector3(0.12, 0.5, 0.25), Vector3(0, 0, x * 40.0))
				return b.build()), _head)
		"sonic":
			MeshBuilder.node(Models.cached("w_sonic", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.cyl(0.7, 0.8, 0.4, Vector3(0, 0.2, 0), Color(0.55, 0.3, 0.6), Vector3.ZERO, 12)
				b.cyl(0.12, 0.14, 3.2, Vector3(0, 1.8, 0), Color(0.7, 0.7, 0.75), Vector3.ZERO, 8)
				for k in 3:
					var a := k * 120.0
					var dir := Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a)))
					b.cyl(0.5, 0.12, 0.9, Vector3(0, 3.0, 0) + dir * 0.5, Color(0.95, 0.8, 0.2), Vector3(90, a, 0), 12)
				return b.build()), self)
			var bird := PigeonRig.new("std")
			bird.position = Vector3(0, 3.4, 0)
			bird.scale = Vector3.ONE * 0.9
			add_child(bird)
		"missile":
			MeshBuilder.node(Models.cached("w_missile", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.cyl(1.2, 1.3, 0.5, Vector3(0, 0.25, 0), Color(0.62, 0.62, 0.66), Vector3.ZERO, 16)
				b.cyl(0.9, 0.9, 0.05, Vector3(0, 0.52, 0), Color(0.25, 0.25, 0.3), Vector3.ZERO, 16)
				for x in [-0.4, 0.4]:
					b.capsule(0.22, 1.6, Vector3(x, 1.2, 0), Color(0.95, 0.85, 0.5))
					b.cyl(0.0, 0.2, 0.3, Vector3(x, 2.05, 0), Color(0.9, 0.3, 0.2), Vector3.ZERO, 8)
					b.box(Vector3(0.6, 0.3, 0.05), Vector3(x, 0.6, 0), Color(0.9, 0.3, 0.2))
				return b.build()), self)
		"shield":
			MeshBuilder.node(Models.cached("w_shield", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.cyl(0.6, 0.7, 0.3, Vector3(0, 0.15, 0), Models.C_METAL_DARK, Vector3.ZERO, 12)
				b.cyl(0.08, 0.08, 3.4, Vector3(0, 1.9, 0), Color(0.3, 0.3, 0.35), Vector3.ZERO, 8)
				b.cyl(0.0, 1.3, 0.9, Vector3(0, 3.6, 0), Color(0.3, 0.6, 1.0), Vector3.ZERO, 10)
				b.sphere(0.12, Vector3(0, 4.1, 0), Color(0.6, 0.9, 1.0))
				return b.build()), self)
		"hangar":
			MeshBuilder.node(Models.cached("w_hangar", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.cyl(1.5, 1.5, 3.2, Vector3(0, 0.1, 0), Color(0.55, 0.6, 0.5), Vector3(90, 0, 0), 12)
				b.box(Vector3(3.2, 0.2, 3.4), Vector3(0, -0.05, 0), Color(0.35, 0.37, 0.4))
				b.box(Vector3(2.0, 1.2, 0.05), Vector3(0, 0.6, 1.62), Color(0.2, 0.22, 0.2))
				return b.build()), self)
			for k in 3:
				_spawn_unit("fighter", k)
		"tank":
			MeshBuilder.node(Models.cached("w_tankdepot", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.box(Vector3(3.0, 1.6, 2.4), Vector3(0, 0.8, 0), Color(0.45, 0.5, 0.35))
				b.box(Vector3(2.2, 1.2, 0.05), Vector3(0, 0.6, 1.21), Color(0.3, 0.33, 0.25))
				for k in 5:
					b.box(Vector3(2.1, 0.04, 0.06), Vector3(0, 0.2 + k * 0.22, 1.24), Color(0.38, 0.42, 0.3))
				return b.build()), self)
			for k in 2:
				_spawn_unit("tank", k)
	_splat = MeshBuilder.node(splat_mesh(), self)
	_splat.position = Vector3(0, 1.6, 0)
	_splat.visible = false
	_lvl_label = Fx.label3d("", 34, Color(1, 0.95, 0.6), 10)
	_lvl_label.position = Vector3(0, 4.6 if type in ["sonic", "shield"] else 3.3, 0)
	add_child(_lvl_label)
	_refresh_label()
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.2, 2.0, 2.2) if type in ["hangar", "tank"] else Vector3(1.3, 2.0, 1.3)
	if type in ["hangar", "tank"]:
		bs.size = Vector3(3.0, 2.0, 3.0)
	cs.shape = bs
	cs.position.y = 1.0
	body.add_child(cs)
	add_child(body)


static func splat_mesh() -> ArrayMesh:
	return Models.cached("splat", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.sphere(0.5, Vector3.ZERO, Color(0.97, 0.96, 0.9), Vector3(1.4, 0.35, 1.2))
		for k in 5:
			var a := k * 1.3
			b.sphere(0.14, Vector3(cos(a) * 0.7, -0.05, sin(a) * 0.6), Color(0.95, 0.94, 0.86))
		b.sphere(0.2, Vector3(0.1, 0.12, 0.05), Color(0.55, 0.45, 0.3), Vector3(1, 0.5, 1))
		return b.build())


func _refresh_label() -> void:
	_lvl_label.text = "%s  Lv%d" % [str(def()["name"]).split(" ")[0], level]


func set_level(l: int) -> void:
	level = l
	_refresh_label()
	Fx.squash(self, 0.2, 0.4)


func _spawn_unit(kind: String, k: int) -> void:
	var u := WarUnit.new()
	war.get("root").add_child(u)
	u.setup(war, self, kind, k)
	_units.append(u)


func splat(secs: float) -> void:
	var rep := int(Game.war["upg"].get("repair", 0))
	disabled_t = maxf(disabled_t, secs / (1.0 + 0.3 * rep))
	_splat.visible = true


func range_m() -> float:
	return float(def()["range"]) * (1.0 + 0.05 * (level - 1))


func damage() -> float:
	return float(def()["dmg"]) * WarData.level_mult(level)


func rate() -> float:
	return float(def()["rate"]) / (1.0 + 0.25 * (level - 1))


func _process(delta: float) -> void:
	if disabled_t > 0.0:
		disabled_t -= delta
		if disabled_t <= 0.0:
			_splat.visible = false
			Fx.sparkle(global_position + Vector3(0, 1.6, 0), 6)
		return
	var tgt_kind := str(def()["target"])
	if tgt_kind == "none" or type in ["hangar", "tank"]:
		return
	_fire_t -= delta
	var target: WarCrow = war.call("nearest_enemy", global_position, range_m(), tgt_kind)
	if target == null:
		_head.rotation.y += delta * 0.3
		return
	var to := target.global_position - global_position
	_head.rotation.y = lerp_angle(_head.rotation.y, atan2(-to.x, -to.z), clampf(delta * 10.0, 0.0, 1.0))
	if _fire_t > 0.0:
		return
	_fire_t = rate()
	match type:
		"sonic":
			_shockwave()
		_:
			_shoot(target)


func _shockwave() -> void:
	Sfx.play("coo1", 0.0, 0.5, 0.2)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.8, 0.3, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	war.get("root").add_child(ring)
	ring.global_position = global_position + Vector3(0, 1.5, 0)
	var r := range_m()
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(r, 2.0, r), 0.45)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(ring.queue_free)
	for e in war.call("enemies_near", global_position, r, "all"):
		var wc := e as WarCrow
		wc.slow(3.0)
		wc.hit(damage(), global_position)


static func ammo_material(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _ammo_mat.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		_ammo_mat[key] = m
	return _ammo_mat[key]


func _shoot(target: WarCrow) -> void:
	var from := global_position + Vector3(0, 2.2, 0)
	var ammo := MeshInstance3D.new()
	var dur := 0.3
	var arc := 1.0
	var mesh: Mesh
	match type:
		"baguette":
			var cm := CapsuleMesh.new()
			cm.radius = 0.16
			cm.height = 0.9
			mesh = cm
			ammo.material_override = ammo_material(Color(0.88, 0.58, 0.26))
			dur = 0.8
			arc = 5.0
			Sfx.play("thud", -8.0, 1.3, 0.1)
		"flak":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.05, 0.05, 0.5)
			mesh = bm
			ammo.material_override = ammo_material(Color(1, 1, 1))
			dur = 0.18
			arc = 0.0
			Sfx.play("twang", -14.0, 2.0, 0.05)
		"missile":
			var cm2 := CapsuleMesh.new()
			cm2.radius = 0.14
			cm2.height = 0.8
			mesh = cm2
			ammo.material_override = ammo_material(Color(0.95, 0.85, 0.5))
			dur = 1.1
			arc = 6.0
			Sfx.play("whoosh", -6.0, 1.4, 0.1)
		_:
			var sm := SphereMesh.new()
			sm.radius = 0.12
			sm.height = 0.24
			mesh = sm
			ammo.material_override = ammo_material(Color(0.95, 0.8, 0.35))
			Sfx.play("twang", -10.0, 1.1, 0.05)
	ammo.mesh = mesh
	war.get("root").add_child(ammo)
	ammo.global_position = from
	var wr: WeakRef = weakref(target)
	var dmg := damage()
	var splash := float(def().get("splash", 0.0))
	var last := {"p": target.global_position}
	var move := func(t: float) -> void:
		var tr := wr.get_ref() as WarCrow
		if tr != null and not tr.dead:
			last["p"] = tr.global_position + Vector3(0, 0.5 * tr.rig.scale.y, 0)
		var goal: Vector3 = last["p"]
		var p := from.lerp(goal, t) + Vector3.UP * sin(t * PI) * arc
		var step := p - ammo.global_position
		if step.length() > 0.001 and step.normalized().cross(Vector3.UP).length() > 0.01:
			ammo.look_at(p, Vector3.UP)
		ammo.global_position = p
	var land := func() -> void:
		var at: Vector3 = last["p"]
		if splash > 0.0:
			Fx.poof(at, Color(0.95, 0.8, 0.5), 10, 0.3)
			for e in war.call("enemies_near", at, splash, "ground"):
				(e as WarCrow).hit(dmg, at)
		else:
			var tr := wr.get_ref() as WarCrow
			if tr != null and not tr.dead:
				tr.hit(dmg, at)
		if type == "missile":
			Fx.poof(at, Color(1, 0.6, 0.2), 14, 0.35)
			Sfx.play("thud", -4.0, 0.8, 0.1)
		ammo.queue_free()
	var tw := ammo.create_tween()
	tw.tween_method(move, 0.0, 1.0, dur)
	tw.tween_callback(land)


func _exit_tree() -> void:
	for u in _units:
		if is_instance_valid(u):
			u.queue_free()
