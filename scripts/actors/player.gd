class_name Player
extends Carrier
## You: the bakery owner in the chef hat. Joystick (drag anywhere) or WASD.

var locked := false
var bot: RefCounted = null     # PlayerBot when running with --auto
var max_label: Label3D
var _ring: MeshInstance3D
var _step_t := 0.0


func _ready() -> void:
	is_player = true
	role = "owner"
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	rig = HumanRig.new("owner")
	add_child(rig)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.8
	add_child(cs)
	setup_pile(Vector3(0, 0.98, -0.6))
	max_label = Fx.label3d("MAX", 50, Color(1, 0.42, 0.35))
	max_label.no_depth_test = true
	max_label.render_priority = 10
	add_child(max_label)
	# soft ring under the player so you can find yourself in a crowd
	_ring = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(1.3, 1.3)
	_ring.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = Items.icon("fx_ring")
	m.albedo_color = Color(1, 1, 1, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = m
	_ring.position.y = 0.05
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func capacity() -> int:
	return Game.player_capacity()


func interval() -> float:
	return 0.07


func _physics_process(delta: float) -> void:
	var v2 := Vector2.ZERO
	if not locked and Game.playing:
		if bot != null:
			v2 = bot.call("steer", delta)
		else:
			v2 = _input_vec()
	var yaw: float = world.get("cam_yaw") if world != null else 0.0
	var dir := Vector3(v2.x, 0, v2.y).rotated(Vector3.UP, yaw)
	var spd := Game.player_speed() * clampf(v2.length(), 0.0, 1.0)
	if dir.length() > 0.05:
		velocity = dir.normalized() * spd
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	global_position.y = 0.0
	if velocity.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), clampf(delta * 14.0, 0.0, 1.0))
		_step_t += delta * velocity.length()
		if _step_t > 1.6:
			_step_t = 0.0
			Fx.poof(global_position + Vector3(0, 0.05, 0), Color(0.95, 0.95, 0.9), 3, 0.12)
	pile.capacity = capacity()
	rig.carrying = pile.count() > 0
	rig.animate(delta, velocity.length())
	update_sway(delta, velocity)
	max_label.visible = pile.is_full() and pile.count() > 0
	if max_label.visible:
		max_label.position = pile.position + Vector3(0, pile.top_height() + 0.45 + sin(Time.get_ticks_msec() / 150.0) * 0.05, 0)


func _input_vec() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Game.hud != null:
		var j: Vector2 = Game.hud.get("joy")
		if j.length() > 0.08:
			v = j
	return v.limit_length(1.0)
