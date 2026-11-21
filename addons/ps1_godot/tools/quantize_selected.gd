## Editor tool: select textures in the FileSystem dock, open this script and run it
## (File > Run, Ctrl+Shift+X). Writes <name>_16c.png (16-color palette) next to each one.
@tool
extends EditorScript

const COLORS := 16
const DITHER := 0.0

func _run() -> void:
	for path in EditorInterface.get_selected_paths():
		var tex = load(path) if ResourceLoader.exists(path) else null
		if tex is Texture2D:
			var out := PS1Palette.quantize(tex, COLORS, DITHER)
			var dst: String = path.get_basename() + "_%dc.png" % COLORS
			out.get_image().save_png(ProjectSettings.globalize_path(dst))
			print("PS1 Maker: ", dst)
	EditorInterface.get_resource_filesystem().scan()
