extends Node
## Boot: title menu over the live world, then play. Also hosts the dev tools
## (--autoshot, --unlock, --auto, --bake-icons); see README.

var world: World
var hud: Hud
var menu: Menu
var _shots: Array = []
var _shot_i := 0
var _clock := 0.0


func _ready() -> void:
	randomize()
	if bool(Game.dev["bake_icons"]):
		var baker := IconBaker.new()
		add_child(baker)
		return
	if str(Game.dev["pose"]) == "pigeon":
		_pose_pigeons()
		_shots = Game.dev["autoshot"]
		return
	_apply_dev_unlocks()
	world = World.new()
	world.name = "World"
	add_child(world)
	hud = Hud.new()
	add_child(hud)
	Game.hud = hud
	hud.visible = false
	var auto_start := (bool(Game.dev["play"]) or Game.test_mode()) and not bool(Game.dev["menu"])
	if auto_start:
		_start()
	else:
		menu = Menu.new()
		add_child(menu)
		menu.play_pressed.connect(_start)
	Sfx.refresh_music()
	_shots = Game.dev["autoshot"]
	if bool(Game.dev["auto"]):
		world.player.bot = PlayerBot.new(world)


## --pose pigeon: close-up line-up of the pigeon variants (for checking the model).
func _pose_pigeons() -> void:
	var root := Node3D.new()
	add_child(root)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.56, 0.82, 0.97)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.86, 0.9, 1.0)
	e.ambient_light_energy = 0.4
	we.environment = e
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	root.add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	g.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Models.C_PEACH
	g.material_override = m
	root.add_child(g)
	var vs := ["std", "dark", "light", "vip", "crow"]
	for i in vs.size():
		var p := PigeonRig.new(vs[i])
		p.position = Vector3(-2.4 + i * 1.2, 0, 0)
		p.rotation.y = -1.2 if i != 2 else 1.2
		root.add_child(p)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 1.6, 3.6)
	cam.look_at(Vector3(0, 0.45, 0))
	cam.current = true


func _start() -> void:
	world.start_play()
	hud.visible = true
	_offline_earnings()


func _offline_earnings() -> void:
	if Game.saved_at <= 0 or Game.test_mode():
		return
	var secs := int(Time.get_unix_time_from_system()) - Game.saved_at
	if secs < 60 or not Game.is_unlocked("hire_cashier"):
		return
	secs = mini(secs, 2 * 3600)
	var staff := world.workers.size()
	var rate := 0.12 * staff * Game.profit_mult() * (1.0 + 0.4 * world.shelves().size())
	var amount := int(rate * secs * 0.5)
	if amount >= 10:
		hud.show_offline(amount, secs)
	Game.saved_at = 0


func _apply_dev_unlocks() -> void:
	var u := str(Game.dev["unlock"])
	if u.is_empty():
		return
	Game.tut = 99
	Game.flags["first_cash"] = true
	if u == "all":
		for z in Layout.ZONES:
			Game.unlocked[str(z["id"])] = true
		return
	if u.begins_with("upto:"):
		var stop := u.substr(5)
		for z in Layout.ZONES:
			Game.unlocked[str(z["id"])] = true
			if str(z["id"]) == stop:
				break
		return
	for id in u.split(","):
		Game.unlocked[id] = true


func _process(delta: float) -> void:
	_clock += delta / maxf(Engine.time_scale, 0.0001)
	if world == null and _shots.is_empty():
		return
	if _shot_i < _shots.size() and _clock >= float(_shots[_shot_i]):
		_shot_i += 1
		_take_shot(_shot_i)
		if _shot_i >= _shots.size():
			get_tree().create_timer(0.2, true, false, true).timeout.connect(get_tree().quit)
	var qa := float(Game.dev["quit_after"])
	if qa > 0.0 and _clock >= qa:
		_report()
		Game.save_game()
		get_tree().quit()


func _take_shot(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := str(Game.dev["shotdir"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := ProjectSettings.globalize_path(dir.path_join("shot_%02d.png" % i))
	img.save_png(path)
	print("[shot] ", path)


func _report() -> void:
	var ids: Array = []
	for z in Layout.ZONES:
		if Game.is_unlocked(str(z["id"])):
			ids.append(str(z["id"]))
	print("[report] t=%.0fs money=%d earned=%d served=%d unlocked=%d/%d pigeons=%d workers=%d" % [
		_clock * Engine.time_scale, Game.money, int(Game.stats["earned"]), int(Game.stats["served"]),
		ids.size(), Layout.ZONES.size(), world.pigeons.size(), world.workers.size()])
	print("[report] last unlocked: ", ids.slice(maxi(0, ids.size() - 4)))
