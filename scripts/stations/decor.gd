class_name Decor
extends Station
## Landmarks that make the bakery more popular: the pigeon fountain, the VIP
## golden perch and the Founder's Statue (a giant golden copy of the logo
## pigeon).

var _t := 0.0
var _birds: Array[PigeonRig] = []
var _crown: Node3D


func build() -> void:
	var kind := str(def["kind"])
	if kind == "statue":
		_build_statue()
	elif str(def.get("model", "")) == "fountain":
		_build_fountain()
	else:
		_build_perch()


func _build_fountain() -> void:
	MeshBuilder.node(Models.cached("fountain", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var stone := Color(0.66, 0.68, 0.74)
		b.cyl(1.6, 1.7, 0.5, Vector3(0, 0.25, 0), stone, Vector3.ZERO, 20)
		b.cyl(1.45, 1.45, 0.06, Vector3(0, 0.46, 0), Color(0.45, 0.75, 1.0), Vector3.ZERO, 20)
		b.cyl(0.25, 0.32, 1.3, Vector3(0, 1.0, 0), stone, Vector3.ZERO, 10)
		b.cyl(0.7, 0.3, 0.25, Vector3(0, 1.7, 0), stone, Vector3.ZERO, 14)
		b.cyl(0.62, 0.62, 0.04, Vector3(0, 1.8, 0), Color(0.5, 0.8, 1.0), Vector3.ZERO, 14)
		b.sphere(0.16, Vector3(0, 1.95, 0), stone)
		return b.build()), self)
	var water := CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.12
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.85, 1.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.material = m
	water.mesh = s
	water.amount = 40
	water.lifetime = 0.9
	water.direction = Vector3.UP
	water.spread = 35.0
	water.initial_velocity_min = 2.2
	water.initial_velocity_max = 2.8
	water.gravity = Vector3(0, -9.0, 0)
	water.position = Vector3(0, 2.05, 0)
	add_child(water)
	for k in 3:
		var bird := PigeonRig.new("std" if k != 1 else "light")
		var a := k * TAU / 3.0 + 0.4
		bird.position = Vector3(cos(a) * 1.55, 0.5, sin(a) * 1.55)
		bird.rotation.y = -a + PI * 0.5
		bird.scale = Vector3.ONE * 0.8
		add_child(bird)
		_birds.append(bird)
	add_collider(Vector3(3.2, 1.0, 3.2), Vector3.ZERO)


func _build_perch() -> void:
	MeshBuilder.node(Models.cached("perch", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.cyl(0.9, 1.0, 0.3, Vector3(0, 0.15, 0), Color(0.55, 0.2, 0.4), Vector3.ZERO, 16)
		b.cyl(0.08, 0.1, 2.2, Vector3(0, 1.3, 0), Models.C_GOLD, Vector3.ZERO, 8)
		b.cyl(0.05, 0.05, 1.8, Vector3(0, 2.3, 0), Models.C_GOLD, Vector3(0, 0, 90), 8)
		b.torus(0.5, 0.05, Vector3(0, 2.9, 0), Models.C_GOLD, Vector3(90, 0, 0))
		b.sphere(0.12, Vector3(0.9, 2.3, 0), Color(1, 0.3, 0.45))
		b.sphere(0.12, Vector3(-0.9, 2.3, 0), Color(1, 0.3, 0.45))
		return b.build()), self)
	var vip := PigeonRig.new("vip")
	vip.position = Vector3(0.45, 2.1, 0)
	vip.scale = Vector3.ONE * 0.75
	add_child(vip)
	_birds.append(vip)
	var l := Fx.label3d("VIP", 60, Models.C_GOLD, 14)
	l.position = Vector3(0, 3.7, 0)
	add_child(l)
	add_collider(Vector3(2.0, 1.0, 2.0), Vector3.ZERO)


func _build_statue() -> void:
	MeshBuilder.node(Models.cached("pedestal", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var stone := Color(0.7, 0.7, 0.75)
		b.box(Vector3(3.6, 0.4, 3.6), Vector3(0, 0.2, 0), stone.darkened(0.1))
		b.box(Vector3(2.8, 1.8, 2.8), Vector3(0, 1.3, 0), stone)
		b.box(Vector3(3.2, 0.3, 3.2), Vector3(0, 2.35, 0), stone.darkened(0.08))
		b.box(Vector3(1.6, 1.0, 0.05), Vector3(0, 1.3, 1.41), Models.C_GOLD)
		return b.build()), self)
	var badge := Sprite3D.new()
	badge.texture = load("res://assets/logo/logo_badge.png")
	badge.pixel_size = 0.9 / 512.0
	badge.position = Vector3(0, 1.38, 1.45)
	add_child(badge)
	var bird := PigeonRig.new("gold")
	bird.position = Vector3(0, 2.5, 0)
	bird.scale = Vector3.ONE * 3.4
	bird.rotation.y = PI + 0.5
	add_child(bird)
	var name_l := Fx.label3d(Game.company, 54, Models.C_GOLD, 14)
	name_l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	name_l.position = Vector3(0, 0.62, 1.82)
	name_l.rotation_degrees = Vector3(-25, 0, 0)
	add_child(name_l)
	Game.company_changed.connect(func(n: String) -> void: name_l.text = n)
	var founder := Fx.label3d("THE FOUNDER", 34, Color(1, 1, 1), 10)
	founder.position = Vector3(0, 6.8, 0)
	add_child(founder)
	add_collider(Vector3(3.6, 2.5, 3.6), Vector3.ZERO)


func _process(delta: float) -> void:
	_t += delta
	for i in _birds.size():
		var b := _birds[i]
		b.animate(delta, 0.0, "peck" if int(_t * 0.3 + i) % 2 == 0 else "idle")
