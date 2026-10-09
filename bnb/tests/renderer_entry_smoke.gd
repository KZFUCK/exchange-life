extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://scenes/operations.tscn").instantiate()
	game.store=load("res://scripts/operations_store.gd").new("/tmp/bnb-renderer-entry-%d.json"%OS.get_process_id())
	root.add_child(game);await process_frame;await process_frame
	game.starter_button.pressed.emit();game.hire_button.pressed.emit()
	var expected:=RenderingServer.get_current_rendering_method()=="gl_compatibility"
	var worker:Node3D=game.board.worker_nodes[1]
	var ok:bool=game.board.native_batch_enabled==expected and worker.skeleton.has_node("BatchedNativeActor_v014")==expected and game.model.valid(game.state)
	print("Renderer entry smoke: ",RenderingServer.get_current_rendering_method(),"; expected batch ",expected,"; passed ",ok)
	game.queue_free();await process_frame;quit(0 if ok else 1)
