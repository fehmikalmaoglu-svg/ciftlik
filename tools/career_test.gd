extends SceneTree
## Kariyer akışı testi: yeni kariyer → sahne yeniden yüklenir → oynanır, kaydedilir → menüden silinir.
## Çalıştır: godot --headless --path . --script res://tools/career_test.gd
## Yalnız 3. yuvayı kullanır; o yuva doluysa dokunmadan çıkar.

const SLOT := 3

func _wait_ready() -> Node:
	for i in 600:
		await process_frame
		var sc := current_scene
		if sc != null and sc.get("ready_done"):
			return sc
	return null

func _initialize() -> void:
	_run()

func _run() -> void:
	var path := "user://career_%d.json" % SLOT
	if FileAccess.file_exists(path):
		print("CAREER TEST SKIP: yuva %d dolu" % SLOT)
		quit()
		return
	change_scene_to_file("res://scenes/main.tscn")
	var g = await _wait_ready()
	if g == null or g.playing:
		print("CAREER TEST FAIL: menü açılmadı")
		quit()
		return
	g._new_career(SLOT, "Deneme Çiftliği")
	await process_frame
	g = await _wait_ready()
	var fails := []
	if g == null:
		fails.append("yeniden yükleme")
	else:
		if not g.playing: fails.append("yeni kariyer oynamıyor")
		if g.farm_name != "Deneme Çiftliği": fails.append("ad %s" % g.farm_name)
		if g.slot != SLOT: fails.append("yuva %d" % g.slot)
		g.coins = 4321
		g._save()
		var info: Dictionary = g._slot_info(SLOT)
		if info.get("coins", 0) != 4321 or info.get("name", "") != "Deneme Çiftliği": fails.append("kayıt %s" % info)
		g._show_menu()
		if g.playing: fails.append("menüye dönülmedi")
		g._delete_slot(SLOT)
		if not FileAccess.file_exists(path): fails.append("tek basışta silindi")
		g._delete_slot(SLOT)
		if FileAccess.file_exists(path): fails.append("silinmedi")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("CAREER TEST ", "OK" if fails.is_empty() else "FAIL: " + ", ".join(fails))
	quit()
