class_name Depot
extends Station
## The military Supply Depot at the outpost. Drop ordered products in the
## supply crate; General Coo and his soldiers wait here, and the army truck
## rolls up when an order is accepted. Rewards land on the cash pile.

var cash: CashPile
var truck: Node3D
var general: PigeonRig
var soldiers: Array[PigeonRig] = []
var _truck_home := Vector3(4.2, 0, 0.3)
var _truck_here := false
var _crate: Node3D
var _t := 0.0
var _rank_label: Label3D


func build() -> void:
	MeshBuilder.node(Models.cached("depot", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var olive := Color(0.42, 0.5, 0.3)
		var dark := Color(0.3, 0.36, 0.22)
		b.box(Vector3(4.6, 2.4, 3.0), Vector3(0, 1.2, -1.6), olive)
		b.prism(Vector3(5.0, 1.1, 3.4), Vector3(0, 2.95, -1.6), dark)
		b.box(Vector3(2.0, 1.8, 0.06), Vector3(0.6, 0.9, -0.08), Color(0.25, 0.28, 0.2))
		for k in 5:
			b.box(Vector3(1.9, 0.04, 0.07), Vector3(0.6, 0.2 + k * 0.35, -0.04), Color(0.35, 0.4, 0.28))
		b.box(Vector3(1.0, 0.5, 0.05), Vector3(-1.4, 1.5, -0.08), Color(0.9, 0.85, 0.6))
		# sandbags
		for k in 7:
			b.sphere(0.5, Vector3(-2.2 + k * 0.72, 0.18, 0.35), Color(0.82, 0.74, 0.52), Vector3(0.7, 0.36, 0.42), Vector3.ZERO, 8)
		for k in 6:
			b.sphere(0.5, Vector3(-1.85 + k * 0.72, 0.46, 0.35), Color(0.78, 0.7, 0.48), Vector3(0.7, 0.34, 0.4), Vector3.ZERO, 8)
		# flag pole with a gold star flag
		b.cyl(0.05, 0.06, 4.2, Vector3(-2.7, 2.1, -2.8), Color(0.8, 0.8, 0.82), Vector3.ZERO, 6)
		b.box(Vector3(1.2, 0.75, 0.04), Vector3(-2.08, 3.75, -2.8), Color(0.35, 0.5, 0.28))
		b.cyl(0.18, 0.18, 0.05, Vector3(-2.08, 3.75, -2.77), Models.C_GOLD, Vector3(90, 0, 0), 5)
		return b.build()), self)
	# supply crate pallet
	_crate = MeshBuilder.node(Models.cached("supply_crate", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(1.5, 0.14, 1.1), Vector3(0, 0.07, 0), Models.C_WOOD.darkened(0.2))
		b.box(Vector3(1.3, 0.8, 0.95), Vector3(0, 0.55, 0), Color(0.55, 0.62, 0.38))
		b.box(Vector3(1.34, 0.08, 0.99), Vector3(0, 0.9, 0), Color(0.4, 0.46, 0.28))
		b.box(Vector3(0.5, 0.3, 0.02), Vector3(0, 0.55, 0.49), Color(0.95, 0.9, 0.7))
		b.cyl(0.1, 0.1, 0.02, Vector3(0, 0.55, 0.5), Color(0.8, 0.2, 0.2), Vector3(90, 0, 0), 5)
		return b.build()), self)
	_crate.position = Vector3(-1.3, 0, 1.0)
	add_pad("crate", Vector3(-1.3, 0, 2.3), 0.85, "military", Color(1.0, 0.9, 0.6, 0.95))
	cash = CashPile.new()
	cash.name = "Cash"
	add_child(cash)
	cash.setup(2, 3, 48)
	cash.position = Vector3(1.3, 0, 1.4)
	var mat := MeshBuilder.node(Models.cached("cashmat", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(1.1, 0.04, 1.1), Vector3(0, 0.02, 0), Color(0.36, 0.72, 0.36))
		return b.build()), self)
	mat.position = cash.position
	# truck
	truck = Node3D.new()
	truck.position = _truck_home
	add_child(truck)
	MeshBuilder.node(Models.cached("army_truck", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var olive := Color(0.38, 0.46, 0.28)
		b.box(Vector3(1.9, 0.9, 1.4), Vector3(0, 1.0, -1.45), olive)                 # cab
		b.box(Vector3(1.7, 0.5, 0.05), Vector3(0, 1.2, -2.16), Color(0.55, 0.75, 0.9)) # windscreen
		b.box(Vector3(2.0, 0.3, 4.4), Vector3(0, 0.55, 0), olive.darkened(0.2))       # chassis
		b.box(Vector3(2.0, 1.5, 2.9), Vector3(0, 1.45, 0.7), Color(0.5, 0.56, 0.38))  # canvas back
		b.box(Vector3(0.3, 0.3, 0.05), Vector3(0, 1.45, 2.16), Models.C_GOLD)
		for z in [-1.5, 1.3]:
			for x in [-1.0, 1.0]:
				b.cyl(0.38, 0.38, 0.28, Vector3(x, 0.38, z), Color(0.15, 0.15, 0.17), Vector3(0, 0, 90), 12)
		b.box(Vector3(0.3, 0.14, 0.05), Vector3(-0.6, 0.75, -2.16), Color(1, 0.95, 0.7))
		b.box(Vector3(0.3, 0.14, 0.05), Vector3(0.6, 0.75, -2.16), Color(1, 0.95, 0.7))
		return b.build()), truck)
	truck.visible = false
	add_collider(Vector3(2.1, 1.8, 4.5), _truck_home)
	# General Coo + a squad of pigeon soldiers
	general = PigeonRig.new("general")
	general.scale = Vector3.ONE * 1.35
	general.position = Vector3(-2.6, 0, 1.6)
	general.rotation.y = PI - 0.4
	add_child(general)
	for k in 3:
		var s := PigeonRig.new("soldier")
		s.position = Vector3(-3.9, 0, -1.6 + k * 0.95)
		s.rotation.y = -PI * 0.5
		add_child(s)
		soldiers.append(s)
	var lbl := Fx.label3d("SUPPLY DEPOT", 46, Color(1, 0.95, 0.7), 12)
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.position = Vector3(0, 3.4, -0.05)
	add_child(lbl)
	_rank_label = Fx.label3d("", 30, Color(1, 1, 1), 10)
	_rank_label.position = Vector3(-2.6, 2.6, 1.6)
	add_child(_rank_label)
	add_collider(Vector3(4.6, 2.4, 3.0), Vector3(0, 0, -1.6))
	add_collider(Vector3(1.5, 1.0, 1.1), Vector3(-1.3, 0, 1.0), 0.2)
	add_collider(Vector3(5.2, 0.8, 0.7), Vector3(0.2, 0, 0.35), 0.1)
	var mil: Military = world.get("military") if world != null else null
	if mil != null and mil.state == "active":
		truck_arrive()


func _process(delta: float) -> void:
	_t += delta
	general.animate(delta, 0.0, "idle")
	for i in soldiers.size():
		# soldiers stand to attention and bob their heads in unison
		soldiers[i].animate(delta, 0.0, "idle" if int(_t * 0.5) % 2 == 0 else "peck")
	_rank_label.text = "General Coo\n" + Military.rank_name(int(Game.military["done"]))


func truck_arrive() -> void:
	if _truck_here:
		return
	_truck_here = true
	truck.visible = true
	truck.position = _truck_home + Vector3(0, 0, 9)
	var tw := truck.create_tween()
	tw.tween_property(truck, "position", _truck_home, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func truck_leave() -> void:
	if not _truck_here:
		return
	_truck_here = false
	var tw := truck.create_tween()
	tw.tween_property(truck, "position", _truck_home + Vector3(0, 0, 9), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Fx.poof(truck.global_position + Vector3(0, 1, 0), Color(0.8, 0.8, 0.8), 14, 0.4)
		truck.visible = false)


func pay_out(amount: int) -> void:
	cash.deposit(amount, global_position + _truck_home + Vector3(0, 2.0, 0))
	Fx.confetti(global_position + Vector3(0, 1.0, 1.5), 60)


func service(a: Carrier, delta: float) -> void:
	var mil: Military = world.get("military")
	if mil != null and mil.state == "active" and in_pad(a, "crate"):
		for t in mil.needed_types():
			if not a.pile.has_type(t) or not a.wants_drop(self, "crate", t):
				continue
			if tick(a, "crate", delta, a.interval()):
				var n := a.pile.take(t)
				if n != null:
					ItemPile.fly_away(n, _crate.global_position + Vector3(0, 0.9, 0), 0.28, 0.9)
					mil.deliver(t)
					if a.is_player:
						Sfx.play("drop", -5.0, 1.0 + randf() * 0.2)
			break
	if a.is_player and cash.value > 0 and cash.near(a.global_position):
		cash.collect(a)


func save_state() -> Dictionary:
	return {"cash": cash.value}


func load_state(d: Dictionary) -> void:
	cash.restore(int(d.get("cash", 0)))
