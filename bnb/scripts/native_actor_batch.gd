extends RefCounted
static var lod_cache:Dictionary={}

static func original_lods(mesh:Mesh,surface:int) -> Array:
	var key:="%s:%d"%[mesh.get_instance_id(),surface]
	if lod_cache.has(key):return lod_cache[key]
	var data:Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
	var width:=2 if int(data.vertex_count)<65536 else 4
	var result:Array=[]
	for lod in data.get("lods",[]):
		var bytes:PackedByteArray=lod.index_data;var indices:=PackedInt32Array()
		indices.resize(bytes.size()/width)
		for i in range(indices.size()):indices[i]=bytes.decode_u16(i*2) if width==2 else bytes.decode_u32(i*4)
		result.append({"edge":float(lod.edge_length),"indices":indices})
	lod_cache[key]=result
	return result

# Diagnostic render batching only. Keep original named meshes hidden for source
# geometry checks and role material references. Do not edit the imported asset.
static func apply(worker) -> Dictionary:
	if worker.skeleton.has_node("BatchedNativeActor_v014"):
		return worker.skeleton.get_node("BatchedNativeActor_v014").get_meta("verification")
	var meshes:Array=worker.actor.find_children("*","MeshInstance3D",true,false)
	var groups:Dictionary={};var skin:Skin;var vertices_before:=0;var surfaces_before:=0
	for mesh in meshes:
		if mesh.skin==null or not mesh.visible:continue
		assert(mesh.transform.is_equal_approx(Transform3D.IDENTITY))
		assert(mesh.mesh.get_blend_shape_count()==0)
		if skin==null:skin=mesh.skin
		assert(mesh.skin==skin)
		for s in range(mesh.mesh.get_surface_count()):
			var material:Material=mesh.get_active_material(s)
			var id:=material.get_instance_id() if material!=null else 0
			if not groups.has(id):groups[id]={"material":material,"surfaces":[]}
			groups[id].surfaces.append([mesh,s])
			vertices_before+=mesh.mesh.surface_get_array_len(s);surfaces_before+=1
	var combined:=ArrayMesh.new();var lod_count:=0;var ranges:Array=[];var material_sources:Array=[];var old_visibility:Dictionary={}
	for group in groups.values():
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var first:MeshInstance3D=group.surfaces[0][0]
		var a:Array=first.mesh.surface_get_arrays(group.surfaces[0][1])
		var count:int=a[Mesh.ARRAY_WEIGHTS].size()/a[Mesh.ARRAY_VERTEX].size()
		if count==8:tool.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
		var parts:Array=[];var offset:=0
		for part in group.surfaces:
			tool.append_from(part[0].mesh,part[1],Transform3D.IDENTITY)
			var arrays:Array=part[0].mesh.surface_get_arrays(part[1])
			parts.append({"offset":offset,"full":arrays[Mesh.ARRAY_INDEX],"lods":original_lods(part[0].mesh,part[1])})
			ranges.append({"source":str(part[0].name),"surface":combined.get_surface_count(),"offset":offset,"count":arrays[Mesh.ARRAY_VERTEX].size()})
			material_sources.append([part[0],part[1],part[0].get_active_material(part[1]).get_instance_id()])
			offset+=arrays[Mesh.ARRAY_VERTEX].size()
		var lods:Dictionary={}
		# Conservative common error limits reuse exact original index buffers;
		# no vertex, skin weight or new simplification is generated.
		for limit in [.00001,.00004,.00016,.00064,.00256,.01024,.04096,.16384,.65536]:
			var indices:=PackedInt32Array();var reduced:=false
			for part in parts:
				var selected:PackedInt32Array=part.full
				for lod in part.lods:
					if lod.edge<=limit:selected=lod.indices;reduced=true
					else:break
				var shifted:=selected.duplicate()
				for i in range(shifted.size()):shifted[i]+=int(part.offset)
				indices.append_array(shifted)
			if reduced:lods[float(limit)]=indices
		var merged_arrays:=tool.commit_to_arrays()
		var flags:int=Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if count==8 else 0
		combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,merged_arrays,[],lods,flags)
		combined.surface_set_material(combined.get_surface_count()-1,group.material)
		lod_count+=lods.size()
	var visible:=MeshInstance3D.new();visible.name="BatchedNativeActor_v014"
	visible.mesh=combined;visible.skin=skin;visible.skeleton=NodePath("..")
	worker.skeleton.add_child(visible)
	for mesh in meshes:
		if mesh.skin!=null:old_visibility[str(mesh.name)]=mesh.visible;mesh.visible=false
	var vertices_after:=0
	for s in range(combined.get_surface_count()):vertices_after+=combined.surface_get_array_len(s)
	var record:={"source_meshes":meshes.size(),"source_surfaces":surfaces_before,"batched_surfaces":combined.get_surface_count(),"source_vertices":vertices_before,"batched_vertices":vertices_after,"original_skin_shared":true,"original_nodes_retained_hidden":true,"geometry_shape_changed":false,"source_LODs_carried":true,"source_LOD_index_groups":lod_count}
	visible.set_meta("verification",record)
	visible.set_meta("source_ranges",ranges);visible.set_meta("material_sources",material_sources);visible.set_meta("old_visibility",old_visibility)
	return record

static func restore(worker) -> void:
	if not worker.skeleton.has_node("BatchedNativeActor_v014"):return
	var visible:MeshInstance3D=worker.skeleton.get_node("BatchedNativeActor_v014")
	var old:Dictionary=visible.get_meta("old_visibility")
	visible.free()
	for mesh in worker.actor.find_children("*","MeshInstance3D",true,false):
		if old.has(str(mesh.name)):mesh.visible=old[str(mesh.name)]

static func synchronize_materials(worker) -> Dictionary:
	if not worker.skeleton.has_node("BatchedNativeActor_v014"):return apply(worker)
	var visible:MeshInstance3D=worker.skeleton.get_node("BatchedNativeActor_v014")
	for entry in visible.get_meta("material_sources"):
		if entry[0].get_active_material(entry[1]).get_instance_id()!=int(entry[2]):
			restore(worker);return apply(worker)
	return visible.get_meta("verification")
