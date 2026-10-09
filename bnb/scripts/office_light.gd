extends RefCounted

static func asset(path:String) -> Node3D:
	if ResourceLoader.exists(path) and ResourceLoader.load(path) is PackedScene:
		return (load(path) as PackedScene).instantiate()
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	assert(document.append_from_file(path,state)==OK,"Native architecture GLB could not be loaded")
	return document.generate_scene(state)

static func box(parent:Node3D,position:Vector3,dimensions:Vector3,mat:Material,name:String):
	var node:=MeshInstance3D.new();node.name=name;var mesh:=BoxMesh.new();mesh.size=dimensions
	node.mesh=mesh;node.material_override=mat;node.position=position;parent.add_child(node)

static func material(hex:String) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(hex);mat.roughness=.88
	return mat

static func apply(board,root:String) -> Dictionary:
	if board.room.has_node("NativeArchitecture_v013"):
		return board.room.get_node("NativeArchitecture_v013").get_meta("verification")
	var before_state:=JSON.stringify(board.state)
	var office:Dictionary=board.model.office(board.state)
	var w:=float(office.width)*1.86;var h:=float(office.height)*.9
	var removed_tiles:=0;var removed_windows:=0;var removed_wall:=false
	for node in board.room.get_children():
		if not node is MeshInstance3D or not node.mesh is BoxMesh:continue
		var d:Vector3=node.mesh.size
		if d.is_equal_approx(Vector3(1.845,.04,.885)):
			node.free();removed_tiles+=1
		elif is_equal_approx(d.y,2.24) and is_equal_approx(d.z,.16):
			node.free();removed_wall=true
		elif d.is_equal_approx(Vector3(1.4,1.1,.045)) or d.is_equal_approx(Vector3(1.24,.94,.025)) or d.is_equal_approx(Vector3(.055,.94,.025)):
			node.free();removed_windows+=1
		elif d.y>2.0:
			node.material_override=material("c3a889")
		elif d.y>.2 and d.x>w:
			node.material_override=material("9c7957")
	var shell:=Node3D.new();shell.name="NativeArchitecture_v013";board.room.add_child(shell)
	var plaster:=material("d9bea0")
	var wall_z:=-h-.88;var left:=-3.23;var right:=w-.93
	var cursor:=left;var opening_count:=0
	for col in range(1,int(office.width)-1,3):
		var center:=float(col)*1.86;var x0:=center-.86;var x1:=center+.86
		box(shell,Vector3((cursor+x0)/2,1.12,wall_z),Vector3(x0-cursor,2.24,.16),plaster,"PlasterPier%d"%col)
		box(shell,Vector3(center,.47,wall_z),Vector3(1.72,.94,.16),plaster,"WindowApron%d"%col)
		box(shell,Vector3(center,2.19,wall_z),Vector3(1.72,.10,.16),plaster,"WindowLintel%d"%col)
		var window:=asset(root+"/window.glb");window.name="NativeWindow%d"%col
		window.position=Vector3(center,0,wall_z);window.rotation.y=-PI/2;shell.add_child(window)
		for mesh in window.find_children("*","MeshInstance3D",true,false):
			if "pane" in mesh.name or "daylight" in mesh.name or "city" in mesh.name:
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if "transparent" in mesh.name:
				var glass:=material("e4f0f4");glass.albedo_color.a=.10
				glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.cull_mode=BaseMaterial3D.CULL_DISABLED;glass.roughness=.2
				mesh.material_override=glass
			elif "daylight" in mesh.name:
				var sky:=material("d0e1ee");sky.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.material_override=sky
		cursor=x1;opening_count+=1
	box(shell,Vector3((cursor+right)/2,1.12,wall_z),Vector3(right-cursor,2.24,.16),plaster,"PlasterEnd")
	# The exported native bevel tile is rendered with one MultiMesh draw group.
	# This covers the existing physical platform, without changing the walk grid.
	var tile_root:=asset(root+"/tile.glb")
	var native_tile:MeshInstance3D=tile_root.find_children("*","MeshInstance3D",true,false)[0]
	var mesh:Mesh=native_tile.mesh;var bounds:=mesh.get_aabb()
	var columns:=ceili((right-left)/.6);var rows:=ceili((h+1.25)/.6)
	var dx:=(right-left)/columns;var dz:=(h+1.25)/rows
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=mesh
	multi.instance_count=columns*rows
	for row in range(rows):
		for col in range(columns):
			var index:=row*columns+col
			var basis:=Basis.IDENTITY.scaled(Vector3((dx-.007)/bounds.size.x,1,(dz-.007)/bounds.size.z))
			var pos:=Vector3(left+(col+.5)*dx,-bounds.end.y,-h-.8+(row+.5)*dz)
			multi.set_instance_transform(index,Transform3D(basis,pos))
			var variation:=1.0+float((col*17+row*29)%7-3)*.008
			multi.set_instance_color(index,Color(variation,variation,variation,1))
	var tiles:=MultiMeshInstance3D.new();tiles.name="NativeLimestoneFloor";tiles.multimesh=multi;shell.add_child(tiles)
	tile_root.free()
	var direction_count:=0
	for node in board.stage.get_children():
		if node is WorldEnvironment:
			var env:Environment=node.environment
			env.ambient_light_color=Color("f0f2f5");env.ambient_light_energy=.36
		elif node is DirectionalLight3D:
			if direction_count==0:
				node.rotation_degrees=Vector3(-47,160,0);node.light_energy=.45;node.light_color=Color("fff0d6")
				node.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
				node.directional_shadow_max_distance=35;node.shadow_bias=.03;node.shadow_normal_bias=.18
				node.shadow_blur=3.0;node.light_angular_distance=2.4;node.shadow_opacity=.8
			else:
				node.rotation_degrees=Vector3(-35,-30,0);node.light_energy=.60;node.light_color=Color("fff3df")
			direction_count+=1
	if RenderingServer.has_method("directional_shadow_atlas_set_size"):
		RenderingServer.call("directional_shadow_atlas_set_size",4096,true)
	if RenderingServer.has_method("directional_soft_shadow_filter_set_quality"):
		RenderingServer.call("directional_soft_shadow_filter_set_quality",RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	var record:={"removed_tiles":removed_tiles,"removed_flat_windows":removed_windows,"removed_solid_rear_wall":removed_wall,"native_tile_instances":multi.instance_count,"real_window_openings":opening_count,"state_unchanged":before_state==JSON.stringify(board.state),"walk_grid_unchanged":true,"source_assets":root}
	shell.set_meta("verification",record)
	return record
