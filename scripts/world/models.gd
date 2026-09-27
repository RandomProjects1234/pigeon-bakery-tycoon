class_name Models
extends RefCounted
## Procedural low-poly models. Static stuff is merged with MeshBuilder and
## cached per type, so e.g. every bread loaf in the game shares one mesh.

# palette (sRGB), tuned to the bright playable-ad look
const C_GRASS := Color(0.63, 0.86, 0.36)
const C_GRASS_DARK := Color(0.52, 0.78, 0.3)
const C_PEACH := Color(1.0, 0.76, 0.52)
const C_PEACH_DARK := Color(0.96, 0.68, 0.45)
const C_DECK := Color(0.86, 0.66, 0.46)
const C_FENCE := Color(0.87, 0.55, 0.3)
const C_FENCE_DARK := Color(0.72, 0.42, 0.22)
const C_WALL := Color(0.95, 0.88, 0.92)
const C_WALL_TRIM := Color(0.78, 0.66, 0.78)
const C_SOIL := Color(0.62, 0.4, 0.24)
const C_SOIL_DARK := Color(0.5, 0.31, 0.18)
const C_WOOD := Color(0.8, 0.56, 0.34)
const C_WOOD_LIGHT := Color(0.95, 0.78, 0.55)
const C_METAL := Color(0.72, 0.76, 0.82)
const C_METAL_DARK := Color(0.45, 0.48, 0.55)
const C_WHITE := Color(0.98, 0.97, 0.95)
const C_RED := Color(0.94, 0.3, 0.3)
const C_INK := Color(0.17, 0.15, 0.2)
const C_BRICK := Color(0.82, 0.42, 0.3)
const C_BRICK_DARK := Color(0.66, 0.32, 0.24)
const C_GLOW := Color(1.0, 0.6, 0.15)
const C_GOLD := Color(1.0, 0.78, 0.2)

static var _cache := {}


static func cached(key: String, maker: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


static func mesh_node(key: String, maker: Callable, parent: Node = null) -> MeshInstance3D:
	return MeshBuilder.node(cached(key, maker), parent)


# ================================================================ items ===
static func item(t: String) -> Node3D:
	var root := Node3D.new()
	root.name = t
	var mi := MeshBuilder.node(item_mesh(t), root)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


static func item_mesh(t: String) -> ArrayMesh:
	return cached("item_" + t, func() -> ArrayMesh: return _build_item(t))


static func _build_item(t: String) -> ArrayMesh:
	var b := MeshBuilder.new()
	match t:
		"wheat":
			# a tied sheaf lying on its side: stalks fanning out into grain heads
			var stalk := Color(0.95, 0.8, 0.36)
			var grain := Color(0.93, 0.68, 0.2)
			var offs := [Vector2(0, 0), Vector2(0.045, 0.03), Vector2(-0.045, 0.03), Vector2(0.03, -0.04), Vector2(-0.03, -0.04), Vector2(0, 0.06), Vector2(0, -0.065)]
			for k in offs.size():
				var o: Vector2 = offs[k]
				var fan := 1.0 + k * 0.03
				b.cyl(0.018, 0.018, 0.34, Vector3(-0.06, 0.075 + o.y, o.x), stalk, Vector3(0, o.x * 250.0, 90), 5)
				b.sphere(0.035, Vector3(0.16, 0.075 + o.y * 1.9 * fan, o.x * 1.9 * fan), grain, Vector3(2.4, 1.0, 1.0), Vector3(0, o.x * 250.0, o.y * -250.0), 7)
			b.cyl(0.075, 0.075, 0.05, Vector3(-0.02, 0.075, 0), Color(0.62, 0.36, 0.2), Vector3(0, 0, 90), 10)
		"sunflower":
			var petal := Color(1.0, 0.78, 0.1)
			for k in 12:
				var a := k * TAU / 12.0
				b.sphere(0.07, Vector3(cos(a) * 0.15, 0.03, sin(a) * 0.15), petal, Vector3(1.3, 0.35, 0.65), Vector3(0, -rad_to_deg(a), 0), 6)
			b.cyl(0.12, 0.12, 0.06, Vector3(0, 0.045, 0), Color(0.45, 0.27, 0.12), Vector3.ZERO, 12)
			b.sphere(0.1, Vector3(0, 0.07, 0), Color(0.38, 0.22, 0.1), Vector3(1, 0.3, 1), Vector3.ZERO, 10)
		"flour":
			b.sphere(0.5, Vector3(0, 0.11, 0), Color(0.98, 0.95, 0.88), Vector3(0.42, 0.22, 0.3), Vector3.ZERO, 12)
			b.cyl(0.155, 0.155, 0.05, Vector3(0, 0.11, 0), Color(0.36, 0.58, 0.95), Vector3(0, 0, 90), 12)
			b.cyl(0.04, 0.06, 0.06, Vector3(0.22, 0.11, 0), Color(0.9, 0.86, 0.76), Vector3(0, 0, -90), 8)
		"tomato":
			b.sphere(0.1, Vector3(0, 0.09, 0), Color(0.93, 0.22, 0.16), Vector3(1, 0.85, 1), Vector3.ZERO, 12)
			b.cyl(0.06, 0.06, 0.02, Vector3(0, 0.175, 0), Color(0.3, 0.65, 0.25), Vector3.ZERO, 5)
		"potato":
			b.sphere(0.5, Vector3(0, 0.085, 0), Color(0.78, 0.57, 0.33), Vector3(0.3, 0.17, 0.21), Vector3(0, 20, 0), 10)
			b.sphere(0.018, Vector3(0.06, 0.16, 0.02), Color(0.55, 0.38, 0.2))
			b.sphere(0.018, Vector3(-0.07, 0.15, -0.03), Color(0.55, 0.38, 0.2))
		"bread":
			var crust := Color(0.86, 0.55, 0.24)
			b.capsule(0.12, 0.48, Vector3(0, 0.1, 0), crust, Vector3(0, 0, 90), Vector3(1, 1, 0.85))
			for k in 3:
				b.box(Vector3(0.035, 0.02, 0.16), Vector3(-0.12 + k * 0.12, 0.2, 0), Color(0.99, 0.84, 0.58), Vector3(0, 35, 0))
		"seeds":
			b.box(Vector3(0.28, 0.25, 0.2), Vector3(0, 0.125, 0), Color(0.82, 0.64, 0.42))
			b.box(Vector3(0.29, 0.035, 0.21), Vector3(0, 0.26, 0), Color(0.68, 0.5, 0.3))
			b.box(Vector3(0.2, 0.13, 0.012), Vector3(0, 0.13, 0.102), Color(0.42, 0.76, 0.36))
			b.cyl(0.04, 0.04, 0.014, Vector3(0, 0.13, 0.11), Color(1.0, 0.82, 0.15), Vector3(90, 0, 0), 8)
		"croissant":
			var c := Color(0.93, 0.62, 0.24)
			var radii := [0.055, 0.075, 0.095, 0.075, 0.055]
			for k in 5:
				var a := deg_to_rad(-70.0 + k * 35.0)
				var p := Vector3(sin(a) * 0.15, 0.075, -cos(a) * 0.15 + 0.08)
				var r: float = radii[k]
				b.sphere(r, p, c.lerp(Color(0.98, 0.78, 0.4), 0.3 if k % 2 == 0 else 0.0), Vector3(1.0, 0.8, 1.0), Vector3.ZERO, 10)
		"pizza":
			b.box(Vector3(0.42, 0.08, 0.42), Vector3(0, 0.04, 0), Color(0.99, 0.96, 0.9))
			b.box(Vector3(0.43, 0.012, 0.1), Vector3(0, 0.082, 0), C_RED)
			b.cyl(0.07, 0.07, 0.014, Vector3(0.1, 0.085, 0.12), Color(0.2, 0.62, 0.3), Vector3.ZERO, 10)
		"fries":
			b.cyl(0.15, 0.11, 0.2, Vector3(0, 0.1, 0), Color(0.92, 0.18, 0.18), Vector3(0, 45, 0), 4)
			b.cyl(0.04, 0.04, 0.012, Vector3(0, 0.12, 0.085), Color(1.0, 0.82, 0.2), Vector3(90, 0, 0), 8)
			var fry := Color(1.0, 0.84, 0.3)
			var tilts := [Vector3(8, 0, -10), Vector3(-6, 0, 6), Vector3(4, 0, 14), Vector3(-10, 0, -4), Vector3(0, 0, 0), Vector3(10, 0, 8)]
			for k in 6:
				var x := -0.06 + (k % 3) * 0.06
				var z := -0.025 + (k / 3) * 0.05
				var tilt: Vector3 = tilts[k]
				b.box(Vector3(0.032, 0.16, 0.032), Vector3(x, 0.24 + (k % 2) * 0.02, z), fry, tilt)
		"cash":
			b.box(Vector3(0.34, 0.06, 0.18), Vector3(0, 0.03, 0), Color(0.46, 0.82, 0.36))
			b.box(Vector3(0.26, 0.062, 0.12), Vector3(0, 0.03, 0), Color(0.36, 0.7, 0.3))
			b.box(Vector3(0.07, 0.064, 0.184), Vector3(0, 0.03, 0), Color(0.95, 0.97, 0.9))
		_:
			b.box(Vector3(0.25, 0.2, 0.25), Vector3(0, 0.1, 0), Color.MAGENTA)
	return b.build()


# ================================================================ crops ===
## One plant tuft at full size, origin on the soil.
static func crop_mesh(crop: String, ripe: bool) -> ArrayMesh:
	return cached("crop_%s_%s" % [crop, ripe], func() -> ArrayMesh: return _build_crop(crop, ripe))


static func _build_crop(crop: String, ripe: bool) -> ArrayMesh:
	var b := MeshBuilder.new()
	var green := Color(0.35, 0.7, 0.25)
	match crop:
		"wheat":
			var stalk := Color(0.93, 0.78, 0.32) if ripe else Color(0.6, 0.8, 0.3)
			var head := Color(0.95, 0.72, 0.22) if ripe else Color(0.55, 0.75, 0.28)
			var offs := [Vector2(0, 0), Vector2(0.1, 0.06), Vector2(-0.09, 0.07), Vector2(0.05, -0.1), Vector2(-0.06, -0.08)]
			for k in offs.size():
				var o: Vector2 = offs[k]
				var h := 0.5 + (k % 3) * 0.07
				var lean := Vector3(o.y * 60.0, 0, -o.x * 60.0)
				b.cyl(0.015, 0.02, h, Vector3(o.x, h * 0.5, o.y), stalk, lean, 5)
				b.sphere(0.045, Vector3(o.x * 1.5, h + 0.05, o.y * 1.5), head, Vector3(0.8, 2.0, 0.8), lean, 6)
		"sunflower":
			b.cyl(0.025, 0.03, 0.62, Vector3(0, 0.31, 0), green, Vector3.ZERO, 6)
			b.sphere(0.09, Vector3(0.07, 0.3, 0), Color(0.3, 0.62, 0.22), Vector3(1.6, 0.3, 0.8), Vector3(0, 0, 20), 6)
			b.sphere(0.09, Vector3(-0.07, 0.42, 0), Color(0.3, 0.62, 0.22), Vector3(1.6, 0.3, 0.8), Vector3(0, 0, -20), 6)
			if ripe:
				b.cyl(0.2, 0.2, 0.04, Vector3(0, 0.68, 0.03), Color(1.0, 0.8, 0.12), Vector3(55, 0, 0), 12)
				b.cyl(0.1, 0.1, 0.05, Vector3(0, 0.69, 0.045), Color(0.45, 0.27, 0.12), Vector3(55, 0, 0), 10)
			else:
				b.sphere(0.09, Vector3(0, 0.66, 0), Color(0.45, 0.72, 0.28), Vector3(1, 0.8, 1), Vector3.ZERO, 8)
		"tomato":
			b.sphere(0.22, Vector3(0, 0.26, 0), Color(0.3, 0.64, 0.24), Vector3(1, 1.1, 1), Vector3.ZERO, 8)
			b.sphere(0.16, Vector3(0.12, 0.4, 0.05), Color(0.36, 0.72, 0.28), Vector3.ONE, Vector3.ZERO, 8)
			var fruit := Color(0.93, 0.22, 0.16) if ripe else Color(0.6, 0.82, 0.3)
			for p in [Vector3(0.14, 0.24, 0.14), Vector3(-0.15, 0.3, 0.1), Vector3(0.02, 0.44, 0.16), Vector3(0.18, 0.4, -0.05)]:
				b.sphere(0.065, p, fruit, Vector3.ONE, Vector3.ZERO, 8)
		"potato":
			b.sphere(0.2, Vector3(0, 0.17, 0), Color(0.33, 0.66, 0.26), Vector3(1.2, 0.8, 1.2), Vector3.ZERO, 8)
			b.sphere(0.13, Vector3(0.1, 0.28, 0.04), Color(0.4, 0.74, 0.3), Vector3.ONE, Vector3.ZERO, 8)
			b.sphere(0.03, Vector3(-0.06, 0.38, 0.05), Color(0.95, 0.95, 1.0))   # little flower
			if ripe:
				b.sphere(0.5, Vector3(0.12, 0.05, 0.18), Color(0.78, 0.57, 0.33), Vector3(0.22, 0.13, 0.16), Vector3.ZERO, 8)
				b.sphere(0.5, Vector3(-0.14, 0.04, 0.15), Color(0.74, 0.53, 0.3), Vector3(0.2, 0.12, 0.15), Vector3.ZERO, 8)
	return b.build()


# ============================================================ scenery =====
static func tree_mesh(variant: int) -> ArrayMesh:
	return cached("tree%d" % variant, func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.cyl(0.12, 0.16, 1.0, Vector3(0, 0.5, 0), Color(0.55, 0.36, 0.22), Vector3.ZERO, 6)
		if variant == 0:
			b.sphere(0.8, Vector3(0, 1.55, 0), Color(0.36, 0.72, 0.3), Vector3(1, 0.95, 1), Vector3.ZERO, 8)
			b.sphere(0.55, Vector3(0.4, 1.95, 0.15), Color(0.42, 0.78, 0.34), Vector3.ONE, Vector3.ZERO, 8)
		elif variant == 1:
			b.cyl(0.0, 0.9, 1.5, Vector3(0, 1.5, 0), Color(0.3, 0.64, 0.34), Vector3.ZERO, 7)
			b.cyl(0.0, 0.7, 1.2, Vector3(0, 2.2, 0), Color(0.36, 0.7, 0.38), Vector3.ZERO, 7)
		else:
			b.sphere(0.65, Vector3(0, 1.4, 0), Color(0.5, 0.78, 0.3), Vector3.ONE, Vector3.ZERO, 8)
			b.sphere(0.5, Vector3(-0.35, 1.2, 0.2), Color(0.45, 0.74, 0.28), Vector3.ONE, Vector3.ZERO, 8)
		return b.build())


static func bush_mesh() -> ArrayMesh:
	return cached("bush", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.sphere(0.45, Vector3(0, 0.3, 0), Color(0.4, 0.74, 0.3), Vector3(1.2, 0.8, 1), Vector3.ZERO, 8)
		b.sphere(0.35, Vector3(0.35, 0.3, 0.1), Color(0.46, 0.8, 0.34), Vector3.ONE, Vector3.ZERO, 8)
		b.sphere(0.06, Vector3(0.1, 0.62, 0.25), Color(1.0, 0.5, 0.6))
		b.sphere(0.06, Vector3(-0.3, 0.5, 0.2), Color(1.0, 0.9, 0.4))
		return b.build())


static func lamp_mesh() -> ArrayMesh:
	return cached("lamp", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.cyl(0.1, 0.14, 0.2, Vector3(0, 0.1, 0), C_METAL_DARK, Vector3.ZERO, 8)
		b.cyl(0.05, 0.05, 2.8, Vector3(0, 1.5, 0), Color(0.8, 0.78, 0.74), Vector3.ZERO, 8)
		b.box(Vector3(0.5, 0.08, 0.14), Vector3(0.2, 2.9, 0), Color(0.8, 0.78, 0.74))
		b.box(Vector3(0.3, 0.16, 0.22), Vector3(0.42, 2.84, 0), Color(0.95, 0.93, 0.85))
		return b.build())


static func fence_segment_mesh(length: float) -> ArrayMesh:
	return cached("fence%.2f" % length, func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var posts := maxi(2, int(ceil(length / 1.2)) + 1)
		for k in posts:
			var x := -length * 0.5 + length * float(k) / float(posts - 1)
			b.box(Vector3(0.14, 0.7, 0.14), Vector3(x, 0.35, 0), C_FENCE)
			b.box(Vector3(0.1, 0.1, 0.1), Vector3(x, 0.72, 0), C_FENCE, Vector3(45, 0, 0), Vector3(1.4, 1, 1))
		b.box(Vector3(length, 0.1, 0.07), Vector3(0, 0.52, 0), C_FENCE_DARK)
		b.box(Vector3(length, 0.1, 0.07), Vector3(0, 0.24, 0), C_FENCE_DARK)
		return b.build())


static func bench_mesh() -> ArrayMesh:
	return cached("bench", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(1.6, 0.08, 0.45), Vector3(0, 0.45, 0), C_WOOD)
		b.box(Vector3(1.6, 0.3, 0.06), Vector3(0, 0.72, -0.2), C_WOOD)
		for x in [-0.65, 0.65]:
			b.box(Vector3(0.08, 0.45, 0.4), Vector3(x, 0.22, 0), C_METAL_DARK)
		return b.build())


static func planter_mesh() -> ArrayMesh:
	return cached("planter", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.cyl(0.26, 0.2, 0.36, Vector3(0, 0.18, 0), Color(0.86, 0.5, 0.36), Vector3.ZERO, 8)
		b.sphere(0.3, Vector3(0, 0.55, 0), Color(0.36, 0.7, 0.3), Vector3(1, 0.9, 1), Vector3.ZERO, 8)
		b.sphere(0.2, Vector3(0.12, 0.72, 0.06), Color(0.42, 0.76, 0.34), Vector3.ONE, Vector3.ZERO, 8)
		return b.build())


static func building_mesh(w: float, d: float, h: float, col: Color, seed_i: int) -> ArrayMesh:
	return cached("bld%.1f_%.1f_%.1f_%d" % [w, d, h, seed_i], func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), col)
		b.box(Vector3(w + 0.3, 0.3, d + 0.3), Vector3(0, h + 0.15, 0), col.darkened(0.15))
		var win := Color(0.55, 0.75, 0.95)
		var floors := int(h / 1.6)
		var cols := int(w / 1.5)
		for f in floors:
			for c in cols:
				var x := -w * 0.5 + (c + 0.5) * (w / cols)
				var y := 1.0 + f * 1.6
				b.box(Vector3(0.8, 0.9, 0.05), Vector3(x, y, d * 0.5 + 0.01), win if (f + c + seed_i) % 5 != 0 else Color(1.0, 0.92, 0.6))
		return b.build())


## Yellow bouncing objective arrow (points down).
static func arrow_mesh() -> ArrayMesh:
	return cached("arrow", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var y := Color(1.0, 0.86, 0.15)
		b.box(Vector3(0.42, 0.7, 0.2), Vector3(0, 0.8, 0), y)
		b.prism(Vector3(1.0, 0.62, 0.22), Vector3(0, 0.15, 0), y, Vector3(180, 0, 0))
		return b.build())
