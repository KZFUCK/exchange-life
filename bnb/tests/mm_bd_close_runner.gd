extends SceneTree
const Main=preload("res://scripts/mm_bd_main.gd")
const Model=preload("res://scripts/mm_bd_model.gd")
const Store=preload("res://scripts/mm_bd_store.gd")
var fixture:String="/tmp/mm-bd-close-20261013.json"
func _initialize()->void:call_deferred("run")
func run()->void:
	var args:PackedStringArray=OS.get_cmdline_user_args();var verify:bool="--verify" in args
	var model=Model.new()
	if not verify:
		var state:Dictionary=model.initial();model.apply(state,{"kind":"begin"})
		for q in model.data.questions:model.apply(state,{"kind":"ask","id":q.id})
		model.apply(state,{"kind":"draft"});model.apply(state,{"kind":"propose","proposal":model.default_proposal(state)});model.apply(state,{"kind":"answer","choice":1})
		for i in range(2):model.apply(state,{"kind":"day","action":"keep","notify":true})
		var error:String=Store.new(fixture).write_course({"active":state,"completed":[],"draft":{}})
		if not error.is_empty():printerr(error);quit(1);return
	var game=Main.new();game.store=Store.new(fixture);root.add_child(game)
	await process_frame;await process_frame;await process_frame
	if verify:
		var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture+".expected.json"))
		var ok:bool=model.valid_course(game.course) and model.same(expected,game.course) and game.s().day==3 and game.page=="execution"
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://qa/mm_bd/reopened.png")
		var f:=FileAccess.open("res://qa/mm_bd/close_results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"passed":ok,"day":game.s().day,"save_path":fixture,"automatic_resume":true},"\t"));f.close()
		print("MM BD close/new-process restore: ",ok);game.queue_free();await process_frame;quit(0 if ok else 1);return
	game.action({"kind":"day","action":"risk","notify":true})
	var f:=FileAccess.open(fixture+".expected.json",FileAccess.WRITE);f.store_string(JSON.stringify(game.course,"",true,true));f.close()
	for control in game.find_children("*","BaseButton",true,false):control.disabled=true
	DisplayServer.window_set_title("BD模拟器 · 关闭验证独立档")
	print("Prepared: saved day2, unsaved day3; awaiting actual native close")
	if "--notification-close" in args:
		await process_frame;await process_frame
		game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
