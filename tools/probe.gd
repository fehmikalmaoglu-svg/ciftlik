extends SceneTree
func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D: t = xf * n.transform
	if n is MeshInstance3D and n.mesh:
		var b: AABB = t * n.get_aabb()
		acc[0] = b if acc[0] == null else acc[0].merge(b)
	for c in n.get_children(): _aabb(c, t, acc)
func _init() -> void:
	var files := []
	for d in ["res://assets/animals/", "res://assets/crops/", "res://assets/nature/"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".fbx") or f.ends_with(".glb"): files.append(d + f)
	for p in files:
		var s: PackedScene = load(p)
		var n := s.instantiate()
		var acc := [null]
		_aabb(n, Transform3D.IDENTITY, acc)
		var anims := ""
		var ap := n.find_children("*", "AnimationPlayer", true, false)
		if ap.size() > 0: anims = str(ap[0].get_animation_list())
		var b = acc[0]
		print("%s  size=%s pos=%s %s" % [p.get_file(), b.size if b else "-", b.position if b else "-", anims])
		n.free()
	quit()
