extends SceneTree
const Main=preload("res://scripts/mm_bd_main.gd")
const Store=preload("res://scripts/mm_bd_store.gd")
const Model=preload("res://scripts/mm_bd_mandate_model.gd")
const MandateStore=preload("res://scripts/mm_bd_mandate_store.gd")
const Channels=preload("res://scripts/mm_bd_channels.gd")
var fixture:String="/tmp/mm-mandate-v2-close-20261013-fixed.json"
var qa:String="res://qa/mm_bd_onboarding_v2_close_fixed"
func _initialize()->void:call_deferred("run")
func work()->Dictionary:return {"0":"客户需求和资金授权已核对，未确认事项需查询。","1":"明示状态和风险影响，保持原有资产和交易账。","2":"按恢复条件由风控审批，指定下次通知时间。"}
func run()->void:
	var verify:bool="--verify" in OS.get_cmdline_user_args();var model=Model.new();var save=MandateStore.new(fixture)
	if not verify:
		var s:Dictionary=model.initial(2);model.apply(s,{"kind":"begin"})
		for q in model.data.questions:model.apply(s,{"kind":"ask","id":q.id})
		model.apply(s,{"kind":"draft","work":work()});model.apply(s,{"kind":"propose","proposal":model.default_proposal(s),"work":work()})
		for turn in model.scenario(s).negotiation:model.apply(s,{"kind":"answer","choice":turn.correct,"work":work()})
		for i in range(2):model.apply(s,{"kind":"day","action":model.scenario(s).events[i].expected,"notify":true,"work":work()})
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
	model.apply(game.mandate_view.course.active,{"kind":"day","action":model.scenario(game.mandate_view.s()).events[2].expected,"notify":true,"work":work()});game.build()
	game.controls.mandate_work_0.text="关窗前未提交的客户通知草稿：等待核对和审批。"
	var expected_course:Dictionary=game.mandate_view.course.duplicate(true);expected_course.work_drafts={"notice_3":{"0":game.controls.mandate_work_0.text,"1":"","2":""}}
	var expected:=FileAccess.open(fixture+".expected",FileAccess.WRITE);expected.store_string(JSON.stringify(expected_course,"",true,true));expected.close()
	for button in game.find_children("*","BaseButton",true,false):button.disabled=true
	DisplayServer.window_set_title("BD研修 V2 · 书面草稿关窗验证独立档")
	print("Prepared new mandate saved day2 / uncommitted day3, awaiting native close.")
