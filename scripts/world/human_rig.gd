class_name HumanRig
extends Node3D
## Chunky little staff member (the player is the "owner" role). Faces -Z.
## Roles: owner, farmer, baker, cashier, janitor.

var role := "owner"
var hips: Node3D
var torso: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var phase := 0.0
var carrying := false
var _idle_t := 0.0

const SKIN := Color(1.0, 0.8, 0.64)


static func colors(r: String) -> Dictionary:
	match r:
		"farmer":
			return {"shirt": Color(0.9, 0.36, 0.3), "pants": Color(0.3, 0.55, 0.85), "over": Color(0.3, 0.55, 0.85)}
		"baker":
			return {"shirt": Color(0.97, 0.96, 0.94), "pants": Color(0.4, 0.4, 0.45), "over": Color(1.0, 0.6, 0.25)}
		"cashier":
			return {"shirt": Color(0.62, 0.42, 0.9), "pants": Color(0.25, 0.22, 0.35), "over": Color(0.62, 0.42, 0.9)}
		"janitor":
			return {"shirt": Color(0.4, 0.62, 0.66), "pants": Color(0.3, 0.42, 0.46), "over": Color(1.0, 0.82, 0.2)}
	return {"shirt": Color(0.24, 0.56, 0.98), "pants": Color(0.2, 0.3, 0.6), "over": Color(0.98, 0.98, 0.98)}


func _init(r := "owner") -> void:
	role = r
	_build()


func _build() -> void:
	var c := colors(role)
	var rr := role
	hips = Node3D.new()
	hips.position = Vector3(0, 0.55, 0)
	add_child(hips)
	torso = Node3D.new()
	hips.add_child(torso)
	MeshBuilder.node(Models.cached("hu_torso_" + rr, func() -> ArrayMesh: return _torso_mesh(rr, c)), torso)
	var arm_mesh := Models.cached("hu_arm_" + rr, func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.capsule(0.075, 0.46, Vector3(0, -0.2, 0), c["shirt"])
		b.sphere(0.085, Vector3(0, -0.44, 0), SKIN, Vector3.ONE, Vector3.ZERO, 8)
		return b.build())
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(0.31 * side, 0.64, 0)
		torso.add_child(arm)
		MeshBuilder.node(arm_mesh, arm)
		if side < 0:
			arm_l = arm
		else:
			arm_r = arm
	var leg_mesh := Models.cached("hu_leg_" + rr, func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.capsule(0.095, 0.5, Vector3(0, -0.24, 0), c["pants"])
		b.box(Vector3(0.17, 0.1, 0.26), Vector3(0, -0.5, -0.04), Color(0.25, 0.2, 0.22))
		return b.build())
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(0.12 * side, 0.02, 0)
		hips.add_child(leg)
		MeshBuilder.node(leg_mesh, leg)
		if side < 0:
			leg_l = leg
		else:
			leg_r = leg


static func _torso_mesh(r: String, c: Dictionary) -> ArrayMesh:
	var b := MeshBuilder.new()
	var shirt: Color = c["shirt"]
	b.capsule(0.27, 0.78, Vector3(0, 0.36, 0), shirt, Vector3.ZERO, Vector3(1, 1, 0.85))
	# apron / overalls bib
	if r == "owner" or r == "baker" or r == "farmer":
		var over: Color = c["over"]
		b.box(Vector3(0.36, 0.42, 0.05), Vector3(0, 0.28, -0.215), over)
		b.box(Vector3(0.44, 0.08, 0.46), Vector3(0, 0.12, 0), over, Vector3.ZERO, Vector3(1, 1, 1))
	# head
	b.sphere(0.25, Vector3(0, 0.98, 0), SKIN, Vector3(1, 0.96, 1), Vector3.ZERO, 14)
	for side in [-1, 1]:
		b.sphere(0.035, Vector3(0.09 * side, 1.01, -0.225), Models.C_INK, Vector3(1, 1.3, 0.6), Vector3.ZERO, 6)
	b.sphere(0.035, Vector3(0, 0.95, -0.25), Color(1.0, 0.68, 0.55), Vector3.ONE, Vector3.ZERO, 6)
	b.sphere(0.04, Vector3(0.16, 0.93, -0.19), Color(1.0, 0.6, 0.6), Vector3(1, 0.6, 0.4), Vector3.ZERO, 6)
	b.sphere(0.04, Vector3(-0.16, 0.93, -0.19), Color(1.0, 0.6, 0.6), Vector3(1, 0.6, 0.4), Vector3.ZERO, 6)
	match r:
		"owner":   # chef toque
			b.cyl(0.21, 0.2, 0.2, Vector3(0, 1.28, 0), Models.C_WHITE, Vector3.ZERO, 12)
			b.sphere(0.17, Vector3(-0.1, 1.44, 0), Models.C_WHITE, Vector3.ONE, Vector3.ZERO, 10)
			b.sphere(0.17, Vector3(0.1, 1.44, 0), Models.C_WHITE, Vector3.ONE, Vector3.ZERO, 10)
			b.sphere(0.18, Vector3(0, 1.5, 0), Models.C_WHITE, Vector3.ONE, Vector3.ZERO, 10)
		"farmer":  # straw hat
			b.cyl(0.42, 0.42, 0.03, Vector3(0, 1.17, 0), Color(0.95, 0.83, 0.5), Vector3.ZERO, 14)
			b.cyl(0.19, 0.22, 0.18, Vector3(0, 1.27, 0), Color(0.95, 0.83, 0.5), Vector3.ZERO, 12)
			b.cyl(0.225, 0.225, 0.05, Vector3(0, 1.21, 0), Color(0.85, 0.3, 0.25), Vector3.ZERO, 12)
		"baker":
			b.cyl(0.22, 0.22, 0.14, Vector3(0, 1.22, 0), Models.C_WHITE, Vector3.ZERO, 12)
		"cashier": # visor cap
			b.dome(0.25, Vector3(0, 1.08, 0), Color(0.3, 0.75, 0.45), Vector3(1.02, 0.6, 1.02))
			b.box(Vector3(0.3, 0.03, 0.2), Vector3(0, 1.1, -0.3), Color(0.3, 0.75, 0.45))
		"janitor":
			b.dome(0.25, Vector3(0, 1.08, 0), Color(1.0, 0.82, 0.2), Vector3(1.02, 0.6, 1.02))
			b.box(Vector3(0.3, 0.03, 0.2), Vector3(0, 1.1, -0.3), Color(1.0, 0.82, 0.2))
	return b.build()


func animate(delta: float, speed: float) -> void:
	var moving := speed > 0.2
	if moving:
		phase += delta * (1.4 + speed * 0.42)
		var s := sin(phase * TAU)
		leg_l.rotation.x = s * 0.7
		leg_r.rotation.x = -s * 0.7
		hips.position.y = 0.55 + absf(cos(phase * TAU)) * 0.05
		torso.rotation.z = s * 0.04
		torso.rotation.x = lerpf(torso.rotation.x, -0.08, delta * 8.0)
	else:
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, delta * 12.0)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, delta * 12.0)
		_idle_t += delta
		hips.position.y = lerpf(hips.position.y, 0.55 + sin(_idle_t * 3.0) * 0.01, delta * 10.0)
		torso.rotation.z = lerpf(torso.rotation.z, 0.0, delta * 8.0)
		torso.rotation.x = lerpf(torso.rotation.x, 0.0, delta * 8.0)
	if carrying:
		arm_l.rotation.x = lerpf(arm_l.rotation.x, 1.35, delta * 14.0)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, 1.35, delta * 14.0)
		arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.25, delta * 14.0)
		arm_r.rotation.z = lerpf(arm_r.rotation.z, -0.25, delta * 14.0)
	else:
		var sw := sin(phase * TAU) * 0.6 if moving else 0.0
		arm_l.rotation.x = lerpf(arm_l.rotation.x, -sw, delta * 12.0)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, sw, delta * 12.0)
		arm_l.rotation.z = lerpf(arm_l.rotation.z, -0.08, delta * 12.0)
		arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.08, delta * 12.0)
