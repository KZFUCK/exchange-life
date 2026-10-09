extends Node3D
const Native=preload("res://scripts/native_office_asset.gd")
var actor:Node3D
var player:AnimationPlayer
var skeleton:Skeleton3D
var walking:=false
var working:=false
var role_id:="engineer"
var employee_id:=0
var clock:=0.0
var active:=true
var speed:=.25
var travel_speed:=.45
var workstation:Node3D
var action:=""
var target:=Vector3.ZERO
var initialized:=false
var skill_level:=1
var applied_role:=""
var progress:=0.0
var earned:Label3D
var previous_jobs:=-1
var earned_life:=0.0
var revenue:=0
var bubble:Label3D

func _ready() -> void:
	actor=Native.worker();add_child(actor)
	player=actor.get_node("AnimationPlayer");player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	skeleton=actor.get_node("ResidentMotionRig/Skeleton3D")
	bubble=Label3D.new();bubble.billboard=BaseMaterial3D.BILLBOARD_ENABLED; bubble.no_depth_test=true
	bubble.font_size=40;bubble.pixel_size=.006;bubble.position.y=1.85;bubble.outline_size=8;add_child(bubble)
	earned=Label3D.new();earned.billboard=BaseMaterial3D.BILLBOARD_ENABLED;earned.no_depth_test=true
	earned.font_size=48;earned.pixel_size=.008;earned.outline_size=10;earned.modulate=Color("a3e89a");earned.visible=false;add_child(earned)

func configure(pos:Vector3,employee:Dictionary,running:bool) -> void:
	target=pos
	if not initialized:position=target;initialized=true
	employee_id=int(employee.id);role_id=employee.role;skill_level=int(employee.get("level",1))
	walking=not employee.path.is_empty();working=employee.desk!=0 and not walking
	if working:position=target
	active=running;progress=employee.progress
	if applied_role!=role_id:
		applied_role=role_id
		var clothes:MeshInstance3D=actor.find_child("continuous green sweater",true,false)
		if clothes!=null and role_id!="engineer":
			var material:StandardMaterial3D=clothes.mesh.surface_get_material(0).duplicate()
			material.albedo_color=Color("8b678c") if role_id=="analyst" else Color("487eaa")
			clothes.material_override=material
	if walking:
		var next:Array=employee.path[0]
		var direction:=Vector3((float(next[0])-float(employee.pos[0]))*1.86,0,-(float(next[1])-float(employee.pos[1]))*.9)
		if direction.length()>.001:
			rotation.y=atan2(direction.x,direction.z)
			travel_speed=2*speed*(1.86 if absf(direction.x)>.001 else .9)
	else:rotation.y=0
	var desired:="WalkForward" if walking else ("Typing" if working and running else ("SeatedIdle" if working else "StandIdle"))
	if desired!=action:
		action=desired;player.play(action);player.advance(0)
	bubble.text=("工程" if role_id=="engineer" else ("市场" if role_id=="analyst" else "客服"))+" %d" % employee_id
	bubble.modulate=Color("f9dc79") if working else Color("f4f2e8")
	if previous_jobs>=0 and int(employee.get("jobs",0))>previous_jobs:
		earned.text="+¥%d" % revenue;earned_life=1.2
	previous_jobs=int(employee.get("jobs",0))
	align_body()

func align_body() -> void:
	if working:actor.position=Vector3(.19547,0,.918)
	else:
		var pelvis:Vector3=skeleton.get_bone_global_pose(skeleton.find_bone("Pelvis")).origin
		actor.position=Vector3(-pelvis.x,0,-pelvis.z)

func _process(delta:float) -> void:
	if actor==null:return
	earned_life=maxf(0,earned_life-delta);earned.visible=earned_life>0
	earned.position=Vector3(0,2.05+(1.2-earned_life)*.35,0)
	if active:
		position=position.move_toward(target,delta*travel_speed)
		player.advance(delta*(travel_speed/.225 if walking else 1.0));align_body()
	else:position=target
	if workstation!=null:workstation.synchronize(self)
