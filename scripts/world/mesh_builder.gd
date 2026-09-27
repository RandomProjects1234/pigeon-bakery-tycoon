class_name MeshBuilder
extends RefCounted
## Merges many coloured primitives into ONE ArrayMesh with vertex colours, so a
## whole bread loaf / pigeon wing / oven is a single draw call. Every mesh
## built here uses the shared `material()`, which reads albedo from vertex colour.

static var _prims := {}
static var _mat: StandardMaterial3D
static var _mat_glow: StandardMaterial3D

var _st := SurfaceTool.new()
var _count := 0


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.82
		_mat.metallic_specular = 0.3
	return _mat


## Same as material() but unshaded-ish glowing (oven mouths, lamps).
static func glow_material() -> StandardMaterial3D:
	if _mat_glow == null:
		_mat_glow = StandardMaterial3D.new()
		_mat_glow.vertex_color_use_as_albedo = true
		_mat_glow.vertex_color_is_srgb = true
		_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _mat_glow


static func node(mesh: Mesh, parent: Node = null, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = glow_material() if glow else material()
	if parent != null:
		parent.add_child(mi)
	return mi


static func _prim(key: String, maker: Callable) -> PrimitiveMesh:
	if not _prims.has(key):
		_prims[key] = maker.call()
	return _prims[key]


func add_mesh(mesh: Mesh, xf: Transform3D, color: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	if idx.is_empty():
		for i in verts.size():
			_st.set_color(color)
			_st.set_normal((nb * norms[i]).normalized())
			_st.add_vertex(xf * verts[i])
	else:
		for i in idx:
			_st.set_color(color)
			_st.set_normal((nb * norms[i]).normalized())
			_st.add_vertex(xf * verts[i])
	_count += 1


static func xform(pos: Vector3, rot_deg: Vector3, scl: Vector3) -> Transform3D:
	var r := Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	return Transform3D(Basis.from_euler(r) * Basis.from_scale(scl), pos)


func box(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshBuilder:
	var m := _prim("box", func() -> PrimitiveMesh: return BoxMesh.new())
	add_mesh(m, xform(pos, rot, size * scl), color)
	return self


func sphere(r: float, pos: Vector3, color: Color, scl := Vector3.ONE, rot := Vector3.ZERO, seg := 12) -> MeshBuilder:
	var key := "sph%d" % seg
	var m := _prim(key, func() -> PrimitiveMesh:
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = seg
		s.rings = maxi(4, seg / 2)
		return s)
	add_mesh(m, xform(pos, rot, scl * r), color)
	return self


## Hemisphere (dome), flat side down.
func dome(r: float, pos: Vector3, color: Color, scl := Vector3.ONE, seg := 14) -> MeshBuilder:
	var key := "dome%d" % seg
	var m := _prim(key, func() -> PrimitiveMesh:
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 1.0
		s.is_hemisphere = true
		s.radial_segments = seg
		s.rings = maxi(3, seg / 3)
		return s)
	add_mesh(m, xform(pos, Vector3.ZERO, scl * r), color)
	return self


func cyl(r_top: float, r_bot: float, h: float, pos: Vector3, color: Color, rot := Vector3.ZERO, seg := 12) -> MeshBuilder:
	# cache by radius ratio so different sizes share a unit primitive
	var ratio := 0.0 if r_bot <= 0.0 else r_top / r_bot
	var base_r := r_bot if r_bot > 0.0 else r_top
	var key := "cyl%d_%.3f_%s" % [seg, ratio, "inv" if r_bot <= 0.0 else ""]
	var m := _prim(key, func() -> PrimitiveMesh:
		var c := CylinderMesh.new()
		if r_bot <= 0.0:
			c.top_radius = 1.0
			c.bottom_radius = 0.0
		else:
			c.top_radius = ratio
			c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = seg
		c.rings = 1
		return c)
	add_mesh(m, xform(pos, rot, Vector3(base_r, h, base_r)), color)
	return self


func capsule(r: float, h: float, pos: Vector3, color: Color, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshBuilder:
	var key := "cap%.3f" % (h / r)
	var m := _prim(key, func() -> PrimitiveMesh:
		var c := CapsuleMesh.new()
		c.radius = 1.0
		c.height = h / r
		c.radial_segments = 12
		c.rings = 4
		return c)
	add_mesh(m, xform(pos, rot, scl * r), color)
	return self


func prism(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshBuilder:
	var m := _prim("prism", func() -> PrimitiveMesh: return PrismMesh.new())
	add_mesh(m, xform(pos, rot, size), color)
	return self


func torus(r_ring: float, r_tube: float, pos: Vector3, color: Color, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshBuilder:
	var key := "tor%.3f" % (r_tube / r_ring)
	var m := _prim(key, func() -> PrimitiveMesh:
		var t := TorusMesh.new()
		t.inner_radius = 1.0 - r_tube / r_ring
		t.outer_radius = 1.0 + r_tube / r_ring
		t.rings = 16
		t.ring_segments = 8
		return t)
	add_mesh(m, xform(pos, rot, scl * r_ring), color)
	return self


func build() -> ArrayMesh:
	_st.index()
	return _st.commit()


func is_empty() -> bool:
	return _count == 0
