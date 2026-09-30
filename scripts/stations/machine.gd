class_name Machine
extends Station
## Converts inputs into a product. Both hand-off spots face the yard (the
## camera): drop raw stuff on the LEFT pad, pick up products on the RIGHT pad.

const TRAY_Z := 1.25
const PAD_Z := 2.25
const PAD_X := 0.66

var inputs: Array[String] = []
var output := ""
var time := 1.5
var in_piles := {}          # type -> ItemPile
var out_pile: ItemPile
var progress := 0.0
var working := false
var _t := 0.0
var _glow_mat: StandardMaterial3D
var _anim := {}
var _max_label: Label3D


func build() -> void:
	for t in def["inputs"]:
		inputs.append(str(t))
	output = str(def["output"])
	time = float(def["time"])
	var model := str(def["model"])
	_build_model(model)
	# trays
	MeshBuilder.node(Models.cached("trays", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		for x in [-0.62, 0.62]:
			b.box(Vector3(1.15, 0.3, 0.72), Vector3(x, 0.15, TRAY_Z), Models.C_METAL)
			b.box(Vector3(1.19, 0.05, 0.76), Vector3(x, 0.31, TRAY_Z), Models.C_METAL_DARK)
			for k in 4:
				b.cyl(0.03, 0.03, 1.05, Vector3(x, 0.335, TRAY_Z - 0.27 + k * 0.18), Color(0.3, 0.32, 0.38), Vector3(0, 0, 90), 6)
		return b.build()), self)
	# piles
	if inputs.size() == 1:
		var p := _make_pile(Vector3(-0.62, 0.36, TRAY_Z), 2, 2, 12, inputs[0])
		in_piles[inputs[0]] = p
	elif inputs.size() == 2:
		for k in inputs.size():
			var p := _make_pile(Vector3(-0.9 + k * 0.56, 0.36, TRAY_Z), 1, 2, 8, inputs[k])
			in_piles[inputs[k]] = p
	else:
		# up to 4 ingredients: a 2x2 grid of little stacks on the input tray
		for k in inputs.size():
			var pos := Vector3(-0.86 + (k % 2) * 0.48, 0.36, TRAY_Z - 0.17 + (k / 2) * 0.34)
			var p := _make_pile(pos, 1, 1, 6, inputs[k])
			in_piles[inputs[k]] = p
	out_pile = _make_pile(Vector3(0.62, 0.36, TRAY_Z), 2, 2, 16, output)
	add_pad("in", Vector3(-PAD_X, 0, PAD_Z), 0.62, inputs[0])
	add_pad("out", Vector3(PAD_X, 0, PAD_Z), 0.62, output, Color(0.75, 1.0, 0.7, 0.95))
	# extra inputs get their icons around the first one on the same pad
	var offs := [Vector3(0.3, 0, 0.3), Vector3(-0.3, 0, 0.3), Vector3(0.3, 0, -0.3)]
	for k in range(1, inputs.size()):
		var s := Sprite3D.new()
		s.texture = Items.icon(inputs[k])
		s.axis = Vector3.AXIS_Y
		s.pixel_size = 0.32 / 128.0
		s.position = Vector3(-PAD_X, 0.05, PAD_Z) + (offs[k - 1] as Vector3)
		s.shaded = false
		add_child(s)
	add_collider(Vector3(2.4, 1.3, 2.75), Vector3(0, 0, 0.25))
	_max_label = Fx.label3d("FULL", 44, Color(1.0, 0.45, 0.35))
	_max_label.position = Vector3(0.62, 1.55, TRAY_Z)
	_max_label.visible = false
	add_child(_max_label)


func _make_pile(pos: Vector3, c: int, r: int, cap: int, t: String) -> ItemPile:
	var p := ItemPile.new()
	p.cols = c
	p.rows = r
	p.spacing = Vector2(0.44, 0.3)
	p.layer_h = Items.height(t)
	p.capacity = cap
	p.jitter = 0.15
	p.position = pos
	add_child(p)
	return p


func _process(delta: float) -> void:
	_t += delta
	var can := not out_pile.is_full()
	for t in inputs:
		if (in_piles[t] as ItemPile).is_empty():
			can = false
	working = can
	if can:
		progress += delta * Game.machine_speed() / time
		if progress >= 1.0:
			progress = 0.0
			_produce()
	_max_label.visible = out_pile.is_full()
	if _max_label.visible:
		_max_label.position.y = 1.55 + sin(_t * 5.0) * 0.06
	_animate(delta)


func _produce() -> void:
	var mouth := to_global(Vector3(0, 0.9, 0.3))
	for t in inputs:
		var n := (in_piles[t] as ItemPile).take()
		if n != null:
			ItemPile.fly_away(n, mouth, 0.22, 0.4)
	out_pile.add_new(output, to_global(Vector3(0.2, 1.3, 0.2)), 0.35, 0.5)
	Game.stats["baked"] = int(Game.stats["baked"]) + 1
	if world != null:
		world.call("notify", "produced", self)


func service(a: Carrier, delta: float) -> void:
	if in_pad(a, "in"):
		for t in inputs:
			var p: ItemPile = in_piles[t]
			if p.is_full() or not a.pile.has_type(t) or not a.wants_drop(self, "in", t):
				continue
			if tick(a, "in_" + t, delta, a.interval()):
				a.pile.give_to(p, t, 0.24, 0.6)
				if a.is_player:
					Sfx.play("drop", -5.0, 0.95 + p.count() * 0.02)
					world.call("notify", "fed", self)
			break
	if in_pad(a, "out") and out_pile.count() > 0 and a.pile.room() > 0 and a.wants_pick(self, "out", output):
		if tick(a, "out", delta, a.interval()):
			out_pile.give_to(a.pile, output, 0.24, 0.6)
			if a.is_player:
				Sfx.play("pop", -4.0, 0.9 + a.pile.count() * 0.035)
				world.call("notify", "picked", self)


func input_room(t: String) -> int:
	if not in_piles.has(t):
		return 0
	return (in_piles[t] as ItemPile).room()


func fill_ratio(t: String) -> float:
	if not in_piles.has(t):
		return 1.0
	var p: ItemPile = in_piles[t]
	return float(p.count()) / float(p.capacity)


func save_state() -> Dictionary:
	var ins := {}
	for t in inputs:
		ins[t] = (in_piles[t] as ItemPile).count()
	return {"in": ins, "out": out_pile.count()}


func load_state(d: Dictionary) -> void:
	var ins: Dictionary = d.get("in", {})
	for t in inputs:
		for i in mini(int(ins.get(t, 0)), (in_piles[t] as ItemPile).capacity):
			(in_piles[t] as ItemPile).add_instant(t)
	for i in mini(int(d.get("out", 0)), out_pile.capacity):
		out_pile.add_instant(output)


# ------------------------------------------------------------- models ----
func _glow(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.albedo_color = Models.C_GLOW
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _glow_mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _smoke(pos: Vector3, color := Color(0.92, 0.92, 0.95)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = 0.18
	s.height = 0.36
	s.radial_segments = 8
	s.rings = 4
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	s.material = m
	p.mesh = s
	p.amount = 8
	p.lifetime = 1.6
	p.direction = Vector3(0.2, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0.25, 0.3, 0)
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(0.5, 1.0))
	c.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = c
	p.color = color
	p.position = pos
	p.emitting = false
	add_child(p)
	return p


func _build_model(model: String) -> void:
	var key := "machine_" + model
	match model:
		"oven":
			MeshBuilder.node(Models.cached(key, func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.box(Vector3(2.2, 1.3, 1.8), Vector3(0, 0.65, -0.2), Models.C_BRICK)
				b.box(Vector3(2.34, 0.16, 1.94), Vector3(0, 1.36, -0.2), Models.C_BRICK_DARK)
				b.box(Vector3(1.1, 0.62, 0.06), Vector3(0, 0.5, 0.7), Color(0.22, 0.12, 0.1))
				b.cyl(0.55, 0.55, 0.06, Vector3(0, 0.81, 0.7), Color(0.22, 0.12, 0.1), Vector3(90, 0, 0), 14)
				b.box(Vector3(1.3, 0.1, 0.2), Vector3(0, 0.16, 0.76), Models.C_BRICK_DARK)
				for p in [Vector3(-0.8, 1.0, 0.71), Vector3(0.75, 0.35, 0.71), Vector3(-0.7, 0.3, 0.71), Vector3(0.85, 1.05, 0.71)]:
					b.box(Vector3(0.3, 0.14, 0.03), p, Color(0.9, 0.52, 0.4))
				b.box(Vector3(0.44, 1.1, 0.44), Vector3(0.62, 1.95, -0.65), Models.C_BRICK_DARK)
				b.box(Vector3(0.56, 0.12, 0.56), Vector3(0.62, 2.52, -0.65), Color(0.4, 0.3, 0.28))
				b.sphere(0.2, Vector3(-0.6, 1.62, -0.3), Color(0.86, 0.55, 0.24), Vector3(1.6, 0.8, 1.0))
				return b.build()), self)
			_glow(Vector3(0.95, 0.5, 0.04), Vector3(0, 0.5, 0.72))
			_anim["smoke"] = _smoke(Vector3(0.62, 2.65, -0.65))
		"packer":
			MeshBuilder.node(Models.cached(key, func() -> ArrayMesh:
				var b := MeshBuilder.new()
				var teal := Color(0.3, 0.72, 0.8)
				b.box(Vector3(2.2, 1.1, 1.8), Vector3(0, 0.55, -0.2), teal)
				b.box(Vector3(2.3, 0.1, 1.9), Vector3(0, 1.12, -0.2), teal.darkened(0.25))
				b.cyl(0.6, 0.22, 0.75, Vector3(-0.45, 1.55, -0.35), Color(1.0, 0.8, 0.2), Vector3.ZERO, 12)
				b.cyl(0.62, 0.62, 0.08, Vector3(-0.45, 1.94, -0.35), Color(0.9, 0.65, 0.15), Vector3.ZERO, 12)
				b.box(Vector3(0.7, 0.7, 0.7), Vector3(0.5, 1.5, -0.3), Models.C_METAL)
				b.box(Vector3(1.4, 0.45, 0.04), Vector3(0, 0.6, 0.71), Color(0.7, 0.9, 1.0))
				for k in 6:
					b.box(Vector3(0.18, 0.14, 0.03), Vector3(-0.9 + k * 0.36, 0.14, 0.72),
						Color(0.15, 0.15, 0.18) if k % 2 == 0 else Color(1.0, 0.82, 0.2))
				b.cyl(0.08, 0.08, 0.06, Vector3(0.85, 0.95, 0.72), Color(1, 0.3, 0.3), Vector3(90, 0, 0), 8)
				b.cyl(0.08, 0.08, 0.06, Vector3(0.62, 0.95, 0.72), Color(0.3, 1, 0.4), Vector3(90, 0, 0), 8)
				return b.build()), self)
			var piston := MeshBuilder.node(Models.cached("piston", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.cyl(0.1, 0.1, 0.6, Vector3(0, 0.3, 0), Models.C_METAL_DARK, Vector3.ZERO, 8)
				b.box(Vector3(0.4, 0.12, 0.4), Vector3(0, 0.02, 0), Models.C_METAL_DARK)
				return b.build()), self)
			piston.position = Vector3(0.5, 1.2, 0.2)
			_anim["piston"] = piston
		"mill":
			MeshBuilder.node(Models.cached(key, func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.box(Vector3(2.2, 1.0, 1.8), Vector3(0, 0.5, -0.2), Models.C_WOOD)
				b.box(Vector3(2.3, 0.1, 1.9), Vector3(0, 1.02, -0.2), Models.C_FENCE_DARK)
				b.cyl(0.62, 0.86, 2.3, Vector3(0, 2.15, -0.35), Color(0.97, 0.92, 0.82), Vector3.ZERO, 12)
				b.cyl(0.0, 0.8, 1.0, Vector3(0, 3.8, -0.35), Color(0.9, 0.32, 0.28), Vector3.ZERO, 12)
				b.box(Vector3(0.5, 0.7, 0.05), Vector3(0, 0.4, 0.71), Color(0.55, 0.34, 0.2))
				b.box(Vector3(0.35, 0.35, 0.05), Vector3(0, 2.0, 0.34), Color(0.55, 0.75, 0.95))
				return b.build()), self)
			var sails := Node3D.new()
			sails.position = Vector3(0, 2.75, 0.42)
			add_child(sails)
			MeshBuilder.node(Models.cached("sails", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.cyl(0.14, 0.14, 0.2, Vector3(0, 0, 0), Models.C_WOOD, Vector3(90, 0, 0), 10)
				for k in 4:
					var a := k * 90.0
					var dir := Vector3(sin(deg_to_rad(a)), cos(deg_to_rad(a)), 0)
					b.box(Vector3(0.08, 1.6, 0.05), dir * 0.8 + Vector3(0, 0, 0.08), Color(0.5, 0.32, 0.2), Vector3(0, 0, -a))
					b.box(Vector3(0.42, 1.2, 0.03), dir * 0.95 + Vector3(0, 0, 0.1) + Vector3(cos(deg_to_rad(a)), -sin(deg_to_rad(a)), 0) * 0.22,
						Color(0.98, 0.96, 0.9), Vector3(0, 0, -a))
				return b.build()), sails)
			_anim["sails"] = sails
		"croissant_oven":
			MeshBuilder.node(Models.cached(key, func() -> ArrayMesh:
				var b := MeshBuilder.new()
				var cream := Color(0.99, 0.91, 0.76)
				var gold := Color(0.95, 0.72, 0.3)
				b.box(Vector3(2.2, 1.2, 1.8), Vector3(0, 0.6, -0.2), cream)
				b.dome(1.0, Vector3(0, 1.2, -0.2), gold, Vector3(1.1, 0.45, 0.9))
				b.box(Vector3(1.24, 0.66, 0.05), Vector3(0, 0.66, 0.7), gold)
				b.box(Vector3(2.24, 0.1, 1.84), Vector3(0, 0.08, -0.2), gold.darkened(0.2))
				for x in [-0.85, 0.85]:
					b.sphere(0.07, Vector3(x, 0.9, 0.72), gold.darkened(0.15))
				return b.build()), self)
			var orn := MeshBuilder.node(Models.item_mesh("croissant"), self)
			orn.position = Vector3(0, 1.62, -0.2)
			orn.scale = Vector3.ONE * 2.2
			_glow(Vector3(1.08, 0.5, 0.04), Vector3(0, 0.66, 0.73))
			_anim["smoke"] = _smoke(Vector3(0.0, 1.8, -0.4), Color(1.0, 0.95, 0.9))
		"fryer":
			MeshBuilder.node(Models.cached(key, func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.box(Vector3(2.2, 1.0, 1.8), Vector3(0, 0.5, -0.2), Models.C_METAL)
				b.box(Vector3(2.2, 0.9, 0.12), Vector3(0, 1.4, -1.04), Models.C_METAL_DARK)
				b.box(Vector3(1.6, 0.04, 1.1), Vector3(0, 1.0, -0.25), Color(1.0, 0.76, 0.22))
				for x in [-0.42, 0.42]:
					b.box(Vector3(0.62, 0.22, 0.85), Vector3(x, 1.08, -0.25), Color(0.3, 0.3, 0.34))
					b.cyl(0.03, 0.03, 0.55, Vector3(x, 1.12, 0.38), Color(0.15, 0.15, 0.2), Vector3(90, 0, 0), 6)
				b.box(Vector3(1.2, 0.35, 0.04), Vector3(0, 0.6, 0.71), Color(0.92, 0.18, 0.18))
				b.box(Vector3(0.9, 0.16, 0.05), Vector3(0, 0.6, 0.72), Color(1.0, 0.84, 0.25))
				return b.build()), self)
			var bub := CPUParticles3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.1
			sm.radial_segments = 6
			sm.rings = 3
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color(1.0, 0.9, 0.5)
			sm.material = bm
			bub.mesh = sm
			bub.amount = 16
			bub.lifetime = 0.5
			bub.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			bub.emission_box_extents = Vector3(0.7, 0.01, 0.45)
			bub.direction = Vector3.UP
			bub.initial_velocity_min = 0.3
			bub.initial_velocity_max = 0.6
			bub.gravity = Vector3.ZERO
			bub.position = Vector3(0, 1.03, -0.25)
			bub.emitting = false
			add_child(bub)
			_anim["bubbles"] = bub
			_anim["smoke"] = _smoke(Vector3(0, 1.5, -0.3), Color(1, 1, 1))
		"pie_oven":
			MeshBuilder.node(Models.cached(key, func() -> ArrayMesh:
				var b := MeshBuilder.new()
				var plum := Color(0.55, 0.3, 0.55)
				b.box(Vector3(2.3, 1.3, 1.9), Vector3(0, 0.65, -0.2), plum)
				b.box(Vector3(2.4, 0.14, 2.0), Vector3(0, 1.35, -0.2), Models.C_GOLD)
				b.box(Vector3(1.2, 0.62, 0.06), Vector3(0, 0.62, 0.72), Models.C_GOLD)
				b.cyl(0.62, 0.62, 0.06, Vector3(0, 0.93, 0.72), Models.C_GOLD, Vector3(90, 0, 0), 14)
				for x in [-0.75, 0.75]:
					b.cyl(0.14, 0.16, 0.9, Vector3(x, 1.85, -0.7), plum.darkened(0.25), Vector3.ZERO, 8)
					b.cyl(0.2, 0.2, 0.08, Vector3(x, 2.32, -0.7), Models.C_GOLD, Vector3.ZERO, 8)
				b.box(Vector3(2.0, 0.1, 0.05), Vector3(0, 0.12, 0.72), Models.C_GOLD)
				return b.build()), self)
			var orn := MeshBuilder.node(Models.item_mesh("pie"), self)
			orn.position = Vector3(0, 1.42, -0.2)
			orn.scale = Vector3.ONE * 2.6
			_glow(Vector3(1.0, 0.5, 0.04), Vector3(0, 0.6, 0.74))
			_anim["smoke"] = _smoke(Vector3(-0.75, 2.45, -0.7), Color(1.0, 0.92, 0.95))
		"pizza_oven":
			MeshBuilder.node(Models.cached(key, func() -> ArrayMesh:
				var b := MeshBuilder.new()
				b.box(Vector3(2.2, 0.8, 1.8), Vector3(0, 0.4, -0.2), Models.C_BRICK_DARK)
				b.dome(1.0, Vector3(0, 0.8, -0.25), Color(0.88, 0.5, 0.34), Vector3(1.0, 0.95, 0.85))
				b.box(Vector3(0.9, 0.5, 0.3), Vector3(0, 1.05, 0.5), Color(0.8, 0.44, 0.3))
				b.box(Vector3(0.7, 0.36, 0.06), Vector3(0, 1.02, 0.66), Color(0.2, 0.1, 0.08))
				b.cyl(0.13, 0.13, 1.0, Vector3(0.45, 2.1, -0.5), Models.C_METAL_DARK, Vector3.ZERO, 8)
				b.cyl(0.2, 0.2, 0.08, Vector3(0.45, 2.62, -0.5), Models.C_METAL_DARK, Vector3.ZERO, 8)
				b.box(Vector3(2.3, 0.08, 1.9), Vector3(0, 0.8, -0.2), Color(0.95, 0.9, 0.85))
				return b.build()), self)
			_glow(Vector3(0.62, 0.3, 0.04), Vector3(0, 1.0, 0.68))
			_anim["smoke"] = _smoke(Vector3(0.45, 2.75, -0.5))


func _animate(delta: float) -> void:
	if _glow_mat != null:
		var k := 1.0 if working else 0.45
		if working:
			k += sin(_t * 13.0) * 0.08 + sin(_t * 7.3) * 0.06
		var g := Models.C_GLOW
		_glow_mat.albedo_color = Color(minf(g.r * k, 1.0), g.g * k, g.b * k, 1.0)
	if _anim.has("smoke"):
		var s: CPUParticles3D = _anim["smoke"]
		if s.emitting != working:
			s.emitting = working
	if _anim.has("bubbles"):
		var bb: CPUParticles3D = _anim["bubbles"]
		if bb.emitting != working:
			bb.emitting = working
	if _anim.has("sails"):
		var sails: Node3D = _anim["sails"]
		sails.rotation.z -= delta * (2.2 if working else 0.25)
	if _anim.has("piston"):
		var pis: Node3D = _anim["piston"]
		var target := 1.2
		if working:
			target = 1.2 - absf(sin(_t * 7.0)) * 0.35
		pis.position.y = lerpf(pis.position.y, target, delta * 20.0)
