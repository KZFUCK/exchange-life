extends RefCounted

const STARTER_DESKS=[[1,1],[2,1],[1,4],[2,4]]

# Existing native props; presentation only. They sit outside the walkable grid.
# Project integration passes res://assets/office_furnishings_v012 after import.
static func asset(asset_root:String,name:String)->Node3D:
	var path:=asset_root+"/"+name+".glb"
	if path.begins_with("res://"):
		return (load(path) as PackedScene).instantiate()
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	if doc.append_from_file(path,state)!=OK:
		push_error("Cannot load native office prop: "+path);return null
	return doc.generate_scene(state)

static func attach(room:Node3D,office:Dictionary,asset_root:String)->Array[Node3D]:
	var result:Array[Node3D]=[]
	var h:=float(office.height)*.9
	var board:=asset(asset_root,"whiteboard")
	if board!=null:
		board.name="CompanyBoard_v012";board.position=Vector3(4.65,.87,-h-.70);board.rotation.y=-PI/2
		board.set_meta("purpose","wall noticeboard; visual only; outside walking grid")
		room.add_child(board);result.append(board)
	var storage:=asset(asset_root,"sideboard")
	if storage!=null:
		storage.name="OfficeStorage_v012";storage.position=Vector3(-2.25,0,-h+1.95)
		storage.set_meta("purpose","documents and books; visual only; outside walking grid")
		room.add_child(storage);result.append(storage)
	var entrance:=asset(asset_root,"entrance")
	if entrance!=null:
		entrance.name="OfficeEntrance_v012";entrance.position=Vector3(0,0,-h-.70);entrance.scale=Vector3.ONE*.8
		entrance.set_meta("purpose","existing entrance facade; outside walking grid")
		room.add_child(entrance);result.append(entrance)
		var label:=Label3D.new();label.text="入口";label.position=Vector3(0,2.15,.12);label.font_size=44;label.pixel_size=.003
		label.modulate=Color("efe2bd");entrance.add_child(label)
	return result

static func station_role(station:Node3D,role_id:String)->void:
	if station.get_meta("office_role_v012","")==role_id:return
	for clone in station.find_children("RoleMonitorCopy*","MeshInstance3D",true,false):clone.free()
	var source_meshes:Array=station.asset.find_children("*","MeshInstance3D",true,false)
	for mesh in source_meshes:
		if not mesh.has_meta("original_transform_v012"):
			mesh.set_meta("original_transform_v012",mesh.transform);mesh.set_meta("original_visible_v012",mesh.visible)
		mesh.transform=mesh.get_meta("original_transform_v012");mesh.visible=mesh.get_meta("original_visible_v012")
		var monitor_part:bool=("monitor" in mesh.name and not "cable" in mesh.name) or "screen" in mesh.name or "code line" in mesh.name
		if role_id=="engineer" and monitor_part:
			var pivot:=Vector3(0,.881,0)
			var shape:=Transform3D(Basis.from_scale(Vector3.ONE*.72),pivot-pivot*.72+Vector3(-.14,0,0))
			mesh.transform=shape*mesh.transform
			var copy:=mesh.duplicate() as MeshInstance3D
			copy.name="RoleMonitorCopy_"+mesh.name;copy.position.x+=.65
			station.asset.add_child(copy)
		if mesh.name.begins_with("paper stack sheet"):
			var index:=int(str(mesh.name).get_slice("_",1)) if "_" in mesh.name else 0
			mesh.visible=index<4 if role_id=="engineer" else (index<10 if role_id=="analyst" else true)
		if mesh.name.begins_with("notebook") and role_id=="engineer":mesh.visible=false
	station.set_meta("office_role_v012",role_id)
	var plaque:=station.get_node_or_null("RoleDeskPlaque_v012") as Label3D
	if plaque==null:
		plaque=Label3D.new();plaque.name="RoleDeskPlaque_v012";station.add_child(plaque)
		var font:=SystemFont.new();font.font_names=PackedStringArray(["PingFang SC","Heiti SC"]);plaque.font=font
		plaque.font_size=24;plaque.pixel_size=.0032;plaque.outline_size=0;plaque.modulate=Color("574a34")
		plaque.position=station.asset.position+Vector3(.10,.883,-.33);plaque.rotation.x=-PI/2
	plaque.text={"engineer":"撮合","support":"客服","analyst":"行情"}.get(role_id,"业务")

static func world_bounds(node:Node3D)->AABB:
	var first:=true;var result:=AABB()
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		var box: AABB=mesh.get_aabb()
		for i in 8:
			var p:Vector3=mesh.global_transform*box.get_endpoint(i)
			if first:result=AABB(p,Vector3.ZERO);first=false
			else:result=result.expand(p)
	return result
