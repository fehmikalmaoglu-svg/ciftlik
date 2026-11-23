extends SceneTree
var frames := 0
var out := ""
func _put(p: String, s: float, pos: Vector3, anim := "") -> void:
	var n: Node3D = Assets.inst(p, s, 0.0, pos)
	root.add_child(n)
	if anim != "":
		var ap := n.find_children("*", "AnimationPlayer", true, false)
		if ap.size() > 0: ap[0].play(anim)
func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	var cam := Camera3D.new(); root.add_child(cam); cam.look_at_from_position(Vector3(3.5, 4, 7), Vector3(3.5, 0.3, 0))
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(-0.9, 0.6, 0); sun.shadow_enabled = true; root.add_child(sun)
	var we := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("#9fd4ff"); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color.WHITE; e.ambient_light_energy = 0.5; we.environment = e; root.add_child(we)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); g.mesh = pm; root.add_child(g)
	_put("res://assets/animals/Cow.fbx", 0.1, Vector3(0, 0, 0), "Armature|Idle")
	_put("res://assets/animals/Pig.fbx", 0.085, Vector3(1.5, 0, 0), "Armature|Idle")
	_put("res://assets/animals/Sheep.fbx", 0.1, Vector3(3, 0, 0), "Armature|Idle")
	var i := 0
	for c in ["Wheat", "Carrot", "Tomato", "Corn", "Pumpkin"]:
		for st in 4:
			_put("res://assets/crops/%s_%d.fbx" % [c, st + 1], 0.6, Vector3(-1 + st * 1.0, 0, 2.2 + i * 0.0) + Vector3(0, 0, 0) if false else Vector3(4.5 + st * 0.9, 0, -1.5 + i * 1.0))
		i += 1
	_put("res://assets/crops/Apple_4.fbx", 0.6, Vector3(-1.5, 0, -2))
	_put("res://assets/crops/Apple_Harvested.fbx", 0.6, Vector3(0.5, 0, -2.5))
	_put("res://assets/nature/tree_oak.glb", 2.0, Vector3(-3, 0, -1))
	_put("res://assets/nature/rock_largeA.glb", 1.0, Vector3(-2.5, 0, 1.5))
func _process(_d: float) -> bool:
	frames += 1
	if frames == 40:
		root.get_texture().get_image().save_png(out)
		quit()
	return false
