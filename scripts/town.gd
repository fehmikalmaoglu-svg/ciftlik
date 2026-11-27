class_name Town
## Çiftliğin güneyindeki köy: ana yol, iki cadde, evler, ahırlar, sokak lambaları, ağaçlar.
## Modeller (ilkhom23 "Low Poly Farm Set 02") lisans gereği repoda yok; yoksa köy kurulmaz, yollar kalır.

const DIR := "res://assets/farm02/town/"
const VEH := "res://assets/vehicles/"   # araçlar ve sokak lambaları (CGTrader ücretsiz, repoda yok)
const SIDE_X := 38.5                      # caddeleri bağlayan yan yollar (x = ±)
const NAME := "Yeşilköy"
## Köyün düzlenen alanı (x, z, genişlik, derinlik)
const RECT := Rect2(-56, 38, 112, 58)
const STREETS := [56.0, 80.0]     # doğu–batı caddeleri (z)
const STREET_HALF := 41.0          # caddelerin yarı uzunluğu (x)
const PLAZA := Vector2(0, 56)       # kavşak meydanı
const PLAZA_R := 5.5
const HOUSES := ["house_01", "house_02", "house_05", "house_06", "house_07", "house_11", "house_12", "house_13",
	"house_03", "house_04", "house_08", "house_09", "house_10", "house_14", "house_15", "house_16"]
const TREES := ["tree_01", "tree_02", "tree_03", "tree_05", "tree_06", "tree_07", "tree_10"]
## Modelin ön yüzünün yerel yönü için ek dönüş (ön yüz +z kabul edilir).
const FRONT := {"house": 0.0, "farmbuilding": 0.0, "farmstractures": 0.0}

static var blocks := {}        # Vector2i → true: yürünemeyen kareler
static var movers := []        # tur atan arabalar: {node, pts, len, s, speed, v}
static var _vmats := {}
static var _meshes := {}

## Köy alanına yakınlık: içeride 1, 8 m dışarıda 0.
static func mask(x: float, z: float) -> float:
	var dx := maxf(maxf(RECT.position.x - x, x - RECT.end.x), 0.0)
	var dz := maxf(maxf(RECT.position.y - z, z - RECT.end.y), 0.0)
	return 1.0 - smoothstep(0.0, 8.0, Vector2(dx, dz).length())

static func on_road(x: float, z: float) -> bool:
	if z > 36.0 and z < RECT.end.y and absf(x) < 2.2:
		return true
	for sz in STREETS:
		if absf(z - sz) < 2.0 and absf(x) < STREET_HALF:
			return true
	if absf(absf(x) - SIDE_X) < 2.0 and z > STREETS[0] - 2.0 and z < STREETS[1] + 2.0:
		return true
	return Vector2(x, z).distance_to(PLAZA) < PLAZA_R

static func available() -> bool:
	return Assets.enabled and ResourceLoader.exists(DIR + "house_07.res")

static func _mesh(file: String) -> Mesh:
	if not _meshes.has(file):
		var p := DIR + file + ".res"
		_meshes[file] = load(p) if ResourceLoader.exists(p) else null
	return _meshes[file]

static func _family(file: String) -> String:
	return file.substr(0, file.rfind("_"))

## En büyük yatay boyutu `width` metre olacak ölçek.
static func _fit(file: String, width: float) -> float:
	var m := _mesh(file)
	if m == null:
		return 1.0
	var sz := m.get_aabb().size
	return width / maxf(sz.x, sz.z)

## Modeli yerleştirir; `face` ön yüzün bakacağı yön. block: tabanı yürünemez yapar.
static func _put(g: Node, root: Node3D, file: String, x: float, z: float, face: float, s: float, block := true, vis := 160.0, shadow := true) -> MeshInstance3D:
	var m := _mesh(file)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = Visuals.f2_mat()
	mi.position = Vector3(x, g.height_at(x, z) - 0.04, z)
	mi.rotation.y = face + FRONT.get(_family(file), 0.0)
	mi.scale = Vector3.ONE * s
	mi.visibility_range_end = vis
	mi.visibility_range_end_margin = 10.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if block:
		var a := m.get_aabb()
		var hx := a.size.x * s / 2.0 - 0.35
		var hz := a.size.z * s / 2.0 - 0.35
		var cx := (a.position.x + a.size.x / 2.0) * s
		var cz := (a.position.z + a.size.z / 2.0) * s
		var r := Vector2(hx, hz).length() + absf(cx) + absf(cz) + 1.0
		var inv := Basis(Vector3.UP, mi.rotation.y).inverse()
		for ix in range(floori(x - r), ceili(x + r)):
			for iz in range(floori(z - r), ceili(z + r)):
				var lp := inv * Vector3(ix + 0.5 - x, 0, iz + 0.5 - z)
				if absf(lp.x - cx) <= hx and absf(lp.z - cz) <= hz:
					blocks[Vector2i(ix, iz)] = true
	return mi

static func _vm(key: String, col: Color, metal := 0.0) -> StandardMaterial3D:
	if not _vmats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.45 if metal > 0.0 else 0.85
		m.metallic = metal
		_vmats[key] = m
	return _vmats[key]

## Araç ya da lamba: yüzey adına göre boyanır (modeller dokusuz gelir). Lamba camı ve farlar gece parlar.
static func vehicle(file: String, paint: Color) -> MeshInstance3D:
	var p := VEH + file + ".res"
	if not _meshes.has(p):
		_meshes[p] = load(p) if Assets.enabled and ResourceLoader.exists(p) else null
	var m: Mesh = _meshes[p]
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	for i in m.get_surface_count():
		var mat: Material
		match m.surface_get_name(i):
			"CarPaint": mat = _vm("paint" + paint.to_html(), paint, 0.15)
			"CarWindows": mat = _vm("glass", Color("#33475b"), 0.3)
			"CarRubber": mat = _vm("rubber", Color("#26262a"))
			"CarLamps", "White": mat = Models.glow()
			"Black": mat = _vm("pole", Color("#34373d"), 0.4)
			_: mat = _vm("grey", Color("#8a929c"), 0.3)
		mi.set_surface_override_material(i, mat)
	mi.visibility_range_end = 130.0
	mi.visibility_range_end_margin = 10.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return mi

const PAINTS := ["#d94b3d", "#3d7dd9", "#f2c14e", "#4caf6a", "#f5f2ea", "#7e57c2", "#ff8a3d", "#5b6670"]
const CAR_SCALE := 0.62

## Park etmiş araç: uzun ekseni yol boyunca.
static func _park(g: Node, root: Node3D, file: String, paint: String, x: float, z: float, along_x: bool, flip := false) -> void:
	var v := vehicle(file, Color(paint))
	if v == null:
		return
	v.scale = Vector3.ONE * CAR_SCALE
	v.position = Vector3(x, g.height_at(x, z), z)
	v.rotation.y = (0.0 if along_x else PI / 2.0) + (PI if flip else 0.0)
	root.add_child(v)
	var a := v.mesh.get_aabb()
	var hl := a.size.x * CAR_SCALE / 2.0
	var hw := a.size.z * CAR_SCALE / 2.0
	var ex := hl if along_x else hw
	var ez := hw if along_x else hl
	for ix in range(floori(x - ex + 0.3), ceili(x + ex - 0.3)):
		for iz in range(floori(z - ez + 0.3), ceili(z + ez - 0.3)):
			blocks[Vector2i(ix, iz)] = true

## Tur atan araba: kapalı yol çizgisi boyunca, sağ şeritte.
static func _drive(root: Node3D, file: String, paint: String, center: Array, phase: float, speed: float) -> void:
	var v := vehicle(file, Color(paint))
	if v == null:
		return
	v.scale = Vector3.ONE * CAR_SCALE
	var n := center.size()
	var pts := []
	for i in n:   # şerit: her köşeyi iki komşu kenarın normaline göre kaydır
		var a: Vector2 = center[(i - 1 + n) % n]
		var b: Vector2 = center[i]
		var c: Vector2 = center[(i + 1) % n]
		var n1 := (b - a).normalized().orthogonal()
		var n2 := (c - b).normalized().orthogonal()
		pts.append(b - (n1 + n2).normalized() * 1.0)
	var tot := 0.0
	for i in n:
		tot += (pts[(i + 1) % n] as Vector2).distance_to(pts[i])
	root.add_child(v)
	movers.append({"node": v, "pts": pts, "len": tot, "s": phase * tot, "speed": speed, "v": speed})

static func _at(pts: Array, s: float) -> Array:
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var l := a.distance_to(b)
		if s <= l:
			return [a.lerp(b, s / maxf(l, 0.001)), (b - a).normalized()]
		s -= l
	return [pts[0], ((pts[1] as Vector2) - (pts[0] as Vector2)).normalized()]

## Arabaları sürer; önünde çiftçi ya da başka araba varsa yavaşlayıp durur.
static func tick(dt: float, who: Array) -> void:
	for m in movers:
		var node: MeshInstance3D = m.node
		if not is_instance_valid(node):
			continue
		var cur: Array = _at(m.pts, m.s)
		var ahead: Vector2 = cur[0] + cur[1] * 3.2
		var want: float = m.speed
		for p in who:
			if Vector2(p.x, p.z).distance_to(ahead) < 2.6:
				want = 0.0
		for o in movers:
			if o != m and is_instance_valid(o.node) and Vector2(o.node.position.x, o.node.position.z).distance_to(ahead) < 2.2:
				want = 0.0
		m.v = move_toward(m.v, want, dt * 6.0)
		m.s = fmod(m.s + m.v * dt, m.len)
		var now: Array = _at(m.pts, m.s)
		node.position = Vector3(now[0].x, 0.0, now[0].y)
		var target := atan2(-now[1].y, now[1].x)
		node.rotation.y = lerp_angle(node.rotation.y, target, minf(1.0, dt * 8.0))

## Yollar: zemin üçgenlerinin tırtıklı kenarı yerine düz şeritler (köy alanı düz, y = 0).
static func _roads(root: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#c8a26b")
	mat.roughness = 1.0
	var strip := func(cx: float, cz: float, w: float, d: float) -> void:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, 0.03, d)
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cx, 0.015, cz)
		root.add_child(mi)
	strip.call(0.0, (37.0 + RECT.end.y) / 2.0, 4.4, RECT.end.y - 37.0)
	for sz in STREETS:
		strip.call(0.0, sz, STREET_HALF * 2.0, 4.0)
	for sx in [-1.0, 1.0]:
		strip.call(sx * SIDE_X, (STREETS[0] + STREETS[1]) / 2.0, 4.0, STREETS[1] - STREETS[0] - 4.0)
	var pl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = PLAZA_R
	cm.bottom_radius = PLAZA_R
	cm.height = 0.04
	cm.radial_segments = 32
	pl.mesh = cm
	var pm := mat.duplicate()
	pm.albedo_color = Color("#d6b47e")
	pl.material_override = pm
	pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pl.position = Vector3(PLAZA.x, 0.02, PLAZA.y)
	root.add_child(pl)

## Yönü (dx, dz) olan bakışın y-dönüşü.
static func _yaw(dx: float, dz: float) -> float:
	return atan2(dx, dz)

## Köyü kurar; gece yanacak lambaların konumlarını döndürür ({x, z, type}).
static func build(g: Node) -> Array:
	blocks.clear()
	var lamps := []
	var root := Node3D.new()
	root.name = "Town"
	g.add_child(root)
	_roads(root)
	if not available():
		return lamps
	var r := RandomNumberGenerator.new()
	r.seed = 2024
	var hi := 0
	var side_props := ["barrel_a001", "barrel_b001", "cratebox_a001", "cratebox_b001", "cart_b001", "cart_c001", "milktank_a002", "bucket_a001", "bench_d001"]
	# cadde evleri: kuzey sırası güneye, güney sırası kuzeye bakar
	for sz in STREETS:
		for row in [-1.0, 1.0]:
			for hx in [-31.0, -18.0, 18.0, 31.0]:
				var file: String = HOUSES[hi % HOUSES.size()]
				hi += 1
				var z: float = sz + row * 7.6
				_put(g, root, file, hx, z, _yaw(0, -row), _fit(file, 8.6))
				# evin yanında birkaç eşya
				var px: float = hx + (5.6 if (r.randf() < 0.5 and absf(hx) < 25.0) else -5.6 * signf(hx) if absf(hx) > 25.0 else -5.6)
				for k in r.randi_range(1, 2):
					var pf: String = side_props[r.randi() % side_props.size()]
					_put(g, root, pf, px + r.randf_range(-0.6, 0.6), z + r.randf_range(-2.5, 2.5) - row * 1.0, r.randf() * TAU, 0.85, true, 110.0, false)
				# bahçe ağacı
				var tf: String = TREES[r.randi() % TREES.size()]
				_put(g, root, tf, hx + r.randf_range(-3.0, 3.0), z + row * 6.4, r.randf() * TAU, r.randf_range(0.75, 1.0), true, 140.0)
	# köy girişi: ana yolun iki yanında yola bakan evler
	for sx in [-1.0, 1.0]:
		var file: String = HOUSES[hi % HOUSES.size()]
		hi += 1
		_put(g, root, file, sx * 9.0, 44.5, _yaw(-sx, 0), _fit(file, 8.6))
	# köy uçlarında ahırlar, silolar, barakalar
	for sx in [-1.0, 1.0]:
		_put(g, root, "farmbuilding_0%d" % (1 if sx < 0 else 2), sx * 49.0, 50.0, _yaw(-sx, 0), _fit("farmbuilding_01", 11.0))
		_put(g, root, "farmbuilding_0%d" % (4 if sx < 0 else 3), sx * 49.0, 84.0, _yaw(-sx, 0), _fit("farmbuilding_04", 11.0))
		_put(g, root, "farmstractures_2%d" % (1 if sx < 0 else 3), sx * 53.0, 61.0, 0.0, 0.62)
		_put(g, root, "farmstractures_22", sx * 53.0, 65.0, 0.0, 0.62)
		_put(g, root, "farmstractures_1%d" % (1 if sx < 0 else 3), sx * 45.5, 66.5, _yaw(-sx, 0), _fit("farmstractures_11", 6.5))
		_put(g, root, "farmstractures_0%d" % (2 if sx < 0 else 3), sx * 47.0, 74.0, _yaw(-sx, 0), _fit("farmstractures_02", 4.0))
		_put(g, root, "car_0%d" % (7 if sx < 0 else 9), sx * 42.0, 58.6 if sx < 0 else 77.4, _yaw(1, 0), 0.9, true, 90.0)
	# meydan: ortada büyük ağaç, çevresinde banklar
	_put(g, root, "tree_02", PLAZA.x, PLAZA.y, 0.3, 1.25)
	for i in 4:
		var a := PI / 4.0 + i * PI / 2.0
		var bx := PLAZA.x + cos(a) * 3.6
		var bz := PLAZA.y + sin(a) * 3.6
		_put(g, root, "bench_a001", bx, bz, _yaw(PLAZA.x - bx, PLAZA.y - bz), 0.85, true, 110.0, false)
	_put(g, root, "bonfire_a001", -6.0, 41.0, 0.0, 0.9, true, 110.0, false)
	_put(g, root, "table_a001", 6.2, 52.0, 0.4, 0.85, true, 110.0, false)
	_put(g, root, "chair_a001", 7.2, 52.5, 2.0, 0.85, false, 90.0, false)
	_put(g, root, "rocks_01", -52.0, 92.0, 0.6, 1.0)
	_put(g, root, "rocks_04", 53.0, 42.0, 2.1, 0.9)
	# sokak lambaları: ana yol ve caddeler
	var lamp := func(x: float, z: float, fx: float, fz: float, kind: String) -> void:
		var v := vehicle(kind, Color.WHITE)
		if v != null:   # kolu (+x) yola uzanır
			v.scale = Vector3.ONE * 0.85
			v.position = Vector3(x, g.height_at(x, z), z)
			v.rotation.y = atan2(-fz, fx)
			v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(v)
			blocks[Vector2i(floori(x), floori(z))] = true
		elif _put(g, root, "streetlight_a001", x, z, _yaw(fx, fz), 1.5, true, 130.0, false) == null:
			return
		lamps.append({"x": x - 0.5, "z": z - 0.5, "type": "townlamp"})
	var zl := 40.0
	while zl < 94.0:
		var sx := -1.0 if int(zl) % 24 < 12 else 1.0
		if absf(zl - PLAZA.y) > PLAZA_R + 1.0:
			lamp.call(sx * 2.9, zl, -sx, 0.0, "lamp_1")
		zl += 12.0
	for sz in STREETS:
		for lx in [-34.0, -24.5, -11.0, 11.0, 24.5, 34.0]:
			var sgn := 1.0 if int(lx) % 2 == 0 else -1.0
			lamp.call(lx, sz + sgn * 2.8, 0.0, -sgn, "lamp_3")
	for sx in [-1.0, 1.0]:   # meydanın kısa direkli lambaları
		lamp.call(PLAZA.x + sx * (PLAZA_R + 0.9), PLAZA.y + 3.0, -sx, 0.0, "lamp_4")
	# park etmiş araçlar, durakta otobüs, ahırların önünde kamyonlar
	_park(g, root, "car_1", PAINTS[0], 3.4, 67.0, false)
	_park(g, root, "car_3", PAINTS[1], -3.4, 72.0, false, true)
	_park(g, root, "car_5", PAINTS[4], 3.4, 84.0, false)
	_park(g, root, "car_2", PAINTS[2], 24.5, 53.2, true)
	_park(g, root, "car_6", PAINTS[5], -11.5, 82.9, true, true)
	_park(g, root, "car_4", PAINTS[3], -24.5, 53.1, true)
	_park(g, root, "policecar", "#22397a", -3.4, 49.5, false, true)
	_park(g, root, "bus", "#f2b632", -3.6, 42.0, false, true)
	_park(g, root, "truck_1", "#c0392b", -42.0, 46.0, false)
	_park(g, root, "truck_2", "#2e7d5b", 42.0, 89.0, false, true)
	# tur atan arabalar: doğu ve batı halkaları
	movers.clear()
	var east := [Vector2(0, 62.0), Vector2(0, STREETS[1]), Vector2(SIDE_X, STREETS[1]), Vector2(SIDE_X, STREETS[0]), Vector2(PLAZA_R + 0.6, STREETS[0]), Vector2(3.9, 60.0)]
	var west := []
	for p in east:
		west.push_front(Vector2(-p.x, p.y))
	_drive(root, "car_4", PAINTS[6], east, 0.0, 4.2)
	_drive(root, "car_2", PAINTS[1], east, 0.5, 3.8)
	_drive(root, "car_6", PAINTS[0], west, 0.2, 4.0)
	_drive(root, "car_1", PAINTS[3], west, 0.7, 4.4)
	# yol kenarı ağaçları ve köy çevresi
	for i in 70:
		var x := r.randf_range(RECT.position.x + 1.0, RECT.end.x - 1.0)
		var z := r.randf_range(RECT.position.y + 1.0, RECT.end.y - 1.0)
		if on_road(x, z) or absf(x) < 4.5 or Vector2(x - (-8.0), z - 31.0).length() < 10.0:
			continue
		var c := Vector2i(floori(x), floori(z))
		var clear := true
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				if blocks.has(c + Vector2i(dx, dz)):
					clear = false
		var near_road := false
		for sz in STREETS:
			if absf(z - sz) < 3.4:
				near_road = true
		if not clear or near_road:
			continue
		_put(g, root, TREES[r.randi() % TREES.size()], x, z, r.randf() * TAU, r.randf_range(0.7, 1.05), true, 140.0)
	# köy tabelası
	_put(g, root, "streetsign_a001", 3.4, 39.0, _yaw(0, -1), 1.2, true, 110.0, false)
	var sg := Label3D.new()
	sg.font = g.font
	sg.text = "🏘️ " + NAME.to_upper()
	sg.font_size = 64
	sg.pixel_size = 0.007
	sg.outline_size = 10
	sg.outline_modulate = Color(0.2, 0.12, 0.05, 0.8)
	sg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sg.position = Vector3(3.4, g.height_at(3.4, 39.0) + 3.6, 39.0)
	root.add_child(sg)
	return lamps
