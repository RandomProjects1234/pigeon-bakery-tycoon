class_name WorldBuilder
extends RefCounted
## Builds the static scenery: ground, the bakery building with the company
## sign, the cafe terrace, fences, the back lot, and the town around it.

static func build(w: Node3D, nav: NavGrid) -> Dictionary:
	var out := {}
	_env(w)
	_ground(w)
	_shop(w, nav)
	_terrace(w, nav)
	out["gate"] = _fences(w, nav)
	_outskirts(w)
	return out


static func _env(w: Node3D) -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.56, 0.82, 0.97)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.86, 0.9, 1.0)
	e.ambient_light_energy = 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	we.environment = e
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_energy = 0.58
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = bool(Game.settings.get("shadows", true))
	sun.shadow_opacity = 0.55
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 48.0
	w.add_child(sun)


static func _slab(w: Node3D, rect: Rect2, y: float, color: Color, key: String) -> void:
	var mi := MeshBuilder.node(Models.cached(key, func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(rect.size.x, 0.02, rect.size.y), Vector3(rect.position.x + rect.size.x * 0.5, y, rect.position.y + rect.size.y * 0.5), color)
		return b.build()), w)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _ground(w: Node3D) -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(260, 260)
	g.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Models.C_GRASS
	m.roughness = 1.0
	g.material_override = m
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(g)
	# darker patches out in the fields
	var patches := MeshBuilder.node(Models.cached("patches", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in 40:
			var p := Vector3(rng.randf_range(-70, 70), 0.004, rng.randf_range(-60, 70))
			if absf(p.x) < 30 and p.z > -30 and p.z < 26:
				continue
			b.cyl(rng.randf_range(3, 8), rng.randf_range(3, 8), 0.01, p, Models.C_GRASS_DARK, Vector3(0, rng.randf() * 90, 0), 9)
		return b.build()), w)
	patches.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# yard work slab under the machines
	_slab(w, Rect2(-16.8, -7.9, 29.4, 6.4), 0.008, Color(0.72, 0.72, 0.74), "slab_machines")
	# shop floor tiles
	var tiles := MeshBuilder.node(Models.cached("shop_tiles", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var r := Layout.SHOP_RECT
		var n := Vector2i(20, 10)
		var ts := Vector2(r.size.x / n.x, r.size.y / n.y)
		for x in n.x:
			for z in n.y:
				var col := Models.C_PEACH if (x + z) % 2 == 0 else Models.C_PEACH_DARK
				b.box(Vector3(ts.x, 0.02, ts.y), Vector3(r.position.x + (x + 0.5) * ts.x, 0.01, r.position.y + (z + 0.5) * ts.y), col)
		return b.build()), w)
	tiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# terrace deck planks
	var deck := MeshBuilder.node(Models.cached("deck", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var r := Layout.TERRACE_RECT
		var planks := 16
		var pw := r.size.x / planks
		for i in planks:
			var col := Models.C_DECK if i % 2 == 0 else Models.C_DECK.darkened(0.07)
			b.box(Vector3(pw - 0.03, 0.02, r.size.y), Vector3(r.position.x + (i + 0.5) * pw, 0.01, r.position.y + r.size.y * 0.5), col)
		return b.build()), w)
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# back-lot dirt path + office path
	_slab(w, Rect2(-1.4, 6.5, 2.8, 14.0), 0.006, Color(0.9, 0.8, 0.6), "path_backlot")
	_slab(w, Rect2(13.4, -7.6, 4.2, 6.0), 0.009, Color(0.9, 0.8, 0.6), "path_office")


static func add_wall(w: Node3D, nav: NavGrid, center: Vector3, size: Vector3, color: Color, key: String) -> Node3D:
	var body := StaticBody3D.new()
	body.position = center + Vector3(0, size.y * 0.5, 0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	w.add_child(body)
	var mi := MeshBuilder.node(Models.cached(key, func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(size, Vector3.ZERO, color)
		b.box(Vector3(size.x + 0.08, 0.12, size.z + 0.08), Vector3(0, size.y * 0.5, 0), Models.C_WALL_TRIM)
		return b.build()), body)
	mi.position = Vector3.ZERO
	nav.set_rect(Vector2(center.x, center.z), Vector2(size.x, size.z), true, 0.3)
	return body


## Fence along a straight x- or z-aligned line, with a collider.
static func add_fence(w: Node3D, nav: NavGrid, a: Vector2, b: Vector2) -> Node3D:
	var root := StaticBody3D.new()
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	root.position = Vector3(mid.x, 0, mid.y)
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	root.rotation.y = 0.0 if along_x else PI * 0.5
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(length, 1.2, 0.3)
	cs.shape = bs
	cs.position.y = 0.6
	root.add_child(cs)
	MeshBuilder.node(Models.fence_segment_mesh(snappedf(length, 0.1)), root)
	w.add_child(root)
	nav.set_line(a, b, true, 0.35)
	return root


static func _shop(w: Node3D, nav: NavGrid) -> void:
	var r := Layout.SHOP_RECT
	var x0 := r.position.x
	var x1 := r.position.x + r.size.x
	var zb := r.position.y
	# back wall with windows, door and bread racks painted on the inside
	var back := add_wall(w, nav, Vector3((x0 + x1) * 0.5, 0, zb - 0.2), Vector3(r.size.x + 0.8, 3.4, 0.4), Models.C_WALL, "wall_back")
	var deco := MeshBuilder.node(Models.cached("wall_back_deco", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var zf := 0.21
		for x in [-11.0, -3.0, 5.0, 11.0]:
			b.box(Vector3(2.0, 1.3, 0.05), Vector3(x, 0.3, zf), Color(0.55, 0.78, 0.98))
			b.box(Vector3(2.2, 0.12, 0.1), Vector3(x, -0.4, zf + 0.02), Color(1, 1, 1))
			b.box(Vector3(0.08, 1.3, 0.07), Vector3(x, 0.3, zf + 0.01), Color(1, 1, 1))
		# staff door
		b.box(Vector3(1.3, 2.3, 0.06), Vector3(-13.8, -0.55, zf), Color(0.6, 0.4, 0.25))
		b.sphere(0.06, Vector3(-13.35, -0.6, zf + 0.05), Models.C_GOLD)
		# bread racks between windows
		for x in [-7.0, 1.0, 8.0]:
			b.box(Vector3(2.2, 2.2, 0.35), Vector3(x, -0.55, zf + 0.18), Color(0.72, 0.5, 0.3))
			for sy in 3:
				var yy := -1.3 + sy * 0.7
				b.box(Vector3(2.1, 0.05, 0.38), Vector3(x, yy, zf + 0.2), Color(0.82, 0.6, 0.38))
				for k in 4:
					b.capsule(0.08, 0.34, Vector3(x - 0.75 + k * 0.5, yy + 0.1, zf + 0.22), Color(0.86, 0.55, 0.24), Vector3(0, 0, 90))
		# baseboard
		b.box(Vector3(29.8, 0.3, 0.06), Vector3(0, -1.55, zf), Models.C_WALL_TRIM)
		# awning stripes
		for i in 25:
			var col := Color(0.95, 0.3, 0.32) if i % 2 == 0 else Color(0.99, 0.98, 0.96)
			b.box(Vector3(1.2, 0.08, 1.1), Vector3(-14.4 + i * 1.2, 1.25, zf + 0.5), col, Vector3(-22, 0, 0))
		return b.build()), back)
	deco.position = Vector3.ZERO
	# low side walls (so the camera can see in)
	add_wall(w, nav, Vector3(x0 - 0.2, 0, (zb + -12.8) * 0.5), Vector3(0.4, 1.1, -12.8 - zb), Models.C_WALL, "wall_left")
	add_wall(w, nav, Vector3(x1 + 0.2, 0, (zb + -8.0) * 0.5), Vector3(0.4, 1.1, -8.0 - zb), Models.C_WALL, "wall_right")
	# company sign above the back wall
	var sign := Node3D.new()
	sign.position = Vector3(-2.0, 4.6, zb - 0.1)
	sign.rotation_degrees = Vector3(-18, 0, 0)
	w.add_child(sign)
	MeshBuilder.node(Models.cached("sign_board", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(10.4, 2.6, 0.2), Vector3.ZERO, Color(1.0, 0.64, 0.14))
		b.box(Vector3(10.0, 2.2, 0.1), Vector3(0, 0, 0.08), Color(1.0, 0.99, 0.95))
		for x in [-3.8, 3.8]:
			b.box(Vector3(0.18, 2.6, 0.18), Vector3(x, -2.3, -0.1), Models.C_METAL_DARK)
		return b.build()), sign)
	var badge := Sprite3D.new()
	badge.texture = load("res://assets/logo/logo_badge.png")
	badge.pixel_size = 2.9 / 512.0
	badge.position = Vector3(-3.9, 0.05, 0.16)
	badge.shaded = false
	sign.add_child(badge)
	var title := Fx.label3d(Game.company, 150, Color(0.95, 0.42, 0.18), 30)
	title.name = "CompanyLabel"
	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	title.position = Vector3(1.25, 0.28, 0.17)
	title.width = 1250
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.outline_modulate = Color(1, 1, 1)
	sign.add_child(title)
	var sub := Fx.label3d("FINE BREAD FOR FINE PIGEONS", 58, Color(0.35, 0.33, 0.45), 0)
	sub.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sub.position = Vector3(1.25, -0.62, 0.17)
	sign.add_child(sub)
	fit_sign(title, Game.company)
	w.set("company_label", title)
	# planters in the corners
	for p in [Vector3(x0 + 0.7, 0, zb + 0.7), Vector3(x1 - 0.7, 0, zb + 0.7), Vector3(x1 - 0.7, 0, -8.7)]:
		var pl := MeshBuilder.node(Models.planter_mesh(), w)
		pl.position = p
		nav.set_rect(Vector2(p.x, p.z), Vector2(0.6, 0.6), true, 0.2)


## Shrinks the sign lettering so long company names still fit the board.
static func fit_sign(l: Label3D, text: String) -> void:
	l.text = text
	l.font_size = clampi(int(150.0 * 13.0 / maxf(13.0, float(text.length()))), 72, 150)


static func _terrace(w: Node3D, nav: NavGrid) -> void:
	for p in [Vector3(-26.2, 0, -21.2), Vector3(-26.2, 0, -8.3), Vector3(-17.8, 0, -21.3)]:
		var pl := MeshBuilder.node(Models.planter_mesh(), w)
		pl.position = p
		nav.set_rect(Vector2(p.x, p.z), Vector2(0.6, 0.6), true, 0.2)
	var bench := MeshBuilder.node(Models.bench_mesh(), w)
	bench.position = Vector3(-22.3, 0, -21.4)
	nav.set_rect(Vector2(-22.3, -21.4), Vector2(1.6, 0.5), true, 0.2)


static func _fences(w: Node3D, nav: NavGrid) -> Node3D:
	# terrace
	add_fence(w, nav, Vector2(-27.4, -22.4), Vector2(-27.4, -7.3))
	add_fence(w, nav, Vector2(-27.4, -22.4), Vector2(-16.9, -22.4))
	add_fence(w, nav, Vector2(-27.4, -7.3), Vector2(-18.4, -7.3))
	# yard
	add_fence(w, nav, Vector2(-18.4, -7.3), Vector2(-18.4, 7.5))
	add_fence(w, nav, Vector2(18.4, -8.2), Vector2(18.4, 7.5))
	add_fence(w, nav, Vector2(12.9, -8.2), Vector2(18.4, -8.2))
	add_fence(w, nav, Vector2(-18.4, 7.5), Vector2(-1.3, 7.5))
	add_fence(w, nav, Vector2(1.3, 7.5), Vector2(18.4, 7.5))
	# back lot (visible from the start, locked behind the gate)
	add_fence(w, nav, Vector2(-18.4, 7.5), Vector2(-18.4, 21.3))
	add_fence(w, nav, Vector2(18.4, 7.5), Vector2(18.4, 21.3))
	add_fence(w, nav, Vector2(-18.4, 21.3), Vector2(18.4, 21.3))
	var gate: Node3D = null
	if not Game.is_unlocked("backlot"):
		gate = add_fence(w, nav, Vector2(-1.3, 7.5), Vector2(1.3, 7.5))
	# lamps in the yard corners
	for p in [Vector3(-17.7, 0, -6.9), Vector3(17.7, 0, 6.8), Vector3(-17.7, 0, 6.8), Vector3(17.7, 0, -7.6)]:
		var l := MeshBuilder.node(Models.lamp_mesh(), w)
		l.position = p
		l.rotation.y = PI if p.x > 0 else 0.0
	return gate


static func _outskirts(w: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# trees outside the fences
	var tree_root := Node3D.new()
	w.add_child(tree_root)
	for i in 90:
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-24, 60))
		var inside_map := p.x > -29.5 and p.x < 20.5 and p.z > -24.0 and p.z < 23.5
		if inside_map:
			continue
		var t := MeshBuilder.node(Models.tree_mesh(rng.randi() % 3), tree_root)
		t.position = p
		t.scale = Vector3.ONE * rng.randf_range(1.2, 2.0)
		t.rotation.y = rng.randf() * TAU
	for i in 30:
		var p := Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-23.5, 40))
		var inside_map := p.x > -28.2 and p.x < 19.2 and p.z > -23.2 and p.z < 22.2
		if inside_map:
			continue
		var bsh := MeshBuilder.node(Models.bush_mesh(), tree_root)
		bsh.position = p
		bsh.rotation.y = rng.randf() * TAU
	# road + sidewalk + town behind the bakery
	var road := MeshBuilder.node(Models.cached("road", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(160, 0.03, 2.2), Vector3(0, 0.015, -24.2), Color(0.85, 0.84, 0.82))
		b.box(Vector3(160, 0.03, 7.0), Vector3(0, 0.012, -28.8), Color(0.42, 0.44, 0.5))
		for i in 40:
			b.box(Vector3(2.0, 0.035, 0.22), Vector3(-78 + i * 4.0, 0.02, -28.8), Color(1, 0.95, 0.7))
		b.box(Vector3(160, 0.03, 2.2), Vector3(0, 0.015, -33.4), Color(0.85, 0.84, 0.82))
		return b.build()), w)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cols := [Color(0.95, 0.75, 0.7), Color(0.72, 0.82, 0.95), Color(0.98, 0.9, 0.65), Color(0.8, 0.92, 0.78), Color(0.9, 0.8, 0.95)]
	var x := -60.0
	var k := 0
	while x < 60.0:
		var bw := rng.randf_range(5.0, 9.0)
		var bh := rng.randf_range(5.0, 13.0)
		var bd := rng.randf_range(6.0, 9.0)
		var col: Color = cols[k % cols.size()]
		var bm := MeshBuilder.node(Models.building_mesh(snappedf(bw, 0.5), snappedf(bd, 0.5), snappedf(bh, 0.5), col, k % 5), w)
		bm.position = Vector3(x + bw * 0.5, 0, -35.0 - bd * 0.5)
		x += bw + rng.randf_range(0.5, 2.0)
		k += 1
	for i in 8:
		var l := MeshBuilder.node(Models.lamp_mesh(), w)
		l.position = Vector3(-35 + i * 10.0, 0, -25.1)
		l.rotation.y = -PI * 0.5
