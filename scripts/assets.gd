class_name Assets
extends RefCounted
## CC0 3D modelleri (Kenney Nature Kit, Quaternius Crops / Farm Animals) yükler.
## Dosya yoksa null döner; çağıran taraf prosedürel modele düşer.

static var enabled := true
static var _scenes := {}
static var _fixed := {}
## Kenney paletini (nane yeşili/şeftali) oyunun sıcak paletine çevir.
const PALETTE := {
	"leafsGreen": "#4caf50", "leafsDark": "#2e7d32", "grass": "#66bb6a",
	"woodBark": "#8d6e63", "woodBarkDark": "#6d4c41", "woodInner": "#d7b98e",
	"dirt": "#9c8a7a", "_defaultMat": "#a8a39a",
}

static func exists(path: String) -> bool:
	if not enabled:
		return false
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path] != null

## Modeli örnekler, ölçekler, malzemelerini düzeltir. Dönen düğüm bir sarmalayıcıdır.
static func inst(path: String, s := 1.0, rot_y := 0.0, pos := Vector3.ZERO) -> Node3D:
	if not exists(path):
		return null
	var n: Node3D = _scenes[path].instantiate()
	n.scale = Vector3.ONE * s
	n.rotation.y = rot_y
	n.position = pos
	_fix(n)
	var w := Node3D.new()
	w.add_child(n)
	return w

## glTF/FBX malzemeleri çoğu zaman metalik=1 gelir ve gökyüzünü yansıtır; mat yapıyoruz.
static func _fix(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		var mi: MeshInstance3D = n
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D:
				if not _fixed.has(m):
					var c: BaseMaterial3D = m.duplicate()
					c.metallic = 0.0
					c.metallic_specular = 0.3
					c.roughness = 0.9
					if PALETTE.has(m.resource_name):
						c.albedo_color = Color(PALETTE[m.resource_name])
					_fixed[m] = c
				mi.set_surface_override_material(i, _fixed[m])
	for c in n.get_children():
		_fix(c)

static func anim_player(n: Node) -> AnimationPlayer:
	var ap := n.find_children("*", "AnimationPlayer", true, false)
	return ap[0] if ap.size() > 0 else null
