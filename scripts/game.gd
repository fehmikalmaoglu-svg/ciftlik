extends Node3D
## Çiftliğim 3D — ana oyun. Dünya, simülasyon, çiftçi, kamera, gün/gece, arayüz, ses ve kayıt.

const FARM_MIN := -12
const FARM_MAX := 11
const DAY_LEN := 900.0   # gündüz ~%70, gece ~%30
const SAVE_PATH := "user://save.json"
const POND_X := 21.0
const POND_Z := 6.0
const POND_R := 4.2
const OFFLINE_CAP := 6.0 * 3600.0
const QUEST_SLOTS := 4
const QUEST_SKIP_COOLDOWN := 24.0 * 3600.0
const QUEST_SKIP_GEMS := 2
const FSPEED := 5.2
## Zemin: köşe rengi + mevsim tonu (yaz kuru, sonbahar sarı, kış karlı).
const GROUND_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float amt = 0.0;
void fragment() {
	vec3 c = COLOR.rgb;
	c = mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	ALBEDO = mix(c, tint.rgb * (0.8 + 1.2 * lum), amt);
	ROUGHNESS = 1.0;
	SPECULAR = 0.3;
}
"""
const SEASON_TINT := [["#7ccf4a", 0.0], ["#b8bf45", 0.3], ["#d0902e", 0.5], ["#eef3f8", 0.7]]

const TOOLS := [
	{"id": "hand", "icon": "✋", "name": "El", "shelf": "seed", "tip": "Akıllı el: ek, sula, topla"},
	{"id": "plow", "icon": "⛏️", "name": "Çapa", "shelf": "", "tip": "Boş çimeni tarlaya çevir"},
	{"id": "seed", "icon": "🌱", "name": "Tohum", "shelf": "seed", "tip": "Seçili tohumu ek"},
	{"id": "water", "icon": "💧", "name": "Sula", "shelf": "", "tip": "Toprağı ıslat: kuruyana kadar 2× hız"},
	{"id": "tree", "icon": "🌳", "name": "Ağaç", "shelf": "tree", "tip": "Meyve ağacı dik"},
	{"id": "animal", "icon": "🐔", "name": "Hayvan", "shelf": "animal", "tip": "Hayvan al"},
	{"id": "decor", "icon": "🌷", "name": "Dekor", "shelf": "decor", "tip": "Çit, yol, çiçek…"},
	{"id": "garden", "icon": "🌼", "name": "Bahçe", "shelf": "garden", "tip": "Çiçek tarhı ve balık göleti"},
	{"id": "remove", "icon": "🗑️", "name": "Kaldır", "shelf": "", "tip": "Nesneyi kaldır (%25 iade)"},
]
const ACT_TXT := {"plant": "🌱 Ek", "water": "💧 Sula", "harvest": "🧺 Topla", "feed": "🌾 Yemle", "flower": "🌼 Çiçek dik", "pond": "🐟 Gölet kur", "plow": "⛏️ Sür", "tree": "🌳 Dik", "animal": "🐾 Yerleştir", "decor": "🎨 Yerleştir", "remove": "🗑️ Kaldır"}
const MARKER_COL := {"hand": "#ffffff", "plow": "#a1673f", "seed": "#8bc34a", "water": "#4fc3f7", "tree": "#2e7d32", "animal": "#ffca28", "decor": "#ce93d8", "garden": "#f48fb1", "remove": "#e53935"}

# ------------------------------------------------------------ durum
var coins := 120
var xp := 0
var level := 1
var day_time := 0.33
var day := 1
var tool := "hand"
var sel := {"seed": "wheat", "tree": "apple", "animal": "chicken", "decor": "path", "garden": "daisy"}
var flv := {}            # çiçek türü -> {"lv", "n"}
var gems := 0
var quests: Array = []   # en fazla QUEST_SLOTS görev
var quest_skip_at := 0.0 # son ücretsiz silme (unix sn)
var muted := false
var medals := 0
var res := {}            # kaynak -> adet
var order := {}          # {"need": {kaynak: adet}, "medals", "xp", "coins"}
var season := 0          # 0 ilkbahar … 3 kış
var season_t := 0.0      # mevsim içinde 0..1
var year := 1
var weather := ""        # "", rain, drought, snow
var weather_t := 0.0     # kalan saniye
var loading := false

var tiles := {}          # Vector2i -> entity (Dictionary)
var entities: Array = []
var lanterns: Array = []
var queue: Array = []
var parts: Array = []
var floats: Array = []

# sahne
var env: Environment
var sun: DirectionalLight3D
var cam: Camera3D
var farmer: Node3D
var fparts: Dictionary
var cursor: MeshInstance3D
var cursor_edge: MeshInstance3D
var grid: MeshInstance3D
var windmill: Node3D
var clouds: Array = []
var lamp_lights: Array = []
var ground_mat: ShaderMaterial
var rain_fx: GPUParticles3D
var snow_fx: GPUParticles3D
var wx_f := 0.0          # yağmur/kar görsel karışımı
var dr_f := 0.0          # kuraklık görsel karışımı
var font: SystemFont

# kamera ve girdi
var cam_yaw := 0.55
var cam_pitch := 0.88
var cam_dist := 20.0
var cam_target := Vector3(0.5, 0, 9)
var hover = null
var painting := false
var rotating := false
var drag_moved := false
var mouse_pos := Vector2.ZERO

var walk_phase := 0.0
var move_target = null   # Vector3: tıklanan yere yürü
var move_marker: MeshInstance3D
var act_t := 0.0
var night_f := 0.0
var day_f_last := 1.0
var fps_t := 0.0
var fps_n := 0
var clock_t := 0.0
var sim_acc := 0.0
var lamp_timer := 0.0
var save_timer := 0.0
var hud_dirty := true
var shown_coins := 120.0
var reset_armed := 0.0

# arayüz
var ui: Control
var lbl_level: Label
var lbl_xp: Label
var bar_xp: ProgressBar
var lbl_coins: Label
var lbl_medals: Label
var lbl_gems: Label
var quest_panel: PanelContainer
var quest_box: VBoxContainer
var quest_open := true
var barn: Control
var barn_box: VBoxContainer
var lbl_clock: Label
var lbl_queue: Label
var shelf_panel: PanelContainer
var shelf_box: HBoxContainer
var tool_buttons := {}
var tip_panel: PanelContainer
var tip_label: Label
var toasts: VBoxContainer
var help: Control
var btn_sound: Button

# ses
var sounds := {}
var players: Array = []
var player_i := 0

# hata ayıklama: --shot=yol.png, --fresh, --night
var shot_path := ""
var shot_t := 0.0

# ============================================================ yardımcılar
static func key(x: int, z: int) -> Vector2i:
	return Vector2i(x, z)

static func in_farm(x: int, z: int) -> bool:
	return x >= FARM_MIN and x <= FARM_MAX and z >= FARM_MIN and z <= FARM_MAX

static func tile_center(x: int, z: int) -> Vector3:
	return Vector3(x + 0.5, 0, z + 0.5)

static func fmt_time(s: float) -> String:
	if s < 60.0:
		return "%dsn" % roundi(s)
	if s < 3600.0:
		return "%ddk" % roundi(s / 60.0)
	return "%.1fsa" % (s / 3600.0)

static func bar(p: float) -> String:
	var n := clampi(roundi(p * 8.0), 0, 8)
	return "▰".repeat(n) + "▱".repeat(8 - n) + " %d%%" % int(p * 100.0)

func height_at(x: float, z: float) -> float:
	var d := maxf(absf(x), absf(z))
	var outside := smoothstep(15.0, 24.0, d)
	var h := (sin(x * 0.15) + cos(z * 0.13) + sin((x + z) * 0.07)) * 1.3 + 1.2
	h = maxf(0.0, h) * outside
	var pd := Vector2(x - POND_X, z - POND_Z).length()
	return lerpf(-0.7, h, smoothstep(POND_R - 0.6, POND_R + 2.5, pd))

# ============================================================ başlat
func _ready() -> void:
	randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
	_make_font()
	_build_env()
	_build_terrain()
	_build_surroundings()
	_build_farm_frame()
	_build_cursor()
	farmer = Models.farmer()
	fparts = farmer.get_meta("parts")
	farmer.position = Vector3(0.5, 0, 9)
	add_child(farmer)
	_build_sounds()
	_build_ui()

	_add_entity({"kind": "building", "type": "house", "x": -11, "z": -12, "w": 4, "d": 4, "rot": 0.0})
	_add_entity({"kind": "building", "type": "barn", "x": 5, "z": -12, "w": 4, "d": 4, "rot": 0.0})
	_add_entity({"kind": "building", "type": "silo", "x": 10, "z": -12, "w": 2, "d": 2, "rot": 0.0})
	_add_entity({"kind": "building", "type": "well", "x": -5, "z": -10, "w": 1, "d": 1, "rot": 0.0})

	var args := OS.get_cmdline_user_args()
	if args.has("--fresh") or not _load():
		_new_game()
		if shot_path == "":
			help.visible = true
	if args.has("--night"):
		day_time = 0.88
	for a in args:
		if a.begins_with("--season="):
			season = clampi(int(a.substr(9)), 0, 3)
		elif a.begins_with("--weather="):
			_start_weather(a.substr(10))
	_apply_season_visual(true)
	if args.has("--demo"):
		_demo()
	if args.has("--barn"):
		res = {"cereal": 24, "veg": 13, "fruit": 9, "milk": 6}
		order = {"need": {"veg": 10, "cereal": 30}, "medals": 3, "xp": 41, "coins": 240}
		_open_barn()
	_render_quests()
	if args.has("--selftest"):
		_selftest()
	_set_tool(tool)
	hud_dirty = true
	get_tree().auto_accept_quit = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()

# ============================================================ dünya
func _make_font() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Nunito", "Segoe UI", "Arial"])
	font.font_weight = 700
	var emo := SystemFont.new()
	emo.font_names = PackedStringArray(["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"])
	var fb: Array[Font] = [emo]
	font.fallbacks = fb

func _build_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#9fd4ff")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#dff1ff")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color("#9fd4ff")
	env.fog_density = 0.0025
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.6
	sun.light_angular_distance = 0.6
	sun.light_energy = 1.4
	add_child(sun)

	for i in 6:
		var l := OmniLight3D.new()
		l.light_color = Color("#ffc966")
		l.omni_range = 7.0
		l.light_energy = 0.0
		l.position = Vector3(0, -50, 0)
		add_child(l)
		lamp_lights.append(l)

	rain_fx = _weather_particles(1800, 0.8, Vector3(0.015, 0.45, 0.015), Color(0.8, 0.88, 1.0, 0.45), 20.0, 3.0, -9.8)
	snow_fx = _weather_particles(1200, 5.0, Vector3(0.045, 0.045, 0.045), Color(1, 1, 1, 0.85), 2.0, 25.0, -0.6)

	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 250.0
	add_child(cam)
	cam.make_current()

func _weather_particles(n: int, life: float, sz: Vector3, col: Color, vel: float, spread: float, grav: float) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 0.5, 18)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = spread
	pm.initial_velocity_min = vel * 0.85
	pm.initial_velocity_max = vel * 1.15
	pm.gravity = Vector3(0.6, grav, 0.2)
	var mesh := BoxMesh.new()
	mesh.size = sz
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = col
	mesh.material = mm
	var g := GPUParticles3D.new()
	g.amount = n
	g.lifetime = life
	g.process_material = pm
	g.draw_pass_1 = mesh
	g.local_coords = false
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visibility_aabb = AABB(Vector3(-25, -20, -25), Vector3(50, 30, 50))
	g.emitting = false
	add_child(g)
	return g

func _build_terrain() -> void:
	var size := 120.0
	var seg := 120
	var n := seg + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var cs := PackedColorArray()
	cs.resize(n * n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c_sand := Color("#e3d28f")
	var c_road := Color("#c8a26b")
	var c_farm := Color("#76c24a")
	var c_grass := Color("#69b443")
	var c_hill := Color("#5fa83e")
	for j in n:
		for i in n:
			var x := -size / 2.0 + i * size / seg
			var z := -size / 2.0 + j * size / seg
			var y := height_at(x, z)
			hs[j * n + i] = y
			var c: Color
			var pd := Vector2(x - POND_X, z - POND_Z).length()
			if pd < POND_R + 1.2:
				c = c_sand
			elif absf(x) < 1.3 and z > 12.4:
				c = c_road
			elif absf(x) <= 12.6 and absf(z) <= 12.6:
				c = c_farm
			else:
				c = c_grass.lerp(c_hill, smoothstep(0.0, 4.0, y))
			var v := rng.randf() * 0.06 - 0.03
			cs[j * n + i] = c.lightened(v) if v > 0.0 else c.darkened(-v)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in seg:
		for i in seg:
			var ids := [j * n + i, j * n + i + 1, (j + 1) * n + i, (j + 1) * n + i + 1]
			var p := []
			for id in ids:
				var ii: int = id % n
				var jj: int = id / n
				p.append(Vector3(-size / 2.0 + ii * size / seg, hs[id], -size / 2.0 + jj * size / seg))
			_tri(st, p[0], p[1], p[2], cs[ids[0]])
			_tri(st, p[1], p[3], p[2], cs[ids[3]])
	var m := st.commit()
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = sh
	var ground := MeshInstance3D.new()
	ground.mesh = m
	ground.material_override = ground_mat
	add_child(ground)

	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = POND_R + 0.6
	wm.bottom_radius = POND_R + 0.6
	wm.height = 0.02
	wm.radial_segments = 28
	water.mesh = wm
	water.material_override = Models.water()
	water.position = Vector3(POND_X, -0.12, POND_Z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	for i in 6:
		var a := i * 1.7
		var rr := 1.0 + (i % 3)
		var lp := Models.cyl(0.25, 0.25, 0.02, 8, "#5aa83c", POND_X + cos(a) * rr, -0.1, POND_Z + sin(a) * rr)
		add_child(lp)
		if i % 2 == 0:
			add_child(Models.ball(0.07, "#f8bbd0", lp.position.x, -0.04, lp.position.z))

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	if nrm.y < 0.0:
		nrm = -nrm
	st.set_color(col)
	st.set_normal(nrm)
	st.add_vertex(a)
	st.set_normal(nrm)
	st.add_vertex(b)
	st.set_normal(nrm)
	st.add_vertex(c)

func _build_surroundings() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 42
	for i in 260:
		var x := (r.randf() - 0.5) * 110.0
		var z := (r.randf() - 0.5) * 110.0
		if maxf(absf(x), absf(z)) < 15.0:
			continue
		if Vector2(x - POND_X, z - POND_Z).length() < POND_R + 2.0:
			continue
		if absf(x) < 3.0 and z > 12.0:
			continue
		if Vector2(x - 17.0, z + 8.0).length() < 3.0:
			continue
		var k := r.randf()
		var t: Node3D
		if k < 0.45:
			t = Visuals.scenery(0, 0.9 + r.randf() * 0.9, r.randf())
		elif k < 0.8:
			t = Visuals.scenery(1, 0.9 + r.randf() * 0.7, r.randf())
		else:
			t = Visuals.scenery(2, 0.8 + r.randf() * 0.6, r.randf())
		t.position = Vector3(x, height_at(x, z) - 0.05, z)
		t.rotation.y = r.randf() * TAU
		add_child(t)
	for i in 160:
		var x := (r.randf() - 0.5) * 70.0
		var z := (r.randf() - 0.5) * 70.0
		if maxf(absf(x), absf(z)) < 13.5 or Vector2(x - POND_X, z - POND_Z).length() < POND_R + 1.0:
			continue
		var t := Models.tuft()
		t.position = Vector3(x, height_at(x, z), z)
		t.rotation.y = r.randf() * 6.0
		add_child(t)
	for i in 12:
		var c := Models.cloud()
		c.position = Vector3((r.randf() - 0.5) * 120.0, 14.0 + r.randf() * 6.0, (r.randf() - 0.5) * 120.0)
		c.scale *= 0.8 + r.randf()
		add_child(c)
		clouds.append(c)
	windmill = Models.building("windmill")
	windmill.position = Vector3(17, height_at(17, -8) - 0.1, -8)
	windmill.rotation.y = -0.9
	add_child(windmill)

func _ring(x: int, z: int) -> bool:
	var lo := FARM_MIN - 1
	var hi := FARM_MAX + 1
	if x < lo or x > hi or z < lo or z > hi:
		return false
	if not (x == lo or x == hi or z == lo or z == hi):
		return false
	if z == hi and (x == -1 or x == 0):
		return false
	return true

func _build_farm_frame() -> void:
	var lo := FARM_MIN - 1
	var hi := FARM_MAX + 1
	for x in range(lo, hi + 1):
		for z in range(lo, hi + 1):
			if not _ring(x, z):
				continue
			var f := Models.fence(_ring(x, z - 1), _ring(x, z + 1), _ring(x + 1, z), _ring(x - 1, z))
			f.position = Vector3(x + 0.5, 0, z + 0.5)
			add_child(f)
	for x in [-1.15, 1.15]:
		add_child(Models.box(0.22, 2.0, 0.22, "#8d5f3a", x, 1.0, hi + 0.5))
	add_child(Models.box(2.9, 0.5, 0.1, "#c79a6a", 0, 1.85, hi + 0.5))
	var sign := Label3D.new()
	sign.text = "ÇİFTLİĞİM"
	sign.font = font
	sign.font_size = 72
	sign.pixel_size = 0.005
	sign.modulate = Color("#4e2f17")
	sign.outline_size = 0
	sign.position = Vector3(0, 1.85, hi + 0.56)
	add_child(sign)

	# tarla ızgarası
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(FARM_MIN, FARM_MAX + 2):
		im.surface_add_vertex(Vector3(i, 0, FARM_MIN))
		im.surface_add_vertex(Vector3(i, 0, FARM_MAX + 1))
		im.surface_add_vertex(Vector3(FARM_MIN, 0, i))
		im.surface_add_vertex(Vector3(FARM_MAX + 1, 0, i))
	im.surface_end()
	grid = MeshInstance3D.new()
	grid.mesh = im
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1, 1, 1, 0.16)
	grid.material_override = gm
	grid.position.y = 0.015
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid.visible = false
	add_child(grid)

func _build_cursor() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	cursor = MeshInstance3D.new()
	cursor.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_color = Color(1, 1, 1, 0.35)
	cursor.material_override = cm
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cursor)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var pts := [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]
	for i in 4:
		im.surface_add_vertex(pts[i])
		im.surface_add_vertex(pts[(i + 1) % 4])
	im.surface_end()
	move_marker = Models.torus(0.28, 0.035, Models.emissive("#ffffff", "#ffe082", 1.2))
	move_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	move_marker.visible = false
	add_child(move_marker)
	cursor_edge = MeshInstance3D.new()
	cursor_edge.mesh = im
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color.WHITE
	cursor_edge.material_override = em
	add_child(cursor_edge)

# ============================================================ varlıklar
func _add_entity(d: Dictionary) -> Dictionary:
	var e := d.duplicate()
	var g := Node3D.new()
	e.group = g
	if e.kind == "pond":
		e.w = 2
		e.d = 2
	if e.has("w"):
		g.position = Vector3(e.x + e.w / 2.0, 0, e.z + e.d / 2.0)
		for i in int(e.w):
			for j in int(e.d):
				tiles[key(e.x + i, e.z + j)] = e
	else:
		g.position = tile_center(e.x, e.z)
		tiles[key(e.x, e.z)] = e
	if not e.has("rot"):
		var flat: bool = e.kind == "plot" or e.kind == "pond" or e.get("type", "") == "fence" or e.get("type", "") == "path"
		e.rot = 0.0 if flat else float(randi() % 8) * PI / 4.0
	g.rotation.y = e.rot
	add_child(g)
	entities.append(e)
	if e.kind == "animal":
		e.wander = {"x": 0.0, "z": 0.0, "tx": 0.0, "tz": 0.0, "wait": randf() * 3.0, "phase": randf() * 6.0}
		if not e.has("t"):
			e.t = 0.0
		if not e.has("ready"):
			e.ready = false
		if not e.has("food"):
			e.food = 1.0
		if not e.has("lv"):
			e.lv = 1
		if not e.has("hv"):
			e.hv = 0
	if e.kind == "flower" or e.kind == "pond":
		if not e.has("t"):
			e.t = 0.0
		if not e.has("ready"):
			e.ready = false
	if e.kind == "flower":
		if not e.has("water"):
			e.water = 0.0
		if not e.has("wet_t"):
			e.wet_t = 0.0
	if e.kind == "plot":
		if e.has("watered"):
			e.water = 1.0 if e.watered else 0.0
			e.erase("watered")
		if not e.has("water"):
			e.water = 0.0
	if e.get("type", "") == "lantern":
		lanterns.append(e)
	_refresh(e)
	if e.get("type", "") == "fence":
		_refresh_fence_neighbors(e.x, e.z)
	if e.get("type", "") == "scarecrow":
		_recompute_boosts()
	if e.kind == "plot":
		e.boost = _scarecrow_near(e.x, e.z)
	return e

func _remove_entity(e: Dictionary) -> void:
	e.group.queue_free()
	entities.erase(e)
	if e.has("w"):
		for i in int(e.w):
			for j in int(e.d):
				tiles.erase(key(e.x + i, e.z + j))
	else:
		tiles.erase(key(e.x, e.z))
	lanterns.erase(e)
	if e.get("type", "") == "fence":
		_refresh_fence_neighbors(e.x, e.z)
	if e.get("type", "") == "scarecrow":
		_recompute_boosts()

func _is_fence(x: int, z: int) -> bool:
	var t = tiles.get(key(x, z))
	return t != null and t.get("type", "") == "fence"

func _refresh_fence_neighbors(x: int, z: int) -> void:
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var t = tiles.get(key(x + dd.x, z + dd.y))
		if t != null and t.get("type", "") == "fence":
			_refresh(t)

func _scarecrow_near(x: int, z: int) -> bool:
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var t = tiles.get(key(x + dx, z + dz))
			if t != null and t.get("type", "") == "scarecrow":
				return true
	return false

func _recompute_boosts() -> void:
	for e in entities:
		if e.kind == "plot":
			e.boost = _scarecrow_near(e.x, e.z)

static func crop_stage(e: Dictionary) -> int:
	return 3 if e.progress >= 1.0 else mini(2, int(e.progress * 3.0))

func _refresh(e: Dictionary) -> void:
	var g: Node3D = e.group
	for c in g.get_children():
		g.remove_child(c)
		c.free()
	match e.kind:
		"plot":
			e.wet_shown = _wet(e)
			g.add_child(Models.soil(e.wet_shown))
			if e.crop != null:
				e.stage = crop_stage(e)
				g.add_child(Visuals.crop(e.crop, e.stage))
		"tree":
			g.add_child(Visuals.tree(e.type, e.age >= 1.0, e.has_fruit))
		"animal":
			e.model = Visuals.animal(e.type)
			g.add_child(e.model)
			e.icon = Models.product(e.type)
			e.icon.position.y = 1.35
			e.icon.visible = e.ready
			g.add_child(e.icon)
			var hl := Label3D.new()
			hl.text = "🌾❔"
			hl.font = font
			hl.font_size = 64
			hl.pixel_size = 0.01
			hl.no_depth_test = true
			hl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			hl.outline_size = 12
			hl.outline_modulate = Color(0.15, 0.1, 0.05, 0.6)
			hl.position.y = 1.0
			g.add_child(hl)
			e.hungry_lbl = hl
			_update_hungry(e)
		"flower":
			var f = Data.FLOWERS[e.type]
			e.wet_shown = _wet(e)
			e.stage = 3 if e.ready else mini(2, int(e.t * 3.0))
			g.add_child(Models.flower_bed(f.color, f.center, e.stage, e.wet_shown))
		"pond":
			g.add_child(Models.fish_pond())
			var fl := Label3D.new()
			fl.text = "🐟"
			fl.font = font
			fl.font_size = 64
			fl.pixel_size = 0.012
			fl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			fl.no_depth_test = true
			fl.outline_size = 12
			fl.outline_modulate = Color(0.1, 0.2, 0.3, 0.6)
			fl.position.y = 0.9
			fl.visible = e.ready
			g.add_child(fl)
			e.icon = fl
		"decor":
			g.add_child(Visuals.decor(e.type, {"n": _is_fence(e.x, e.z - 1), "s": _is_fence(e.x, e.z + 1), "e": _is_fence(e.x + 1, e.z), "w": _is_fence(e.x - 1, e.z)}))
		"building":
			g.add_child(Models.building(e.type))

# ============================================================ simülasyon
func _wet(e: Dictionary) -> bool:
	return e.water > 0.0

func _grow_rate(e: Dictionary) -> float:
	var r := 0.5
	if weather == "snow":
		r = 0.6
	elif _wet(e):
		r = 1.0
	return r * (1.25 if e.boost else 1.0)

func _in_season(c) -> bool:
	return c == null or not c.has("seasons") or c.seasons.has(season)

func _simulate(dt: float) -> void:
	season_t += dt / Data.SEASON_LEN
	while season_t >= 1.0:
		season_t -= 1.0
		season = (season + 1) % 4
		if season == 0:
			year += 1
		_on_season_start()
	if weather != "":
		weather_t -= dt
		if weather_t <= 0.0:
			_end_weather()
	var drain := 0.0 if weather == "snow" else dt / Data.WATER_DUR * (3.0 if weather == "drought" else 1.0)
	for e in entities:
		match e.kind:
			"plot":
				if weather == "rain":
					e.water = minf(1.0, e.water + dt / 8.0)
				elif e.water > 0.0:
					e.water = maxf(0.0, e.water - drain)
				var refreshed := false
				if e.crop != null and e.progress < 1.0:
					var c = Data.CROPS[e.crop]
					e.progress = minf(1.0, e.progress + dt * _grow_rate(e) / c.time)
					if crop_stage(e) != e.stage:
						_refresh(e)
						refreshed = true
				if not refreshed and _wet(e) != e.wet_shown:
					_refresh(e)
			"tree":
				var t = Data.TREES[e.type]
				if e.age < 1.0:
					e.age = minf(1.0, e.age + dt / t.grow)
					if e.age >= 1.0:
						_refresh(e)
				elif not e.has_fruit:
					e.fruit_t += dt / t.regrow
					if e.fruit_t >= 1.0:
						e.has_fruit = true
						e.fruit_t = 0.0
						_refresh(e)
			"flower":
				if weather == "rain":
					e.water = minf(1.0, e.water + dt / 8.0)
				elif e.water > 0.0:
					e.water = maxf(0.0, e.water - drain)
				if not e.ready:
					var ft: float = Data.FLOWERS[e.type].time
					var step := minf(dt, (1.0 - e.t) * ft)
					if _wet(e) or weather == "snow":
						e.wet_t += step
					e.t += step / ft
					if e.t >= 0.9999:
						e.t = 1.0
						e.ready = true
				var st := 3 if e.ready else mini(2, int(e.t * 3.0))
				if st != e.stage or _wet(e) != e.wet_shown:
					_refresh(e)
			"pond":
				if not e.ready:
					e.t += dt / Data.POND.time
					if e.t >= 1.0:
						e.t = 0.0
						e.ready = true
						e.icon.visible = true
			"animal":
				if not e.ready and e.food > 0.0:
					var at: float = Data.ANIMALS[e.type].time
					var step := minf(dt, e.food * at * Data.FEED_CYCLES)
					e.food = maxf(0.0, e.food - step / (at * Data.FEED_CYCLES))
					e.t += step / at
					if e.t >= 1.0:
						e.t = 0.0
						e.ready = true
						e.icon.visible = true
					if e.food <= 0.0 or e.ready:
						_update_hungry(e)

# ============================================================ ekonomi
func _spend(n: int) -> void:
	coins -= n
	hud_dirty = true

func _gain(c: int, x: int, pos: Vector3, icon: String) -> void:
	if c > 0:
		_quest_event("earn", "", c)
	coins += c
	xp += x
	hud_dirty = true
	_float_text(pos, "+%d 🪙" % c, Color("#ffe066"))
	if x > 0:
		_float_text(pos + Vector3(0, -0.3, 0), "+%d XP" % x, Color("#b9ff7a"))
	_float_text(pos + Vector3(0, 0.4, 0), icon, Color.WHITE)
	while xp >= Data.xp_for_level(level):
		xp -= Data.xp_for_level(level)
		level += 1
		_on_level_up()

func _on_level_up() -> void:
	var names := []
	for list in [Data.CROPS, Data.TREES, Data.ANIMALS, Data.DECOR]:
		for k in list:
			if list[k].level == level:
				names.append("%s %s" % [list[k].icon, list[k].name])
	var msg := "⭐ Seviye %d!" % level
	if names.size() > 0:
		msg += "\nYeni: " + ", ".join(names)
	_toast(msg, "level")
	_sfx("level")
	var cols := ["#ffd54f", "#ff5c8a", "#4fc3f7", "#81c784"]
	for i in 4:
		_burst(farmer.position + Vector3(0, 1.2, 0), cols[i], 14, 5.0)
	_render_shelf()

# ============================================================ eylemler
func _unlocked(item) -> bool:
	return item != null and item.level <= level

func _resolve(t: String, arg, x: int, z: int):
	if not in_farm(x, z):
		return null
	var e = tiles.get(key(x, z))
	match t:
		"hand":
			if e == null:
				return null
			if e.kind == "plot":
				if e.crop == null:
					var c = Data.CROPS.get(arg)
					return "plant" if _unlocked(c) and _in_season(c) and coins >= c.cost else null
				if e.progress >= 1.0:
					return "harvest"
				if e.water < Data.WATER_REFILL and weather != "snow":
					return "water"
				return null
			if e.kind == "tree" and e.has_fruit:
				return "harvest"
			if e.kind == "pond" and e.ready:
				return "harvest"
			if e.kind == "flower":
				if e.ready:
					return "harvest"
				if e.water < Data.WATER_REFILL and weather != "snow":
					return "water"
				return null
			if e.kind == "animal":
				if e.ready:
					return "harvest"
				if e.food < Data.FEED_REFILL and _can_feed(e):
					return "feed"
			return null
		"plow":
			return "plow" if e == null else null
		"seed":
			var c = Data.CROPS.get(arg)
			return "plant" if e != null and e.kind == "plot" and e.crop == null and _unlocked(c) and _in_season(c) and coins >= c.cost else null
		"water":
			if e != null and e.kind == "flower":
				return "water" if e.water < Data.WATER_REFILL and weather != "snow" and not e.ready else null
			return "water" if e != null and e.kind == "plot" and e.water < Data.WATER_REFILL and weather != "snow" and (e.crop == null or e.progress < 1.0) else null
		"tree":
			var c = Data.TREES.get(arg)
			return "tree" if e == null and _unlocked(c) and coins >= c.cost else null
		"animal":
			var c = Data.ANIMALS.get(arg)
			return "animal" if e == null and _unlocked(c) and coins >= c.cost else null
		"decor":
			var c = Data.DECOR.get(arg)
			return "decor" if e == null and _unlocked(c) and coins >= c.cost else null
		"garden":
			if arg == "pond":
				return "pond" if _unlocked(Data.POND) and coins >= Data.POND.cost and _free_area(x, z, 2, 2) else null
			var c = Data.FLOWERS.get(arg)
			return "flower" if e == null and _unlocked(c) and coins >= c.cost else null
		"remove":
			return "remove" if e != null and e.kind != "building" else null
	return null

func _free_area(x: int, z: int, w: int, d: int) -> bool:
	for i in w:
		for j in d:
			if not in_farm(x + i, z + j) or tiles.has(key(x + i, z + j)):
				return false
	return true

func _perform(item: Dictionary) -> bool:
	var x: int = item.x
	var z: int = item.z
	var arg = item.arg
	var act = _resolve(item.tool, arg, x, z)
	if act == null:
		return false
	var e = tiles.get(key(x, z))
	var pos := tile_center(x, z)
	match act:
		"plow":
			_add_entity({"kind": "plot", "x": x, "z": z, "crop": null, "progress": 0.0, "water": 0.0})
			_burst(pos + Vector3(0, 0.15, 0), "#8b5a3c", 8, 2.0)
			_sfx("plow")
		"plant":
			var c = Data.CROPS[arg]
			_spend(c.cost)
			_quest_event("plant", arg, 1)
			e.crop = arg
			e.progress = 0.0
			_refresh(e)
			_float_text(pos, "-%d 🪙" % c.cost, Color("#ffb4a8"))
			_burst(pos + Vector3(0, 0.2, 0), "#8bc34a", 6, 2.0)
			_sfx("plant")
		"water":
			e.water = 1.0
			_refresh(e)
			_quest_event("water", "", 1)
			_burst(pos + Vector3(0, 0.5, 0), "#4fc3f7", 12, 2.5)
			_sfx("water")
		"harvest":
			if e.kind == "plot":
				var ck: String = e.crop
				var c = Data.CROPS[ck]
				_burst(pos + Vector3(0, 0.4, 0), c.color, 12, 3.5)
				e.crop = null
				e.progress = 0.0
				_refresh(e)
				_gain(c.sell, c.xp, pos, c.icon)
				_store(ck, pos)
				_quest_event("crop", ck, 1)
			elif e.kind == "tree":
				var t = Data.TREES[e.type]
				e.has_fruit = false
				e.fruit_t = 0.0
				_refresh(e)
				_burst(pos + Vector3(0, 1.2, 0), t.fruit, 14, 3.0)
				_gain(t.sell, t.xp, pos, t.icon)
				_store(e.type, pos)
				_quest_event("fruit", e.type, 1)
			elif e.kind == "animal":
				var a = Data.ANIMALS[e.type]
				e.ready = false
				e.t = 0.0
				e.icon.visible = false
				_burst(pos + Vector3(0, 1.0, 0), a.color, 10, 3.0)
				_gain(int(round(a.sell * Data.animal_sell_mult(e.lv))), a.xp, pos, a.picon)
				_store(e.type, pos, Data.animal_extra_yield(e.lv))
				_animal_harvested(e, pos)
				_quest_event("animal", e.type, 1)
				_update_hungry(e)
			elif e.kind == "flower":
				_harvest_flower(e, pos)
			elif e.kind == "pond":
				var pd = Data.POND
				e.ready = false
				e.t = 0.0
				e.icon.visible = false
				var pc := Vector3(e.x + 1.0, 0, e.z + 1.0)
				_burst(pc + Vector3(0, 0.4, 0), "#4fc3f7", 14, 3.5)
				_gain(pd.sell, pd.xp, pc, pd.icon)
				_store("pond", pc)
				_quest_event("fish", "", 1)
			_sfx("harvest")
		"feed":
			_feed_pen(e)
		"flower":
			var f = Data.FLOWERS[arg]
			_spend(f.cost)
			_add_entity({"kind": "flower", "type": arg, "x": x, "z": z})
			_float_text(pos, "-%d 🪙" % f.cost, Color("#ffb4a8"))
			_burst(pos + Vector3(0, 0.2, 0), f.color, 8, 2.0)
			_sfx("plant")
		"pond":
			_spend(Data.POND.cost)
			_add_entity({"kind": "pond", "type": "pond", "x": x, "z": z})
			var pc := Vector3(x + 1.0, 0, z + 1.0)
			_float_text(pc, "-%d 🪙" % Data.POND.cost, Color("#ffb4a8"))
			_burst(pc + Vector3(0, 0.3, 0), "#4fc3f7", 16, 3.0)
			_sfx("water")
		"tree":
			var t = Data.TREES[arg]
			_spend(t.cost)
			_quest_event("tree", arg, 1)
			_add_entity({"kind": "tree", "type": arg, "x": x, "z": z, "age": 0.0, "fruit_t": 0.0, "has_fruit": false})
			_float_text(pos, "-%d 🪙" % t.cost, Color("#ffb4a8"))
			_burst(pos + Vector3(0, 0.3, 0), "#66bb6a", 10, 2.5)
			_sfx("place")
		"animal":
			var a = Data.ANIMALS[arg]
			_spend(a.cost)
			_add_entity({"kind": "animal", "type": arg, "x": x, "z": z, "t": 0.0, "ready": false})
			_float_text(pos, "-%d 🪙" % a.cost, Color("#ffb4a8"))
			_burst(pos + Vector3(0, 0.5, 0), "#ffffff", 10, 2.5)
			_sfx("animal")
		"decor":
			var dd = Data.DECOR[arg]
			_spend(dd.cost)
			_add_entity({"kind": "decor", "type": arg, "x": x, "z": z})
			_burst(pos + Vector3(0, 0.2, 0), "#d7ccc8", 6, 2.0)
			_sfx("place")
		"remove":
			var def = null
			if e.kind == "tree":
				def = Data.TREES[e.type]
			elif e.kind == "animal":
				def = Data.ANIMALS[e.type]
			elif e.kind == "decor":
				def = Data.DECOR[e.type]
			elif e.kind == "flower":
				def = Data.FLOWERS[e.type]
			elif e.kind == "pond":
				def = Data.POND
			_remove_entity(e)
			_burst(pos + Vector3(0, 0.3, 0), "#9e9e9e", 10, 2.5)
			if def != null and def.cost >= 8:
				var back := int(def.cost * 0.25)
				coins += back
				hud_dirty = true
				_float_text(pos, "+%d 🪙" % back, Color("#ffe066"))
			_sfx("remove")
	return true

func _current_arg():
	match tool:
		"hand", "seed": return sel.seed
		"tree": return sel.tree
		"animal": return sel.animal
		"garden": return sel.garden
		"decor": return sel.decor
	return null

func _enqueue(t: Vector2i) -> void:
	var arg = _current_arg()
	for q in queue:
		if q.x == t.x and q.z == t.y:
			return
	if _resolve(tool, arg, t.x, t.y) == null:
		if in_farm(t.x, t.y) and not drag_moved:
			_explain_fail(arg, t.x, t.y)
		return
	if queue.size() > 300:
		return
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.86, 0.86)
	m.mesh = pm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var col := Color(MARKER_COL[tool])
	col.a = 0.45
	mm.albedo_color = col
	m.material_override = mm
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(t.x + 0.5, 0.14, t.y + 0.5)
	add_child(m)
	queue.append({"x": t.x, "z": t.y, "tool": tool, "arg": arg, "marker": m})
	move_target = null

func _explain_fail(arg, x: int, z: int) -> void:
	var e = tiles.get(key(x, z))
	var list = {"seed": Data.CROPS, "hand": Data.CROPS, "tree": Data.TREES, "animal": Data.ANIMALS, "decor": Data.DECOR, "garden": Data.garden()}.get(tool)
	var def = list.get(arg) if list != null and arg != null else null
	if def != null and not _unlocked(def):
		_toast("🔒 %s için seviye %d gerekli" % [def.name, def.level], "warn")
		return
	var seedish := tool == "hand" or tool == "seed"
	if def != null and seedish and not _in_season(def) and e != null and e.kind == "plot" and e.crop == null:
		_sfx("error")
		_toast("%s %s bu mevsim ekilmez (%s)" % [Data.SEASONS[season].icon, def.name, Data.season_names(def.seasons)], "warn")
		return
	if (tool == "hand") and e != null and e.kind == "animal" and not e.ready and e.food < Data.FEED_REFILL and not _can_feed(e):
		_sfx("error")
		_toast("🌾 Yem için ambarda tahıl ya da yeterli altın yok", "warn")
		return
	if tool == "water" and weather == "snow":
		_toast("🌨️ Kar yağarken sulamaya gerek yok", "hint")
		return
	var target_ok: bool = (e != null and e.kind == "plot" and e.crop == null) if seedish else e == null
	if def != null and coins < def.cost and target_ok:
		_sfx("error")
		_toast("🪙 Yeterli altının yok", "warn")
		return
	if tool == "garden" and arg == "pond" and not _free_area(x, z, 2, 2):
		_toast("🐟 Gölet için 2×2 boş alan gerekli", "hint")
		return
	if tool == "seed" and e == null:
		_toast("⛏️ Önce Çapa ile toprağı sür (2)", "hint")

func _clear_queue() -> void:
	for q in queue:
		q.marker.queue_free()
	queue.clear()

# ============================================================ çiftçi
func _update_farmer(dt: float) -> void:
	var moving := false
	var kx := (1.0 if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) else 0.0)
	var kf := (1.0 if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) else 0.0)
	var dir := Vector3.ZERO
	if kx != 0.0 or kf != 0.0:
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		dir = (fwd * kf + right * kx).normalized()
		move_target = null
	elif move_target != null:
		var d: Vector3 = move_target - farmer.position
		d.y = 0.0
		if d.length() < 0.08:
			move_target = null
		else:
			dir = d.normalized()
	elif act_t <= 0.0:
		while queue.size() > 0 and _resolve(queue[0].tool, queue[0].arg, queue[0].x, queue[0].z) == null:
			queue.pop_front().marker.queue_free()
		if queue.size() > 0:
			var q = queue[0]
			var tgt := tile_center(q.x, q.z)
			var d := Vector3(tgt.x - farmer.position.x, 0, tgt.z - farmer.position.z)
			var target_e = tiles.get(key(q.x, q.z))
			if q.tool == "garden" and q.arg == "pond" or (target_e != null and target_e.kind == "pond"):
				tgt = Vector3(target_e.x + 1.0, 0, target_e.z + 1.0) if target_e != null else Vector3(q.x + 1.0, 0, q.z + 1.0)
				d = Vector3(tgt.x - farmer.position.x, 0, tgt.z - farmer.position.z)
			var reach := 1.6 if q.tool == "garden" and q.arg == "pond" or (target_e != null and target_e.kind == "pond") else 1.0 if q.tool == "tree" or q.tool == "animal" or (target_e != null and target_e.kind == "tree") else 0.75
			if d.length() > reach:
				dir = d.normalized()
			else:
				if d.length() > 0.01:
					farmer.rotation.y = atan2(d.x, d.z)
				_perform(q)
				q.marker.queue_free()
				queue.pop_front()
				act_t = 0.22
				hud_dirty = true
	if dir != Vector3.ZERO:
		var step := dir * FSPEED * dt
		if move_target != null:
			var rem: Vector3 = move_target - farmer.position
			rem.y = 0.0
			if step.length() > rem.length():
				step = rem
		var np := farmer.position + step
		if _blocked(np):
			# bina: eksen boyunca kaymayı dene
			if not _blocked(Vector3(np.x, 0, farmer.position.z)):
				np = Vector3(np.x, 0, farmer.position.z)
			elif not _blocked(Vector3(farmer.position.x, 0, np.z)):
				np = Vector3(farmer.position.x, 0, np.z)
			else:
				np = farmer.position
				move_target = null
		farmer.position = Vector3(clampf(np.x, -40, 40), farmer.position.y, clampf(np.z, -40, 40))
		farmer.rotation.y = lerp_angle(farmer.rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 14.0))
		moving = true
	farmer.position.y = maxf(0.0, height_at(farmer.position.x, farmer.position.z))
	move_marker.visible = move_target != null
	if move_target != null:
		move_marker.rotation.y += dt * 3.0
	if moving:
		walk_phase += dt * 11.0
	var sw := sin(walk_phase) * 0.7 if moving else 0.0
	fparts.leg_l.rotation.x = lerpf(fparts.leg_l.rotation.x, sw, 0.3)
	fparts.leg_r.rotation.x = lerpf(fparts.leg_r.rotation.x, -sw, 0.3)
	fparts.arm_l.rotation.x = lerpf(fparts.arm_l.rotation.x, -sw * 0.8, 0.3)
	fparts.body.position.y = absf(sin(walk_phase)) * 0.05 if moving else 0.0
	if act_t > 0.0:
		act_t -= dt
		fparts.arm_r.rotation.x = -1.6 * sin((1.0 - act_t / 0.22) * PI)
	else:
		fparts.arm_r.rotation.x = lerpf(fparts.arm_r.rotation.x, sw * 0.8, 0.3)

func _update_camera(dt: float) -> void:
	if Input.is_physical_key_pressed(KEY_Q):
		cam_yaw += dt * 1.8
	if Input.is_physical_key_pressed(KEY_E):
		cam_yaw -= dt * 1.8
	cam_target = cam_target.lerp(farmer.position, 1.0 - exp(-dt * 4.0))
	var cp := cos(cam_pitch)
	cam.position = cam_target + Vector3(sin(cam_yaw) * cp * cam_dist, sin(cam_pitch) * cam_dist, cos(cam_yaw) * cp * cam_dist)
	cam.look_at(cam_target + Vector3(0, 0.5, 0), Vector3.UP)

# ============================================================ girdi
func _pick(mp: Vector2):
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	var hit = Plane(Vector3.UP, 0.1).intersects_ray(from, dir)
	if hit == null:
		return null
	return Vector2i(floori(hit.x), floori(hit.z))

func _pick_point(mp: Vector2):
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(mp), cam.project_ray_normal(mp))
	return hit

func _walk_to(p) -> void:
	if p == null:
		return
	p.x = clampf(p.x, -40.0, 40.0)
	p.z = clampf(p.z, -40.0, 40.0)
	p.y = 0.0
	move_target = p
	move_marker.position = Vector3(p.x, height_at(p.x, p.z) + 0.05, p.z)
	move_marker.visible = true

func _blocked(p: Vector3) -> bool:
	var t = tiles.get(key(floori(p.x), floori(p.z)))
	return t != null and t.kind == "building"

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mouse_pos = ev.position
		if rotating:
			cam_yaw -= ev.relative.x * 0.008
	elif ev is InputEventMouseButton and not ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			painting = false
		elif ev.button_index == MOUSE_BUTTON_RIGHT or ev.button_index == MOUSE_BUTTON_MIDDLE:
			rotating = false

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				painting = true
				drag_moved = false
				hover = _pick(ev.position)
				if hover != null:
					var he = tiles.get(key(hover.x, hover.y))
					if he != null and he.kind == "building" and (he.type == "barn" or he.type == "silo"):
						_open_barn()
						return
					if _resolve(tool, _current_arg(), hover.x, hover.y) != null:
						_enqueue(hover)
					else:
						_walk_to(_pick_point(ev.position))
						_explain_fail(_current_arg(), hover.x, hover.y)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				rotating = true
			MOUSE_BUTTON_WHEEL_UP:
				cam_dist = clampf(cam_dist * 0.9, 7.0, 45.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				cam_dist = clampf(cam_dist * 1.1, 7.0, 45.0)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode
		if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < TOOLS.size():
			_set_tool(TOOLS[k - KEY_1].id)
		elif k == KEY_ESCAPE:
			_clear_queue()
			help.visible = false
			barn.visible = false
		elif k == KEY_J:
			quest_open = not quest_open
			_render_quests()
		elif k == KEY_B:
			if barn.visible:
				barn.visible = false
			else:
				_open_barn()

func _update_hover() -> void:
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var p = null if over_ui else _pick(mouse_pos)
	if painting and p != null and (hover == null or p != hover):
		drag_moved = true
		_enqueue(p)
	hover = p

func _update_cursor() -> void:
	if hover == null:
		cursor.visible = false
		cursor_edge.visible = false
		tip_panel.visible = false
		return
	var x: int = hover.x
	var z: int = hover.y
	var arg = _current_arg()
	var act = _resolve(tool, arg, x, z)
	var col: Color
	if act != null:
		col = Color("#ff5252") if tool == "remove" else Color("#b9ff7a")
	else:
		col = Color.WHITE if in_farm(x, z) else Color("#ff8a80")
	var e = tiles.get(key(x, z))
	var c := tile_center(x, z)
	var s := Vector3.ONE
	if e != null and e.has("w"):
		c = Vector3(e.x + e.w / 2.0, 0, e.z + e.d / 2.0)
		s = Vector3(e.w, 1, e.d)
	elif e == null and tool == "garden" and arg == "pond":
		c = Vector3(x + 1.0, 0, z + 1.0)
		s = Vector3(2, 1, 2)
	cursor.position = c + Vector3(0, 0.13, 0)
	cursor.scale = s
	cursor_edge.position = cursor.position
	cursor_edge.scale = s
	var cm: StandardMaterial3D = cursor.material_override
	cm.albedo_color = Color(col, 0.35 if act != null else 0.15)
	var em: StandardMaterial3D = cursor_edge.material_override
	em.albedo_color = col
	cursor.visible = true
	cursor_edge.visible = true
	var info := _describe(e, act, arg, x, z)
	if info != "":
		tip_label.text = info
		tip_panel.visible = true
		tip_panel.reset_size()
		var vp := get_viewport().get_visible_rect().size
		tip_panel.position = Vector2(minf(mouse_pos.x + 16, vp.x - tip_panel.size.x - 8), minf(mouse_pos.y + 18, vp.y - tip_panel.size.y - 8))
	else:
		tip_panel.visible = false

func _describe(e, act, arg, x: int, z: int) -> String:
	if not in_farm(x, z) and e == null:
		return ""
	var s := ""
	if e != null:
		match e.kind:
			"plot":
				if e.crop == null:
					s = "Sürülmüş toprak"
				else:
					var c = Data.CROPS[e.crop]
					s = "%s %s\n" % [c.icon, c.name]
					if e.progress >= 1.0:
						s += "✅ Hasada hazır!"
					else:
						var rate := _grow_rate(e)
						s += "%s · %s" % [bar(e.progress), fmt_time((1.0 - e.progress) * c.time / rate)]
					if e.boost:
						s += " · 🧑‍🌾+25%"
				if weather == "snow":
					s += "\n🌨️ kar: sabit hız, sulama gerekmez"
				elif _wet(e):
					s += "\n💧 " + bar(e.water)
				else:
					s += "\n🏜️ kuru · yarı hız"
			"tree":
				var t = Data.TREES[e.type]
				s = "%s %s\n" % [t.icon, t.name]
				if e.age < 1.0:
					s += "büyüyor " + bar(e.age)
				elif e.has_fruit:
					s += "✅ Meyve hazır!"
				else:
					s += "meyve " + bar(e.fruit_t)
			"animal":
				var a = Data.ANIMALS[e.type]
				s = "%s %s · ⭐ Sv %d" % [a.icon, a.name, e.lv]
				if e.lv < Data.ANIMAL_MAX_LV:
					s += " (%d/%d)" % [e.hv, e.lv * Data.HARVESTS_PER_LV]
				var pen := _pen(e)
				if pen.size() > 1:
					s += " · ağıl: %d" % pen.size()
				s += "\n"
				s += ("✅ %s %s hazır!" % [a.picon, a.product]) if e.ready else ("%s %s" % [a.picon, bar(e.t)])
				if e.food <= 0.0 and not e.ready:
					s += "\n🍽️ Aç! Üretim durdu"
				else:
					s += "\n🌾 yem " + bar(e.food)
			"flower":
				var f = Data.FLOWERS[e.type]
				var fl := _flower_lv(e.type)
				s = "%s %s · ⭐ Sv %d" % [f.icon, f.name, fl.lv]
				if fl.lv < Data.FLOWER_MAX_LV:
					s += " (%d/%d)" % [fl.n, fl.lv * Data.FLOWER_HARVESTS_PER_LV]
				s += "\n"
				s += "✅ Çiçekler açtı!" if e.ready else "%s · %s" % [bar(e.t), fmt_time((1.0 - e.t) * f.time)]
				s += "\n💐 sulama bonusu ×%.1f" % (1.0 + Data.FLOWER_WET_BONUS * _flower_wet_frac(e))
				if weather == "snow":
					s += " · 🌨️ kar sular"
				elif _wet(e):
					s += " · 💧 " + bar(e.water)
				else:
					s += " · 🏜️ kuru"
			"pond":
				s = "🐟 %s\n" % Data.POND.name
				s += "✅ Balıklar hazır!" if e.ready else "🐟 " + bar(e.t)
			"decor":
				s = "%s %s" % [Data.DECOR[e.type].icon, Data.DECOR[e.type].name]
			"building":
				s = "🏠 " + Data.BUILDINGS[e.type]
	if act != null:
		var extra := ""
		match act:
			"plant": extra = " %s %s  -%d🪙" % [Data.CROPS[arg].icon, Data.CROPS[arg].name, Data.CROPS[arg].cost]
			"feed": extra = " " + _feed_cost_text(e)
			"flower": extra = " %s %s  -%d🪙" % [Data.FLOWERS[arg].icon, Data.FLOWERS[arg].name, Data.FLOWERS[arg].cost]
			"pond": extra = "  -%d🪙" % Data.POND.cost
			"tree": extra = " %s  -%d🪙" % [Data.TREES[arg].icon, Data.TREES[arg].cost]
			"animal": extra = " %s  -%d🪙" % [Data.ANIMALS[arg].icon, Data.ANIMALS[arg].cost]
			"decor": extra = " %s  -%d🪙" % [Data.DECOR[arg].icon, Data.DECOR[arg].cost]
		s += ("\n" if s != "" else "") + "👉 " + ACT_TXT[act] + extra
	return s

# ============================================================ efektler
func _burst(pos: Vector3, color: String, n := 10, up := 2.5) -> void:
	var mat := Models.mat(color)
	for i in n:
		var m := Models.box(0.08, 0.08, 0.08, mat)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = pos + Vector3(randf_range(-0.2, 0.2), randf() * 0.2, randf_range(-0.2, 0.2))
		add_child(m)
		parts.append({"m": m, "v": Vector3(randf_range(-1.2, 1.2), up * (0.6 + randf() * 0.6), randf_range(-1.2, 1.2)), "t": 0.0})

func _update_parts(dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p = parts[i]
		p.t += dt
		p.v.y -= 9.0 * dt
		var m: MeshInstance3D = p.m
		m.position += p.v * dt
		m.rotation += Vector3(dt * 6.0, dt * 4.0, 0)
		m.scale = Vector3.ONE * maxf(0.01, 1.0 - p.t / 0.9)
		if p.t > 0.9:
			m.queue_free()
			parts.remove_at(i)

func _float_text(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 56
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(0.15, 0.1, 0.05, 0.7)
	l.position = pos + Vector3(0, 1.3, 0)
	add_child(l)
	floats.append({"l": l, "t": 0.0})

func _update_floats(dt: float) -> void:
	for i in range(floats.size() - 1, -1, -1):
		var f = floats[i]
		f.t += dt
		var l: Label3D = f.l
		l.position.y += dt * 0.9
		var a := 1.0 - maxf(0.0, (f.t - 0.8) / 0.6)
		l.modulate.a = a
		l.outline_modulate.a = a * 0.7
		if f.t > 1.4:
			l.queue_free()
			floats.remove_at(i)

func _toast(msg: String, kind := "") -> void:
	if loading:
		return
	for c in toasts.get_children():
		if c.get_meta("msg", "") == msg:
			return
	var p := PanelContainer.new()
	p.set_meta("msg", msg)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Color(0.18, 0.12, 0.08, 0.92)
	if kind == "level":
		bg = Color("#f4a300")
	elif kind == "warn":
		bg = Color(0.63, 0.16, 0.12, 0.92)
	p.add_theme_stylebox_override("panel", _sb(bg, 12, Color.WHITE if kind == "level" else Color(0, 0, 0, 0), 2 if kind == "level" else 0, 10))
	var l := Label.new()
	l.text = msg
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color("#5a3500") if kind == "level" else Color.WHITE)
	l.add_theme_font_size_override("font_size", 19 if kind == "level" else 15)
	p.add_child(l)
	toasts.add_child(p)
	var life := 3.2 if kind == "level" else 1.9
	var tw := create_tween()
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

# ============================================================ ses
func _build_sounds() -> void:
	sounds = {
		"plow": _synth([[160, 70, "tri", 0.14, 0.4, 0.0]]),
		"plant": _synth([[520, 760, "sine", 0.1, 0.3, 0.0]]),
		"water": _synth([[1200, 380, "sine", 0.18, 0.22, 0.0]]),
		"harvest": _synth([[660, 990, "tri", 0.09, 0.32, 0.0], [990, 1320, "tri", 0.1, 0.25, 0.07]]),
		"place": _synth([[300, 480, "tri", 0.12, 0.35, 0.0]]),
		"animal": _synth([[700, 900, "square", 0.06, 0.12, 0.0], [900, 650, "square", 0.08, 0.12, 0.08]]),
		"remove": _synth([[400, 120, "saw", 0.15, 0.15, 0.0]]),
		"error": _synth([[220, 160, "saw", 0.12, 0.15, 0.0]]),
		"level": _synth([[523, 528, "tri", 0.22, 0.3, 0.0], [659, 665, "tri", 0.22, 0.3, 0.11], [784, 791, "tri", 0.22, 0.3, 0.22], [1046, 1056, "tri", 0.3, 0.3, 0.33]]),
	}
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func _synth(segs: Array) -> AudioStreamWAV:
	var rate := 22050
	var total := 0.0
	for s in segs:
		total = maxf(total, s[5] + s[3])
	var n := int(total * rate) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	for s in segs:
		var f0: float = s[0]
		var f1: float = s[1]
		var dur: float = s[3]
		var vol: float = s[4]
		var start := int(s[5] * rate)
		var phase := 0.0
		for i in int(dur * rate):
			var t := float(i) / rate
			var f := f0 * pow(f1 / f0, t / dur)
			phase += f / rate
			var fr := phase - floorf(phase)
			var w := 0.0
			match s[2]:
				"sine": w = sin(fr * TAU)
				"tri": w = 4.0 * absf(fr - 0.5) - 1.0
				"square": w = 1.0 if fr < 0.5 else -1.0
				_: w = 2.0 * fr - 1.0
			var env_v := vol * exp(-t / dur * 5.0) * minf(1.0, t * 400.0)
			if start + i < n:
				buf[start + i] += w * env_v
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _sfx(kind: String) -> void:
	if muted or not sounds.has(kind):
		return
	var p: AudioStreamPlayer = players[player_i]
	player_i = (player_i + 1) % players.size()
	p.stream = sounds[kind]
	p.play()

# ============================================================ gün/gece
func _update_day(dt: float) -> void:
	day_time += dt / DAY_LEN * lerpf(1.8, 0.7, day_f_last)
	if day_time >= 1.0:
		day_time -= 1.0
		day += 1
		hud_dirty = true
	var ang := (day_time - 0.25) * TAU
	var elev := sin(ang)
	var day_f := smoothstep(-0.12, 0.3, elev)
	night_f = 1.0 - smoothstep(-0.15, 0.1, elev)
	day_f_last = smoothstep(-0.05, 0.05, elev)
	var set_f := maxf(0.0, 1.0 - absf(elev) / 0.32) * (1.0 if elev > -0.3 else 0.0)
	var sky := Color("#0d1633").lerp(Color("#9fd4ff"), day_f).lerp(Color("#ffa66b"), set_f * 0.55)
	wx_f = move_toward(wx_f, 1.0 if weather == "rain" or weather == "snow" else 0.0, dt * 0.3)
	dr_f = move_toward(dr_f, 1.0 if weather == "drought" else 0.0, dt * 0.3)
	var grey := Color("#c3cbd5") if weather == "snow" or season == 3 else Color("#7f8b99")
	sky = sky.lerp(grey.lerp(Color("#151a26"), night_f), wx_f * 0.7)
	sky = sky.lerp(Color("#f2d79c"), dr_f * 0.35 * day_f)
	env.fog_density = 0.0025 + 0.012 * wx_f
	var ep := cam_target + Vector3(0, 14, 0)
	rain_fx.global_position = ep
	snow_fx.global_position = ep
	rain_fx.emitting = weather == "rain"
	snow_fx.emitting = weather == "snow"
	env.background_color = sky
	env.fog_light_color = sky
	env.ambient_light_color = Color("#6d82c9").lerp(Color("#dff1ff"), day_f)
	env.ambient_light_energy = 0.3 + 0.2 * day_f
	var qang := ang
	var s_elev := maxf(sin(qang), 0.15)
	var off := Vector3(cos(qang) * 30.0, s_elev * 35.0, 12.0)
	sun.look_at_from_position(off, Vector3.ZERO, Vector3.UP)
	sun.light_energy = (1.15 * day_f + 0.12) * (1.0 - 0.5 * wx_f)
	sun.light_color = Color("#9fb4ff") if night_f > 0.5 else Color("#ffb37a").lerp(Color("#fff3d6"), smoothstep(0.0, 0.5, elev)).lerp(Color("#ffcf86"), dr_f * 0.5)
	Models.glow().emission_energy_multiplier = night_f * 3.0
	var hh := int(day_time * 24.0)
	var mm := int(day_time * 24.0 * 60.0) % 60
	var icon := "🌙" if night_f > 0.6 else ("🌅" if set_f > 0.4 else "☀️")
	var sn = Data.SEASONS[season]
	var left := ceili((1.0 - season_t) * Data.SEASON_LEN / 60.0)
	var txt := "%s %02d:%02d · Gün %d   ·   %s %s (%d dk) · Yıl %d" % [icon, hh, mm - mm % 10, day, sn.icon, sn.name, left, year]
	if weather != "":
		txt += "   ·   %s %s" % [Data.WEATHER[weather].icon, Data.WEATHER[weather].name]
	lbl_clock.text = txt

func _update_lamps(dt: float) -> void:
	lamp_timer -= dt
	if lamp_timer <= 0.0:
		lamp_timer = 0.5
		var list := lanterns.duplicate()
		var ct := cam_target
		list.sort_custom(func(a, b): return Vector2(a.x - ct.x, a.z - ct.z).length_squared() < Vector2(b.x - ct.x, b.z - ct.z).length_squared())
		for i in lamp_lights.size():
			var l: OmniLight3D = lamp_lights[i]
			l.position = Vector3(list[i].x + 0.5, 1.5, list[i].z + 0.5) if i < list.size() else Vector3(0, -50, 0)
	for l in lamp_lights:
		l.light_energy = night_f * 1.4

func _animate_world(dt: float) -> void:
	clock_t += dt
	var blades: Node3D = windmill.get_meta("blades")
	blades.rotation.z += dt * 0.8
	for c in clouds:
		c.position.x += dt * 0.6
		if c.position.x > 65.0:
			c.position.x = -65.0
	for e in entities:
		if e.kind == "pond" and e.ready:
			e.icon.position.y = 0.9 + absf(sin(clock_t * 3.0 + e.x)) * 0.25
			continue
		if e.kind != "animal":
			continue
		var w = e.wander
		var m: Node3D = e.model
		var head = m.get_meta("head") if m.has_meta("head") else null
		if w.wait > 0.0:
			w.wait -= dt
			if head != null:
				head.rotation.x = maxf(0.0, sin(clock_t * 6.0 + w.phase)) * 0.6 if e.type == "chicken" else sin(clock_t * 1.5 + w.phase) * 0.12
			if w.wait <= 0.0:
				w.tx = randf_range(-0.35, 0.35)
				w.tz = randf_range(-0.35, 0.35)
				_animal_anim(m, true)
		else:
			var dx: float = w.tx - w.x
			var dz: float = w.tz - w.z
			var d := Vector2(dx, dz).length()
			if d < 0.02:
				w.wait = 1.0 + randf() * 3.0
				_animal_anim(m, false)
			else:
				var s := minf(d, dt * 0.45)
				w.x += dx / d * s
				w.z += dz / d * s
				m.rotation.y = atan2(dx, dz)
				m.position.y = absf(sin(clock_t * 12.0)) * 0.03
		m.position.x = w.x
		m.position.z = w.z
		if e.ready:
			e.icon.position.y = 1.35 + sin(clock_t * 3.0 + w.phase) * 0.08
			e.icon.rotation.y += dt * 1.5
		elif e.hungry_lbl.visible:
			e.hungry_lbl.position.y = 1.0 + absf(sin(clock_t * 2.5 + w.phase)) * 0.12

func _animal_anim(m: Node3D, walking: bool) -> void:
	if not m.has_meta("anim"):
		return
	var ap: AnimationPlayer = m.get_meta("anim")
	var walk: String = m.get_meta("walk", "")
	var target: String = walk if walking and walk != "" else m.get_meta("idle", "")
	if target != "" and ap.current_animation != target:
		ap.play(target, 0.25)

# ============================================================ arayüz
func _sb(bg: Color, r := 16, border := Color(0, 0, 0, 0), bw := 0, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(r)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s

func _card() -> StyleBoxFlat:
	var s := _sb(Color("#fffaeef0"), 18, Color.WHITE, 2, 8)
	s.shadow_color = Color(0.29, 0.2, 0.14, 0.25)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	return s

func _panel(pad := 8) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _card()
	s.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", s)
	return p

func _btn_styles(b: Button, normal: Color, hover: Color, border := Color(0, 0, 0, 0), bw := 0) -> void:
	b.add_theme_stylebox_override("normal", _sb(normal, 14, border, bw, 4))
	b.add_theme_stylebox_override("hover", _sb(hover, 14, border, bw, 4))
	b.add_theme_stylebox_override("pressed", _sb(hover.darkened(0.08), 14, border, bw, 4))
	b.add_theme_stylebox_override("disabled", _sb(normal, 14, border, bw, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 15
	th.set_color("font_color", "Label", Color("#4a3424"))
	th.set_color("font_color", "Button", Color("#4a3424"))
	th.set_color("font_hover_color", "Button", Color("#4a3424"))
	th.set_color("font_pressed_color", "Button", Color("#4a3424"))
	th.set_color("font_disabled_color", "Button", Color("#4a3424"))
	ui.theme = th
	layer.add_child(ui)

	# --- üst bar
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_top = 12
	top.offset_right = -12
	top.add_theme_constant_override("separation", 10)
	ui.add_child(top)

	var stats := _panel(8)
	top.add_child(stats)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 12)
	stats.add_child(sh)
	var badge := PanelContainer.new()
	var bs := _sb(Color("#f4b400"), 23, Color.WHITE, 3, 0)
	bs.shadow_color = Color("#c78f00")
	bs.shadow_size = 0
	badge.add_theme_stylebox_override("panel", bs)
	badge.custom_minimum_size = Vector2(46, 46)
	lbl_level = Label.new()
	lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_level.add_theme_font_size_override("font_size", 20)
	lbl_level.add_theme_color_override("font_color", Color("#6b4200"))
	badge.add_child(lbl_level)
	sh.add_child(badge)
	var xv := VBoxContainer.new()
	xv.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_child(xv)
	lbl_xp = Label.new()
	lbl_xp.add_theme_font_size_override("font_size", 12)
	lbl_xp.add_theme_color_override("font_color", Color("#8a7260"))
	xv.add_child(lbl_xp)
	bar_xp = ProgressBar.new()
	bar_xp.show_percentage = false
	bar_xp.custom_minimum_size = Vector2(140, 10)
	bar_xp.add_theme_stylebox_override("background", _sb(Color("#eadcc6"), 6, Color(0, 0, 0, 0), 0, 0))
	bar_xp.add_theme_stylebox_override("fill", _sb(Color("#5cbf2f"), 6, Color(0, 0, 0, 0), 0, 0))
	xv.add_child(bar_xp)
	sh.add_child(VSeparator.new())
	lbl_coins = Label.new()
	lbl_coins.custom_minimum_size = Vector2(100, 0)
	lbl_coins.add_theme_font_size_override("font_size", 21)
	lbl_coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sh.add_child(lbl_coins)
	lbl_medals = Label.new()
	lbl_medals.add_theme_font_size_override("font_size", 21)
	lbl_medals.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sh.add_child(lbl_medals)
	lbl_gems = Label.new()
	lbl_gems.add_theme_font_size_override("font_size", 21)
	lbl_gems.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sh.add_child(lbl_gems)

	var clockp := _panel(12)
	top.add_child(clockp)
	lbl_clock = Label.new()
	clockp.add_child(lbl_clock)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var acts := _panel(6)
	top.add_child(acts)
	var ah := HBoxContainer.new()
	acts.add_child(ah)
	btn_sound = _icon_btn("🔊", "Ses aç/kapa")
	btn_sound.pressed.connect(func():
		muted = not muted
		btn_sound.text = "🔇" if muted else "🔊")
	ah.add_child(btn_sound)
	var bb := _icon_btn("📦", "Ambar  [B]")
	bb.pressed.connect(_open_barn)
	ah.add_child(bb)
	var bh := _icon_btn("❔", "Yardım")
	bh.pressed.connect(func(): help.visible = not help.visible)
	ah.add_child(bh)
	var br := _icon_btn("♻️", "Sıfırla (iki kez bas)")
	br.pressed.connect(_on_reset)
	ah.add_child(br)

	# --- alt: raf + alet çubuğu
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_bottom = -12
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 8)
	ui.add_child(bottom)

	lbl_queue = Label.new()
	lbl_queue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_queue.add_theme_color_override("font_color", Color.WHITE)
	lbl_queue.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	lbl_queue.add_theme_constant_override("outline_size", 4)
	bottom.add_child(lbl_queue)

	shelf_panel = _panel(8)
	shelf_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(shelf_panel)
	shelf_box = HBoxContainer.new()
	shelf_box.add_theme_constant_override("separation", 6)
	shelf_panel.add_child(shelf_box)

	var tb := _panel(6)
	tb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(tb)
	var th_box := HBoxContainer.new()
	th_box.add_theme_constant_override("separation", 4)
	tb.add_child(th_box)
	for i in TOOLS.size():
		var t = TOOLS[i]
		var b := Button.new()
		b.text = "%s\n%s" % [t.icon, t.name]
		b.tooltip_text = "%s  [%d]" % [t.tip, i + 1]
		b.custom_minimum_size = Vector2(66, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		var id: String = t.id
		b.pressed.connect(func(): _set_tool(id))
		th_box.add_child(b)
		tool_buttons[id] = b

	# --- ipucu
	tip_panel = PanelContainer.new()
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.add_theme_stylebox_override("panel", _sb(Color(0.18, 0.12, 0.08, 0.92), 10, Color(0, 0, 0, 0), 0, 9))
	tip_label = Label.new()
	tip_label.add_theme_color_override("font_color", Color.WHITE)
	tip_label.add_theme_font_size_override("font_size", 14)
	tip_panel.add_child(tip_label)
	tip_panel.visible = false
	ui.add_child(tip_panel)

	# --- bildirimler
	toasts = VBoxContainer.new()
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.anchor_left = 0.5
	toasts.anchor_right = 0.5
	toasts.offset_top = 84
	toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.add_theme_constant_override("separation", 6)
	ui.add_child(toasts)

	# --- yardım
	help = ColorRect.new()
	help.color = Color(0.12, 0.2, 0.08, 0.35)
	help.set_anchors_preset(Control.PRESET_FULL_RECT)
	help.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(help)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	help.add_child(cc)
	var hp := _panel(24)
	cc.add_child(hp)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	hp.add_child(hv)
	var h1 := Label.new()
	h1.text = "🌾 Çiftliğim 3D"
	h1.add_theme_font_size_override("font_size", 28)
	hv.add_child(h1)
	var body := Label.new()
	body.custom_minimum_size = Vector2(520, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "Toprağı sür, tohum ek, sula, hasat et; altınla ağaç, hayvan ve dekor al. Seviye atladıkça yeni ekinler açılır.\n\n• Sol tık / sürükle — seçili aleti karelere uygula (çiftçi sırayla yapar)\n• Sağ tık sürükle veya Q / E — kamerayı döndür · Tekerlek — yakınlaştır\n• Boş yere tıkla — çiftçi oraya yürür · WASD / oklar — yürüt\n• 1–9 — alet seç · B — 📦 Ambar (kaynak sat, sipariş teslim et) · Esc — iptal\n• ✋ El akıllıdır: boş tarlaya seçili tohumu eker, susuzu sular, hazırı toplar.\n• 💧 Sulanan toprak bir süre ıslak kalır (2× hız), sonra kurur · 🧑‍🌾 Korkuluk çevresine +%25 hız verir.\n• 🐔 Hayvanlar yem ister (tahıl; yoksa altın). Aç hayvan üretmez; ✋ ile yemle. Yan yana aynı tür hayvanlar ağıl olur, biri yemlenince hepsi yer. Topladıkça seviye atlar, daha çok kazandırır.\n• 🌼 Bahçe (9): çiçek tarhları kalıcıdır, sabit sürede açar; büyürken sulu kalırsa 3 kata kadar kazanç. 🐟 Gölet 2×2 kare, kendiliğinden balık verir.\n• 📜 Görevler (J): aynı anda 4 görev; bitince 🏅 madalya, 💎 elmas ve XP. Günde bir görev ücretsiz silinir, sonrası 2 💎.\n• 🌸 Dört mevsim (10'ar dk): bazı tohumlar yalnız kendi mevsiminde ekilir. 🌧️ Yağmur sular, 🔥 kuraklıkta su çabuk biter, 🌨️ karda sulamaya gerek yok.\n• Oyun otomatik kaydedilir; sen yokken de çiftlik büyür."
	hv.add_child(body)
	var go := Button.new()
	go.text = "Başlayalım!"
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(180, 44)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.add_theme_font_size_override("font_size", 17)
	go.add_theme_color_override("font_color", Color.WHITE)
	go.add_theme_color_override("font_hover_color", Color.WHITE)
	go.add_theme_color_override("font_pressed_color", Color.WHITE)
	_btn_styles(go, Color("#6fbf3b"), Color("#7fcf4b"))
	go.pressed.connect(func(): help.visible = false)
	hv.add_child(go)
	help.visible = false
	_build_barn_ui()
	_build_quest_ui()

func _icon_btn(icon: String, tip: String) -> Button:
	var b := Button.new()
	b.text = icon
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	_btn_styles(b, Color(0, 0, 0, 0), Color("#f3e6cf"))
	return b

func _on_reset() -> void:
	if Time.get_ticks_msec() / 1000.0 - reset_armed < 3.0:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		get_tree().reload_current_scene()
		return
	reset_armed = Time.get_ticks_msec() / 1000.0
	_toast("♻️ Sıfırlamak için 3 sn içinde tekrar bas", "warn")

func _set_tool(id: String) -> void:
	tool = id
	for k in tool_buttons:
		var b: Button = tool_buttons[k]
		var on: bool = k == id
		if on:
			_btn_styles(b, Color("#6fbf3b"), Color("#7fcf4b"))
		else:
			_btn_styles(b, Color(0, 0, 0, 0), Color("#f3e6cf"))
		b.add_theme_color_override("font_color", Color.WHITE if on else Color("#4a3424"))
		b.add_theme_color_override("font_hover_color", Color.WHITE if on else Color("#4a3424"))
	grid.visible = id != "hand"
	_render_shelf()

func _shelf_key() -> String:
	for t in TOOLS:
		if t.id == tool:
			return t.shelf
	return ""

func _render_shelf() -> void:
	var cat := _shelf_key()
	if cat == "":
		shelf_panel.visible = false
		return
	shelf_panel.visible = true
	for c in shelf_box.get_children():
		c.queue_free()
	var list = {"seed": Data.CROPS, "tree": Data.TREES, "animal": Data.ANIMALS, "decor": Data.DECOR, "garden": Data.garden()}[cat]
	for k in list:
		var it = list[k]
		var locked: bool = it.level > level
		var meta := ""
		match cat:
			"seed": meta = "⏱%s → %d🪙" % [fmt_time(it.time), it.sell] if _in_season(it) else "🚫 " + Data.season_icons(it.seasons)
			"tree": meta = "🍃%s → %d🪙" % [fmt_time(it.regrow), it.sell]
			"animal": meta = "%s%s → %d🪙" % [it.picon, fmt_time(it.time), it.sell]
			"decor": meta = "✨ bonus" if it.has("info") else " "
			"garden":
				if k == "pond":
					meta = "🐟%s → %d🪙" % [fmt_time(it.time), it.sell]
				else:
					meta = "⏱%s → %d🪙 💧×3" % [fmt_time(it.time), int(round(it.sell * Data.flower_mult(_flower_lv(k).lv)))]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(98, 92)
		b.add_theme_font_size_override("font_size", 12)
		b.text = "%s\n%s\n🪙 %d\n%s" % [it.icon, it.name, it.cost, ("🔒 Sv %d" % it.level) if locked else meta]
		b.tooltip_text = it.get("info", it.name)
		if cat == "garden" and k != "pond":
			b.tooltip_text = "%s · Sv %d\nKalıcı tarh: hasattan sonra yeniden açar.\nBüyürken sulu tutarsan kazanç 3 katına kadar çıkar." % [it.name, _flower_lv(k).lv]
		if cat == "seed":
			b.tooltip_text = "%s\nMevsim: %s" % [it.name, Data.season_names(it.seasons)]
		var selected: bool = sel[cat] == k
		_btn_styles(b, Color("#f1ffe6") if selected else Color.WHITE, Color("#fbf3e4"), Color("#6fbf3b") if selected else Color("#e7d7bf"), 2)
		if locked or (cat == "seed" and not _in_season(it)):
			b.modulate = Color(0.7, 0.7, 0.7, 0.75)
		b.set_meta("cost", it.cost)
		var kk: String = k
		b.pressed.connect(func():
			if locked:
				_toast("🔒 Seviye %d gerekli" % it.level, "warn")
				return
			sel[cat] = kk
			_render_shelf())
		shelf_box.add_child(b)
	_update_afford()

func _update_afford() -> void:
	for b in shelf_box.get_children():
		if b.is_queued_for_deletion():
			continue
		var poor: bool = b.get_meta("cost", 0) > coins
		b.add_theme_color_override("font_color", Color("#c62828") if poor else Color("#4a3424"))
		b.add_theme_color_override("font_hover_color", Color("#c62828") if poor else Color("#4a3424"))

func _update_hud(dt: float) -> void:
	shown_coins = lerpf(shown_coins, coins, minf(1.0, dt * 10.0))
	if absf(shown_coins - coins) < 0.5:
		shown_coins = coins
	lbl_coins.text = "🪙 %d" % roundi(shown_coins)
	lbl_queue.text = ("İş sırası: %d · Esc iptal" % queue.size()) if queue.size() > 0 else ""
	if not hud_dirty:
		return
	hud_dirty = false
	var need := Data.xp_for_level(level)
	lbl_level.text = str(level)
	lbl_medals.text = "🏅 %d" % medals
	lbl_gems.text = "💎 %d" % gems
	lbl_xp.text = "Seviye · %d / %d XP" % [xp, need]
	bar_xp.max_value = need
	bar_xp.value = xp
	_update_afford()

# ============================================================ kayıt
func _save() -> void:
	var ents := []
	for e in entities:
		if e.kind == "building":
			continue
		var s := {"k": e.kind, "x": e.x, "z": e.z, "r": e.rot}
		if e.has("type"): s.t = e.type
		match e.kind:
			"plot":
				s.c = e.crop
				s.p = e.progress
				s.w = snappedf(e.water, 0.001)
			"tree":
				s.a = e.age
				s.f = e.fruit_t
				s.h = e.has_fruit
			"animal":
				s.at = e.t
				s.rd = e.ready
				s.fd = snappedf(e.food, 0.001)
			"flower":
				s.at = e.t
				s.rd = e.ready
				s.wa = snappedf(e.water, 0.001)
				s.wt = snappedf(e.wet_t, 0.01)
			"pond":
				s.at = e.t
				s.rd = e.ready
				s.lv = e.lv
				s.hv = e.hv
		ents.append(s)
	var data := {"v": 1, "gems": gems, "quests": quests, "qskip": quest_skip_at, "flv": flv, "season": season, "season_t": season_t, "year": year, "weather": weather, "weather_t": weather_t, "medals": medals, "res": res, "order": order, "coins": coins, "xp": xp, "level": level, "day_time": day_time, "day": day, "sel": sel, "muted": muted,
		"saved_at": Time.get_unix_time_from_system(), "ents": ents, "fx": farmer.position.x, "fz": farmer.position.z}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func _load() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("v", 0)) != 1:
		return false
	coins = int(data.coins)
	xp = int(data.xp)
	level = int(data.level)
	day_time = float(data.day_time)
	day = int(data.get("day", 1))
	muted = bool(data.get("muted", false))
	medals = int(data.get("medals", 0))
	gems = int(data.get("gems", 0))
	quest_skip_at = float(data.get("qskip", 0.0))
	quests = []
	var qd = data.get("quests", [])
	if typeof(qd) == TYPE_ARRAY:
		for q in qd:
			if typeof(q) == TYPE_DICTIONARY and q.has("kind"):
				quests.append({"kind": str(q.kind), "arg": str(q.get("arg", "")), "text": str(q.get("text", "")),
					"need": int(q.need), "have": int(q.get("have", 0)), "medals": int(q.medals), "gems": int(q.gems), "xp": int(q.xp)})
	flv = {}
	var fd = data.get("flv", {})
	if typeof(fd) == TYPE_DICTIONARY:
		for k in fd:
			flv[k] = {"lv": int(fd[k].lv), "n": int(fd[k].n)}
	season = clampi(int(data.get("season", 0)), 0, 3)
	season_t = float(data.get("season_t", 0.0))
	year = int(data.get("year", 1))
	weather = str(data.get("weather", ""))
	if not Data.WEATHER.has(weather):
		weather = ""
	weather_t = float(data.get("weather_t", 0.0))
	res = {}
	for k in data.get("res", {}):
		res[k] = int(data.res[k])
	order = {}
	var od = data.get("order", {})
	if typeof(od) == TYPE_DICTIONARY and od.has("need"):
		var need := {}
		for k in od.need:
			need[k] = int(od.need[k])
		order = {"need": need, "medals": int(od.medals), "xp": int(od.xp), "coins": int(od.coins)}
	for k in data.get("sel", {}):
		sel[k] = data.sel[k]
	for s in data.ents:
		var x := int(s.x)
		var z := int(s.z)
		if tiles.has(key(x, z)):
			continue
		var base := {"kind": s.k, "x": x, "z": z, "rot": float(s.get("r", 0.0))}
		if s.has("t"):
			base.type = s.t
		match s.k:
			"plot":
				base.crop = s.get("c")
				base.progress = float(s.get("p", 0.0))
				var w = s.get("w", 0.0)
				base.water = (1.0 if w else 0.0) if typeof(w) == TYPE_BOOL else float(w)
			"tree":
				base.age = float(s.get("a", 0.0))
				base.fruit_t = float(s.get("f", 0.0))
				base.has_fruit = bool(s.get("h", false))
			"animal":
				base.t = float(s.get("at", 0.0))
				base.ready = bool(s.get("rd", false))
				base.food = float(s.get("fd", 1.0))
			"flower", "pond":
				base.t = float(s.get("at", 0.0))
				base.ready = bool(s.get("rd", false))
				base.water = float(s.get("wa", 0.0))
				base.wet_t = float(s.get("wt", 0.0))
				base.lv = int(s.get("lv", 1))
				base.hv = int(s.get("hv", 0))
		_add_entity(base)
	_recompute_boosts()
	if order.is_empty():
		_new_order()
	_fill_quests()
	farmer.position = Vector3(float(data.get("fx", 0.5)), 0, float(data.get("fz", 9.0)))
	cam_target = farmer.position
	btn_sound.text = "🔇" if muted else "🔊"
	var away := minf(OFFLINE_CAP, Time.get_unix_time_from_system() - float(data.get("saved_at", 0)))
	if away > 20.0:
		var left := away
		loading = true
		while left > 0.0:
			_simulate(minf(5.0, left))
			left -= 5.0
		loading = false
		_toast("🌙 Sen yokken çiftliğin %s boyunca büyüdü!" % fmt_time(away), "level")
	return true

func _new_game() -> void:
	for z in range(-6, 12):
		for x in [-1, 0]:
			_add_entity({"kind": "decor", "type": "path", "x": x, "z": z})
	for x in range(-10, -1):
		for z in [-7, -6]:
			_add_entity({"kind": "decor", "type": "path", "x": x, "z": z})
	var i := 0
	for x in range(2, 8):
		for z in range(1, 5):
			var planted := i < 16
			_add_entity({"kind": "plot", "x": x, "z": z, "crop": ("wheat" if i < 8 else "carrot") if planted else null,
				"progress": (1.0 if i < 4 else 0.15 + (i % 5) * 0.15) if planted else 0.0, "watered": planted and i % 3 != 0})
			i += 1
	_add_entity({"kind": "animal", "type": "chicken", "x": -6, "z": 2})
	_add_entity({"kind": "animal", "type": "chicken", "x": -5, "z": 3, "ready": true, "t": 0.0})
	_add_entity({"kind": "animal", "type": "chicken", "x": -7, "z": 3, "t": 0.5, "food": 0.0})
	for x in range(-9, -2):
		_add_entity({"kind": "decor", "type": "fence", "x": x, "z": 1})
		_add_entity({"kind": "decor", "type": "fence", "x": x, "z": 5})
	for z in range(2, 5):
		_add_entity({"kind": "decor", "type": "fence", "x": -9, "z": z})
		_add_entity({"kind": "decor", "type": "fence", "x": -3, "z": z})
	_add_entity({"kind": "tree", "type": "apple", "x": -6, "z": -3, "age": 1.0, "fruit_t": 0.0, "has_fruit": true})
	_add_entity({"kind": "tree", "type": "apple", "x": -3, "z": -3, "age": 0.4, "fruit_t": 0.0, "has_fruit": false})
	_new_order()
	for d in [["flowers", -11, -7], ["flowers", -11, -6], ["lantern", -2, 10], ["lantern", 1, 10], ["lantern", -3, -5], ["bush", 10, 9], ["hay", 5, -6], ["rock", 9, 6]]:
		_add_entity({"kind": "decor", "type": d[0], "x": d[1], "z": d[2]})
	_recompute_boosts()
	quests = []
	_fill_quests()

# ============================================================ döngü
func _process(delta: float) -> void:
	var dt := minf(0.1, delta)
	if painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		painting = false
	sim_acc += dt
	if sim_acc > 0.1:
		_simulate(sim_acc)
		sim_acc = 0.0
	_update_farmer(dt)
	_update_camera(dt)
	_update_day(dt)
	_update_lamps(dt)
	_animate_world(dt)
	_update_parts(dt)
	_update_floats(dt)
	_update_hover()
	_update_cursor()
	_update_hud(dt)
	save_timer += dt
	if save_timer > 10.0:
		save_timer = 0.0
		if shot_path == "":
			_save()
	if OS.get_cmdline_user_args().has("--fps"):
		fps_t += delta
		if fps_t > 3.0:
			fps_n += 1
		if fps_t > 8.0:
			print("FPS ortalama: %.1f" % (fps_n / (fps_t - 3.0)))
			get_tree().quit()
	if shot_path != "":
		shot_t += delta
		if shot_t > 4.0:
			get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()

# ============================================================ öz test (--selftest)
func _selftest() -> void:
	var fails := []
	quests = []
	season = 0
	season_t = 0.0
	weather = ""
	var c0 := coins
	if not _perform({"x": 2, "z": 1, "tool": "hand", "arg": "wheat"}): fails.append("hasat")
	if coins != c0 + 12: fails.append("hasat altını %d" % coins)
	if tiles[key(2, 1)].crop != null: fails.append("hasat sonrası tarla boş değil")
	if not _perform({"x": 2, "z": 1, "tool": "hand", "arg": "carrot"}): fails.append("el ile ekim")
	if not _perform({"x": 2, "z": 1, "tool": "water", "arg": null}): fails.append("sulama")
	if not _perform({"x": 0, "z": 0, "tool": "plow", "arg": null}) == false: fails.append("yol üstüne sürme engellenmedi")
	if not _perform({"x": 9, "z": 2, "tool": "plow", "arg": null}): fails.append("sürme")
	if not _perform({"x": 9, "z": 2, "tool": "seed", "arg": "wheat"}): fails.append("tohum")
	if _perform({"x": 9, "z": 3, "tool": "seed", "arg": "tomato"}): fails.append("kilitli ekin ekildi")
	coins = 5000
	level = 6
	if not _perform({"x": 9, "z": 5, "tool": "tree", "arg": "cherry"}): fails.append("ağaç")
	if not _perform({"x": 10, "z": 5, "tool": "animal", "arg": "cow"}): fails.append("hayvan")
	if not _perform({"x": 8, "z": 5, "tool": "decor", "arg": "scarecrow"}): fails.append("korkuluk")
	if not tiles[key(9, 2)].boost: fails.append("korkuluk bonusu")
	if not _perform({"x": 10, "z": 5, "tool": "remove", "arg": null}): fails.append("kaldır")
	if not _perform({"x": 9, "z": 2, "tool": "water", "arg": null}): fails.append("sulama 2")
	_simulate(Data.CROPS.wheat.time * 0.85)
	if tiles[key(9, 2)].progress < 1.0: fails.append("büyüme %.2f" % tiles[key(9, 2)].progress)
	# tıklanan yere yürüme + bina engeli
	farmer.position = Vector3(0.5, 0, 9)
	_clear_queue()
	_walk_to(Vector3(6.3, 0, 11.2))
	for i in 200:
		_update_farmer(0.05)
	if farmer.position.distance_to(Vector3(6.3, 0, 11.2)) > 0.1: fails.append("yürüme %s" % farmer.position)
	_walk_to(Vector3(-9, 0, -10))
	for i in 200:
		_update_farmer(0.05)
	if _blocked(farmer.position): fails.append("binanın içine girdi")
	# Aşama 1: kaynak, satış, sipariş
	res = {}
	medals = 0
	var tree_e = tiles[key(9, 5)]
	tree_e.age = 1.0
	tree_e.has_fruit = true
	coins = 100
	var c1 := coins
	if not _perform({"x": 9, "z": 5, "tool": "hand", "arg": "wheat"}): fails.append("meyve hasadı")
	if res.get("fruit", 0) != 5: fails.append("kiraz kaynağı %s" % res)
	_sell("fruit", 2)
	if res.fruit != 3 or coins != c1 + 95 + 12: fails.append("satış altını %d" % coins)
	order = {"need": {"fruit": 3}, "medals": 2, "xp": 10, "coins": 30}
	_deliver()
	if medals != 2 or res.fruit != 0: fails.append("sipariş teslimi")
	if order.is_empty(): fails.append("yeni sipariş oluşmadı")
	res = {"veg": Data.BARN_CAP - 1}
	_store("pumpkin", Vector3.ZERO)
	if _res_total() != Data.BARN_CAP: fails.append("ambar kapasitesi %d" % _res_total())
	res = {}
	_selftest_seasons(fails)
	_selftest_animals(fails)
	_selftest_garden(fails)
	_selftest_quests(fails)
	var n_before := entities.size()
	_save()
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data.ents.size() != n_before - 4: fails.append("kayıt varlık sayısı %d / %d" % [data.ents.size(), n_before - 4])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("SELFTEST ", "OK" if fails.is_empty() else "FAIL: " + ", ".join(fails))
	get_tree().quit()

## --demo: ekran görüntüleri için her türden örnek yerleştirir.
func _demo() -> void:
	coins = 5000
	level = 6
	var crops := ["wheat", "carrot", "tomato", "corn", "sunflower", "pumpkin"]
	for i in crops.size():
		for st in 4:
			var x := 2 + st
			var z := -5 + i
			if tiles.has(key(x, z)):
				continue
			_add_entity({"kind": "plot", "x": x, "z": z, "crop": crops[i], "progress": [0.0, 0.4, 0.75, 1.0][st], "watered": st < 3})
	var an := [["cow", 8, 2], ["pig", 9, 3], ["sheep", 10, 2], ["cow", 10, 4]]
	for a in an:
		_add_entity({"kind": "animal", "type": a[0], "x": a[1], "z": a[2], "ready": a[1] == 9})
	var tr := [["apple", -6, 7, 1.0, true], ["orange", -4, 7, 1.0, true], ["cherry", -2, 7, 1.0, true], ["apple", -6, 9, 1.0, false], ["orange", -4, 9, 0.3, false]]
	for t in tr:
		if not tiles.has(key(t[1], t[2])):
			_add_entity({"kind": "tree", "type": t[0], "x": t[1], "z": t[2], "age": t[3], "fruit_t": 0.0, "has_fruit": t[4]})
	var fls := [["daisy", 8, 0.0, false, 1.0], ["tulip", 9, 0.5, false, 0.0], ["rose", 10, 0.8, false, 1.0], ["lavender", 11, 1.0, true, 0.0], ["tulip", 7, 1.0, true, 1.0]]
	for f in fls:
		if not tiles.has(key(f[1], -1)):
			_add_entity({"kind": "flower", "type": f[0], "x": f[1], "z": -1, "t": f[2], "ready": f[3], "water": f[4]})
	if _free_area(8, -4, 2, 2):
		_add_entity({"kind": "pond", "type": "pond", "x": 8, "z": -4, "ready": true})
	farmer.position = Vector3(6.5, 0, 1.5)
	cam_target = farmer.position
	cam_dist = 11.0

# ============================================================ görevler (Aşama 5)
func _owned(kind: String, type: String) -> bool:
	for e in entities:
		if e.kind == kind and e.get("type", "") == type:
			return true
	return false

func _owned_kind(kind: String) -> bool:
	for e in entities:
		if e.kind == kind:
			return true
	return false

## Görev şablonu: ihtiyaç ve ödül seviyeye göre ölçeklenir.
func _make_quest(kind: String, arg: String) -> Dictionary:
	var need := 1
	var val := 1.0
	var text := ""
	var lv := level
	match kind:
		"crop":
			var c = Data.CROPS[arg]
			need = maxi(3, int(round(300.0 / c.time))) + lv
			val = c.sell
			text = "%s %d %s topla" % [c.icon, need, c.name]
		"fruit":
			var t = Data.TREES[arg]
			need = 3 + lv / 2
			val = t.sell
			text = "%s %d kez %s topla" % [t.icon, need, t.name]
		"animal":
			var a = Data.ANIMALS[arg]
			need = 3 + lv / 2
			val = a.sell
			text = "%s %d kez %s topla" % [a.picon, need, a.product]
		"flower":
			need = 4 + lv / 2
			val = 20.0
			text = "🌼 %d çiçek tarhı topla" % need
		"fish":
			need = 3 + lv / 3
			val = 40.0
			text = "🐟 %d kez balık tut" % need
		"plant":
			need = 15 + lv * 2
			val = 6.0
			text = "🌱 %d tohum ek" % need
		"water":
			need = 15 + lv * 2
			val = 4.0
			text = "💧 %d kez sula" % need
		"feed":
			need = 4 + lv / 2
			val = 15.0
			text = "🌾 %d kez hayvan yemle" % need
		"sell":
			need = 30 + lv * 5
			val = 3.0
			text = "💰 Ambardan %d kaynak sat" % need
		"order":
			need = 1 + lv / 4
			val = 150.0
			text = "📋 %d pazar siparişi teslim et" % need
		"tree":
			need = 1 + lv / 5
			val = 100.0
			text = "🌳 %d ağaç dik" % need
		"earn":
			need = 300 + lv * 100
			val = 0.3
			text = "🪙 %d altın kazan" % need
	var v := need * val
	return {"kind": kind, "arg": arg, "text": text, "need": need, "have": 0,
		"medals": maxi(1, int(v / 60.0)), "gems": 1 if v < 250.0 else 2, "xp": maxi(5, int(v / 5.0))}

func _quest_candidates() -> Array:
	var out := []
	for k in Data.CROPS:
		if Data.CROPS[k].level <= level:
			out.append(["crop", k])
	for k in Data.TREES:
		if _owned("tree", k):
			out.append(["fruit", k])
	for k in Data.ANIMALS:
		if _owned("animal", k):
			out.append(["animal", k])
	out.append(["flower", ""])
	if _owned_kind("pond"):
		out.append(["fish", ""])
	for k in ["plant", "water", "sell", "order", "earn"]:
		out.append([k, ""])
	if _owned_kind("animal"):
		out.append(["feed", ""])
	if Data.TREES.apple.level <= level:
		out.append(["tree", ""])
	var active := {}
	for q in quests:
		active[q.kind + ":" + q.arg] = true
	return out.filter(func(c): return not active.has(c[0] + ":" + c[1]))

func _random_quest() -> Dictionary:
	var c := _quest_candidates()
	var pick = c[randi() % c.size()]
	return _make_quest(pick[0], pick[1])

func _fill_quests() -> void:
	while quests.size() < QUEST_SLOTS:
		quests.append(_random_quest())
	_render_quests()

func _quest_event(kind: String, arg: String, n: int) -> void:
	if n <= 0:
		return
	var done := []
	for i in quests.size():
		var q = quests[i]
		if q.kind == kind and (q.arg == "" or q.arg == arg):
			q.have = mini(q.need, q.have + n)
			if q.have >= q.need:
				done.append(i)
	for i in done:
		var q = quests[i]
		medals += q.medals
		gems += q.gems
		quests[i] = _random_quest()
		_toast("📜 Görev tamamlandı: %s\n+%d 🏅  +%d 💎  +%d XP" % [q.text, q.medals, q.gems, q.xp], "level")
		_gain(0, q.xp, farmer.position, "📜")
		_sfx("level")
	hud_dirty = true
	_render_quests()

func _skip_quest(i: int) -> bool:
	var now := Time.get_unix_time_from_system()
	if now - quest_skip_at >= QUEST_SKIP_COOLDOWN:
		quest_skip_at = now
	elif gems >= QUEST_SKIP_GEMS:
		gems -= QUEST_SKIP_GEMS
	else:
		var left := QUEST_SKIP_COOLDOWN - (now - quest_skip_at)
		_toast("⏳ Ücretsiz silme %s sonra (ya da %d 💎)" % [fmt_time(left), QUEST_SKIP_GEMS], "warn")
		return false
	var old = quests[i]
	quests.remove_at(i)
	var nq := _random_quest()
	quests.insert(i, nq)
	if nq.kind == old.kind and nq.arg == old.arg and _quest_candidates().size() > 0:
		quests[i] = _random_quest()
	hud_dirty = true
	_render_quests()
	return true

func _build_quest_ui() -> void:
	quest_panel = _panel(10)
	quest_panel.position = Vector2(12, 84)
	quest_panel.custom_minimum_size = Vector2(290, 0)
	quest_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(quest_panel)
	ui.move_child(quest_panel, help.get_index())
	quest_box = VBoxContainer.new()
	quest_box.add_theme_constant_override("separation", 6)
	quest_panel.add_child(quest_box)

func _render_quests() -> void:
	if quest_box == null:
		return
	for c in quest_box.get_children():
		quest_box.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	var t := Label.new()
	t.text = "📜 Görevler"
	t.add_theme_font_size_override("font_size", 17)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var tg := _small_btn(" ▾ " if quest_open else " ▸ ", func():
		quest_open = not quest_open
		_render_quests())
	tg.tooltip_text = "Görevleri aç/kapa  [J]"
	head.add_child(tg)
	quest_box.add_child(head)
	quest_panel.reset_size()
	if not quest_open:
		return
	for i in quests.size():
		var q = quests[i]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var top := HBoxContainer.new()
		var l := Label.new()
		l.text = q.text
		l.add_theme_font_size_override("font_size", 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(l)
		var cnt := Label.new()
		cnt.text = "%d/%d" % [q.have, q.need]
		cnt.add_theme_font_size_override("font_size", 13)
		cnt.add_theme_color_override("font_color", Color("#8a7260"))
		top.add_child(cnt)
		var ii := i
		var x := _small_btn("✕", func(): _skip_quest(ii))
		x.custom_minimum_size = Vector2(26, 24)
		x.add_theme_font_size_override("font_size", 11)
		x.tooltip_text = "Görevi sil (günde 1 ücretsiz, sonra %d 💎)" % QUEST_SKIP_GEMS
		top.add_child(x)
		row.add_child(top)
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 6)
		pb.max_value = q.need
		pb.value = q.have
		pb.add_theme_stylebox_override("background", _sb(Color("#eadcc6"), 3, Color(0, 0, 0, 0), 0, 0))
		pb.add_theme_stylebox_override("fill", _sb(Color("#5cbf2f"), 3, Color(0, 0, 0, 0), 0, 0))
		row.add_child(pb)
		var rw := Label.new()
		rw.text = "🏅 %d   💎 %d   +%d XP" % [q.medals, q.gems, q.xp]
		rw.add_theme_font_size_override("font_size", 12)
		rw.add_theme_color_override("font_color", Color("#9a6a00"))
		row.add_child(rw)
		quest_box.add_child(row)
	quest_panel.reset_size()

func _selftest_quests(fails: Array) -> void:
	medals = 0
	gems = 0
	quests = []
	_fill_quests()
	if quests.size() != QUEST_SLOTS: fails.append("görev sayısı %d" % quests.size())
	var keys := {}
	for q in quests:
		keys[q.kind + ":" + q.arg] = true
	if keys.size() != QUEST_SLOTS: fails.append("tekrarlı görev")
	for i in 40:
		var rq := _random_quest()
		if rq.text == "" or rq.need <= 0: fails.append("boş görev %s" % rq)
	quests = [_make_quest("crop", "wheat"), _make_quest("sell", ""), _make_quest("water", ""), _make_quest("earn", "")]
	quests[0].need = 2
	quests[1].need = 5
	var q0 = quests[0]
	_quest_event("crop", "carrot", 1)
	if q0.have != 0: fails.append("yanlış ekin sayıldı")
	_quest_event("crop", "wheat", 1)
	if q0.have != 1: fails.append("görev ilerlemedi")
	var m0 := medals
	_quest_event("crop", "wheat", 1)
	if quests[0] == q0 or medals != m0 + q0.medals or gems != q0.gems: fails.append("görev ödülü")
	if quests.size() != QUEST_SLOTS: fails.append("tamamlanınca görev eksildi")
	res = {"egg": 5}
	var q1 = quests[1]
	_sell("egg", 5)
	if quests[1] == q1: fails.append("satış görevi tamamlanmadı")
	quest_skip_at = 0.0
	gems = 0
	var q2 = quests[2]
	if not _skip_quest(2) or quests[2] == q2: fails.append("ücretsiz silme")
	var q3 = quests[3]
	if _skip_quest(3) or quests[3] != q3: fails.append("bekleme süresi yok sayıldı")
	gems = QUEST_SKIP_GEMS
	if not _skip_quest(3) or gems != 0: fails.append("elmasla silme")
	res = {}

# ============================================================ çiçekler ve gölet (Aşama 4)
func _flower_lv(t: String) -> Dictionary:
	if not flv.has(t):
		flv[t] = {"lv": 1, "n": 0}
	return flv[t]

func _flower_wet_frac(e: Dictionary) -> float:
	return clampf(e.wet_t / Data.FLOWERS[e.type].time, 0.0, 1.0)

func _harvest_flower(e: Dictionary, pos: Vector3) -> void:
	var f = Data.FLOWERS[e.type]
	var frac := _flower_wet_frac(e)
	var fl := _flower_lv(e.type)
	var mult := (1.0 + Data.FLOWER_WET_BONUS * frac) * Data.flower_mult(fl.lv)
	_burst(pos + Vector3(0, 0.4, 0), f.color, 14, 3.5)
	_gain(int(round(f.sell * mult)), int(round(f.xp * (1.0 + Data.FLOWER_WET_BONUS * frac))), pos, f.icon)
	_store(e.type, pos, int(round(frac * 2.0)))
	_quest_event("flower", e.type, 1)
	if frac > 0.95:
		_float_text(pos + Vector3(0, 0.75, 0), "💐 ×%.0f" % (1.0 + Data.FLOWER_WET_BONUS), Color("#ffb3e6"))
	e.ready = false
	e.t = 0.0
	e.wet_t = 0.0
	_refresh(e)
	if fl.lv < Data.FLOWER_MAX_LV:
		fl.n += 1
		if fl.n >= fl.lv * Data.FLOWER_HARVESTS_PER_LV:
			fl.n = 0
			fl.lv += 1
			_toast("%s %s seviye %d! Tüm %s tarhları +%%%d kazanç" % [f.icon, f.name, fl.lv, f.name, int(round((Data.flower_mult(fl.lv) - 1.0) * 100.0))], "level")
			if tool == "garden":
				_render_shelf()

func _selftest_garden(fails: Array) -> void:
	coins = 2000
	level = 6
	res = {}
	flv = {}
	weather = ""
	if not _perform({"x": 10, "z": 11, "tool": "garden", "arg": "daisy"}): fails.append("çiçek dikme")
	var f = tiles[key(10, 11)]
	if not _perform({"x": 10, "z": 11, "tool": "water", "arg": null}): fails.append("çiçek sulama")
	_simulate(Data.FLOWERS.daisy.time)
	if not f.ready: fails.append("çiçek açmadı %.3f" % f.t)
	var c0 := coins
	if not _perform({"x": 10, "z": 11, "tool": "hand", "arg": "wheat"}): fails.append("çiçek hasadı")
	if coins - c0 != 30: fails.append("sulu çiçek kazancı %d" % (coins - c0))
	if res.get("flower", 0) != 4: fails.append("çiçek kaynağı %s" % res)
	if f.ready or f.t != 0.0 or not tiles.has(key(10, 11)): fails.append("çiçek yeniden açmıyor")
	f.water = 0.0
	_simulate(Data.FLOWERS.daisy.time)
	c0 = coins
	_perform({"x": 10, "z": 11, "tool": "hand", "arg": "wheat"})
	if coins - c0 != 10: fails.append("kuru çiçek kazancı %d" % (coins - c0))
	flv.daisy.n = Data.FLOWER_HARVESTS_PER_LV - 1
	f.water = 0.0
	_simulate(Data.FLOWERS.daisy.time)
	_perform({"x": 10, "z": 11, "tool": "hand", "arg": "wheat"})
	if flv.daisy.lv != 2: fails.append("çiçek seviyesi %s" % flv.daisy)
	# gölet
	if _resolve("garden", "pond", 10, 10) != null: fails.append("gölet dolu alana kuruldu")
	if not _perform({"x": 8, "z": 9, "tool": "garden", "arg": "pond"}): fails.append("gölet kurma")
	var pd = tiles.get(key(9, 10))
	if pd == null or pd.kind != "pond": fails.append("gölet 2×2 değil")
	if _resolve("garden", "daisy", 9, 9) != null: fails.append("gölet üstüne çiçek")
	_simulate(Data.POND.time + 0.5)
	if not pd.ready: fails.append("gölet balık üretmedi")
	res = {}
	if not _perform({"x": 9, "z": 10, "tool": "hand", "arg": "wheat"}): fails.append("balık toplama")
	if res.get("fish", 0) != 4: fails.append("balık kaynağı %s" % res)
	if not _perform({"x": 9, "z": 10, "tool": "remove", "arg": null}): fails.append("gölet kaldırma")
	if tiles.has(key(8, 9)) or tiles.has(key(9, 10)): fails.append("gölet kareleri boşalmadı")
	res = {}

# ============================================================ hayvan yemi, ağıl, seviye (Aşama 3)
## Bitişik (4 yön) aynı tür hayvanlar bir ağıldır.
func _pen(e: Dictionary) -> Array:
	var out := [e]
	var seen := {key(e.x, e.z): true}
	var i := 0
	while i < out.size():
		var c = out[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var k := key(c.x + d.x, c.z + d.y)
			if seen.has(k):
				continue
			var n = tiles.get(k)
			if n != null and n.kind == "animal" and n.type == e.type:
				seen[k] = true
				out.append(n)
	return out

## Ağıldaki eksik yem için gereken tahıl.
func _feed_need(e: Dictionary) -> int:
	var need := 0.0
	for a in _pen(e):
		need += Data.ANIMALS[a.type].feed * (1.0 - a.food)
	return ceili(need - 0.001)

func _feed_split(e: Dictionary) -> Vector2i:
	var need := _feed_need(e)
	var from_res := mini(need, res.get("cereal", 0))
	return Vector2i(from_res, (need - from_res) * Data.FEED_COIN)

func _can_feed(e: Dictionary) -> bool:
	return _feed_split(e).y <= coins

func _feed_cost_text(e: Dictionary) -> String:
	var sp := _feed_split(e)
	var parts := []
	if sp.x > 0:
		parts.append("-%d🌾" % sp.x)
	if sp.y > 0:
		parts.append("-%d🪙" % sp.y)
	var n := _pen(e).size()
	return ("(ağıl %d) " % n if n > 1 else "") + " ".join(parts)

func _feed_pen(e: Dictionary) -> void:
	_quest_event("feed", e.type, 1)
	var sp := _feed_split(e)
	if sp.x > 0:
		res.cereal -= sp.x
	if sp.y > 0:
		_spend(sp.y)
	var pos := tile_center(e.x, e.z)
	_float_text(pos, ("-%d 🌾" % sp.x) if sp.x > 0 else ("-%d 🪙" % sp.y), Color("#ffe2a8"))
	for a in _pen(e):
		a.food = 1.0
		_update_hungry(a)
		_burst(tile_center(a.x, a.z) + Vector3(0, 0.3, 0), "#f0c75e", 6, 2.0)
	_sfx("plant")
	if barn.visible:
		_render_barn()

func _update_hungry(e: Dictionary) -> void:
	if e.has("hungry_lbl"):
		e.hungry_lbl.visible = e.food <= 0.0 and not e.ready

func _animal_harvested(e: Dictionary, pos: Vector3) -> void:
	if e.lv >= Data.ANIMAL_MAX_LV:
		return
	e.hv += 1
	if e.hv >= e.lv * Data.HARVESTS_PER_LV:
		e.hv = 0
		e.lv += 1
		var a = Data.ANIMALS[e.type]
		_float_text(pos + Vector3(0, 0.7, 0), "⭐ Sv %d" % e.lv, Color("#ffd54f"))
		_toast("%s %s seviye %d oldu! Kazancı +%%%d" % [a.icon, a.name, e.lv, int(round((Data.animal_sell_mult(e.lv) - 1.0) * 100.0))], "level")
		_burst(pos + Vector3(0, 1.0, 0), "#ffd54f", 14, 4.0)

func _selftest_animals(fails: Array) -> void:
	coins = 100
	level = 6
	res = {"cereal": 1}
	var a := _add_entity({"kind": "animal", "type": "chicken", "x": 10, "z": 7, "food": 0.0})
	var b := _add_entity({"kind": "animal", "type": "chicken", "x": 11, "z": 7, "food": 0.0})
	if _pen(a).size() != 2: fails.append("ağıl boyutu %d" % _pen(a).size())
	_simulate(30.0)
	if a.t != 0.0: fails.append("aç hayvan üretti")
	if _resolve("hand", "wheat", 10, 7) != "feed": fails.append("yemle eylemi yok")
	if not _perform({"x": 10, "z": 7, "tool": "hand", "arg": "wheat"}): fails.append("yemleme")
	if a.food != 1.0 or b.food != 1.0: fails.append("ağıl yemi paylaşmadı")
	if res.cereal != 0 or coins != 100 - Data.FEED_COIN: fails.append("yem bedeli %d/%d" % [res.cereal, coins])
	_simulate(Data.ANIMALS.chicken.time)
	if not a.ready: fails.append("yemli hayvan üretmedi")
	if absf(a.food - (1.0 - 1.0 / Data.FEED_CYCLES)) > 0.01: fails.append("yem azalması %.3f" % a.food)
	a.hv = Data.HARVESTS_PER_LV - 1
	if not _perform({"x": 10, "z": 7, "tool": "hand", "arg": "wheat"}): fails.append("hayvan hasadı")
	if a.lv != 2: fails.append("hayvan seviyesi %d" % a.lv)
	a.ready = true
	var c0 := coins
	res = {}
	_perform({"x": 10, "z": 7, "tool": "hand", "arg": "wheat"})
	if coins != c0 + int(round(Data.ANIMALS.chicken.sell * Data.animal_sell_mult(2))): fails.append("seviye bonusu %d" % (coins - c0))
	if res.get("egg", 0) != Data.YIELD.chicken[1] + Data.animal_extra_yield(2): fails.append("seviye yumurta %s" % res)
	res = {}

# ============================================================ mevsim ve hava (Aşama 2)
func _on_season_start() -> void:
	var sn = Data.SEASONS[season]
	var prev := (season + 3) % 4
	var fresh := []
	for k in Data.CROPS:
		var c = Data.CROPS[k]
		if c.seasons.has(season) and not c.seasons.has(prev) and c.level <= level:
			fresh.append(c.icon + " " + c.name)
	var msg := "%s %s geldi!" % [sn.icon, sn.name]
	if fresh.size() > 0:
		msg += "\nEkilebilir: " + ", ".join(fresh)
	_toast(msg, "level")
	if season != 3:
		var n := 0
		for e in entities:
			if e.kind == "tree" and e.age >= 1.0 and not e.has_fruit:
				e.has_fruit = true
				e.fruit_t = 0.0
				_refresh(e)
				n += 1
		if n > 0:
			_toast("🌳 Ağaçlar mevsim meyvesi verdi (%d)" % n)
	if weather != "":
		_end_weather()
	var r := randf()
	for wc in Data.WEATHER_CHANCE[season]:
		if r < wc[1]:
			_start_weather(wc[0])
			break
		r -= wc[1]
	_apply_season_visual(loading)
	if shelf_box != null:
		_render_shelf()

func _start_weather(w: String) -> void:
	if not Data.WEATHER.has(w):
		return
	weather = w
	weather_t = randf_range(150.0, 300.0)
	_toast("%s %s" % [Data.WEATHER[w].icon, Data.WEATHER[w].msg], "warn" if w == "drought" else "")

func _end_weather() -> void:
	if weather != "":
		_toast("🌤️ Hava açıldı")
	weather = ""
	weather_t = 0.0

func _apply_season_visual(instant: bool) -> void:
	var t = SEASON_TINT[season]
	var col := Color(t[0])
	if instant:
		ground_mat.set_shader_parameter("tint", col)
		ground_mat.set_shader_parameter("amt", t[1])
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(ground_mat, "shader_parameter/tint", col, 6.0)
	tw.tween_property(ground_mat, "shader_parameter/amt", t[1], 6.0)

func _selftest_seasons(fails: Array) -> void:
	season = 0
	season_t = 0.0
	weather = ""
	coins = 1000
	level = 6
	if not _perform({"x": 9, "z": 3, "tool": "plow", "arg": null}): fails.append("sürme 3")
	if not _perform({"x": 9, "z": 3, "tool": "seed", "arg": "tomato"}): fails.append("ilkbaharda domates")
	var e = tiles[key(9, 3)]
	var b := 1.25 if e.boost else 1.0
	var w_exp := 1.0 - Data.CROPS.tomato.time / 2.0 / Data.WATER_DUR
	_simulate(Data.CROPS.tomato.time / 2.0)
	if absf(e.progress - 0.25 * b) > 0.01: fails.append("susuz büyüme %.3f" % e.progress)
	if not _perform({"x": 9, "z": 3, "tool": "water", "arg": null}): fails.append("sulama 3")
	if _resolve("water", null, 9, 3) != null: fails.append("dolu toprağa tekrar sulama")
	_simulate(Data.CROPS.tomato.time / 2.0)
	if absf(e.progress - 0.75 * b) > 0.01: fails.append("sulu büyüme %.3f" % e.progress)
	if absf(e.water - w_exp) > 0.01: fails.append("su azalması %.3f" % e.water)
	_start_weather("drought")
	_simulate(10.0)
	if absf(e.water - (w_exp - 30.0 / Data.WATER_DUR)) > 0.01: fails.append("kuraklık %.3f" % e.water)
	_start_weather("rain")
	e.water = 0.0
	_simulate(8.0)
	if e.water < 0.99: fails.append("yağmur %.3f" % e.water)
	_start_weather("snow")
	e.water = 0.0
	if _resolve("water", null, 9, 3) != null: fails.append("karda sulama")
	if absf(_grow_rate(e) - 0.6 * b) > 0.001: fails.append("kar hızı")
	_end_weather()
	season = 2
	if not _perform({"x": 8, "z": 3, "tool": "plow", "arg": null}): fails.append("sürme 4")
	if _resolve("seed", "tomato", 8, 3) != null: fails.append("sonbaharda domates ekildi")
	if _resolve("seed", "pumpkin", 8, 3) != "plant": fails.append("sonbaharda balkabağı")
	var tree_e = tiles[key(9, 5)]
	tree_e.has_fruit = false
	tree_e.age = 1.0
	season = 3
	season_t = 1.0 - 0.5 / Data.SEASON_LEN
	var y0 := year
	_simulate(1.0)
	if season != 0 or year != y0 + 1: fails.append("mevsim geçişi %d/%d" % [season, year])
	if not tree_e.has_fruit: fails.append("mevsim meyvesi")
	_end_weather()

# ============================================================ ambar, satış, sipariş (Aşama 1)
func _res_total() -> int:
	var t := 0
	for k in res:
		t += res[k]
	return t

## Hasadın kaynağını ambara koyar; yer yoksa sığdığı kadarını.
func _store(src: String, pos: Vector3, extra := 0) -> void:
	if not Data.YIELD.has(src):
		return
	var r: String = Data.YIELD[src][0]
	var amt: int = Data.YIELD[src][1] + extra
	var add := mini(amt, Data.BARN_CAP - _res_total())
	if add > 0:
		res[r] = res.get(r, 0) + add
		_float_text(pos + Vector3(0.35, -0.15, 0), "+%d %s" % [add, Data.RESOURCES[r].icon], Color("#e6f7ff"))
	if add < amt:
		_toast("📦 Ambar dolu! B ile aç, kaynak sat.", "warn")
	if barn.visible:
		_render_barn()

func _sell(r: String, n: int) -> void:
	n = mini(n, res.get(r, 0))
	if n <= 0:
		return
	res[r] -= n
	var gain_c: int = n * Data.RESOURCES[r].price
	coins += gain_c
	_quest_event("sell", r, n)
	_quest_event("earn", "", gain_c)
	hud_dirty = true
	_sfx("harvest")
	_toast("💰 %d %s satıldı: +%d 🪙" % [n, Data.RESOURCES[r].icon, gain_c])
	_render_barn()

## Oyuncunun seviyesinde üretebildiği kaynaklardan rastgele bir sipariş.
func _new_order() -> void:
	var avail := []
	for list in [Data.CROPS, Data.TREES, Data.ANIMALS, Data.garden()]:
		for k in list:
			if list[k].level <= level and Data.YIELD.has(k):
				var r: String = Data.YIELD[k][0]
				if not avail.has(r):
					avail.append(r)
	avail.shuffle()
	var need := {}
	var value := 0
	for i in mini(2, avail.size()):
		var n := randi_range(4, 8) + level * 2
		need[avail[i]] = n
		value += n * int(Data.RESOURCES[avail[i]].price)
	order = {"need": need, "medals": maxi(1, value / 40), "xp": maxi(5, value / 4), "coins": int(value * 1.5)}

func _can_deliver() -> bool:
	if order.is_empty():
		return false
	for r in order.need:
		if res.get(r, 0) < order.need[r]:
			return false
	return true

func _deliver() -> void:
	if not _can_deliver():
		return
	for r in order.need:
		res[r] -= order.need[r]
	medals += order.medals
	_quest_event("order", "", 1)
	var got: int = order.medals
	_gain(order.coins, order.xp, farmer.position, "🏅")
	_new_order()
	_toast("📋 Sipariş teslim edildi! +%d 🏅" % got, "level")
	hud_dirty = true
	_render_barn()

func _open_barn() -> void:
	help.visible = false
	barn.visible = true
	_render_barn()

func _build_barn_ui() -> void:
	barn = ColorRect.new()
	barn.color = Color(0.12, 0.2, 0.08, 0.35)
	barn.set_anchors_preset(Control.PRESET_FULL_RECT)
	barn.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(barn)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	barn.add_child(cc)
	var p := _panel(20)
	p.custom_minimum_size = Vector2(580, 0)
	cc.add_child(p)
	barn_box = VBoxContainer.new()
	barn_box.add_theme_constant_override("separation", 8)
	p.add_child(barn_box)
	barn.visible = false

func _small_btn(text: String, cb: Callable, enabled := true, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 32)
	b.disabled = not enabled
	if primary:
		_btn_styles(b, Color("#6fbf3b"), Color("#7fcf4b"))
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			b.add_theme_color_override(st, Color.WHITE)
	else:
		_btn_styles(b, Color("#f3e6cf"), Color("#ead9bb"))
	if not enabled:
		b.modulate = Color(1, 1, 1, 0.5)
	b.pressed.connect(cb)
	return b

func _change_order() -> void:
	if coins < 20:
		return
	coins -= 20
	hud_dirty = true
	_new_order()
	_render_barn()

func _render_barn() -> void:
	for c in barn_box.get_children():
		barn_box.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	var t := Label.new()
	t.text = "📦 Ambar   %d / %d" % [_res_total(), Data.BARN_CAP]
	t.add_theme_font_size_override("font_size", 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_small_btn("  ✕  ", func(): barn.visible = false))
	barn_box.add_child(head)
	var fill := ProgressBar.new()
	fill.show_percentage = false
	fill.custom_minimum_size = Vector2(0, 8)
	fill.max_value = Data.BARN_CAP
	fill.value = _res_total()
	fill.add_theme_stylebox_override("background", _sb(Color("#eadcc6"), 4, Color(0, 0, 0, 0), 0, 0))
	fill.add_theme_stylebox_override("fill", _sb(Color("#e0a030") if _res_total() > Data.BARN_CAP * 0.85 else Color("#5cbf2f"), 4, Color(0, 0, 0, 0), 0, 0))
	barn_box.add_child(fill)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	var any := false
	for r in Data.RESOURCES:
		var n: int = res.get(r, 0)
		if n <= 0:
			continue
		any = true
		var info = Data.RESOURCES[r]
		var nm := Label.new()
		nm.text = "%s %s" % [info.icon, info.name]
		nm.custom_minimum_size = Vector2(150, 0)
		grid.add_child(nm)
		var cnt := Label.new()
		cnt.text = "× %d" % n
		cnt.custom_minimum_size = Vector2(60, 0)
		grid.add_child(cnt)
		var pr := Label.new()
		pr.text = "%d🪙/adet" % info.price
		pr.add_theme_color_override("font_color", Color("#8a7260"))
		grid.add_child(pr)
		var rr: String = r
		grid.add_child(_small_btn("Sat 10", func(): _sell(rr, 10)))
		grid.add_child(_small_btn("Tümü (+%d🪙)" % (n * int(info.price)), func(): _sell(rr, 999999), true, true))
	if any:
		barn_box.add_child(grid)
	else:
		var e := Label.new()
		e.text = "Ambar boş. Hasat edince kaynaklar buraya gelir."
		e.add_theme_color_override("font_color", Color("#8a7260"))
		barn_box.add_child(e)

	barn_box.add_child(HSeparator.new())
	var ot := Label.new()
	ot.text = "📋 Pazar Siparişi"
	ot.add_theme_font_size_override("font_size", 19)
	barn_box.add_child(ot)
	var need_parts := []
	for r in order.get("need", {}):
		var have: int = res.get(r, 0)
		var want: int = order.need[r]
		var mark := "✅" if have >= want else "▫️"
		need_parts.append("%s %s %s  %d / %d" % [mark, Data.RESOURCES[r].icon, Data.RESOURCES[r].name, mini(have, want), want])
	var nl := Label.new()
	nl.text = "\n".join(need_parts)
	barn_box.add_child(nl)
	var rw := Label.new()
	rw.text = "Ödül:  🏅 %d   ·   +%d XP   ·   +%d 🪙" % [order.get("medals", 0), order.get("xp", 0), order.get("coins", 0)]
	rw.add_theme_color_override("font_color", Color("#9a6a00"))
	barn_box.add_child(rw)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_small_btn("  Teslim et  ", _deliver, _can_deliver(), true))
	row.add_child(_small_btn("Değiştir (-20🪙)", _change_order, coins >= 20))
	barn_box.add_child(row)
