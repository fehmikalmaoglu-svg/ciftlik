class_name Models
extends RefCounted
## Low-poly prosedürel modeller: hepsi kodla, basit geometrilerden çizilir.
## Web sürümündeki models.js'in birebir karşılığı.

static var _meshes := {}
static var _mats := {}
static var _glow: StandardMaterial3D
static var _water: ShaderMaterial
const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;
uniform vec4 shallow : source_color = vec4(0.36, 0.74, 0.88, 1.0);
uniform vec4 deep : source_color = vec4(0.10, 0.36, 0.55, 1.0);
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wp.xz;
	float t = TIME;
	vec2 g = vec2(cos(p.x * 1.7 + t * 1.3) + 0.7 * cos(p.x * 0.9 + p.y * 1.3 + t * 0.9) + 0.4 * cos(p.y * 3.1 + t * 2.1),
		sin(p.y * 1.9 - t * 1.1) + 0.7 * sin(p.y * 0.7 - p.x * 1.1 + t * 0.8) + 0.4 * sin(p.x * 2.9 - t * 1.7)) * 0.05;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(g.x, 1.0, g.y)), 0.0)).xyz);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, 0.45) * (1.0 - fr * 0.6);
	ALPHA = mix(0.8, 0.97, fr);
	METALLIC = 0.0;
	ROUGHNESS = 0.03;
	SPECULAR = 0.5 + 0.5 * fr;
}
"""

# ------------------------------------------------------------ malzemeler
static func mat(c: String) -> StandardMaterial3D:
	if not _mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c)
		m.roughness = 0.9
		_mats[c] = m
	return _mats[c]

static func emissive(c: String, e: String, energy: float) -> StandardMaterial3D:
	var k := "%s|%s|%s" % [c, e, energy]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c)
		m.emission_enabled = true
		m.emission = Color(e)
		m.emission_energy_multiplier = energy
		_mats[k] = m
	return _mats[k]

## Geceleri parlayan ortak malzeme (fener, pencere). Oyun enerjisini değiştirir.
static func glow() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.albedo_color = Color("#ffe9a8")
		_glow.emission_enabled = true
		_glow.emission = Color("#ffb300")
		_glow.emission_energy_multiplier = 0.0
	return _glow

static func water() -> ShaderMaterial:
	if _water == null:
		var sh := Shader.new()
		sh.code = WATER_SHADER
		_water = ShaderMaterial.new()
		_water.shader = sh
	return _water

# ------------------------------------------------------------ geometri
## Pürüzsüz normalleri yüz normalleriyle değiştirir: low-poly "facet" görünümü.
static func _flat(src: Mesh, offset := Vector3.ZERO) -> ArrayMesh:
	var arr := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count := idx.size() if idx.size() > 0 else verts.size()
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	for i in range(0, count, 3):
		var ia := idx[i] if idx.size() > 0 else i
		var ib := idx[i + 1] if idx.size() > 0 else i + 1
		var ic := idx[i + 2] if idx.size() > 0 else i + 2
		var a := verts[ia]
		var b := verts[ib]
		var c := verts[ic]
		var fn := (b - a).cross(c - a)
		if fn.length_squared() < 1e-12:
			continue
		fn = fn.normalized()
		if norms.size() > 0 and fn.dot(norms[ia] + norms[ib] + norms[ic]) < 0.0:
			fn = -fn
		out_v.append(a + offset)
		out_v.append(b + offset)
		out_v.append(c + offset)
		out_n.append(fn)
		out_n.append(fn)
		out_n.append(fn)
	var res := []
	res.resize(Mesh.ARRAY_MAX)
	res[Mesh.ARRAY_VERTEX] = out_v
	res[Mesh.ARRAY_NORMAL] = out_n
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res)
	return m

static func _mi(mesh: Mesh, c, x: float, y: float, z: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = c if c is Material else mat(str(c))
	m.position = Vector3(x, y, z)
	m.rotation_order = EULER_ORDER_XYZ
	return m

static func box(w: float, h: float, d: float, c, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	var k := "b%s|%s|%s" % [w, h, d]
	if not _meshes.has(k):
		var b := BoxMesh.new()
		b.size = Vector3(w, h, d)
		_meshes[k] = b
	return _mi(_meshes[k], c, x, y, z)

static func cyl(rt: float, rb: float, h: float, s: int, c, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	var k := "c%s|%s|%s|%s" % [rt, rb, h, s]
	if not _meshes.has(k):
		var m := CylinderMesh.new()
		m.top_radius = rt
		m.bottom_radius = rb
		m.height = h
		m.radial_segments = s
		m.rings = 0
		_meshes[k] = _flat(m)
	return _mi(_meshes[k], c, x, y, z)

static func cone(r: float, h: float, s: int, c, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return cyl(0.0, r, h, s, c, x, y, z)

static func ball(r: float, c, x := 0.0, y := 0.0, z := 0.0, detail := 0) -> MeshInstance3D:
	var k := "s%s|%s" % [r, detail]
	if not _meshes.has(k):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 7 if detail == 0 else 11
		m.rings = 4 if detail == 0 else 6
		_meshes[k] = _flat(m)
	return _mi(_meshes[k], c, x, y, z)

## Yumuşak gölgeli (facet'siz) ilkel şekiller: karakter ve yapraklı ekinler için.
static func sball(r: float, c, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	var k := "S%s" % r
	if not _meshes.has(k):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 16
		m.rings = 8
		_meshes[k] = m
	return _mi(_meshes[k], c, x, y, z)

static func scyl(rt: float, rb: float, h: float, c, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	var k := "C%s|%s|%s" % [rt, rb, h]
	if not _meshes.has(k):
		var m := CylinderMesh.new()
		m.top_radius = rt
		m.bottom_radius = rb
		m.height = h
		m.radial_segments = 16
		m.rings = 1
		_meshes[k] = m
	return _mi(_meshes[k], c, x, y, z)

static func scap(r: float, h: float, c, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	var k := "K%s|%s" % [r, h]
	if not _meshes.has(k):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 14
		m.rings = 4
		_meshes[k] = m
	return _mi(_meshes[k], c, x, y, z)

static func dodec(r: float, c, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	var k := "d%s" % r
	if not _meshes.has(k):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 5
		m.rings = 3
		_meshes[k] = _flat(m)
	return _mi(_meshes[k], c, x, y, z)

## Üçgen prizma, tabanı y=0'da, mahya z ekseni boyunca.
static func prism(w: float, h: float, d: float, c, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	var k := "p%s|%s|%s" % [w, h, d]
	if not _meshes.has(k):
		var m := PrismMesh.new()
		m.size = Vector3(w, h, d)
		_meshes[k] = _flat(m, Vector3(0, h / 2.0, 0))
	return _mi(_meshes[k], c, x, y, z)

static func torus(big_r: float, small_r: float, c, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	var k := "t%s|%s" % [big_r, small_r]
	if not _meshes.has(k):
		var m := TorusMesh.new()
		m.inner_radius = big_r - small_r
		m.outer_radius = big_r + small_r
		m.rings = 20
		m.ring_segments = 6
		_meshes[k] = _flat(m)
	return _mi(_meshes[k], c, x, y, z)

static func rot(n: Node3D, x := 0.0, y := 0.0, z := 0.0) -> Node3D:
	n.rotation = Vector3(x, y, z)
	return n

static func scl(n: Node3D, x: float, y := -1.0, z := -1.0) -> Node3D:
	n.scale = Vector3(x, x if y < 0 else y, x if z < 0 else z)
	return n

static func node(x := 0.0, y := 0.0, z := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(x, y, z)
	n.rotation_order = EULER_ORDER_XYZ
	return n

static func add(parent: Node, child: Node) -> Node:
	parent.add_child(child)
	return child

## Beşik çatı: üçgen alınlık + iki eğik levha. Mahya z ekseni boyunca.
static func gable_roof(w: float, d: float, h: float, wall: String, roof: String, over := 0.25) -> Node3D:
	var g := node()
	add(g, prism(w, h, d, wall))
	var half := w / 2.0 + over
	var ang := atan2(h, w / 2.0)
	var length := half / cos(ang)
	var y_mid := (h - over * tan(ang)) / 2.0 + 0.04
	for s in [-1.0, 1.0]:
		var slab := box(snappedf(length, 0.001), 0.1, d + over * 2.0, roof, s * half / 2.0, y_mid, 0)
		slab.rotation.z = -s * ang
		add(g, slab)
	add(g, box(0.16, 0.12, d + over * 2.0 + 0.02, roof, 0, h + 0.02, 0))
	return g

static func _eyes(g: Node3D, x: float, y: float, z: float, c := "#212121") -> void:
	add(g, box(0.035, 0.035, 0.02, c, -x, y, z))
	add(g, box(0.035, 0.035, 0.02, c, x, y, z))

# ------------------------------------------------------------ çiftçi
static func farmer(shirt := "#e8574a") -> Node3D:
	const SKIN := "#f3c69b"
	var SHIRT := shirt
	var SHIRT2 := Color(shirt).darkened(0.18).to_html(false)
	const OVER := "#3d7cc9"
	const OVER2 := "#2f63a3"
	const BOOT := "#5a3a26"
	const HAIR := "#7a4a26"
	const HAT := "#ecc66a"
	var g := node()
	# bacaklar (dönme noktası kalçada)
	var legs := []
	for x in [-0.095, 0.095]:
		var p := node(x, 0.45, 0)
		add(p, scap(0.078, 0.42, OVER, 0, -0.17, 0))
		add(p, scyl(0.088, 0.088, 0.06, OVER2, 0, -0.34, 0))
		add(p, scl(sball(0.085, BOOT, 0, -0.4, 0.035), 1.0, 0.65, 1.45))
		add(p, box(0.15, 0.03, 0.25, "#3b2416", 0, -0.445, 0.035))
		add(g, p)
		legs.append(p)
	var body := node()
	add(g, body)
	# gövde: gömlek + tulum
	add(body, scyl(0.165, 0.19, 0.36, SHIRT, 0, 0.71, 0))
	for y in [0.62, 0.72, 0.82]:
		add(body, scyl(0.172 - (y - 0.62) * 0.1, 0.178 - (y - 0.62) * 0.1, 0.018, SHIRT2, 0, y, 0))
	add(body, scyl(0.2, 0.19, 0.17, OVER, 0, 0.53, 0))
	add(body, box(0.25, 0.21, 0.05, OVER, 0, 0.68, 0.16))
	add(body, box(0.11, 0.07, 0.012, OVER2, 0, 0.69, 0.19))
	for sx in [-1.0, 1.0]:
		var st := box(0.045, 0.3, 0.03, OVER, sx * 0.1, 0.8, 0.15)
		st.rotation.z = sx * 0.12
		add(body, st)
		add(body, box(0.045, 0.3, 0.03, OVER, sx * 0.1, 0.78, -0.16))
		add(body, sball(0.022, "#ffd54f", sx * 0.1, 0.76, 0.19))
	add(body, scyl(0.11, 0.14, 0.05, SHIRT2, 0, 0.9, 0))
	var scarf := cone(0.07, 0.1, 3, "#f2c94c", 0, 0.86, 0.12)
	scarf.rotation.x = PI
	add(body, scarf)
	# baş
	var head := node(0, 1.06, 0)
	add(body, head)
	add(head, scl(sball(0.2, SKIN), 1.0, 0.95, 0.95))
	for sx in [-1.0, 1.0]:
		add(head, sball(0.05, SKIN, sx * 0.195, -0.01, 0))
		add(head, scl(sball(0.045, "#ffffff", sx * 0.075, 0.0, 0.168), 0.8, 1.0, 0.45))
		add(head, sball(0.028, "#3b2a20", sx * 0.075, -0.004, 0.186))
		add(head, sball(0.009, "#ffffff", sx * 0.066, 0.01, 0.2))
		add(head, box(0.06, 0.016, 0.012, HAIR, sx * 0.075, 0.068, 0.182))
		add(head, scl(sball(0.035, "#f4a1a1", sx * 0.12, -0.065, 0.15), 1.0, 0.6, 0.35))
	add(head, sball(0.032, "#eab184", 0, -0.04, 0.192))
	add(head, box(0.055, 0.012, 0.01, "#8a3b2a", 0, -0.1, 0.18))
	add(head, scl(sball(0.205, HAIR, 0, 0.06, -0.035), 1.03, 0.78, 1.02))
	for bx in [-0.09, 0.0, 0.09]:
		add(head, scl(sball(0.065, HAIR, bx, 0.12, 0.13), 1.0, 0.7, 0.8))
	for sx in [-1.0, 1.0]:
		add(head, scl(sball(0.06, HAIR, sx * 0.17, 0.02, -0.02), 0.6, 1.2, 1.0))
	# hasır şapka
	var hat := node(0, 0.0, -0.01)
	hat.rotation.x = -0.12
	add(hat, scyl(0.33, 0.33, 0.022, HAT, 0, 0.15, 0))
	add(hat, scyl(0.16, 0.185, 0.15, HAT, 0, 0.23, 0))
	add(hat, scl(sball(0.16, HAT, 0, 0.3, 0), 1.0, 0.35, 1.0))
	add(hat, scyl(0.19, 0.19, 0.035, "#d84a3a", 0, 0.18, 0))
	add(head, hat)
	# kollar (dönme noktası omuzda)
	var arms := []
	for sx in [-1.0, 1.0]:
		var p := node(sx * 0.235, 0.86, 0)
		p.rotation.z = sx * 0.1
		add(p, scap(0.066, 0.22, SHIRT, 0, -0.07, 0))
		add(p, scap(0.055, 0.2, SKIN, 0, -0.23, 0))
		add(p, sball(0.06, SKIN, 0, -0.34, 0.01))
		add(body, p)
		arms.append(p)
	var tool := node(0, -0.35, 0.04)
	add(tool, rot(scyl(0.018, 0.018, 0.8, "#9c6b3f", 0, 0, 0.25), PI / 2.0))
	add(tool, scyl(0.025, 0.025, 0.06, "#9e9e9e", 0, 0, 0.62))
	add(tool, box(0.17, 0.03, 0.12, "#b0bec5", 0, -0.05, 0.66))
	add(arms[1], tool)
	# sulama kovası (ağzı +z yönünde)
	var can := node(0, -0.36, 0.08)
	add(can, scyl(0.085, 0.095, 0.17, "#4fa36b", 0, -0.02, 0.0))
	add(can, scyl(0.09, 0.09, 0.025, "#3d8457", 0, 0.065, 0.0))
	var spout := scyl(0.018, 0.026, 0.24, "#4fa36b", 0, 0.02, 0.15)
	spout.rotation.x = 1.0
	add(can, spout)
	var rose := scyl(0.04, 0.02, 0.04, "#3d8457", 0, 0.09, 0.26)
	rose.rotation.x = 1.0
	add(can, rose)
	var handle := scyl(0.012, 0.012, 0.16, "#3d8457", 0, 0.12, -0.02)
	handle.rotation.z = PI / 2.0
	add(can, handle)
	var spout_tip := node(0, 0.1, 0.3)
	add(can, spout_tip)
	add(arms[1], can)
	# tohum/yem kesesi
	var bag := node(0, -0.38, 0.05)
	add(bag, scl(sball(0.075, "#c9a46a"), 1.0, 1.15, 1.0))
	add(bag, scyl(0.03, 0.045, 0.05, "#a8834c", 0, 0.08, 0))
	add(arms[1], bag)
	# hasat sepeti (sol el)
	var basket := node(0.02, -0.4, 0.1)
	add(basket, scyl(0.13, 0.1, 0.12, "#c48a4a", 0, 0, 0))
	add(basket, scyl(0.125, 0.125, 0.02, "#a8703a", 0, 0.06, 0))
	var bh := scyl(0.01, 0.01, 0.24, "#a8703a", 0, 0.12, 0)
	bh.rotation.z = PI / 2.0
	add(basket, bh)
	for k in 3:
		add(basket, sball(0.045, ["#e53935", "#ff9800", "#8bc34a"][k], -0.05 + k * 0.05, 0.07, 0.02))
	add(arms[0], basket)
	g.set_meta("parts", {"leg_l": legs[0], "leg_r": legs[1], "arm_l": arms[0], "arm_r": arms[1], "body": body, "head": head,
		"hoe": tool, "can": can, "spout": spout_tip, "bag": bag, "basket": basket})
	return g

# ------------------------------------------------------------ tarla ve ekinler
static func soil(wet := false, seed := 0) -> Node3D:
	var base := "#5b3a27" if wet else "#8b5a3c"
	var ridge := "#53351f" if wet else "#9a6744"
	var clod := ["#4a2e1f", "#62402a"] if wet else ["#a8744d", "#7d4f33"]
	var g := node()
	add(g, box(0.96, 0.09, 0.96, base, 0, 0.045, 0))
	for z in [-0.3, 0.0, 0.3]:
		var r := cyl(0.07, 0.07, 0.9, 6, ridge, 0, 0.09, z)
		r.rotation.z = PI / 2.0
		r.scale = Vector3(1.0, 1.0, 0.75)
		add(g, r)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in 7:
		var c := dodec(0.025 + rng.randf() * 0.025, clod[i % 2], rng.randf_range(-0.42, 0.42), 0.1 + rng.randf() * 0.04, rng.randf_range(-0.42, 0.42))
		c.rotation = Vector3(rng.randf() * 3.0, rng.randf() * 3.0, 0)
		add(g, c)
	return g

## Kalıcı çiçek tarhı: yuvarlak toprak, 5 bitki. stage 0..3.
static func flower_bed(color: String, center: String, stage: int, wet: bool) -> Node3D:
	var g := node()
	add(g, cyl(0.44, 0.47, 0.09, 10, "#5d3a26" if wet else "#7a5136", 0, 0.045, 0))
	add(g, torus(0.45, 0.035, "#7cb342", 0, 0.08, 0))
	var spots := [[0.0, 0.0], [-0.22, -0.18], [0.22, -0.18], [-0.2, 0.2], [0.2, 0.2]]
	var hs := [0.0, 0.1, 0.18, 0.26]
	for i in spots.size():
		var x: float = spots[i][0]
		var z: float = spots[i][1]
		if stage == 0:
			var sp := _sprout(x, z)
			sp.position.y = 0.08
			add(g, sp)
			continue
		var h: float = hs[stage] + (i % 3) * 0.025
		add(g, cyl(0.012, 0.014, h, 4, "#558b2f", x, 0.09 + h / 2.0, z))
		add(g, rot(box(0.09, 0.015, 0.04, "#7cb342", x + 0.04, 0.09 + h * 0.45, z), 0, 0.5 * i, 0.5))
		var top := 0.09 + h
		if stage == 2:
			add(g, ball(0.035, "#8bc34a", x, top, z))
			add(g, ball(0.025, color, x, top + 0.025, z))
		elif stage == 3:
			for k in 5:
				var a := TAU * k / 5.0 + i
				add(g, ball(0.045, color, x + cos(a) * 0.05, top, z + sin(a) * 0.05))
			add(g, ball(0.035, center, x, top + 0.02, z))
	return g

## 2×2 balık göleti: taş kenar, su, nilüfer yaprakları. Merkez orijinde.
static func fish_pond() -> Node3D:
	var g := node()
	add(g, cyl(0.98, 1.0, 0.06, 16, "#8d6e63", 0, 0.03, 0))
	add(g, cyl(0.84, 0.84, 0.05, 18, water(), 0, 0.075, 0))
	for k in 14:
		var a := TAU * k / 14.0
		add(g, rot(dodec(0.13 + (k % 3) * 0.02, "#9e9e9e" if k % 2 == 0 else "#bdbdbd", cos(a) * 0.9, 0.09, sin(a) * 0.9), 0.3 * k, a, 0))
	for lp in [[-0.35, 0.2], [0.3, -0.3], [0.1, 0.42]]:
		add(g, cyl(0.12, 0.12, 0.012, 7, "#66bb6a", lp[0], 0.11, lp[1]))
	add(g, ball(0.04, "#f8bbd0", -0.35, 0.13, 0.2))
	add(g, cone(0.04, 0.4, 4, "#7cb342", -0.7, 0.25, -0.55))
	add(g, cone(0.035, 0.32, 4, "#8bc34a", -0.6, 0.2, -0.68))
	return g

const SPOTS4 := [[-0.22, -0.22], [0.22, -0.22], [-0.22, 0.22], [0.22, 0.22]]
const SPOTS9 := [[-0.28, -0.28], [-0.28, 0.0], [-0.28, 0.28], [0.0, -0.28], [0.0, 0.0], [0.0, 0.28], [0.28, -0.28], [0.28, 0.0], [0.28, 0.28]]

static func _sprout(x: float, z: float) -> Node3D:
	var s := node(x, 0, z)
	add(s, rot(box(0.05, 0.12, 0.015, "#8bc34a", -0.03, 0.05, 0), 0, 0, 0.6))
	add(s, rot(box(0.05, 0.12, 0.015, "#9ccc65", 0.03, 0.05, 0), 0, 0, -0.6))
	return s

static func crop(type: String, stage: int) -> Node3D:
	var g := node(0, 0.1, 0)
	if stage == 0:
		for p in SPOTS4:
			add(g, _sprout(p[0], p[1]))
		return g
	var inner: Node3D
	match type:
		"wheat": inner = _wheat(stage)
		"carrot": inner = _carrot(stage)
		"tomato": inner = _tomato(stage)
		"corn": inner = _corn(stage)
		"sunflower": inner = _sunflower(stage)
		"lettuce": inner = _leafy(stage, ["#9ccc65", "#7cb342", "#c5e1a5"], 0.13, false)
		"cabbage": inner = _leafy(stage, ["#8fc79a", "#6fa86b", "#b3d9a0"], 0.17, true)
		_: inner = _pumpkin(stage)
	if stage == 1:
		inner.scale = Vector3.ONE * 0.5
	elif stage == 2:
		inner.scale = Vector3.ONE * 0.78
	add(g, inner)
	return g

## Yapraklı baş (marul/lahana): ortada top, çevresinde dışa açılan yumuşak yapraklar.
static func _leafy(stage: int, cols: Array, r: float, round_head: bool) -> Node3D:
	var g := node()
	var spots := [[-0.22, -0.22], [0.22, -0.22], [-0.22, 0.22], [0.22, 0.22]]
	for si in spots.size():
		var sp = spots[si]
		var pl := node(sp[0], 0, sp[1])
		pl.rotation.y = si * 1.3
		var n := 7 if stage == 3 else 5
		for k in n:
			var a := TAU * k / n
			var lf := node(cos(a) * r * 0.55, r * 0.35, sin(a) * r * 0.55)
			lf.rotation = Vector3(0, -a, 0)
			var leaf := scl(sball(r * 0.75, cols[k % 2], r * 0.35, 0, 0), 1.0, 0.32, 0.75)
			leaf.rotation.z = 0.75 - (0.25 if stage == 3 else 0.0)
			add(lf, leaf)
			add(pl, lf)
		if stage >= 2:
			var hr := r * (0.85 if round_head else 0.7)
			var hd := sball(hr, cols[2], 0, r * 0.65, 0)
			if not round_head:
				hd.scale = Vector3(1.0, 0.8, 1.0)
			add(pl, hd)
			if round_head:
				for k in 3:
					var vein := scl(sball(hr * 0.9, cols[0], 0, r * 0.65, 0), 1.03, 1.03, 0.2)
					vein.rotation.y = k * PI / 3.0
					add(pl, vein)
		add(g, pl)
	return g

static func _wheat(stage: int) -> Node3D:
	var g := node()
	var ripe := stage == 3
	var stalk := "#d4a93c" if ripe else "#7cb342"
	var head := "#f0c75e" if ripe else "#aed581"
	for i in SPOTS9.size():
		var p = SPOTS9[i]
		var h := 0.5 + float((i * 37) % 10) / 50.0
		var tilt := float((i * 53) % 10 - 5) / 40.0
		var s := node(p[0], 0, p[1])
		s.rotation = Vector3(tilt, 0, -tilt)
		add(s, cyl(0.012, 0.018, h, 4, stalk, 0, h / 2.0, 0))
		add(s, box(0.045, 0.16, 0.045, head, 0, h + 0.06, 0))
		add(s, rot(box(0.02, 0.18, 0.06, "#c9a13a" if ripe else "#8bc34a", 0.03, 0.12, 0), 0, 0, -0.5))
		add(g, s)
	return g

static func _carrot(stage: int) -> Node3D:
	var g := node()
	for p in SPOTS4:
		var t := node(p[0], 0, p[1])
		for k in 3:
			var c := cone(0.035, 0.34, 4, "#388e3c" if k == 1 else "#43a047", 0, 0.16, 0)
			c.rotation = Vector3(sin(k * 2.1) * 0.35, 0, cos(k * 2.1) * 0.35)
			add(t, c)
		if stage == 3:
			add(t, cyl(0.065, 0.045, 0.09, 6, "#fb8c00", 0, 0.02, 0))
		add(g, t)
	return g

static func _tomato(stage: int) -> Node3D:
	var g := node()
	for bp in [[-0.2, -0.18], [0.2, 0.18]]:
		var b := node(bp[0], 0, bp[1])
		add(b, cyl(0.015, 0.015, 0.85, 4, "#a1887f", 0, 0.42, 0))
		add(b, ball(0.17, "#388e3c", 0, 0.28, 0))
		add(b, ball(0.14, "#43a047", 0.08, 0.46, 0.04))
		add(b, ball(0.13, "#2e7d32", -0.07, 0.58, -0.04))
		add(b, ball(0.1, "#43a047", 0.01, 0.72, 0.03))
		if stage >= 2:
			var col := "#e53935" if stage == 3 else "#9ccc65"
			var r := 0.065 if stage == 3 else 0.045
			for f in [[0.15, 0.3, 0.1], [-0.15, 0.4, 0.08], [0.08, 0.56, -0.15], [-0.1, 0.26, -0.13], [0.04, 0.68, 0.13]]:
				add(b, ball(r, col, f[0], f[1], f[2]))
		add(g, b)
	return g

static func _corn(stage: int) -> Node3D:
	var g := node()
	var ripe := stage == 3
	for sp in [[-0.18, 0.12, 0.3], [0.2, -0.12, 2.2]]:
		var s := node(sp[0], 0, sp[1])
		s.rotation.y = sp[2]
		add(s, cyl(0.03, 0.045, 1.2, 5, "#9ccc65" if ripe else "#7cb342", 0, 0.6, 0))
		for lf in [[0.3, 1.0], [0.55, -1.0], [0.8, 1.0], [1.0, -1.0]]:
			add(s, rot(box(0.05, 0.42, 0.015, "#8bc34a", lf[1] * 0.12, lf[0], 0), 0, 0, lf[1] * -0.8))
		add(s, cone(0.05, 0.22, 5, "#d4a93c" if ripe else "#c5e1a5", 0, 1.3, 0))
		if stage >= 2:
			add(s, rot(cyl(0.06, 0.045, 0.28, 6, "#ffd54f" if ripe else "#c5e1a5", 0.08, 0.68, 0), 0, 0, -0.35))
			add(s, rot(box(0.07, 0.24, 0.05, "#7cb342", 0.1, 0.64, 0.03), 0, 0, -0.35))
		add(g, s)
	return g

static func _sunflower(stage: int) -> Node3D:
	var g := node()
	add(g, cyl(0.03, 0.045, 1.25, 5, "#689f38", 0, 0.62, 0))
	add(g, rot(scl(ball(0.15, "#7cb342", 0.16, 0.5, 0), 1, 0.2, 0.6), 0, 0, -0.4))
	add(g, rot(scl(ball(0.15, "#689f38", -0.16, 0.78, 0), 1, 0.2, 0.6), 0, 0, 0.4))
	var head := node(0, 1.3, 0.05)
	head.rotation.x = -0.35
	if stage == 3:
		add(head, rot(cyl(0.16, 0.16, 0.06, 10, "#5d4037"), PI / 2.0))
		add(head, rot(cyl(0.17, 0.17, 0.04, 10, "#558b2f", 0, 0, -0.04), PI / 2.0))
		for i in 12:
			var a := float(i) / 12.0 * TAU
			var p := box(0.08, 0.17, 0.025, "#fdd835" if i % 2 else "#fbc02d", cos(a) * 0.23, sin(a) * 0.23, 0)
			p.rotation.z = a - PI / 2.0
			add(head, p)
	else:
		add(head, ball(0.1, "#9ccc65"))
	add(g, head)
	return g

static func _pumpkin(stage: int) -> Node3D:
	var g := node()
	for lp in [[-0.25, -0.2], [0.27, -0.15], [-0.2, 0.27], [0.22, 0.28]]:
		add(g, scl(ball(0.2, "#558b2f", lp[0], 0.06, lp[1]), 1, 0.3, 1))
	add(g, rot(cyl(0.02, 0.02, 0.7, 4, "#689f38", 0, 0.04, 0), 0, 0.6, PI / 2.0))
	if stage >= 2:
		var ripe := stage == 3
		var col := "#fb8c00" if ripe else "#9ccc65"
		var col2 := "#f57c00" if ripe else "#8bc34a"
		var r := 0.14 if ripe else 0.08
		for i in 6:
			var a := float(i) / 6.0 * TAU
			add(g, scl(ball(snappedf(r * 1.25, 0.001), col if i % 2 else col2, cos(a) * r, r * 1.05, sin(a) * r, 1), 1, 0.85, 1))
		add(g, cyl(0.025, 0.035, 0.12, 5, "#5d4037", 0, r * 2.1, 0))
	return g

# ------------------------------------------------------------ ağaçlar
const TREE_STYLE := {
	"apple":  {"leaf": ["#43a047", "#4caf50", "#388e3c"], "fruit": "#e53935", "r": 0.075, "cl": [[0, 1.15, 0, 0.5], [0.32, 0.98, 0.12, 0.36], [-0.3, 1.02, -0.1, 0.38], [0.04, 1.5, -0.04, 0.33]]},
	"orange": {"leaf": ["#2e7d32", "#1b5e20", "#33691e"], "fruit": "#fb8c00", "r": 0.08, "cl": [[0, 1.2, 0, 0.58], [0, 1.62, 0, 0.36]]},
	"cherry": {"leaf": ["#7cb342", "#689f38", "#8bc34a"], "fruit": "#b71c1c", "r": 0.05, "cl": [[0, 1.1, 0, 0.42], [0.32, 1.04, 0.1, 0.32], [-0.3, 1.06, 0.12, 0.3], [0, 1.44, 0, 0.3], [0.1, 1.1, -0.32, 0.3]]},
}
const FRUIT_ANG := [[0.4, 1.0], [2.5, 1.3], [4.4, 0.9], [1.4, 1.6], [5.5, 1.5]]

static func tree(type: String, grown := true, fruit := false) -> Node3D:
	var st = TREE_STYLE[type]
	var g := node()
	var inner := node()
	add(g, inner)
	add(inner, cyl(0.08, 0.13, 1.0, 6, "#8d6e63", 0, 0.5, 0))
	add(inner, rot(cyl(0.04, 0.05, 0.4, 5, "#8d6e63", 0.12, 0.85, 0), 0, 0, -0.7))
	var cl: Array = st["cl"]
	for i in cl.size():
		var c = cl[i]
		add(inner, ball(c[3], st["leaf"][i % 3], c[0], c[1], c[2]))
	if grown and fruit:
		for i in cl.size():
			var c = cl[i]
			var n := 5 if i == 0 else 3
			for j in n:
				var th: float = FRUIT_ANG[j][0]
				var ph: float = FRUIT_ANG[j][1]
				var r: float = c[3] * 0.97
				var p := Vector3(c[0] + cos(th) * sin(ph) * r, c[1] + cos(ph) * r, c[2] + sin(th) * sin(ph) * r)
				add(inner, ball(st["r"], st["fruit"], p.x, p.y, p.z))
				if type == "cherry":
					add(inner, ball(st["r"], st["fruit"], p.x + 0.06, p.y - 0.03, p.z))
	elif grown and type == "cherry":
		for c in cl:
			for fa in FRUIT_ANG:
				add(inner, ball(0.045, "#f8bbd0", c[0] + cos(fa[0]) * sin(fa[1]) * c[3], c[1] + cos(fa[1]) * c[3], c[2] + sin(fa[0]) * sin(fa[1]) * c[3]))
	if not grown:
		inner.scale = Vector3.ONE * 0.45
	return g

# ------------------------------------------------------------ hayvanlar
static func animal(type: String) -> Node3D:
	match type:
		"chicken": return _chicken()
		"cow": return _cow()
		"sheep": return _sheep()
		_: return _pig()

static func _chicken() -> Node3D:
	var g := node()
	add(g, scl(ball(0.2, "#fafafa", 0, 0.3, 0, 1), 1, 0.9, 1.15))
	add(g, rot(box(0.12, 0.2, 0.06, "#eeeeee", 0, 0.44, -0.22), -0.4))
	for s in [-1.0, 1.0]:
		add(g, scl(ball(0.1, "#f0f0f0", s * 0.17, 0.3, 0), 0.4, 0.7, 1.1))
		add(g, cyl(0.015, 0.015, 0.16, 4, "#ffa000", s * 0.07, 0.08, 0))
		add(g, box(0.06, 0.015, 0.08, "#ffa000", s * 0.07, 0.008, 0.03))
	var head := node(0, 0.5, 0.17)
	add(head, ball(0.11, "#fafafa", 0, 0, 0, 1))
	add(head, box(0.03, 0.08, 0.12, "#e53935", 0, 0.11, 0))
	add(head, rot(cone(0.035, 0.08, 4, "#ffa000", 0, -0.01, 0.12), PI / 2.0))
	add(head, box(0.03, 0.05, 0.03, "#e53935", 0, -0.07, 0.08))
	_eyes(head, 0.08, 0.02, 0.06)
	add(g, head)
	g.set_meta("head", head)
	return g

static func _cow() -> Node3D:
	var g := node()
	const W := "#fafafa"
	const B := "#3b2b25"
	add(g, box(0.5, 0.42, 0.85, W, 0, 0.62, 0))
	add(g, box(0.52, 0.2, 0.24, B, 0, 0.7, -0.15))
	add(g, box(0.2, 0.22, 0.3, B, 0.16, 0.6, 0.2))
	add(g, box(0.16, 0.16, 0.2, B, -0.18, 0.75, 0.28))
	for lp in [[-0.17, -0.3], [0.17, -0.3], [-0.17, 0.3], [0.17, 0.3]]:
		add(g, box(0.12, 0.4, 0.12, W, lp[0], 0.22, lp[1]))
		add(g, box(0.13, 0.06, 0.13, "#4e342e", lp[0], 0.03, lp[1]))
	add(g, box(0.2, 0.1, 0.18, "#f8bbd0", 0, 0.38, -0.12))
	add(g, rot(cyl(0.02, 0.02, 0.4, 4, W, 0, 0.6, -0.45), 0.3))
	add(g, box(0.06, 0.1, 0.06, B, 0, 0.42, -0.5))
	var head := node(0, 0.82, 0.5)
	add(head, box(0.32, 0.32, 0.3, W))
	add(head, box(0.3, 0.16, 0.12, "#f8bbd0", 0, -0.08, 0.18))
	add(head, box(0.04, 0.04, 0.02, "#ad1457", -0.07, -0.06, 0.245))
	add(head, box(0.04, 0.04, 0.02, "#ad1457", 0.07, -0.06, 0.245))
	for s in [-1.0, 1.0]:
		add(head, rot(cone(0.035, 0.14, 5, "#efebe9", s * 0.13, 0.22, -0.02), 0, 0, -s * 0.5))
		add(head, box(0.14, 0.07, 0.08, W, s * 0.21, 0.08, -0.04))
	add(head, box(0.33, 0.1, 0.2, B, 0, 0.12, -0.02))
	_eyes(head, 0.09, 0.05, 0.151)
	add(g, head)
	g.set_meta("head", head)
	g.scale = Vector3.ONE * 0.85
	return g

static func _sheep() -> Node3D:
	var g := node()
	const WL := "#f5f5f5"
	const D := "#3d3d3d"
	for b in [[0, 0.5, 0, 0.24], [0.15, 0.55, 0.15, 0.2], [-0.15, 0.55, 0.15, 0.2], [0.15, 0.55, -0.15, 0.2], [-0.15, 0.55, -0.15, 0.2], [0, 0.68, 0, 0.2], [0, 0.55, -0.27, 0.16]]:
		add(g, ball(b[3], WL, b[0], b[1], b[2]))
	for lp in [[-0.13, -0.18], [0.13, -0.18], [-0.13, 0.18], [0.13, 0.18]]:
		add(g, box(0.08, 0.32, 0.08, D, lp[0], 0.16, lp[1]))
	var head := node(0, 0.62, 0.36)
	add(head, box(0.2, 0.24, 0.26, D))
	for s in [-1.0, 1.0]:
		add(head, rot(box(0.13, 0.05, 0.07, D, s * 0.14, 0.05, -0.04), 0, 0, s * -0.3))
	add(head, ball(0.1, "#ffffff", 0, 0.14, -0.04))
	_eyes(head, 0.06, 0.03, 0.131, "#fafafa")
	add(g, head)
	g.set_meta("head", head)
	return g

static func _pig() -> Node3D:
	var g := node()
	const P := "#f6a5c0"
	const D := "#ec7fa6"
	add(g, scl(ball(0.32, P, 0, 0.42, 0, 1), 0.85, 0.78, 1.15))
	for lp in [[-0.14, -0.2], [0.14, -0.2], [-0.14, 0.2], [0.14, 0.2]]:
		add(g, box(0.1, 0.24, 0.1, D, lp[0], 0.12, lp[1]))
	add(g, rot(cyl(0.015, 0.015, 0.14, 4, D, 0, 0.5, -0.38), -0.8))
	var head := node(0, 0.5, 0.33)
	add(head, ball(0.2, P, 0, 0, 0, 1))
	add(head, rot(cyl(0.09, 0.09, 0.08, 8, D, 0, -0.03, 0.19), PI / 2.0))
	add(head, box(0.025, 0.04, 0.02, "#ad1457", -0.035, -0.03, 0.235))
	add(head, box(0.025, 0.04, 0.02, "#ad1457", 0.035, -0.03, 0.235))
	for s in [-1.0, 1.0]:
		add(head, rot(cone(0.065, 0.12, 4, D, s * 0.11, 0.17, 0.02), 0.3, 0, -s * 0.3))
	_eyes(head, 0.08, 0.06, 0.17)
	add(g, head)
	g.set_meta("head", head)
	return g

static func product(type: String) -> Node3D:
	var g := node()
	match type:
		"chicken":
			add(g, scl(ball(0.12, "#fff3d6", 0, 0, 0, 1), 0.85, 1.12, 0.85))
		"sheep":
			add(g, ball(0.11, "#ffffff", -0.07, 0, 0))
			add(g, ball(0.1, "#f3f3f3", 0.08, 0.02, 0))
			add(g, ball(0.09, "#fafafa", 0, 0.09, 0.02))
		"pig":
			add(g, cyl(0.04, 0.05, 0.12, 6, "#efe3c8", 0, -0.04, 0))
			add(g, scl(ball(0.13, "#c0392b", 0, 0.05, 0, 1), 1, 0.6, 1))
			add(g, ball(0.025, "#ffffff", 0.06, 0.1, 0.05))
			add(g, ball(0.02, "#ffffff", -0.05, 0.11, -0.03))
		"cow":
			add(g, cyl(0.07, 0.08, 0.2, 8, "#ffffff", 0, -0.02, 0))
			add(g, cyl(0.04, 0.07, 0.06, 8, "#ffffff", 0, 0.11, 0))
			add(g, cyl(0.045, 0.045, 0.04, 8, "#1e88e5", 0, 0.16, 0))
			add(g, cyl(0.082, 0.082, 0.06, 8, "#64b5f6", 0, -0.02, 0))
	add(g, torus(0.2, 0.025, emissive("#ffe082", "#ffca28", 0.8), 0, -0.16, 0))
	return g

# ------------------------------------------------------------ binalar
static func _window(g: Node3D, x: float, y: float, z: float, ry := 0.0) -> Node3D:
	var w := node(x, y, z)
	w.rotation.y = ry
	add(w, box(0.62, 0.56, 0.05, "#ffffff"))
	add(w, box(0.5, 0.44, 0.06, glow()))
	add(w, box(0.04, 0.44, 0.07, "#ffffff"))
	add(w, box(0.5, 0.04, 0.07, "#ffffff"))
	add(g, w)
	return w

static func building(type: String) -> Node3D:
	match type:
		"house": return _house()
		"barn": return _barn()
		"silo": return _silo()
		"well": return _well()
		_: return _windmill()

static func _house() -> Node3D:
	var g := node()
	add(g, box(3.2, 0.2, 2.8, "#9e9e9e", 0, 0.1, 0))
	add(g, box(3.0, 1.7, 2.6, "#fbe9c6", 0, 1.05, 0))
	for x in [-1.5, 1.5]:
		for z in [-1.3, 1.3]:
			add(g, box(0.14, 1.72, 0.14, "#8d6e63", x, 1.05, z))
	add(g, box(3.05, 0.12, 2.65, "#8d6e63", 0, 1.9, 0))
	var roof := gable_roof(2.6, 3.0, 1.2, "#fbe9c6", "#c0392b", 0.28)
	roof.rotation.y = PI / 2.0
	roof.position.y = 1.95
	add(g, roof)
	add(g, box(0.35, 1.0, 0.35, "#8d6e63", 0.9, 2.75, -0.35))
	add(g, box(0.45, 0.1, 0.45, "#5d4037", 0.9, 3.28, -0.35))
	add(g, box(0.62, 1.1, 0.06, "#6d4c41", 0, 0.75, 1.31))
	add(g, box(0.06, 0.06, 0.04, "#ffd54f", 0.2, 0.75, 1.35))
	_window(g, -0.95, 1.2, 1.31)
	_window(g, 0.95, 1.2, 1.31)
	_window(g, 1.51, 1.2, 0, PI / 2.0)
	_window(g, -1.51, 1.2, 0, PI / 2.0)
	var wtop := _window(g, 0, 2.5, 1.2)
	wtop.scale = Vector3.ONE * 0.7
	for x in [-0.95, 0.95]:
		add(g, box(0.66, 0.14, 0.16, "#8d6e63", x, 0.86, 1.4))
		for dx in [-0.2, 0.0, 0.2]:
			add(g, ball(0.07, "#ffd23f" if dx == 0.0 else "#ff5c8a", x + dx, 0.97, 1.4))
	add(g, box(1.3, 0.12, 0.7, "#a1887f", 0, 0.16, 1.65))
	add(g, box(1.4, 0.08, 0.8, "#c0392b", 0, 1.55, 1.6))
	for x in [-0.62, 0.62]:
		add(g, box(0.07, 1.4, 0.07, "#ffffff", x, 0.85, 1.95))
	return g

static func _barn() -> Node3D:
	var g := node()
	const R := "#b23a2e"
	const WT := "#ffffff"
	add(g, box(3.4, 2.0, 2.8, R, 0, 1.0, 0))
	for x in [-1.7, 1.7]:
		for z in [-1.4, 1.4]:
			add(g, box(0.12, 2.02, 0.12, WT, x, 1.0, z))
	var roof := gable_roof(3.4, 2.8, 1.35, R, "#5d4037", 0.25)
	roof.position.y = 2.0
	add(g, roof)
	add(g, box(1.4, 1.5, 0.06, "#8e2a20", 0, 0.75, 1.41))
	for t in [[1.5, 0.1, 0, 1.5], [0.1, 1.5, -0.7, 0.75], [0.1, 1.5, 0.7, 0.75], [0.08, 1.5, 0, 0.75]]:
		add(g, box(t[0], t[1], 0.08, WT, t[2], t[3], 1.43))
	var diag := snappedf(Vector2(0.7, 1.5).length(), 0.001)
	var ang := atan2(0.7, 1.5)
	for sx in [-0.35, 0.35]:
		for s in [-1.0, 1.0]:
			add(g, rot(box(0.07, diag, 0.08, WT, sx, 0.75, 1.44), 0, 0, s * ang))
	add(g, box(0.7, 0.55, 0.06, WT, 0, 2.5, 1.41))
	add(g, box(0.55, 0.42, 0.08, "#3e2723", 0, 2.5, 1.42))
	add(g, box(0.5, 0.25, 0.25, "#e8c547", 0, 2.35, 1.4))
	_window(g, 1.71, 1.2, 0, PI / 2.0)
	_window(g, -1.71, 1.2, 0, PI / 2.0)
	return g

static func _silo() -> Node3D:
	var g := node()
	add(g, cyl(0.72, 0.72, 3.2, 12, "#cfd8dc", 0, 1.6, 0))
	for y in [0.8, 1.6, 2.4]:
		add(g, cyl(0.74, 0.74, 0.08, 12, "#90a4ae", 0, y, 0))
	add(g, scl(ball(0.74, "#b0bec5", 0, 3.2, 0, 1), 1, 0.6, 1))
	add(g, box(0.06, 2.8, 0.06, "#78909c", 0.2, 1.5, 0.73))
	add(g, box(0.06, 2.8, 0.06, "#78909c", -0.2, 1.5, 0.73))
	var y := 0.3
	while y < 2.9:
		add(g, box(0.4, 0.03, 0.04, "#78909c", 0, y, 0.74))
		y += 0.3
	return g

static func _well() -> Node3D:
	var g := node()
	add(g, cyl(0.45, 0.5, 0.5, 10, "#9e9e9e", 0, 0.25, 0))
	add(g, cyl(0.47, 0.47, 0.08, 10, "#bdbdbd", 0, 0.52, 0))
	add(g, cyl(0.36, 0.36, 0.02, 10, water(), 0, 0.45, 0))
	for x in [-0.42, 0.42]:
		add(g, box(0.08, 1.0, 0.08, "#6d4c41", x, 0.85, 0))
	var roof := gable_roof(1.0, 0.8, 0.4, "#8d6e63", "#c0392b", 0.12)
	roof.rotation.y = PI / 2.0
	roof.position.y = 1.32
	add(g, roof)
	add(g, rot(cyl(0.04, 0.04, 0.9, 6, "#5d4037", 0, 1.1, 0), 0, 0, PI / 2.0))
	add(g, cyl(0.01, 0.01, 0.3, 3, "#3e2723", 0, 0.92, 0))
	add(g, cyl(0.09, 0.07, 0.13, 8, "#8d6e63", 0, 0.72, 0))
	return g

static func _windmill() -> Node3D:
	var g := node()
	add(g, cyl(0.7, 1.1, 3.6, 8, "#efebe9", 0, 1.8, 0))
	add(g, cone(0.95, 0.9, 8, "#c0392b", 0, 4.05, 0))
	add(g, box(0.5, 0.9, 0.06, "#6d4c41", 0, 0.45, 1.05))
	var wm := _window(g, 0, 2.2, 0.86)
	wm.scale = Vector3.ONE * 0.6
	add(g, rot(cyl(0.12, 0.12, 0.5, 8, "#5d4037", 0, 3.4, 0.85), PI / 2.0))
	var blades := node(0, 3.4, 1.1)
	for k in 4:
		var b := node()
		b.rotation.z = k * PI / 2.0
		add(b, box(0.08, 1.9, 0.06, "#6d4c41", 0, 1.0, 0))
		add(b, box(0.42, 1.45, 0.03, "#fff8e1", 0.25, 1.1, 0))
		var y := 0.5
		while y < 1.9:
			add(b, box(0.45, 0.03, 0.04, "#8d6e63", 0.25, y, 0.01))
			y += 0.35
		add(blades, b)
	add(blades, ball(0.14, "#5d4037"))
	add(g, blades)
	g.set_meta("blades", blades)
	return g

# ------------------------------------------------------------ dekor
const FLOWER_COLS := ["#ff5c8a", "#ffd23f", "#b388ff", "#ff7043", "#ffffff", "#4fc3f7"]

static func fence(n := false, s := false, e := false, w := false) -> Node3D:
	var g := node()
	const P := "#a47148"
	const RL := "#c79a6a"
	add(g, box(0.13, 0.62, 0.13, P, 0, 0.31, 0))
	add(g, box(0.17, 0.05, 0.17, "#8d5f3a", 0, 0.64, 0))
	for y in [0.45, 0.22]:
		if e: add(g, box(0.5, 0.07, 0.05, RL, 0.25, y, 0))
		if w: add(g, box(0.5, 0.07, 0.05, RL, -0.25, y, 0))
		if s: add(g, box(0.05, 0.07, 0.5, RL, 0, y, 0.25))
		if n: add(g, box(0.05, 0.07, 0.5, RL, 0, y, -0.25))
	return g

## Çit kapısı: iki direk + çapraz destekli kanat. along_x: kapı x ekseni boyunca uzanır.
static func gate(along_x: bool) -> Node3D:
	var g := node()
	const P := "#8d5f3a"
	const D := "#d9ae7a"
	var inner := node()
	for x in [-0.44, 0.44]:
		add(inner, box(0.15, 0.78, 0.15, P, x, 0.39, 0))
		add(inner, box(0.19, 0.05, 0.19, "#6d4527", x, 0.8, 0))
	var door := node(-0.37, 0, 0)
	door.set_meta("door", true)
	for y in [0.2, 0.42, 0.62]:
		add(door, box(0.74, 0.08, 0.05, D, 0.37, y, 0))
	var br := box(0.8, 0.06, 0.05, D, 0.37, 0.41, 0.01)
	br.rotation.z = 0.5
	add(door, br)
	add(door, box(0.05, 0.05, 0.06, "#424242", 0.67, 0.42, 0.03))
	add(inner, door)
	if not along_x:
		inner.rotation.y = PI / 2.0
	add(g, inner)
	return g

## Tavuk kümesi: 2×2 kare, merkez orijinde, kapı +z yönünde.
static func coop() -> Node3D:
	var g := node()
	const W := "#c9874d"
	const WD := "#a86a35"
	for x in [-0.55, 0.55]:
		for z in [-0.45, 0.45]:
			add(g, box(0.09, 0.42, 0.09, WD, x, 0.21, z))
	add(g, box(1.35, 0.1, 1.15, WD, 0, 0.45, 0))
	add(g, box(1.25, 0.75, 1.05, W, 0, 0.87, 0))
	for x in [-0.45, -0.15, 0.15, 0.45]:
		add(g, box(0.025, 0.75, 1.07, WD, x, 0.87, 0))
	var roof := gable_roof(1.25, 1.05, 0.5, W, "#b8402f", 0.16)
	roof.position.y = 1.24
	add(g, roof)
	add(g, box(0.34, 0.44, 0.04, "#5d3a1a", 0, 0.73, 0.54))
	add(g, box(0.4, 0.05, 0.05, "#f0c75e", 0, 0.52, 0.56))
	var ramp := box(0.3, 0.035, 0.7, WD, 0, 0.27, 0.82)
	ramp.rotation.x = 0.62
	add(g, ramp)
	for i in 4:
		add(g, box(0.3, 0.02, 0.03, "#7a4a24", 0, 0.12 + i * 0.1, 0.62 + i * 0.13))
	var win := cyl(0.12, 0.12, 0.04, 8, "#ffe9a8", 0.4, 1.0, 0.54)
	win.rotation.x = PI / 2.0
	add(g, win)
	add(g, box(0.5, 0.12, 0.3, "#e6c15a", -0.45, 0.06, 0.75))
	return g

static func decor(type: String, conn := {}) -> Node3D:
	var g := node()
	match type:
		"gate":
			return gate(conn.get("e", false) or conn.get("w", false) or not (conn.get("n", false) or conn.get("s", false)))
		"fence":
			return fence(conn.get("n", false), conn.get("s", false), conn.get("e", false), conn.get("w", false))
		"path":
			var cols := ["#b9b2a6", "#a8a196", "#c4beb3", "#aea79b"]
			var ps := [[-0.23, -0.23], [0.23, -0.23], [-0.23, 0.23], [0.23, 0.23]]
			for i in 4:
				add(g, box(0.43, 0.05, 0.43, cols[i], ps[i][0], 0.025, ps[i][1]))
		"flowers":
			add(g, box(0.9, 0.1, 0.9, "#6d4c41", 0, 0.05, 0))
			for x in [-0.45, 0.45]:
				add(g, box(0.06, 0.16, 0.94, "#a1887f", x, 0.08, 0))
			for z in [-0.45, 0.45]:
				add(g, box(0.94, 0.16, 0.06, "#a1887f", 0, 0.08, z))
			var i := 0
			for x in [-0.25, 0.0, 0.25]:
				for z in [-0.25, 0.0, 0.25]:
					var h := 0.18 + float((i * 7) % 5) * 0.03
					add(g, cyl(0.012, 0.012, h, 3, "#558b2f", x, 0.1 + h / 2.0, z))
					add(g, ball(0.07, FLOWER_COLS[(i * 5) % FLOWER_COLS.size()], x, 0.12 + h, z))
					add(g, ball(0.03, "#ffeb3b", x, 0.16 + h, z))
					i += 1
		"rock":
			add(g, scl(dodec(0.3, "#9e9e9e", 0, 0.18, 0), 1.2, 0.8, 1))
			add(g, scl(dodec(0.18, "#bdbdbd", 0.28, 0.1, 0.15), 1, 0.8, 1))
			add(g, scl(dodec(0.12, "#8d8d8d", -0.25, 0.07, 0.2), 1, 0.8, 1))
		"bush":
			add(g, ball(0.32, "#3e8e41", 0, 0.3, 0))
			add(g, ball(0.24, "#4caf50", 0.22, 0.25, 0.1))
			add(g, ball(0.22, "#388e3c", -0.2, 0.24, -0.08))
			add(g, ball(0.2, "#43a047", 0, 0.5, 0.05))
			for b in [[0.2, 0.42, 0.25], [-0.15, 0.5, 0.2], [0.05, 0.62, -0.1]]:
				add(g, ball(0.04, "#e91e63", b[0], b[1], b[2]))
		"lantern":
			add(g, box(0.3, 0.08, 0.3, "#616161", 0, 0.04, 0))
			add(g, cyl(0.04, 0.05, 1.4, 6, "#424242", 0, 0.74, 0))
			add(g, box(0.22, 0.3, 0.22, glow(), 0, 1.55, 0))
			for x in [-0.11, 0.11]:
				for z in [-0.11, 0.11]:
					add(g, box(0.03, 0.32, 0.03, "#424242", x, 1.55, z))
			add(g, rot(cone(0.2, 0.18, 4, "#424242", 0, 1.79, 0), 0, PI / 4.0))
			add(g, box(0.26, 0.04, 0.26, "#424242", 0, 1.39, 0))
		"hay":
			add(g, rot(cyl(0.34, 0.34, 0.7, 12, "#e8c547", 0, 0.34, 0), 0, 0, PI / 2.0))
			for x in [-0.18, 0.18]:
				add(g, rot(cyl(0.345, 0.345, 0.04, 12, "#c9a227", x, 0.34, 0), 0, 0, PI / 2.0))
		"scarecrow":
			add(g, box(0.08, 1.5, 0.08, "#8d6e63", 0, 0.75, 0))
			add(g, box(1.0, 0.07, 0.07, "#8d6e63", 0, 1.1, 0))
			add(g, box(0.36, 0.45, 0.2, "#3f51b5", 0, 1.02, 0))
			add(g, box(0.22, 0.14, 0.21, "#e53935", 0, 1.2, 0))
			for s in [-1.0, 1.0]:
				add(g, box(0.28, 0.14, 0.16, "#3f51b5", s * 0.3, 1.1, 0))
				add(g, rot(cone(0.06, 0.16, 4, "#e8c547", s * 0.5, 1.1, 0), 0, 0, s * PI / 2.0))
			add(g, ball(0.17, "#f3d9a4", 0, 1.43, 0, 1))
			_eyes(g, 0.06, 1.46, 0.155)
			add(g, box(0.1, 0.025, 0.02, "#5d4037", 0, 1.37, 0.16))
			add(g, cyl(0.3, 0.3, 0.025, 10, "#c8a15a", 0, 1.56, 0))
			add(g, cone(0.16, 0.22, 8, "#c8a15a", 0, 1.68, 0))
	return g

# ------------------------------------------------------------ doğa
static func pine(s := 1.0) -> Node3D:
	var g := node()
	add(g, cyl(0.1, 0.14, 0.6, 5, "#6d4c41", 0, 0.3, 0))
	add(g, cone(0.75, 1.0, 7, "#2e7d32", 0, 0.95, 0))
	add(g, cone(0.6, 0.85, 7, "#388e3c", 0, 1.45, 0))
	add(g, cone(0.42, 0.7, 7, "#43a047", 0, 1.9, 0))
	g.scale = Vector3.ONE * s
	return g

static func round_tree(s := 1.0, col := "#4caf50") -> Node3D:
	var g := node()
	add(g, cyl(0.1, 0.15, 1.0, 6, "#795548", 0, 0.5, 0))
	add(g, ball(0.6, col, 0, 1.3, 0))
	add(g, ball(0.4, col, 0.35, 1.05, 0.1))
	add(g, ball(0.38, col, -0.3, 1.15, -0.15))
	g.scale = Vector3.ONE * s
	return g

static func cloud() -> Node3D:
	var g := node()
	var m := emissive("#ffffff", "#ffffff", 0.35)
	for b in [[0, 0, 0, 1.2], [1.2, -0.2, 0.2, 0.9], [-1.2, -0.25, 0, 0.85], [0.4, 0.5, -0.2, 0.8], [-0.5, 0.3, 0.4, 0.7]]:
		var mi := ball(b[3], m, b[0], b[1], b[2], 1)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add(g, mi)
	g.scale = Vector3(1.4, 0.8, 1)
	return g

static func tuft() -> Node3D:
	var g := node()
	for k in 3:
		var c := cone(0.04, 0.25, 3, "#5ea83a", (k - 1) * 0.05, 0.12, 0)
		c.rotation.z = (k - 1) * 0.4
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add(g, c)
	return g
