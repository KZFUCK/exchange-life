extends SceneTree
const Main=preload("res://scripts/mm_bd_main.gd")
const Store=preload("res://scripts/mm_bd_store.gd")
const Model=preload("res://scripts/mm_bd_mandate_model.gd")
const MandateStore=preload("res://scripts/mm_bd_mandate_store.gd")
const Channels=preload("res://scripts/mm_bd_channels.gd")
var fixture:String="/tmp/mm-mandate-close-20261013.json"
var qa:String="res://qa/mm_mandates"
func _initialize()->void:call_deferred("run")
func run()->void:
	var verify:bool="--verify" in OS.get_cmdline_user_args();var model=Model.new();var save=MandateStore.new(fixture)
	if not verify:
		var s:Dictionary=model.initial(2);model.apply(s,{"kind":"begin"})
		for q in model.data.questions:model.apply(s,{"kind":"ask","id":q.id})
		model.apply(s,{"kind":"draft"});model.apply(s,{"kind":"propose","proposal":model.default_proposal(s)})
		for turn in model.scenario(s).negotiation:model.apply(s,{"kind":"answer","choice":turn.correct})
		for i in range(2):model.apply(s,{"kind":"day","action":model.scenario(s).events[i].expected,"notify":true})
		var error:String=save.write_course({"active":s,"completed":[],"draft":{}})
		if not error.is_empty():printerr(error);quit(1);return
	var game=Main.new();game.store=Store.new(fixture+".spot");game.mandate_store=save;game.channels=Channels.new(fixture+".lesson");root.add_child(game)
	for i in range(5):await process_frame
	if verify:
		var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture+".expected"))
		var ok:bool=game.page=="mandate" and model.same(game.mandate_view.course,expected) and game.mandate_view.s().day==3 and model.valid_course(expected)
		await RenderingServer.frame_post_draw;DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa));root.get_texture().get_image().save_png(qa+"/reopened.png")
		var f:=FileAccess.open(qa+"/close_results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"passed":ok,"day":game.mandate_view.s().day,"auto_resumed":game.page=="mandate","whole_course_matches":model.same(game.mandate_view.course,expected)},"\t"));f.close()
		print("Mandate native close/new process restore: ",ok);game.queue_free();await process_frame;quit(0 if ok else 1);return
	# Exercise close-save with a deliberately uncommitted test-only delivery state.
	model.apply(game.mandate_view.course.active,{"kind":"day","action":model.scenario(game.mandate_view.s()).events[2].expected,"notify":true});game.build()
	var expected:=FileAccess.open(fixture+".expected",FileAccess.WRITE);expected.store_string(JSON.stringify(game.mandate_view.course,"",true,true));expected.close()
	for button in game.find_children("*","BaseButton",true,false):button.disabled=true
	DisplayServer.window_set_title("BD研修 · 新委托关窗验证独立档")
	print("Prepared new mandate saved day2 / uncommitted day3, awaiting native close.")
