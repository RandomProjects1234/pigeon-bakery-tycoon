class_name TrashBin
extends Station
## Stand next to it to dump whatever you are carrying.

var _lid: Node3D


func build() -> void:
	MeshBuilder.node(Models.cached("trash", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.cyl(0.38, 0.32, 0.9, Vector3(0, 0.45, 0), Color(0.3, 0.7, 0.45), Vector3.ZERO, 12)
		b.cyl(0.4, 0.4, 0.06, Vector3(0, 0.88, 0), Color(0.25, 0.58, 0.38), Vector3.ZERO, 12)
		for k in 3:
			b.box(Vector3(0.04, 0.6, 0.02), Vector3(-0.15 + k * 0.15, 0.45, 0.37), Color(0.22, 0.52, 0.34))
		return b.build()), self)
	_lid = MeshBuilder.node(Models.cached("trashlid", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.dome(0.4, Vector3.ZERO, Color(0.35, 0.78, 0.5), Vector3(1, 0.4, 1), 12)
		b.box(Vector3(0.2, 0.06, 0.06), Vector3(0, 0.18, 0), Color(0.22, 0.52, 0.34))
		return b.build()), self)
	_lid.position = Vector3(0, 0.9, 0)
	add_pad("dump", Vector3(0, 0, 1.0), 0.65, "ui_close", Color(1.0, 0.75, 0.75, 0.95))
	add_collider(Vector3(0.8, 1.0, 0.8), Vector3.ZERO, 0.2)


func service(a: Carrier, delta: float) -> void:
	if not a.is_player or a.pile.is_empty() or not in_pad(a, "dump"):
		return
	if tick(a, "dump", delta, 0.06):
		var n := a.pile.take()
		if n != null:
			ItemPile.fly_away(n, global_position + Vector3(0, 0.9, 0), 0.25, 0.8)
			Sfx.play("trash", -8.0, randf_range(0.9, 1.2), 0.08)
			Fx.squash(_lid, 0.3, 0.3)
