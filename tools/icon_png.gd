extends SceneTree
## icon.svg → 256 px PNG (kurulum simgesi için). Kullanım: --headless --script res://tools/icon_png.gd -- <çıktı.png>
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"), 256.0 / 128.0)
	img.save_png(out)
	print("ICON OK ", img.get_size())
	quit()
