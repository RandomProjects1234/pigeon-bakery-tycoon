class_name Limo
extends Station
## The company limo at the outpost: step on the pad to ride to the HQ tower.

var _was_on := false


func build() -> void:
	MeshBuilder.node(Models.cached("limo_bakery", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var black := Color(0.08, 0.08, 0.1)
		b.box(Vector3(5.2, 0.7, 1.8), Vector3(0, 0.6, 0), black)
		b.box(Vector3(3.2, 0.55, 1.6), Vector3(0.2, 1.2, 0), Color(0.12, 0.12, 0.15))
		b.box(Vector3(3.0, 0.35, 1.62), Vector3(0.2, 1.25, 0), Color(0.4, 0.5, 0.65))
		for x in [-1.9, 1.9]:
			for z in [-0.9, 0.9]:
				b.cyl(0.35, 0.35, 0.22, Vector3(x, 0.35, z), Color(0.2, 0.2, 0.22), Vector3(90, 0, 0), 12)
		b.box(Vector3(0.05, 0.1, 0.2), Vector3(-2.62, 0.9, 0), Models.C_GOLD)
		b.box(Vector3(1.4, 0.02, 2.4), Vector3(0.4, 0.01, 2.0), Color(0.8, 0.1, 0.15))
		return b.build()), self)
	var l := Fx.label3d("Limo to your HQ Tower", 36, Color(1, 0.9, 0.5), 10)
	l.position = Vector3(0.4, 2.4, 1.4)
	add_child(l)
	add_pad("ride", Vector3(0.4, 0, 2.6), 0.8, "hq", Color(1.0, 0.9, 0.6, 0.95))
	add_collider(Vector3(5.3, 1.6, 1.9), Vector3.ZERO)


func service(a: Carrier, _delta: float) -> void:
	if not a.is_player:
		return
	var on := in_pad(a, "ride")
	if on and not _was_on and world != null:
		world.call("travel", "hq")
	_was_on = on
