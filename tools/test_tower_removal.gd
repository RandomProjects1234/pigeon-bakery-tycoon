extends Node
## godot --headless --path . tools/test_tower_removal.tscn -- --fresh --quit-after 30

class TestWorld extends Node:
	var location := "bakery"

var _failures := 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)

func _button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null

func _run() -> void:
	Game.dev["quit_after"] = 30.0
	Game.playing = true
	Game.money = 1000000000
	get_window().size = Vector2i(1280, 720)
	var world := TestWorld.new()
	add_child(world)
	Game.world = world
	var war := CrowWar.new(world)
	add_child(war)
	war.set_physics_process(false)
	var hud := Hud.new()
	add_child(hud)
	hud.set_process(false)
	Game.hud = hud
	_check(war.build_weapon(0, "slingshot"), "A tower must build on an empty pad")
	_check(war.upgrade_weapon(0), "A tower must be upgradeable before removal")
	var tower: HQWeapon = war.weapons[0]
	hud.war_pad_menu(war, 0)
	_button(hud._modal, "Remove").pressed.emit()
	_check(hud._modal.name == "WarRemove", "Remove must open a confirmation")
	_check(war.weapons.has(0), "Opening the confirmation must keep the tower")
	_button(hud._modal, "Keep it").pressed.emit()
	_check(war.weapons.has(0) and tower.level == 2, "Cancel must preserve the tower and its upgrades")
	_check(_button(hud._modal, "Remove") != null and _button(hud._modal, "Keep it") == null, "Cancel must return to the upgrade menu")
	_button(hud._modal, "Remove").pressed.emit()
	var args := OS.get_cmdline_user_args()
	var proof_index := args.find("--proof")
	if proof_index >= 0 and proof_index + 1 < args.size():
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[proof_index + 1])
	var money_before := Game.money
	_button(hud._modal, "Remove").pressed.emit()
	_check(not war.weapons.has(0), "Confirm must free the occupied pad")
	_check(not tower.is_inside_tree(), "The removed tower's model and collisions must detach immediately")
	_check(not (Game.war["weapons"] as Dictionary).has("0"), "Removal must update saved weapons")
	_check(Game.money == money_before, "Removal must not charge or refund money")
	_check(hud._modal == null, "Successful removal must close the dialog")
	_check(not war.remove_weapon(0), "Removing an empty pad must be harmless")
	_check(war.build_weapon(0, "baguette"), "A different tower must be buildable on the freed pad")
	_check(war.weapons[0].type == "baguette" and war.weapons[0].level == 1, "A replacement must start at level one")
	_check(war.build_weapon(1, "shield") and war.build_weapon(2, "shield"), "Multiple shields must build")
	war.shield_hp = war.shield_max()
	war.remove_weapon(1)
	_check(war.shield_hp == war.shield_max() and war.shield_hp > 0.0, "Removing one shield must clamp health to the remaining capacity")
	war.remove_weapon(2)
	_check(war.shield_hp == 0.0 and not war._dome.visible, "Removing the final shield must clear its health and dome")
	for weapon_type in ["hangar", "tank"]:
		war.build_weapon(3, weapon_type)
		var deployment: HQWeapon = war.weapons[3]
		var units := deployment._units.duplicate()
		_check(units.size() == (3 if weapon_type == "hangar" else 2), "Deployment must create its units")
		war.remove_weapon(3)
		for unit in units:
			_check(not unit.is_processing(), "Removed deployment units must stop immediately")
		await get_tree().process_frame
		for unit in units:
			_check(not is_instance_valid(unit), "Removing a deployment must free its fighters or tanks")
	# In-flight effects belong to the tower and must not keep freed callbacks alive.
	var enemy := WarCrow.new()
	war.add_child(enemy)
	enemy.set_process(false)
	enemy.rig = PigeonRig.new("crow")
	enemy.add_child(enemy.rig)
	var replacement: HQWeapon = war.weapons[0]
	replacement._shoot(enemy)
	var projectile := replacement.get_child(replacement.get_child_count() - 1)
	_check(projectile is MeshInstance3D and (projectile as Node3D).top_level, "Tower shots must belong to the tower without inheriting its transform")
	war.remove_weapon(0)
	await get_tree().process_frame
	_check(not is_instance_valid(projectile), "Removing a firing tower must clean up its in-flight projectile")
	war.build_weapon(4, "sonic")
	war.build_weapon(5, "slingshot")
	war.remove_weapon(4)
	# Round-trip the state through JSON exactly as the save file does, then reload HQ.
	Game.war = JSON.parse_string(JSON.stringify(Game.war))
	war.queue_free()
	await get_tree().process_frame
	var restored := CrowWar.new(world)
	add_child(restored)
	restored.set_physics_process(false)
	_check(restored.weapons.size() == 1 and restored.weapons.has(5), "Reload must restore the retained tower and leave removed pads empty")
	Game.world = null
	Game.hud = null
	print("Tower removal regression checks: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
