class_name TvVan
extends Station
## The Crow's Nest TV van, parked at the outpost after Producer Pip's invite.
## Walk up the red carpet to go on the show.

var _dish: Node3D
var _was_on := false
var _label: Label3D


func build() -> void:
	MeshBuilder.node(Models.cached("tv_van", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var white := Color(0.96, 0.96, 0.98)
		b.box(Vector3(3.2, 1.6, 1.8), Vector3(0, 1.1, 0), white)
		b.box(Vector3(1.0, 1.1, 1.8), Vector3(-1.9, 0.85, 0), white)
		b.box(Vector3(0.6, 0.55, 1.6), Vector3(-2.2, 1.15, 0), Color(0.55, 0.75, 0.95))
		b.box(Vector3(3.22, 0.35, 1.82), Vector3(0, 0.75, 0), Color(0.85, 0.15, 0.2))
		for x in [-1.9, 1.0]:
			for z in [-0.9, 0.9]:
				b.cyl(0.33, 0.33, 0.25, Vector3(x, 0.33, z), Color(0.15, 0.15, 0.17), Vector3(90, 0, 0), 12)
		# the red carpet
		b.box(Vector3(1.4, 0.02, 2.6), Vector3(0.4, 0.01, 2.2), Color(0.8, 0.1, 0.15))
		for x in [-0.45, 1.25]:
			for z in [1.4, 3.0]:
				b.cyl(0.05, 0.07, 0.8, Vector3(x, 0.4, z), Models.C_GOLD, Vector3.ZERO, 6)
		b.box(Vector3(0.05, 0.05, 1.6), Vector3(-0.45, 0.72, 2.2), Color(0.6, 0.05, 0.1))
		b.box(Vector3(0.05, 0.05, 1.6), Vector3(1.25, 0.72, 2.2), Color(0.6, 0.05, 0.1))
		return b.build()), self)
	_dish = Node3D.new()
	_dish.position = Vector3(0.6, 1.95, 0)
	add_child(_dish)
	MeshBuilder.node(Models.cached("tv_dish", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.cyl(0.05, 0.05, 0.4, Vector3(0, 0.2, 0), Color(0.6, 0.6, 0.65), Vector3.ZERO, 6)
		b.dome(0.45, Vector3(0, 0.45, 0.05), Color(0.9, 0.9, 0.93), Vector3(1, 0.4, 1), 12)
		return b.build()), _dish)
	_dish.rotation_degrees = Vector3(-35, 0, 0)
	var logo := Fx.label3d("CROW'S NEST", 60, Color(1, 0.85, 0.3), 14)
	logo.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	logo.position = Vector3(0.1, 1.25, 0.92)
	add_child(logo)
	_label = Fx.label3d("ON AIR - step on the carpet!", 36, Color(1, 1, 1), 10)
	_label.position = Vector3(0.4, 3.2, 1.5)
	add_child(_label)
	add_pad("carpet", Vector3(0.4, 0, 3.0), 0.8, "nest", Color(1.0, 0.8, 0.8, 0.95))
	add_collider(Vector3(4.2, 2.0, 1.9), Vector3(-0.4, 0, 0))


func _process(_delta: float) -> void:
	_dish.rotation.y = sin(Time.get_ticks_msec() / 900.0) * 0.6
	var nest: Node = world.get("nest") if world != null else null
	var cool := 0.0
	if nest != null:
		cool = float(nest.get("cooldown"))
	if cool > 0.0:
		_label.text = "Next season in %ds" % int(ceil(cool))
	else:
		_label.text = "ON AIR - step on the carpet!"
	_label.position.y = 3.2 + sin(Time.get_ticks_msec() / 250.0) * 0.06


func service(a: Carrier, _delta: float) -> void:
	if not a.is_player:
		return
	var on := in_pad(a, "carpet")
	if on and not _was_on and world != null:
		world.call("start_nest")
	_was_on = on
