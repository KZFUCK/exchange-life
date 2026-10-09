extends RefCounted
const Furnishings=preload("res://scripts/office_furnishings.gd")
const AREAS={
	"meeting":{"name":"短会角","behavior":"presentation_only","members":["sofa","coffeetable"]},
	"administration":{"name":"行政共享","behavior":"presentation_only","members":["printer","storage"]},
	"maintenance":{"name":"机房维护","behavior":"presentation_only","members":["server","boxes"]}
}

static func area_sign(parent:Node3D,title:String,position:Vector3,rotation:Vector3,font_size:int=50,pixel_size:float=.006) -> Label3D:
	var label:=Label3D.new();label.name="AreaSign_"+title;label.text=title
	var font:=SystemFont.new();font.font_names=PackedStringArray(["PingFang SC","Heiti SC"]);label.font=font
	label.font_size=font_size;label.pixel_size=pixel_size;label.outline_size=0;label.modulate=Color("665a42")
	label.position=position;label.rotation_degrees=rotation;parent.add_child(label);return label

static func attach(room:Node3D,office:Dictionary) -> Dictionary:
	var existing:=room.get_node_or_null("SharedSpaces")
	if existing!=null:existing.free()
	var group:=Node3D.new();group.name="SharedSpaces";room.add_child(group)
	var members:Dictionary={"meeting":[],"administration":[],"maintenance":[]}
	var h:=float(office.height)*.9;var w:=float(office.width)*1.86
	for node in room.get_children():
		var asset_name:String=node.get_meta("office_asset","")
		if node.name=="OfficeStorage_v012":asset_name="storage"
		for area in AREAS:
			if asset_name in AREAS[area].members:
				node.set_meta("shared_area",area);node.set_meta("behavior","presentation_only");members[area].append(node)
		if asset_name=="coffeetable":
			# Keep the entire old tabletop outside the grid, not just its origin.
			var bounds:=Furnishings.world_bounds(node)
			if bounds.end.x>-.98:node.position.x-=bounds.end.x+.98
		if asset_name=="plant":
			var bounds:=Furnishings.world_bounds(node)
			if bounds.end.z>-h+.40:node.position.z-=bounds.end.z+h-.40
	area_sign(group,"短会角",Vector3(-2.0,.01,-.72),Vector3(-90,0,0),65,.006)
	area_sign(group,"行政共享",Vector3(-3.20,2.0,-h+2.48),Vector3(0,90,0))
	area_sign(group,"机房维护",Vector3(w-5.35,2.08,-h-.77),Vector3.ZERO)
	group.set_meta("behavior","presentation_only")
	return members
