@tool
extends EditorScenePostImport

# glTF carries COLOR_0 for the sculpted complexion, but this Godot import
# produced a white material with vertex albedo disabled. Encode exported linear
# colors as sRGB before storage, matching the material colors in Compatibility.
func _post_import(scene: Node) -> Object:
	apply_vertex_materials(scene)
	return scene

func apply_vertex_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		var source: ArrayMesh = node.mesh
		var encoded := ArrayMesh.new()
		var has_colors := false
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array = source.surface_get_arrays(surface)
			var colors = arrays[Mesh.ARRAY_COLOR]
			if colors is PackedColorArray and not colors.is_empty():
				has_colors = true
				var srgb := PackedColorArray()
				for color in colors: srgb.append(color.linear_to_srgb())
				arrays[Mesh.ARRAY_COLOR] = srgb
				var imported: Material = node.get_active_material(surface)
				if imported is StandardMaterial3D:
					var material := imported.duplicate() as StandardMaterial3D
					material.vertex_color_use_as_albedo = true
					material.vertex_color_is_srgb = true
					node.set_surface_override_material(surface, material)
			encoded.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
			encoded.surface_set_material(surface, source.surface_get_material(surface))
		if has_colors: node.mesh = encoded
	for child in node.get_children(): apply_vertex_materials(child)
