extends RefCounted

# Both templates retain the exact v009c imported meshes/materials and bind poses.
# Split at runtime so the original Blender/GLB and its import settings stay intact.
const SOURCE_PATH := "res://assets/character_body_v009/resident_body_v009c.glb"
static var worker_template: PackedScene
static var station_template: PackedScene

static func prepare() -> void:
	if worker_template != null:return
	var source: PackedScene=load(SOURCE_PATH)
	var worker:Node3D=source.instantiate()
	for child in worker.get_children():
		if child is MeshInstance3D and child.skin==null:child.free()
	var player:AnimationPlayer=worker.get_node("AnimationPlayer")
	for library_name in player.get_animation_library_list():
		var library:AnimationLibrary=player.get_animation_library(library_name).duplicate(true)
		player.remove_animation_library(library_name);player.add_animation_library(library_name,library)
		for action in library.get_animation_list():
			var animation:Animation=library.get_animation(action)
			for i in range(animation.get_track_count()-1,-1,-1):
				if not str(animation.track_get_path(i)).begins_with("ResidentMotionRig/"):animation.remove_track(i)
			animation.loop_mode=Animation.LOOP_LINEAR if action in ["Typing","SeatedIdle","StandIdle","WalkForward"] else Animation.LOOP_NONE
	worker_template=PackedScene.new();worker_template.pack(worker);worker.free()
	var station:Node3D=source.instantiate()
	station.get_node("ResidentMotionRig").free()
	var station_player:AnimationPlayer=station.get_node("AnimationPlayer")
	for library_name in station_player.get_animation_library_list():
		var library:AnimationLibrary=station_player.get_animation_library(library_name).duplicate(true)
		station_player.remove_animation_library(library_name);station_player.add_animation_library(library_name,library)
		for action in library.get_animation_list():
			var animation:Animation=library.get_animation(action)
			for i in range(animation.get_track_count()-1,-1,-1):
				if str(animation.track_get_path(i)).begins_with("ResidentMotionRig/"):animation.remove_track(i)
			animation.loop_mode=Animation.LOOP_LINEAR if action=="Typing" else Animation.LOOP_NONE
	station_template=PackedScene.new();station_template.pack(station);station.free()

static func worker() -> Node3D:
	prepare();return worker_template.instantiate()

static func station() -> Node3D:
	prepare();return station_template.instantiate()
