extends Node
## Run with: godot --headless --path . tools/test_military_hud.tscn -- --fresh --quit-after 30

class TestWorld extends Node:
	var military: Military
	var security: Security

var _failures := 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)

func _settle(hud: Hud) -> void:
	for frame in 4:
		hud._adapt_layout()
		hud._update_military_panels()
		await get_tree().process_frame

func _run() -> void:
	Game.dev["quit_after"] = 30.0
	Game.playing = true
	var world := TestWorld.new()
	get_tree().root.add_child(world)
	Game.world = world
	world.military = Military.new(world)
	world.military.state = "active"
	world.military.order = {"need": {"bread": 12, "seeds": 20}, "got": {"bread": 0, "seeds": 0}, "time": 90.0}
	var hud := Hud.new()
	get_tree().root.add_child(hud)
	hud.set_process(false)
	Game.hud = hud
	await _settle(hud)
	var first_row := hud._order_rows.get_child(0)
	var initial_height := hud._order_panel.size.y
	for delivered in [1, 2, 12, 15]:
		world.military.order["got"]["bread"] = delivered
		await _settle(hud)
		_check(hud._order_rows.get_child_count() == 2, "Deliveries must not duplicate product rows")
		_check(hud._order_rows.get_child(0) == first_row, "Deliveries should update existing labels")
		_check(is_equal_approx(hud._order_panel.size.y, initial_height), "Deliveries must not inflate panel height")
		_check(hud._order_counts["bread"].text == "%d / 12" % mini(delivered, 12), "Delivery count must update and cap at the requirement")
	_check(hud._order_counts["bread"].get_theme_color("font_color") == Color(0.6, 1, 0.5), "Completed product rows must turn green")
	# An order can start with exactly the same delivered counts as the last one.
	world.military.order = {"need": {"bread": 99, "seeds": 88}, "got": {"bread": 15, "seeds": 0}, "time": 60.0}
	await _settle(hud)
	_check(hud._order_counts["bread"].text == "15 / 99", "New requirements must refresh even when delivered counts are unchanged")
	world.military.order = {"need": {"pizza": 40}, "got": {"pizza": 0}, "time": 60.0}
	await _settle(hud)
	_check(hud._order_rows.get_child_count() == 1 and hud._order_counts.has("pizza"), "A new order must replace obsolete product rows")
	world.security = Security.new(world)
	world.security.warn_t = 3.0
	hud._global_pill.visible = true
	hud._global_label.text = "Global +$999/s"
	for window_size in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(390, 844), Vector2i(844, 390)]:
		get_window().size = window_size
		await _settle(hud)
		var bounds := hud._order_panel.get_global_rect()
		_check(bounds.position.x >= 0.0 and bounds.end.x <= hud.root.size.x - 15.5, "Order panel must stay inside the right edge at %s" % window_size)
		_check(bounds.end.y <= hud.root.size.y, "Order panel must stay inside the bottom edge at %s" % window_size)
		_check(not bounds.intersects(hud._money_pill.get_global_rect()), "Order panel must not overlap cash")
		_check(not bounds.intersects(hud._global_pill.get_global_rect()), "Order panel must not overlap global income")
		if hud._portrait:
			_check(not bounds.intersects(hud._obj_panel.get_global_rect()), "Portrait task panel must not overlap the objective")
			_check(not bounds.intersects(hud._raid_panel.get_global_rect()), "Portrait task panel must not overlap the raid warning")
	world.military.state = "idle"
	hud._update_military_panels()
	_check(not hud._order_panel.visible, "Finished orders must hide the panel")
	Game.world = null
	Game.hud = null
	hud.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("Military HUD regression checks: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
