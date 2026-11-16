## Import script: select a .glb/.gltf/.blend, then in the Import dock set
## "Import Script" to this file and click Reimport. The model is saved with PS1 materials.
@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	PS1Convert.apply(scene)
	return scene
