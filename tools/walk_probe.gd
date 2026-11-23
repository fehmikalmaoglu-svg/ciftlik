extends SceneTree
## Uzak noktalara yürüme denemesi: --fresh ile çalıştır, kayıtlara dokunmaz.

func _initialize() -> void:
	_run()

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	var g = null
	for i in 600:
		await process_frame
		g = current_scene
		if g != null and g.get("ready_done") and g.playing:
			break
	for target in [Vector3(35, 0, 35), Vector3(-50, 0, -30), Vector3(18, 0, 3), Vector3(0, 0, 50)]:
		g.farmer.position = Vector3(0.5, 0, 9.0)
		g._walk_to(target)
		var t := 0
		var log := []
		for f in 1500:
			g._update_farmer(1.0 / 60.0)
			var d: float = Vector2(g.farmer.position.x - target.x, g.farmer.position.z - target.z).length()
			if f % 60 == 0:
				log.append("%.1f,%.1f" % [g.farmer.position.x, g.farmer.position.z])
			if g.move_target == null:
				break
			t = f
		print("hedef ", target, " son ", g.farmer.position, " kare ", t, " iz ", " ".join(log))
	quit()
