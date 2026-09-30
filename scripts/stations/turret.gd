class_name Turret
extends Station
## Seed Slingshot: a little watchtower that flings seeds at raiding crows.

const RANGE := 8.5
const RELOAD := 1.1

var _head: Node3D
var _reload_t := 0.0
var _seed_mat: StandardMaterial3D


func build() -> void:
	MeshBuilder.node(base_mesh(), self)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.68, 0)
	add_child(_head)
	MeshBuilder.node(head_mesh(), _head)
	add_collider(Vector3(1.1, 1.8, 1.1), Vector3.ZERO, 0.2)


static func base_mesh() -> ArrayMesh:
	return Models.cached("turret_base", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		for x in [-0.35, 0.35]:
			for z in [-0.35, 0.35]:
				b.box(Vector3(0.14, 1.6, 0.14), Vector3(x, 0.8, z), Models.C_WOOD, Vector3(-z * 10, 0, x * 10))
		b.box(Vector3(1.1, 0.12, 1.1), Vector3(0, 1.62, 0), Models.C_WOOD_LIGHT)
		b.box(Vector3(0.9, 0.08, 0.08), Vector3(0, 0.8, 0.36), Models.C_WOOD.darkened(0.2))
		b.box(Vector3(0.9, 0.08, 0.08), Vector3(0, 0.8, -0.36), Models.C_WOOD.darkened(0.2))
		b.sphere(0.5, Vector3(0.3, 1.85, 0.3), Color(0.85, 0.7, 0.45), Vector3(0.36, 0.4, 0.36), Vector3.ZERO, 8)
		return b.build())


static func head_mesh() -> ArrayMesh:
	return Models.cached("turret_head", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var wood := Color(0.6, 0.38, 0.22)
		b.cyl(0.06, 0.07, 0.5, Vector3(0, 0.25, 0), wood, Vector3.ZERO, 6)
		b.cyl(0.05, 0.05, 0.45, Vector3(-0.14, 0.62, -0.05), wood, Vector3(0, 0, 25), 6)
		b.cyl(0.05, 0.05, 0.45, Vector3(0.14, 0.62, -0.05), wood, Vector3(0, 0, -25), 6)
		b.box(Vector3(0.5, 0.05, 0.05), Vector3(0, 0.78, 0.05), Color(0.85, 0.3, 0.3))
		b.sphere(0.07, Vector3(0, 0.78, 0.12), Color(0.95, 0.85, 0.5))
		return b.build())


func _process(delta: float) -> void:
	_reload_t -= delta
	var sec: Security = world.get("security") if world != null else null
	if sec == null or sec.raiders.is_empty():
		_head.rotation.y += delta * 0.4
		return
	var target := sec.nearest(global_position, RANGE)
	if target == null:
		return
	var to := target.global_position - global_position
	_head.rotation.y = lerp_angle(_head.rotation.y, atan2(to.x, to.z), clampf(delta * 10.0, 0.0, 1.0))
	if _reload_t <= 0.0:
		_reload_t = RELOAD
		_fire(target)


func _fire(target: Raider) -> void:
	if _seed_mat == null:
		_seed_mat = StandardMaterial3D.new()
		_seed_mat.albedo_color = Color(0.95, 0.8, 0.35)
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	sm.radial_segments = 6
	sm.rings = 3
	s.mesh = sm
	s.material_override = _seed_mat
	world.add_child(s)
	var a := global_position + Vector3(0, 2.4, 0)
	s.global_position = a
	Sfx.play("twang", -8.0, randf_range(0.9, 1.1), 0.05)
	var wr: WeakRef = weakref(target)
	var move := func(t: float) -> void:
		var tr := wr.get_ref() as Raider
		if tr != null:
			var b := tr.global_position + Vector3(0, 0.5, 0)
			s.global_position = a.lerp(b, t) + Vector3.UP * sin(t * PI) * 1.2
	var land := func() -> void:
		var tr := wr.get_ref() as Raider
		if tr != null and tr.hittable():
			tr.hit(1, s.global_position)
		s.queue_free()
	var tw := s.create_tween()
	tw.tween_method(move, 0.0, 1.0, 0.3)
	tw.tween_callback(land)
