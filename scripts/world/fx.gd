class_name Fx
extends RefCounted
## Juice: floating "+$5" texts, confetti, smoke poofs, sparkles, pop-in tweens.

static var root: Node3D
static var _font: Font
static var _confetti_mat: StandardMaterial3D
static var _puff_mat: StandardMaterial3D
static var _spark_mat: StandardMaterial3D


## Nunito Black: an open-licensed (OFL) chunky rounded font bundled in
## assets/fonts, so the EXE and the web build look identical.
static func font() -> Font:
	if _font == null:
		var ff: FontFile = load("res://assets/fonts/Nunito-Variable.ttf")
		var fv := FontVariation.new()
		fv.base_font = ff
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): 900}
		_font = fv
	return _font


static func label3d(text: String, size := 64, color := Color.WHITE, outline := 16) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font()
	l.font_size = size
	l.outline_size = outline
	l.modulate = color
	l.outline_modulate = Color(0.16, 0.12, 0.22)
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.double_sided = true
	return l


static func float_text(pos: Vector3, text: String, color := Color(1, 1, 1), size := 70, rise := 1.3, dur := 1.0) -> void:
	if root == null or not is_instance_valid(root):
		return
	var l := label3d(text, size, color)
	l.no_depth_test = true
	l.render_priority = 20
	root.add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", pos + Vector3.UP * rise, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	tw.tween_property(l, "outline_modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	tw.chain().tween_callback(l.queue_free)


static func pop_in(n: Node3D, dur := 0.45, delay := 0.0) -> void:
	var target := n.scale if n.scale.length() > 0.01 else Vector3.ONE
	n.scale = Vector3.ONE * 0.01
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(n, "scale", target, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func squash(n: Node3D, amount := 0.15, dur := 0.25) -> void:
	if n.has_meta("sq"):
		var old: Variant = n.get_meta("sq")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := n.create_tween()
	n.scale = Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount)
	tw.tween_property(n, "scale", Vector3.ONE, dur).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	n.set_meta("sq", tw)


static func _free_later(n: Node, secs: float) -> void:
	var t := n.get_tree().create_timer(secs, false)
	t.timeout.connect(n.queue_free)


static func confetti(pos: Vector3, amount := 60, spread := 50.0) -> void:
	if root == null or not is_instance_valid(root):
		return
	if _confetti_mat == null:
		_confetti_mat = StandardMaterial3D.new()
		_confetti_mat.vertex_color_use_as_albedo = true
		_confetti_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_confetti_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.09)
	q.material = _confetti_mat
	p.mesh = q
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.8
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector3(0, -9.0, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.angular_velocity_min = -600.0
	p.angular_velocity_max = 600.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.particle_flag_rotate_y = true
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 0.3, 0.35), Color(1, 0.8, 0.1), Color(0.3, 0.85, 0.4),
		Color(0.3, 0.6, 1.0), Color(0.8, 0.4, 1.0), Color(1, 0.55, 0.2)])
	p.color_initial_ramp = g
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_later(p, 3.0)


static func poof(pos: Vector3, color := Color(1, 1, 1), amount := 14, size := 0.35) -> void:
	if root == null or not is_instance_valid(root):
		return
	if _puff_mat == null:
		_puff_mat = StandardMaterial3D.new()
		_puff_mat.vertex_color_use_as_albedo = true
		_puff_mat.roughness = 1.0
	var p := CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	s.radial_segments = 8
	s.rings = 4
	s.material = _puff_mat
	p.mesh = s
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 1.0, 0)
	p.damping_min = 3.0
	p.damping_max = 5.0
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = c
	p.color = color
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_later(p, 1.5)


static func sparkle(pos: Vector3, amount := 10) -> void:
	if root == null or not is_instance_valid(root):
		return
	if _spark_mat == null:
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.albedo_texture = Items.icon("fx_sparkle")
		_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spark_mat.vertex_color_use_as_albedo = true
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	q.material = _spark_mat
	p.mesh = q
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.8
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 90.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -1.0, 0)
	var c := Curve.new()
	c.add_point(Vector2(0, 0.2))
	c.add_point(Vector2(0.25, 1.0))
	c.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = c
	p.color = Color(1.0, 0.95, 0.5)
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_later(p, 1.5)
