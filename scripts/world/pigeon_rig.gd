class_name PigeonRig
extends Node3D
## A rock pigeon modelled on the user's photo: slate-grey head, dark
## iridescent neck, pale grey wings with two black wing bars, dark tail with a
## black tip, orange eye, white cere on the beak and coral-pink feet.
## Faces -Z. ~0.95 m tall at scale 1 (cartoon customer size).
##
## Variants: "std" (the photo), "dark", "light", "vip" (white + crown),
## "crow" (the thief), "gold" (the statue).

var variant := "std"
var body: Node3D
var head: Node3D
var wing_l: Node3D   # flap node
var wing_r: Node3D
var spread_l: Node3D
var spread_r: Node3D
var leg_l: Node3D
var leg_r: Node3D

var phase := 0.0
var _peck_t := 0.0
var _flap_t := 0.0
var _look_t := 0.0
var _look_target := 0.0
var _head_base := Vector3(0, 0.36, -0.28)
const BODY_Y := 0.39


static func palette(v: String) -> Dictionary:
	match v:
		"dark", "general":
			return {"body": Color(0.5, 0.52, 0.57), "belly": Color(0.44, 0.46, 0.5), "wing": Color(0.58, 0.6, 0.65),
				"neck": Color(0.17, 0.18, 0.21), "head": Color(0.28, 0.3, 0.34), "tail": Color(0.32, 0.33, 0.37),
				"bar": Color(0.1, 0.1, 0.12), "tip": Color(0.22, 0.23, 0.26), "eye": Color(0.95, 0.45, 0.12),
				"feet": Color(0.93, 0.47, 0.52), "beak": Color(0.2, 0.2, 0.22), "cere": Color(0.92, 0.9, 0.85),
				"sheen1": Color(0.22, 0.42, 0.36), "sheen2": Color(0.38, 0.27, 0.46)}
		"light":
			return {"body": Color(0.76, 0.77, 0.8), "belly": Color(0.68, 0.7, 0.74), "wing": Color(0.84, 0.85, 0.88),
				"neck": Color(0.33, 0.35, 0.4), "head": Color(0.48, 0.5, 0.55), "tail": Color(0.5, 0.52, 0.57),
				"bar": Color(0.16, 0.16, 0.18), "tip": Color(0.4, 0.41, 0.45), "eye": Color(0.95, 0.45, 0.12),
				"feet": Color(0.93, 0.5, 0.55), "beak": Color(0.25, 0.25, 0.27), "cere": Color(0.95, 0.93, 0.9),
				"sheen1": Color(0.3, 0.5, 0.44), "sheen2": Color(0.46, 0.36, 0.54)}
		"vip":
			return {"body": Color(0.97, 0.97, 0.98), "belly": Color(0.92, 0.92, 0.94), "wing": Color(1, 1, 1),
				"neck": Color(0.93, 0.93, 0.95), "head": Color(0.98, 0.98, 1.0), "tail": Color(0.94, 0.94, 0.96),
				"bar": Color(0.95, 0.78, 0.25), "tip": Color(0.9, 0.9, 0.93), "eye": Color(0.2, 0.15, 0.1),
				"feet": Color(0.95, 0.55, 0.6), "beak": Color(0.95, 0.75, 0.4), "cere": Color(1, 1, 1),
				"sheen1": Color(0.95, 0.9, 0.7), "sheen2": Color(0.98, 0.85, 0.5)}
		"crow", "crow_boss":
			return {"body": Color(0.12, 0.12, 0.15), "belly": Color(0.1, 0.1, 0.13), "wing": Color(0.16, 0.16, 0.2),
				"neck": Color(0.1, 0.1, 0.13), "head": Color(0.13, 0.13, 0.16), "tail": Color(0.1, 0.1, 0.12),
				"bar": Color(0.2, 0.2, 0.26), "tip": Color(0.08, 0.08, 0.1), "eye": Color(0.9, 0.85, 0.3),
				"feet": Color(0.2, 0.2, 0.22), "beak": Color(0.08, 0.08, 0.09), "cere": Color(0.1, 0.1, 0.12),
				"sheen1": Color(0.15, 0.2, 0.3), "sheen2": Color(0.2, 0.15, 0.28)}
		"gold":
			var g := Color(0.93, 0.7, 0.22)
			var gd := Color(0.78, 0.55, 0.15)
			return {"body": g, "belly": gd, "wing": Color(1.0, 0.8, 0.3), "neck": gd, "head": g, "tail": gd,
				"bar": Color(0.6, 0.4, 0.1), "tip": gd, "eye": Color(0.3, 0.2, 0.08), "feet": gd, "beak": gd,
				"cere": Color(1.0, 0.9, 0.55), "sheen1": g, "sheen2": g}
	# the photo pigeon
	return {"body": Color(0.64, 0.66, 0.71), "belly": Color(0.56, 0.58, 0.63), "wing": Color(0.74, 0.76, 0.8),
		"neck": Color(0.21, 0.22, 0.26), "head": Color(0.36, 0.38, 0.43), "tail": Color(0.4, 0.42, 0.47),
		"bar": Color(0.1, 0.1, 0.12), "tip": Color(0.3, 0.31, 0.35), "eye": Color(0.95, 0.42, 0.1),
		"feet": Color(0.93, 0.47, 0.52), "beak": Color(0.2, 0.2, 0.22), "cere": Color(0.93, 0.91, 0.86),
		"sheen1": Color(0.24, 0.44, 0.38), "sheen2": Color(0.4, 0.28, 0.48)}


func _init(v := "std") -> void:
	variant = v
	_build()


func _build() -> void:
	var p := palette(variant)
	var v := variant
	body = Node3D.new()
	body.name = "Body"
	body.position = Vector3(0, BODY_Y, 0)
	add_child(body)
	MeshBuilder.node(Models.cached("pg_body_" + v, func() -> ArrayMesh: return _body_mesh(p)), body)

	head = Node3D.new()
	head.name = "Head"
	head.position = _head_base
	body.add_child(head)
	MeshBuilder.node(Models.cached("pg_head_" + v, func() -> ArrayMesh: return _head_mesh(p)), head)

	var wing_mesh := Models.cached("pg_wing_" + v, func() -> ArrayMesh: return _wing_mesh(p))
	for side in [-1, 1]:
		var root := Node3D.new()
		root.position = Vector3(0.18 * side, 0.1, -0.12)
		body.add_child(root)
		var flap := Node3D.new()
		root.add_child(flap)
		var spread := Node3D.new()
		flap.add_child(spread)
		var wm := MeshBuilder.node(wing_mesh, spread)
		wm.position = Vector3(0.012 * side, 0, 0)
		if side < 0:
			wing_l = flap
			spread_l = spread
		else:
			wing_r = flap
			spread_r = spread

	var leg_mesh := Models.cached("pg_leg_" + v, func() -> ArrayMesh: return _leg_mesh(p))
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(0.08 * side, -0.12, 0.02)
		body.add_child(leg)
		MeshBuilder.node(leg_mesh, leg)
		if side < 0:
			leg_l = leg
		else:
			leg_r = leg

	_accessories(v)
	if v == "vip":
		var crown := MeshBuilder.node(Models.cached("pg_crown", func() -> ArrayMesh:
			var b := MeshBuilder.new()
			b.cyl(0.075, 0.065, 0.06, Vector3(0, 0, 0), Models.C_GOLD, Vector3.ZERO, 8)
			for k in 5:
				var a := k * TAU / 5.0
				b.cyl(0.0, 0.022, 0.06, Vector3(cos(a) * 0.058, 0.055, sin(a) * 0.058), Models.C_GOLD, Vector3.ZERO, 4)
			b.sphere(0.018, Vector3(0, 0.02, -0.07), Color(1, 0.3, 0.4))
			return b.build()), head)
		crown.position = Vector3(0, 0.15, -0.01)


## Hats and gear for the military / crow-clan variants.
func _accessories(v: String) -> void:
	match v:
		"general":
			var cap := MeshBuilder.node(Models.cached("pg_general_cap", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				var olive := Color(0.33, 0.42, 0.24)
				b.cyl(0.15, 0.12, 0.09, Vector3(0, 0.02, 0), olive, Vector3.ZERO, 12)
				b.cyl(0.165, 0.165, 0.03, Vector3(0, 0.07, 0.0), olive.darkened(0.15), Vector3.ZERO, 12)
				b.box(Vector3(0.2, 0.02, 0.1), Vector3(0, -0.02, -0.14), Color(0.15, 0.15, 0.17), Vector3(-12, 0, 0))
				b.box(Vector3(0.24, 0.03, 0.02), Vector3(0, 0.0, -0.12), Models.C_GOLD)
				b.cyl(0.03, 0.03, 0.02, Vector3(0, 0.05, -0.13), Models.C_GOLD, Vector3(90, 0, 0), 5)
				return b.build()), head)
			cap.position = Vector3(0, 0.12, -0.01)
			var medals := MeshBuilder.node(Models.cached("pg_medals", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				var cols := [Color(0.9, 0.2, 0.2), Color(0.2, 0.4, 0.9), Models.C_GOLD]
				for k in 3:
					var x := -0.06 + k * 0.06
					var c: Color = cols[k]
					b.box(Vector3(0.035, 0.05, 0.02), Vector3(x, 0.03, 0), c)
					b.cyl(0.018, 0.018, 0.012, Vector3(x, -0.01, -0.005), Models.C_GOLD, Vector3(90, 0, 0), 8)
				return b.build()), body)
			medals.position = Vector3(0, 0.1, -0.35)
		"soldier":
			var helmet := MeshBuilder.node(Models.cached("pg_helmet", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				var olive := Color(0.36, 0.45, 0.26)
				b.dome(0.15, Vector3(0, 0, 0), olive, Vector3(1.0, 0.8, 1.05), 12)
				b.cyl(0.165, 0.165, 0.015, Vector3(0, 0.005, 0), olive.darkened(0.2), Vector3.ZERO, 12)
				return b.build()), head)
			helmet.position = Vector3(0, 0.05, -0.01)
		"crow_boss":
			var band := MeshBuilder.node(Models.cached("pg_bandana", func() -> ArrayMesh:
				var b := MeshBuilder.new()
				var red := Color(0.85, 0.12, 0.12)
				b.cyl(0.137, 0.137, 0.06, Vector3(0, 0, 0), red, Vector3.ZERO, 12)
				b.box(Vector3(0.05, 0.03, 0.14), Vector3(0.03, 0.0, 0.18), red, Vector3(0, 20, -20))
				b.box(Vector3(0.05, 0.03, 0.12), Vector3(-0.03, -0.01, 0.17), red, Vector3(0, -25, 25))
				# eye patch
				b.cyl(0.04, 0.04, 0.02, Vector3(0.105, -0.025, -0.075), Color(0.03, 0.03, 0.03), Vector3(0, 0, 90), 10)
				return b.build()), head)
			band.position = Vector3(0, 0.06, 0)


static func _body_mesh(p: Dictionary) -> ArrayMesh:
	var b := MeshBuilder.new()
	var body_c: Color = p["body"]
	b.sphere(0.5, Vector3(0, 0.02, 0.03), body_c, Vector3(0.44, 0.4, 0.68))
	b.sphere(0.5, Vector3(0, -0.06, 0.0), p["belly"], Vector3(0.38, 0.3, 0.52))
	# dark breast + neck
	b.sphere(0.5, Vector3(0, 0.13, -0.19), p["neck"], Vector3(0.36, 0.44, 0.34))
	b.cyl(0.095, 0.12, 0.24, Vector3(0, 0.26, -0.25), p["neck"], Vector3(-12, 0, 0), 10)
	# iridescent sheen on the neck (green over purple)
	var n: Color = p["neck"]
	b.sphere(0.5, Vector3(0, 0.25, -0.27), n.lerp(p["sheen1"], 0.55), Vector3(0.235, 0.14, 0.16))
	b.sphere(0.5, Vector3(0, 0.16, -0.3), n.lerp(p["sheen2"], 0.5), Vector3(0.3, 0.1, 0.16))
	# tail, with the black terminal band
	b.box(Vector3(0.2, 0.045, 0.36), Vector3(0, 0.02, 0.44), p["tail"], Vector3(10, 0, 0))
	b.box(Vector3(0.21, 0.05, 0.07), Vector3(0, -0.01, 0.6), p["bar"], Vector3(10, 0, 0))
	return b.build()


static func _head_mesh(p: Dictionary) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.sphere(0.13, Vector3(0, 0.02, -0.02), p["head"], Vector3(0.95, 0.95, 1.08))
	b.cyl(0.0, 0.034, 0.11, Vector3(0, -0.005, -0.17), p["beak"], Vector3(-90, 0, 0), 8)
	b.sphere(0.034, Vector3(0, 0.02, -0.125), p["cere"], Vector3(1.0, 0.7, 1.25))
	for side in [-1, 1]:
		b.sphere(0.033, Vector3(0.088 * side, 0.035, -0.07), p["eye"], Vector3.ONE, Vector3.ZERO, 8)
		b.sphere(0.017, Vector3(0.112 * side, 0.04, -0.078), Color(0.05, 0.05, 0.05), Vector3.ONE, Vector3.ZERO, 6)
		b.sphere(0.007, Vector3(0.118 * side, 0.05, -0.088), Color(1, 1, 1), Vector3.ONE, Vector3.ZERO, 4)
	return b.build()


static func _wing_mesh(p: Dictionary) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.sphere(0.5, Vector3(0, -0.02, 0.24), p["wing"], Vector3(0.1, 0.23, 0.58))
	# the two black wing bars from the photo
	b.box(Vector3(0.104, 0.24, 0.04), Vector3(0, -0.03, 0.25), p["bar"], Vector3(-35, 0, 0))
	b.box(Vector3(0.096, 0.21, 0.04), Vector3(0, -0.04, 0.36), p["bar"], Vector3(-35, 0, 0))
	# dark primaries at the tip
	b.sphere(0.5, Vector3(0, -0.03, 0.5), p["tip"], Vector3(0.07, 0.13, 0.3))
	return b.build()


static func _leg_mesh(p: Dictionary) -> ArrayMesh:
	var b := MeshBuilder.new()
	var f: Color = p["feet"]
	b.cyl(0.024, 0.028, 0.24, Vector3(0, -0.13, 0), f, Vector3.ZERO, 6)
	for yaw in [-28.0, 0.0, 28.0]:
		var d := Vector3(sin(deg_to_rad(yaw)) * -0.05, 0, -cos(deg_to_rad(yaw)) * 0.05)
		b.box(Vector3(0.026, 0.02, 0.1), Vector3(d.x, -0.26, d.z - 0.01), f, Vector3(0, yaw, 0))
	b.box(Vector3(0.022, 0.02, 0.06), Vector3(0, -0.26, 0.04), f)
	return b.build()


## mode: "idle", "walk", "fly", "peck", "hop"
func animate(delta: float, speed: float, mode: String) -> void:
	match mode:
		"walk":
			phase += delta * (2.2 + speed * 1.6)
			var s := sin(phase * TAU)
			leg_l.rotation.x = s * 0.55
			leg_r.rotation.x = -s * 0.55
			body.rotation.z = s * 0.07
			body.position.y = BODY_Y + absf(s) * 0.025
			# the classic pigeon head-bob: thrust forward fast, hold, repeat
			var f := fmod(phase * 2.0, 1.0)
			var thrust := smoothstep(0.0, 0.25, f) * (1.0 - smoothstep(0.25, 1.0, f))
			head.position = _head_base + Vector3(0, -thrust * 0.02, -thrust * 0.085)
			head.rotation.x = lerpf(head.rotation.x, 0.0, delta * 10.0)
			head.rotation.y = lerpf(head.rotation.y, 0.0, delta * 6.0)
			_fold_wings(delta)
			body.rotation.x = lerpf(body.rotation.x, 0.0, delta * 8.0)
		"fly":
			_flap_t += delta
			var flap := sin(_flap_t * 16.0)
			spread_l.rotation.y = lerpf(spread_l.rotation.y, -1.45, delta * 10.0)
			spread_r.rotation.y = lerpf(spread_r.rotation.y, 1.45, delta * 10.0)
			wing_l.rotation.z = -(flap * 0.9 + 0.2)
			wing_r.rotation.z = flap * 0.9 + 0.2
			leg_l.rotation.x = lerpf(leg_l.rotation.x, -1.1, delta * 8.0)
			leg_r.rotation.x = lerpf(leg_r.rotation.x, -1.1, delta * 8.0)
			body.rotation.x = lerpf(body.rotation.x, -0.25, delta * 5.0)
			body.position.y = BODY_Y + flap * 0.03
			head.position = head.position.lerp(_head_base, delta * 8.0)
		"peck":
			_peck_t += delta
			var cyc := fmod(_peck_t, 0.9)
			var down := 0.0
			if cyc < 0.3:
				down = sin(cyc / 0.3 * PI)
			head.rotation.x = -down * 1.1
			head.position = _head_base + Vector3(0, -down * 0.1, -down * 0.08)
			body.rotation.x = lerpf(body.rotation.x, -0.25 * down, delta * 12.0)
			_rest_legs(delta)
			_fold_wings(delta)
		_:
			_rest_legs(delta)
			_fold_wings(delta)
			body.rotation.x = lerpf(body.rotation.x, 0.0, delta * 8.0)
			body.rotation.z = lerpf(body.rotation.z, 0.0, delta * 8.0)
			body.position.y = lerpf(body.position.y, BODY_Y, delta * 8.0)
			head.position = head.position.lerp(_head_base, delta * 8.0)
			head.rotation.x = lerpf(head.rotation.x, 0.0, delta * 8.0)
			# idle head turns
			_look_t -= delta
			if _look_t <= 0.0:
				_look_t = randf_range(0.6, 2.2)
				_look_target = randf_range(-0.7, 0.7)
			head.rotation.y = lerpf(head.rotation.y, _look_target, delta * 9.0)


func _fold_wings(delta: float) -> void:
	spread_l.rotation.y = lerpf(spread_l.rotation.y, 0.0, delta * 10.0)
	spread_r.rotation.y = lerpf(spread_r.rotation.y, 0.0, delta * 10.0)
	wing_l.rotation.z = lerpf(wing_l.rotation.z, 0.0, delta * 10.0)
	wing_r.rotation.z = lerpf(wing_r.rotation.z, 0.0, delta * 10.0)


func _rest_legs(delta: float) -> void:
	leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, delta * 10.0)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, delta * 10.0)
