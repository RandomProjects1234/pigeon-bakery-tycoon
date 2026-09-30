class_name SecurityHQ
extends Station
## Security booth in the back lot. Guards are hired here; its siren light
## spins while a Crow Clan raid is coming or under way.

var _light: Node3D
var _light_mat: StandardMaterial3D


func build() -> void:
	MeshBuilder.node(Models.cached("security_hq", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var navy := Color(0.22, 0.3, 0.5)
		b.box(Vector3(3.2, 2.3, 2.4), Vector3(0, 1.15, -0.2), Color(0.9, 0.92, 0.96))
		b.box(Vector3(3.4, 0.25, 2.6), Vector3(0, 2.4, -0.2), navy)
		b.box(Vector3(3.22, 0.35, 2.42), Vector3(0, 0.7, -0.2), navy)
		b.box(Vector3(1.6, 0.8, 0.05), Vector3(0.5, 1.5, 1.01), Color(0.55, 0.75, 0.95))
		b.box(Vector3(0.8, 1.7, 0.05), Vector3(-0.95, 0.85, 1.01), Color(0.3, 0.36, 0.5))
		b.box(Vector3(0.9, 0.05, 0.3), Vector3(0.5, 1.08, 1.12), navy)
		# camera on a pole
		b.cyl(0.04, 0.04, 0.6, Vector3(1.4, 2.8, 0.7), Color(0.3, 0.3, 0.35), Vector3.ZERO, 6)
		b.box(Vector3(0.18, 0.16, 0.34), Vector3(1.4, 3.1, 0.82), Color(0.95, 0.95, 0.97), Vector3(20, 0, 0))
		return b.build()), self)
	_light = Node3D.new()
	_light.position = Vector3(0, 2.62, -0.2)
	add_child(_light)
	_light_mat = StandardMaterial3D.new()
	_light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_mat.albedo_color = Color(0.5, 0.15, 0.15)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.3
	dome.mesh = sm
	dome.material_override = _light_mat
	_light.add_child(dome)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.08, 0.1)
	beam.mesh = bm
	beam.material_override = _light_mat
	beam.position = Vector3(0.25, 0, 0)
	_light.add_child(beam)
	var lbl := Fx.label3d("SECURITY", 44, Color(1, 1, 1), 12)
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.position = Vector3(0, 2.2, 1.05)
	add_child(lbl)
	add_collider(Vector3(3.4, 2.4, 2.6), Vector3(0, 0, -0.2))


func door_pos() -> Vector3:
	return to_global(Vector3(-0.95, 0, 1.6))


func _process(delta: float) -> void:
	var sec: Security = world.get("security") if world != null else null
	var alarm := sec != null and (sec.raid_active or sec.warn_t > 0.0)
	if alarm:
		_light.rotation.y += delta * 8.0
		_light_mat.albedo_color = Color(1.0, 0.2, 0.2)
	else:
		_light_mat.albedo_color = Color(0.5, 0.15, 0.15)
