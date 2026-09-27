class_name IconBaker
extends Node
## `godot -- --bake-icons` renders every item model to assets/icons/<item>.png
## (transparent, 128 px) so the UI icons match the 3D items exactly.
## tools/outline_icons.py then adds the sticker outline.

const ITEMS: Array[String] = ["wheat", "sunflower", "flour", "tomato", "potato", "bread", "seeds",
	"croissant", "pizza", "fries", "cash"]


func _ready() -> void:
	_bake()


func _bake() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.7
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.0
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	cam.current = true
	for t in ITEMS:
		var n := Models.item(t)
		vp.add_child(n)
		var mi := n.get_child(0) as MeshInstance3D
		var aabb := mi.get_aabb()
		var c := aabb.get_center()
		var r := aabb.size.length() * 0.5
		cam.size = r * 2.05
		var dir := Vector3(0.45, 0.75, 1.0).normalized()
		cam.position = c + dir * 4.0
		cam.look_at(c, Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		var path := ProjectSettings.globalize_path("res://assets/icons/%s.png" % t)
		img.save_png(path)
		print("[bake] ", path)
		n.queue_free()
		await get_tree().process_frame
	get_tree().quit()
