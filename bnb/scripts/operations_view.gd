extends Control
signal cell_clicked(cell:Array)
signal employee_clicked(id:int)
signal furniture_clicked(id:int)
const Worker=preload("res://scenes/worker_token.tscn")
const Station=preload("res://scenes/workstation_token.tscn")
const Batch=preload("res://scripts/native_actor_batch.gd")
const Light=preload("res://scripts/office_light.gd")
const SharedSpaces=preload("res://scripts/office_shared_spaces.gd")
const Furnishings=preload("res://scripts/office_furnishings.gd")
const Model=preload("res://scripts/operations_model.gd")
var model=Model.new()
var state:Dictionary={}
var placing:=false
var selecting_furniture:=false
var moving_furniture:=0
var hovered:Array=[]
var worker_nodes:Dictionary={}
var furniture_nodes:Dictionary={}
var time:=0.0
var paused:=false
var simulation_speed:=.25
var viewport:SubViewport
var camera:Camera3D
var stage:Node3D
var room:Node3D
var objects:Node3D
var ghost:Node3D
var room_level:=0
var furnishings_enabled:=true
var native_architecture_enabled:=true
var native_batch_enabled:=DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method()=="gl_compatibility"
var architecture_record:Dictionary={}
var shared_space_members:Dictionary={}

func _ready() -> void:
	custom_minimum_size=Vector2(560,350);mouse_filter=MOUSE_FILTER_STOP;clip_contents=true
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.size=Vector2i(1280,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X;add_child(viewport)
	var screen:=TextureRect.new();screen.texture=viewport.get_texture();screen.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	screen.stretch_mode=TextureRect.STRETCH_SCALE;screen.mouse_filter=MOUSE_FILTER_IGNORE;add_child(screen)
	stage=Node3D.new();viewport.add_child(stage);objects=Node3D.new();stage.add_child(objects)
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("efe1c6")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("fff1d6");env.ambient_light_energy=.35
	environment.environment=env;stage.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);light.light_energy=.55
	light.light_color=Color("fff0d6");light.shadow_enabled=true;light.directional_shadow_max_distance=40;stage.add_child(light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-30,140,0);fill.light_energy=.2;stage.add_child(fill)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;stage.add_child(camera);camera.current=true
	resized.connect(fit_camera)

func world(cell:Array) -> Vector3:return Vector3(float(cell[0])*1.86,0,-float(cell[1])*.9)

func point(cell:Array) -> Vector2:
	if camera==null:return Vector2.ZERO
	return camera.unproject_position(world(cell))*size/Vector2(viewport.size)

func tile_at(pos:Vector2) -> Array:
	var p:=pos*Vector2(viewport.size)/size
	var origin:=camera.project_ray_origin(p);var direction:=camera.project_ray_normal(p)
	var hit:=origin+direction*(-origin.y/direction.y)
	return [roundi(hit.x/1.86),roundi(-hit.z/.9)]

func box(parent:Node3D,position:Vector3,dimensions:Vector3,color:Color) -> MeshInstance3D:
	var item:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=dimensions;item.mesh=mesh;item.position=position
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.85;item.material_override=mat;parent.add_child(item);return item

func decoration(parent:Node3D,asset:String,pos:Vector3,angle:float=0.0) -> Node3D:
	var node:Node3D=(load("res://assets/office_decor_v011/"+asset+".glb") as PackedScene).instantiate()
	node.position=pos;node.rotation.y=angle;node.set_meta("office_asset",asset);parent.add_child(node);return node

func build_room() -> void:
	if room!=null:room.free()
	room=Node3D.new();stage.add_child(room);var o:=model.office(state);room_level=int(state.office)
	var w:=float(o.width)*1.86;var h:=float(o.height)*.9
	box(room,Vector3((w-1.86)/2-1.15,-.18,-(h-.9)/2-.65),Vector3(w+2.3,.3,h+1.3),Color("b6a080"))
	for y in range(int(o.height)):
		for x in range(int(o.width)):
			box(room,world([x,y])+Vector3(0,-.02,0),Vector3(1.845,.04,.885),Color("e7d4b5") if (x+y)%2==0 else Color("e0cba8"))
	# Back and left walls leave the two camera-facing edges open, like an office cutaway.
	box(room,Vector3((w-1.86)/2-1.15,1.12,-h-.88),Vector3(w+2.3,2.24,.16),Color("d4b892"))
	box(room,Vector3(-3.30,1.12,-(h-.9)/2-.65),Vector3(.16,2.24,h+1.3),Color("dfc39b"))
	for x in range(1,int(o.width)-1,3):
		box(room,Vector3(x*1.86,1.25,-h-.79),Vector3(1.4,1.1,.045),Color("927c62"))
		box(room,Vector3(x*1.86,1.25,-h-.76),Vector3(1.24,.94,.025),Color("a5cadd"))
		box(room,Vector3(x*1.86,1.25,-h-.74),Vector3(.055,.94,.025),Color("f2e9d8"))
	var sign:=Label3D.new();sign.text="MOONEX\n交易所人生";sign.position=Vector3(-3.20,1.55,-1.15);sign.rotation_degrees.y=90
	sign.font_size=64;sign.pixel_size=.006;sign.modulate=Color("584a35");room.add_child(sign)
	# Decorations occupy the physical border outside the walkable game grid.
	decoration(room,"tallplant",Vector3(-2.15,0,-h+1.0))
	decoration(room,"sofa",Vector3(-2.60,0,-2.15),PI/2)
	decoration(room,"coffeetable",Vector3(-1.45,0,-2.15))
	decoration(room,"printer",Vector3(-2.25,0,-h+2.9))
	decoration(room,"server",Vector3(w-2.1,0,-h-.15))
	decoration(room,"server",Vector3(w-3.2,0,-h-.15))
	decoration(room,"boxes",Vector3(w-4.45,0,-h-.15))
	decoration(room,"plant",Vector3(w-6.1,0,-h-.15))
	box(room,world(model.entrance(state))+Vector3(0,.015,0),Vector3(.8,.025,.7),Color("73927d"))
	if furnishings_enabled:
		Furnishings.attach(room,o,"res://assets/office_furnishings_v012")
		shared_space_members=SharedSpaces.attach(room,o)
	else:shared_space_members={}
	architecture_record=Light.apply(self,"res://assets/office_light_v013") if native_architecture_enabled else {}
	ghost=Node3D.new();room.add_child(ghost)
	fit_camera()

func fit_camera() -> void:
	if camera==null or state.is_empty() or size.y<1:return
	viewport.size=Vector2i(maxi(1,int(size.x)),maxi(1,int(size.y)))
	var o:=model.office(state)
	var w:=float(o.width)*1.86;var h:=float(o.height)*.9
	var lo:=Vector3(-3.4,-.35,-h-1.0);var hi:=Vector3(w-.7,2.5,.55)
	var target:Vector3=(lo+hi)/2
	camera.position=target+Vector3(12,11,14);camera.look_at(target);camera.size=w+h+4
	var screen_lo:=Vector2(INF,INF);var screen_hi:=Vector2(-INF,-INF)
	for x in [lo.x,hi.x]:
		for y in [lo.y,hi.y]:
			for z in [lo.z,hi.z]:
				var pixel:Vector2=camera.unproject_position(Vector3(x,y,z));screen_lo=screen_lo.min(pixel);screen_hi=screen_hi.max(pixel)
	var span:Vector2=screen_hi-screen_lo
	camera.size*=maxf(span.x/maxf(1,size.x-40),span.y/maxf(1,size.y-30))

func sync(data:Dictionary) -> void:
	state=data
	if stage==null or state.is_empty():return
	if room_level!=int(state.office):build_room()
	var live:={}
	for employee in state.staff:
		var id:=int(employee.id);live[id]=true
		if not worker_nodes.has(id):worker_nodes[id]=Worker.instantiate();objects.add_child(worker_nodes[id])
		worker_nodes[id].speed=simulation_speed
		worker_nodes[id].revenue=int(model.role(employee.role).revenue)
		var old_role:String=worker_nodes[id].applied_role
		worker_nodes[id].configure(world(employee.pos),employee,state.running)
		if native_batch_enabled:
			Batch.apply(worker_nodes[id])
			if old_role!=worker_nodes[id].applied_role:Batch.synchronize_materials(worker_nodes[id])
		else:Batch.restore(worker_nodes[id])
		worker_nodes[id].active=state.running and not paused
	for id in worker_nodes.keys():
		if not live.has(id):worker_nodes[id].free();worker_nodes.erase(id)
	live={}
	for desk in state.furniture:
		var id:=int(desk.id);live[id]=true
		if not furniture_nodes.has(id):furniture_nodes[id]=Station.instantiate();objects.add_child(furniture_nodes[id])
		furniture_nodes[id].position=world(desk.cell);furniture_nodes[id].assigned=desk.worker!=0
	for id in furniture_nodes.keys():
		if not live.has(id):furniture_nodes[id].free();furniture_nodes.erase(id)
	for worker in worker_nodes.values():worker.workstation=null
	for desk in state.furniture:
		var worker:Node3D=worker_nodes.get(int(desk.worker))
		if worker!=null:
			worker.workstation=furniture_nodes[int(desk.id)]
			if furnishings_enabled:Furnishings.station_role(furniture_nodes[int(desk.id)],worker.role_id)
		furniture_nodes[int(desk.id)].synchronize(worker)
	show_ghost()

func show_ghost() -> void:
	if ghost==null:return
	for c in ghost.get_children():c.free()
	if (placing or moving_furniture!=0) and hovered.size()==2 and model.inside(state,hovered):
		var error:String=model.move_error(state,moving_furniture,hovered) if moving_furniture!=0 else model.place_error(state,hovered)
		var color:=Color("75a170") if error.is_empty() else Color("c37360")
		for c in [hovered,[hovered[0],hovered[1]+1]]:box(ghost,world(c)+Vector3(0,.025,0),Vector3(1.82,.05,.84),color)

func _gui_input(event:InputEvent) -> void:
	if state.is_empty():return
	if event is InputEventMouseMotion:hovered=tile_at(event.position);show_ghost()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if selecting_furniture:
			var picked:=0;var closest:=INF
			for id in furniture_nodes:
				var bounds:=Furnishings.world_bounds(furniture_nodes[id]);var lo:=Vector2(INF,INF);var hi:=Vector2(-INF,-INF)
				for x in [bounds.position.x,bounds.end.x]:
					for y in [bounds.position.y,bounds.end.y]:
						for z in [bounds.position.z,bounds.end.z]:
							var p:=camera.unproject_position(Vector3(x,y,z))*size/Vector2(viewport.size);lo=lo.min(p);hi=hi.max(p)
				var rect:=Rect2(lo,hi-lo).grow(3)
				var distance:=rect.get_center().distance_to(event.position)
				if rect.has_point(event.position) and distance<closest:picked=int(id);closest=distance
			if picked!=0:furniture_clicked.emit(picked)
			accept_event();return
		if not placing and moving_furniture==0:
			for worker in worker_nodes.values():
				var p:=camera.unproject_position(worker.global_position+Vector3(0,.8,0))*size/Vector2(viewport.size)
				if p.distance_to(event.position)<24:employee_clicked.emit(worker.employee_id);accept_event();return
		cell_clicked.emit(tile_at(event.position));accept_event()
