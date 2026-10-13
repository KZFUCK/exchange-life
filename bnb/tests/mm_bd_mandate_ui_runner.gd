extends "res://tests/mm_bd_ui_runner.gd"
const MandateStore=preload("res://scripts/mm_bd_mandate_store.gd")
const Channels=preload("res://scripts/mm_bd_channels.gd")
var fixture:String
func make_game()->Control:
	var g=Main.new();g.store=Store.new(fixture+".spot");g.mandate_store=MandateStore.new(fixture);g.channels=Channels.new(fixture+".lesson");return g
func write_work()->void:
	for i in range(3):game.controls["mandate_work_"+str(i)].text="客户授权、资金与成本已核对；未知状态需查询，异常先暂停并由风控确认恢复条件。"
	await frames()
func run()->void:
	qa="res://qa/mm_bd_onboarding_v2_ui/";fixture="/tmp/mm-mandate-ui-%d.json"%OS.get_process_id();root.size=Vector2i(1440,900);game=make_game();root.add_child(game);root.add_child(SyntheticOnly.new());await frames(8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa));var original_course:Dictionary=game.course.duplicate(true);var lessons_before:Dictionary=game.channels.state.duplicate(true)
	await click("channels_entry");await click("channel_client_0");check(game.page=="mandate" and game.mandate_view.s().phase=="discovery","channel lesson links to full Uniswap client workflow")
	for index in range(4):
		if index>0:
			await click("mandate_home");await click("mandate_%d"%index)
		await capture("discovery_%d"%index);await click("mandate_draft");check(game.mandate_view.s().phase=="discovery","incomplete new-channel discovery blocks pricing")
		for q in game.mandate_view.model.data.questions:await click("mandate_ask_"+q.id)
		await write_work();await click("mandate_draft");check(game.mandate_view.s().phase=="proposal","all channel-specific facts unlock proposal fields")
		await capture("proposal_%d"%index);await click("mandate_example");await write_work()
		if index==0:
			game.controls.mandate_form_fee.value=7000;await click("mandate_propose")
			for turn in game.mandate_view.model.scenario(game.mandate_view.s()).negotiation:
				await write_work();await click("mandate_answer_%d"%int(turn.correct))
			check(game.mandate_view.s().phase=="proposal","over-budget offer returns to live proposal UI")
			game.controls.mandate_form_fee.value=5300;await click("save");check(game.mandate_store.read_course().course.draft.fee==5300,"global save routes to new mandate draft")
			game.controls.mandate_form_fee.value=6000;await click("load");game.controls.confirm=game.confirmation.get_ok_button();await click("confirm")
			check(game.controls.mandate_form_fee.value==5300,"global load confirmation restores correct mandate draft")
		await write_work();await click("mandate_propose");await capture("negotiation_%d"%index)
		if index==0:
			await write_work();await click("mandate_answer_0");check(game.mandate_view.s().phase=="negotiation" and game.mandate_view.s().round==0,"wrong guarantee cannot advance first negotiation round")
		for turn in game.mandate_view.model.scenario(game.mandate_view.s()).negotiation:
			await write_work();await click("mandate_answer_%d"%int(turn.correct))
		check(game.mandate_view.s().phase=="execution","three actual objections lead to authorized delivery")
		if game.mandate_view.s().phase!="execution":finish();return
		for day in range(6):
			if day==0:await capture("delivery_%d"%index)
			if day==0:
				root.size=Vector2i(1200,720);await frames(6);await capture("delivery_%d_720p"%index)
				for id in ["mandate_day_keep","mandate_day_risk","mandate_day_pause"]:check(game.controls[id].get_global_rect().end.y<=game.size.y+1,"channel delivery actions pinned at laptop size")
			if day==1:root.size=Vector2i(1440,900);await frames(6)
			var e:Dictionary=game.mandate_view.model.scenario(game.mandate_view.s()).events[day];await write_work();await click("mandate_day_"+e.expected)
			if day==2:
				var before:Dictionary=game.mandate_view.course.duplicate(true);game.queue_free();await frames(3);game=make_game();root.add_child(game);await frames(8)
				check(game.page=="mandate" and game.mandate_view.model.same(before,game.mandate_view.course) and game.mandate_view.s().day==3,"new scene automatically resumes day three for this channel")
		check(game.mandate_view.s().phase=="handoff","UI requires actual internal handoff")
		await write_work();await click("mandate_handoff")
		check(game.mandate_view.s().phase=="debrief" and game.mandate_view.course.completed.size()==index+1,"complete mouse-driven mandate recorded exactly once")
		await capture("debrief_%d"%index);await click("mandate_export");check(game.status_label.text.contains("完整委托复盘已导出"),"complete mandate report exports proposal negotiations and delivery ledger")
	check(game.model.same(original_course,game.course),"original spot case progress unchanged")
	check(game.channels.same_state(lessons_before,game.channels.state),"mechanism quiz records unchanged")
	await click("nav_records");await capture("records")
	for i in range(4):check(is_instance_valid(game.controls.get("mandate_record_%d"%i)),"unified records includes new channel mandate")
	await click("nav_mandates");await capture("catalog");root.size=Vector2i(1200,720);await frames(6);await capture("catalog_720p")
	await click("mandate_resume");check(game.page=="mandate","resume control works at laptop size")
	root.size=Vector2i(1440,900);await frames(4)
	await click("nav_mandates");await click("mandate_assessment_0")
	check(game.mandate_view.s().mode=="assessment" and int(game.mandate_view.s().variant)>0,"independent mode chosen from real catalog control")
	for q in game.mandate_view.model.data.questions:await click("mandate_ask_"+q.id)
	var edit:TextEdit=game.controls.mandate_work_0;await click("mandate_work_0")
	var typed:String="客户确认预算与资产权属，未知授权待查。"
	for i in typed.length():
		var key:=InputEventKey.new();key.device=991;key.pressed=true;key.unicode=typed.unicode_at(i);root.push_input(key,true)
	await frames(3);check(edit.text==typed,"Chinese authored memo accepts real keyboard input")
	await click("save");check(game.mandate_store.read_course().course.work_drafts.memo_0["0"]==typed,"unfinished writing persists through explicit save")
	await click("load");game.controls.confirm=game.confirmation.get_ok_button();await click("confirm")
	check(game.controls.mandate_work_0.text==typed,"read-from-disk restores memo into visible text input")
	await click("nav_channels");await click("nav_mandates");await click("mandate_resume")
	check(game.controls.mandate_work_0.text==typed,"navigating away and back preserves unfinished memo")
	await write_work();await click("mandate_draft")
	check(not is_instance_valid(game.controls.get("mandate_example")),"independent proposal has no example-fill button")
	check(int(game.controls.mandate_form_risk.selected)==0,"authorization is not selected for learner")
	var p:Dictionary=game.mandate_view.model.default_proposal(game.mandate_view.s())
	for field in game.mandate_view.fields:
		if field=="risk":game.mandate_view.fields[field].select(int(p[field]))
		else:game.mandate_view.fields[field].value=p[field]
	await write_work();await click("mandate_propose")
	for turn in game.mandate_view.model.scenario(game.mandate_view.s()).negotiation:
		await write_work();await click("mandate_answer_%d"%int(turn.correct))
	check(game.mandate_view.s().phase=="execution","independent authored negotiation proceeds")
	for e in game.mandate_view.model.scenario(game.mandate_view.s()).events:
		await write_work();await click("mandate_day_"+e.expected)
	await write_work();await click("mandate_handoff")
	game.controls.mandate_review_author.text="测试带教"
	game.controls.mandate_review_feedback.text="测试反馈：逐项核对事实、授权和恢复条件，补充未确认问题。"
	for kind in ["memo","rationale","response","notice","handoff"]:game.controls["mandate_review_"+kind].select(2)
	var before_score:int=game.mandate_view.model.grade(game.mandate_view.s()).score
	await click("mandate_review_save")
	check(game.mandate_store.read_course().course.reviews.size()==1 and game.mandate_view.model.grade(game.mandate_view.s()).score==before_score,"local mentor rubric saves separately without changing automatic score")
	await click("mandate_export");check(game.status_label.text.contains("复盘已导出"),"independent report exports authored work and reviewer feedback")
	var active_before:Dictionary=game.mandate_view.course.active.duplicate(true)
	await click("nav_records");await click("mandate_record_review_0")
	check(not game.mandate_view.review_target.is_empty() and game.mandate_view.model.same(game.mandate_view.course.active,active_before),"historic record opens for mentor review without replacing current active course")
	game.controls.mandate_review_author.text="测试历史审阅"
	game.controls.mandate_review_feedback.text="历史交付审阅：补充证据来源及未确认授权，列出后续责任人。"
	await click("mandate_review_save")
	check(game.mandate_store.read_course().course.reviews.size()==2,"historic mentor feedback persists under the matching record hash")
	finish()
func finish()->void:
	var f:=FileAccess.open(qa+"ui_results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"mandates":game.mandate_view.course},"\t",true,true));f.close()
	print("Mandate graphical checks: %d; failures: %d"%[checks,failures.size()]);game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
