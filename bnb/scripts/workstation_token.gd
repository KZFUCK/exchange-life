extends Node3D
const Native=preload("res://scripts/native_office_asset.gd")
var assigned:=false
var asset:Node3D
var player:AnimationPlayer
func _ready() -> void:
	asset=Native.station();asset.position=Vector3(.19547,0,.018);add_child(asset)
	player=asset.get_node("AnimationPlayer");player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
func synchronize(worker:Node3D) -> void:
	if worker==null or not worker.working:
		player.play("SeatedIdle");player.seek(0,true);return
	player.play(worker.action);player.seek(worker.player.current_animation_position,true)
